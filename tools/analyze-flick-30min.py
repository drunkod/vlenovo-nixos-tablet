#!/usr/bin/env python3
"""Summarise Linux /proc jiffy samples from measure-flick-30min.sh.

No graphics or system writes. CLI: script path [--allow-partial].
By default reject a run under 30 minutes or with restarted processes.
"""
from __future__ import annotations
import csv
import io
import statistics
import sys
from pathlib import Path

def summarize(text: str, allow_partial: bool=False) -> str:
    lines = text.splitlines()
    header = next((line for line in lines if line.startswith("# duration_s=")), "")
    if not header:
        raise ValueError("Missing probe metadata")
    meta = dict(item.split("=", 1) for item in header.removeprefix("# ").split()
                if "=" in item)
    hz = float(meta["hz"])
    rows = list(csv.DictReader(io.StringIO("\n".join(
        line for line in lines if line and not line.startswith("#")))))
    if len(rows) < 2:
        raise ValueError("Need at least two complete samples")
    if any(len(row) != 14 or None in row for row in rows):
        raise ValueError("Malformed sample")
    elapsed = [int(row["elapsed_s"]) for row in rows]
    duration = elapsed[-1] - elapsed[0]
    if duration < 1800 and not allow_partial:
        raise ValueError(f"Incomplete 30-minute sample: {duration}s")
    if not all(a < b for a, b in zip(elapsed, elapsed[1:])):
        raise ValueError("Non-monotonic or duplicate sample elapsed")
    if max(b-a for a,b in zip(elapsed,elapsed[1:])) > 45:
        raise ValueError("Sampling gap over 45s; counters may not represent idle")
    errors = []
    stable = {}
    for label in ("flick", "qml", "native"):
        pids = {row[f"{label}_pid"] for row in rows}
        stable[label] = len(pids)==1 and "NA" not in pids and "" not in pids
        if not stable[label]:
            errors.append(f"{label} PID changed or missing")
    if any(r["services"] != "active" for r in rows):
        errors.append("Flick service became inactive")
    if any(r["wayland_socket"] != "present" for r in rows):
        errors.append("Wayland socket became absent")
    if errors:
        raise ValueError("; ".join(errors))
    out = [
        "# Read-only Flick CPU trace",
        "",
        f"Duration: **{duration}s** ({duration/60:.1f} minutes), "
        f"**{len(rows)}** samples, jiffy counter clock {hz:g}Hz.",
        f"Start (UTC): {rows[0]['timestamp_utc']}. End: {rows[-1]['timestamp_utc']}.",
        "All three process IDs remained stable; Flick service active and Wayland socket present in every sample.",
        "",
        "| Process | Mean CPU (one core = 100%) | Median 15s CPU | Peak 15s CPU | Median RSS |",
        "|---|---:|---:|---:|---:|",
    ]
    for label in ("flick", "qml", "native"):
        ts = [int(row[f"{label}_ticks"]) for row in rows]
        if any(b<a for a,b in zip(ts,ts[1:])):
            raise ValueError(f"{label} jiffy counter decreased")
        rates = [(b-a)/((tb-ta)*hz)*100
                 for a,b,ta,tb in zip(ts,ts[1:],elapsed,elapsed[1:])]
        mean = (ts[-1]-ts[0])/(duration*hz)*100
        rss = [int(r[f"{label}_rss_kb"]) for r in rows if r[f"{label}_rss_kb"]!="NA"]
        medianrss = (statistics.median(rss)/1024) if rss else float("nan")
        out.append(f"| {label} (PID {rows[0][f'{label}_pid']}) | "
                   f"{mean:.1f}% | {statistics.median(rates):.1f}% | "
                   f"{max(rates):.1f}% | {medianrss:.1f} MiB |")
    q = [int(row["qml_llvmpipe_threads"]) for row in rows]
    out += [
        "",
        f"QML llvmpipe worker threads: min={min(q)}, max={max(q)}, "
        f"median={statistics.median(q):g}.",
        "",
        "These are CPU-jiffy deltas averaged over the sampling period, "
        "not GPU-utilisation or instantaneous frequency readings. "
        "Screen/user activity and CPU frequency are not controlled. "
        "No optimized candidate was activated during this baseline.",
    ]
    return "\n".join(out)+"\n"

def main() -> None:
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("csv", type=Path)
    p.add_argument("--allow-partial", action="store_true")
    a=p.parse_args()
    try:
        print(summarize(a.csv.read_text(), a.allow_partial),end="")
    except (ValueError,KeyError) as e:
        p.error(str(e))

if __name__=="__main__":
    main()
