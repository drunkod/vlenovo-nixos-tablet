#!/usr/bin/env python3
"""Read-only CPU/memory stability analyzer for time-bounded live trial.

Uses the same Linux /proc tick measurements as the original 30-minute
baseline. Rejects missing services, PID restarts and software fallback.
"""
from pathlib import Path
import argparse,csv,io,statistics
def analyze(path:Path,minimum:int=240):
    lines=path.read_text().splitlines()
    line=next((x for x in lines if x.startswith("# duration_s=")),None)
    if line is None:raise ValueError("Missing trace metadata")
    md=dict(x.split("=",1) for x in line[2:].split() if "=" in x)
    hz=int(md["hz"])
    records=list(csv.DictReader(io.StringIO('\n'.join(x for x in lines if x and not x.startswith('#')))))
    if len(records)<3:raise ValueError("Trace too short")
    time=[int(x["elapsed_s"]) for x in records]
    if time[-1]-time[0]<minimum:raise ValueError("Incomplete soak window")
    if any(b<=a or b-a>40 for a,b in zip(time,time[1:])):
        raise ValueError("Unreliable sampling interval")
    if any(x["services"]!="active" or x["wayland_socket"]!="present" for x in records):
        raise ValueError("Compositor or Wayland socket disappeared")
    if any(int(x["qml_llvmpipe_threads"])!=0 for x in records):
        raise ValueError("QML returned to software renderer")
    result={"samples":len(records),"seconds":time[-1]-time[0]}
    for process in ("flick","qml"):
        if len({x[process+"_pid"] for x in records})!=1:
            raise ValueError(f"{process} PID restart")
        ticks=[int(x[process+"_ticks"]) for x in records]
        rss=[int(x[process+"_rss_kb"]) for x in records]
        if any(b<a for a,b in zip(ticks,ticks[1:])):raise ValueError("CPU tick reset")
        if any(x<=0 for x in rss):raise ValueError("Invalid RSS")
        result[process]={
            "percent":100*(ticks[-1]-ticks[0])/(hz*result["seconds"]),
            "rss_start_mib":rss[0]/1024,
            "rss_end_mib":rss[-1]/1024,
            "rss_max_mib":max(rss)/1024,
            "rss_change_mib":(rss[-1]-rss[0])/1024,
        }
    return result
def format_report(r):
    lines=[
        "# Timed combined Flick EGL/QML stability trial",
        "",
        f"Observed runtime sample window: **{r['seconds']} seconds**, {r['samples']} samples.",
        "All sampled Flick/QML PIDs stayed constant, Flick service and Wayland socket were present, and QML llvmpipe workers remained at zero.",
        "",
        "| Process | CPU (of one core) | Start RSS | End RSS | Peak RSS | RSS change |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for process in ("flick","qml"):
        p=r[process]
        lines.append(f"| {process} | {p['percent']:.1f}% | {p['rss_start_mib']:.1f} MiB | {p['rss_end_mib']:.1f} MiB | {p['rss_max_mib']:.1f} MiB | {p['rss_change_mib']:+.1f} MiB |")
    lines += ["",f"Combined sampled Flick+QML CPU: **{r['flick']['percent']+r['qml']['percent']:.1f}% of one core**.", "",
              "These /proc readings do not establish physical display correctness, actual frame rate, render latency or a memory-leak-free long-term service. The timed rollback must be checked separately."]
    return '\n'.join(lines)+'\n'
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("trace",type=Path)
    p.add_argument("--minimum-seconds",type=int,default=240)
    args=p.parse_args()
    try:print(format_report(analyze(args.trace,args.minimum_seconds)),end="")
    except (ValueError,KeyError,AssertionError) as e:p.error(str(e))
