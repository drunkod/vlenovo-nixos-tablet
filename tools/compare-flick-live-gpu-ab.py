#!/usr/bin/env python3
"""Compare original and temporary live Flick CPU traces using /proc tick deltas.

These data are not randomized or physically supervised. Rejects invalid PID,
sample continuity, services, Wayland socket and llvmpipe-worker observations.
"""
from pathlib import Path
import argparse,csv,io,re
def load(path:Path,minimum:int,workers:int):
    contents=path.read_text().splitlines()
    header=next((line for line in contents if line.startswith("# duration_s=")),None)
    if not header:raise ValueError(f"{path}: missing timing metadata")
    props=dict(x.split("=",1) for x in header[2:].split() if "=" in x)
    hz=int(props['hz'])
    assert hz>0
    rows=list(csv.DictReader(io.StringIO('\n'.join(x for x in contents if x and not x.startswith("#")))))
    if len(rows)<3:raise ValueError(f"{path}: not enough samples")
    spans=[int(r["elapsed_s"]) for r in rows]
    if spans[-1]<minimum:raise ValueError(f"{path}: trace too short")
    if any(b<=a or b-a>31 for a,b in zip(spans,spans[1:])):
        raise ValueError(f"{path}: discontinuous samples")
    for group in ("flick","qml"):
        ids={r[group+"_pid"] for r in rows}
        if len(ids)!=1 or "NA" in ids or not all(i.isdigit() and int(i)>0 for i in ids):
            raise ValueError(f"{path}: {group} PID changed")
        ticks=[int(r[group+"_ticks"]) for r in rows]
        if any(b<a for a,b in zip(ticks,ticks[1:])):
            raise ValueError(f"{path}: counter reset")
    if any(r["services"]!="active" or r["wayland_socket"]!="present" for r in rows):
        raise ValueError(f"{path}: compositor/Wayland absent")
    if any(int(r["qml_llvmpipe_threads"])!=workers for r in rows):
        raise ValueError(f"{path}: unexpected software renderer changes")
    result={"span":spans[-1]-spans[0],"samples":len(rows),"workers":workers}
    for kind in ("flick","qml"):
        start,end=rows[0],rows[-1]
        result[kind]=100*(int(end[kind+"_ticks"])-int(start[kind+"_ticks"]))/(hz*result["span"])
        result[kind+"_rss_mib"]=int(end[kind+"_rss_kb"])/1024
    result["total"]=result["flick"]+result["qml"]
    return result

def main(args):
    records=[
      ("Original 30-min baseline A",load(args.baseline1,1800,4)),
      ("Original 30-min baseline B",load(args.baseline2,1800,4)),
      ("Qt EGL-only live",load(args.egl,45,0)),
      ("Qt EGL + QML skip live",load(args.combined,75,0))]
    print("# Flick physical tablet live graphics A/B CPU report")
    print()
    print("| Variant | Sample span | Flick CPU | QML CPU | Sum | QML llvmpipe workers |")
    print("|---|---:|---:|---:|---:|---:|")
    for name,r in records:
        print(f"| {name} | {r['span']} s | {r['flick']:.1f}% | {r['qml']:.1f}% | {r['total']:.1f}% | {r['workers']} |")
    base=records[0][1]
    base2=records[1][1]
    egl=records[2][1]
    qml=records[3][1]
    baseline=(base["total"]+base2["total"])/2
    print()
    print(f"Original combined CPU baseline mean: {baseline:.1f}% of one logical core.")
    print(f"EGL-only combined CPU change vs original: {(egl['total']/baseline-1)*100:.1f}%.")
    print(f"EGL+QML combined CPU change vs original: {(qml['total']/baseline-1)*100:.1f}%.")
    print(f"Flick-only CPU change with combined candidate: {(qml['flick']/((base['flick']+base2['flick'])/2)-1)*100:.1f}%.")
    print()
    print("Note: percentages are additive per-process CPU time, normalized to one logical core. "
          "Baseline spans 30 minutes each, while candidate trials last under 90 seconds; workload "
          "animation, CPU frequency and temperature are not precisely controlled. "
          "No visual/touch input correctness check was possible over SSH. "
          "No inference of sustained energy savings or compositor frame correctness. "
          "Both candidates were restored automatically via a root/systemd timer.")
if __name__=="__main__":
 p=argparse.ArgumentParser(description=__doc__)
 for opt in ("baseline1","baseline2","egl","combined"):p.add_argument(opt,type=Path)
 a=p.parse_args()
 try:main(a)
 except (ValueError,KeyError,AssertionError) as exc:p.error(str(exc))
