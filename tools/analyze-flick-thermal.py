#!/usr/bin/env python3
"""Summarize read-only tablet thermal and CPU clock samples, rejecting invalid traces."""
from __future__ import annotations
import argparse
import csv
import statistics
from pathlib import Path

EXPECTED=("timestamp_utc","elapsed_s","tcpu_mc","soc0_mc","soc1_mc",
          "cpu0_khz","cpu1_khz","cpu2_khz","cpu3_khz",
          "ac_online","battery_percent","flick_pid")

def summarize(path:Path, min_seconds:int=1500) -> str:
    with path.open(newline="") as stream:
        r=csv.DictReader(stream)
        if not r.fieldnames or tuple(r.fieldnames)!=EXPECTED:
            raise ValueError("Thermal telemetry schema mismatch")
        rows=list(r)
    if len(rows)<2:raise ValueError("Not enough thermal samples")
    try:
        t=[int(row["elapsed_s"]) for row in rows]
        temps={n:[int(row[n]) for row in rows]
               for n in ("tcpu_mc","soc0_mc","soc1_mc")}
        freqs={n:[int(row[n]) for row in rows]
               for n in ("cpu0_khz","cpu1_khz","cpu2_khz","cpu3_khz")}
        mains=[int(row["ac_online"]) for row in rows]
        battery=[int(row["battery_percent"]) for row in rows]
        pids={int(row["flick_pid"]) for row in rows}
    except ValueError as exc:
        raise ValueError("Non-numeric sensor value") from exc
    if t[-1]-t[0]<min_seconds:
        raise ValueError("Thermal capture too short")
    if any(b<=a or b-a>75 for a,b in zip(t,t[1:])):
        raise ValueError("Thermal interval gap/disorder")
    if len(pids)!=1 or next(iter(pids))<=0:
        raise ValueError("Flick PID changed or missing")
    if any(v < -10000 or v>130000 for values in temps.values() for v in values):
        raise ValueError("Impossible temperature value")
    if any(v<100000 or v>5000000 for values in freqs.values() for v in values):
        raise ValueError("Impossible CPU frequency")
    if any(v not in (0,1) for v in mains) or any(v<0 or v>100 for v in battery):
        raise ValueError("Power supply sensor invalid")
    lines=[
      "# Tablet thermal and clock-rate context",
      "",
      f"Span: {t[-1]-t[0]} seconds, {len(rows)} samples.",
      f"Active Flick PID {next(iter(pids))} was stable.",
      "",
      "| Probe | Minimum | Median | Maximum |",
      "|---|---:|---:|---:|",
    ]
    for label,n in (("CPU TCPU","tcpu_mc"),("SoC DTS0","soc0_mc"),("SoC DTS1","soc1_mc")):
        xs=temps[n]
        lines.append(f"| {label} | {min(xs)/1000:.1f}°C | {statistics.median(xs)/1000:.1f}°C | {max(xs)/1000:.1f}°C |")
    for n in ("cpu0_khz","cpu1_khz","cpu2_khz","cpu3_khz"):
        xs=freqs[n]
        lines.append(f"| {n} | {min(xs)/1000:.0f} MHz | {statistics.median(xs)/1000:.0f} MHz | {max(xs)/1000:.0f} MHz |")
    below=sum(1 for row in rows for n in freqs if int(row[n])<1500000)
    total=len(rows)*len(freqs)
    lines += [
        "",
        f"Samples with core frequency below 1500 MHz: {below} of {total} "
        f"({100*below/total:.1f}%).",
        f"AC mains online in {sum(mains)} of {len(mains)} samples; "
        f"battery charge range {min(battery)}–{max(battery)}%.",
        "",
        "A low frequency reading does not itself establish thermal throttling: "
        "CPUfreq governors change clocks for other reasons. This is an "
        "observational workload/temperature context, not a power-efficiency benchmark.",
    ]
    return "\n".join(lines)+"\n"

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("trace",type=Path)
    parser.add_argument("--allow-partial",action="store_true")
    a=parser.parse_args()
    try:
        print(summarize(a.trace,60 if a.allow_partial else 1500),end="")
    except ValueError as exc:
        parser.error(str(exc))
