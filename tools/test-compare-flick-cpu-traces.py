#!/usr/bin/env python3
"""Synthetic CPU delta and PID continuity regressions."""
import importlib.util
import tempfile
from pathlib import Path

mod=Path(__file__).with_name("compare-flick-cpu-traces.py")
spec=importlib.util.spec_from_file_location("cpu_compare",mod)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def sample(multiplier=1,pid_changed=False):
    head = "# duration_s=1800 interval_s=15 hz=100 flick=8 qml=9 native=10\n"
    head += ("timestamp_utc,elapsed_s,flick_pid,flick_ticks,flick_rss_kb,"
             "qml_pid,qml_ticks,qml_rss_kb,native_pid,native_ticks,native_rss_kb,"
             "qml_llvmpipe_threads,wayland_socket,services\n")
    rows=[]
    for t in range(0,1816,15):
        pid=12 if pid_changed and t>1000 else 8
        rows.append(f"2026-10-21T00:00:00Z,{t},{pid},{t*100*multiplier},102400,"
                    f"9,{t*30*multiplier},51200,10,{t*5*multiplier},20480,"
                    f"4,present,active\n")
    return head+"".join(rows)
with tempfile.TemporaryDirectory() as tmp:
    a=Path(tmp)/"a.csv";b=Path(tmp)/"b.csv"
    a.write_text(sample());b.write_text(sample(2))
    report=m.compare(a,b)
    assert "100.0%" in report and "200.0%" in report,report
    assert "+100.0 pp" in report
    assert "baseline 1 [4]; baseline 2 [4]" in report
    b.write_text(sample(2,True))
    try:m.compare(a,b)
    except ValueError as e:assert "changed" in str(e)
    else:raise AssertionError("PID change not rejected")
    b.write_text(sample(2).split("2026-10-21T00:00:00Z,900",1)[0])
    try:m.compare(a,b)
    except ValueError as e:assert "not a completed" in str(e)
    else:raise AssertionError("incomplete trace not rejected")
print("CPU_BASELINE_COMPARISON_REGRESSIONS=PASS")
