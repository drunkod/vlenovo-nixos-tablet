#!/usr/bin/env python3
"""Read-only comparison of two /proc jiffy traces.

Only intended for the same tablet and workload, not statistical causal proof.
Five-minute windows expose baseline variation before an optimized A/B trial.
"""
from __future__ import annotations

import argparse
import csv
import io
import statistics
from pathlib import Path

PROCESSES = ("flick", "qml", "native")

def load(path: Path, min_seconds: int = 1800):
    text = path.read_text()
    lines = text.splitlines()
    header = next((x[2:] for x in lines if x.startswith("# duration_s=")), None)
    if not header:
        raise ValueError(f"{path.name}: metadata missing")
    meta = dict(part.split("=", 1) for part in header.split() if "=" in part)
    hz = float(meta["hz"])
    if hz <= 0:
        raise ValueError("invalid CLK_TCK")
    records = list(csv.DictReader(io.StringIO("\n".join(
        x for x in lines if x and not x.startswith("#")))))
    elapsed = [int(r["elapsed_s"]) for r in records]
    if len(records) < 2 or elapsed[-1] - elapsed[0] < min_seconds:
        raise ValueError(f"{path.name}: not a completed {min_seconds}s trace")
    if any(a >= b or b - a > 45 for a, b in zip(elapsed, elapsed[1:])):
        raise ValueError(f"{path.name}: sampling interval abnormal")
    for process in PROCESSES:
        pids = {r[f"{process}_pid"] for r in records}
        if len(pids) != 1 or "NA" in pids:
            raise ValueError(f"{path.name}: {process} process changed")
        ticks = [int(r[f"{process}_ticks"]) for r in records]
        if any(b < a for a, b in zip(ticks, ticks[1:])):
            raise ValueError(f"{path.name}: {process} CPU ticks reset")
    if any(r["services"] != "active" or r["wayland_socket"] != "present" for r in records):
        raise ValueError(f"{path.name}: service or Wayland display disappeared")
    return records, elapsed, hz

def measure(records, elapsed, hz):
    delta_seconds = elapsed[-1] - elapsed[0]
    result = {"duration": delta_seconds, "samples": len(records)}
    for process in PROCESSES:
        ticks = [int(r[f"{process}_ticks"]) for r in records]
        means = []
        for start in range(0, 1800, 300):
            stop = start + 300
            # Bounded bins based on recorded wall-clock endpoints, preserving
            # the actual delta time and weighting by elapsed duration.
            idx = [i for i,t in enumerate(elapsed) if start <= t <= stop]
            if len(idx) < 2:
                raise ValueError("missing 5-minute window")
            first,last=idx[0],idx[-1]
            means.append(100*(ticks[last]-ticks[first])/
                         (hz*(elapsed[last]-elapsed[first])))
        rss = [int(r[f"{process}_rss_kb"]) for r in records]
        result[process] = {
            "cpu_mean":100*(ticks[-1]-ticks[0])/(hz*delta_seconds),
            "five_min_means":means,
            "rss_median_mib":statistics.median(rss)/1024,
            "rss_max_mib":max(rss)/1024,
        }
    result["llvmpipe_threads"] = sorted({int(r["qml_llvmpipe_threads"]) for r in records})
    return result

def compare(one: Path, two: Path):
    a = measure(*load(one))
    b = measure(*load(two))
    lines = [
        "# Original Flick repeat-baseline stability",
        "",
        "Both independent traces were collected from the original running Flick; neither uses an optimized candidate.",
        f"First trace: {a['duration']}s, {a['samples']} samples. "
        f"Second trace: {b['duration']}s, {b['samples']} samples.",
        "",
        "| Process | Baseline 1 mean CPU | Baseline 2 mean CPU | Absolute delta | 5-min range (baseline 1) | 5-min range (baseline 2) | Median RSS 1 / 2 |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for process in PROCESSES:
        p,q = a[process],b[process]
        fm,sm=p["five_min_means"],q["five_min_means"]
        lines.append(
            f"| {process} | {p['cpu_mean']:.1f}% | {q['cpu_mean']:.1f}% | "
            f"{q['cpu_mean']-p['cpu_mean']:+.1f} pp | "
            f"{min(fm):.1f}–{max(fm):.1f}% | "
            f"{min(sm):.1f}–{max(sm):.1f}% | "
            f"{p['rss_median_mib']:.1f} / {q['rss_median_mib']:.1f} MiB |"
        )
    lines += [
        "",
        f"QML llvmpipe worker counts seen: baseline 1 {a['llvmpipe_threads']}; "
        f"baseline 2 {b['llvmpipe_threads']}.",
        "",
        "CPU percentages refer to a single logical core (100%=one fully busy core). "
        "Five-minute ranges are observed variation, not 95% confidence intervals. "
        "Physical workload, CPU frequency, background interrupts and thermals "
        "were not controlled. Changes after installing a candidate must therefore "
        "be assessed using repeated comparable measurements and graphics correctness, "
        "not just a single CPU percentage.",
    ]
    return "\n".join(lines)+"\n"

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("first",type=Path)
    parser.add_argument("second",type=Path)
    args=parser.parse_args()
    try:
        print(compare(args.first,args.second),end="")
    except (ValueError,KeyError) as e:
        parser.error(str(e))
