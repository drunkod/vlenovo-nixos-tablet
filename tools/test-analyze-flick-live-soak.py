#!/usr/bin/env python3
import importlib.util,tempfile
from pathlib import Path
spec=importlib.util.spec_from_file_location("soak",Path(__file__).with_name("analyze-flick-live-soak.py"))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
header="# duration_s=300 interval_s=10 hz=100 flick=101 qml=102 native=\n"
cols="timestamp_utc,elapsed_s,flick_pid,flick_ticks,flick_rss_kb,qml_pid,qml_ticks,qml_rss_kb,native_pid,native_ticks,native_rss_kb,qml_llvmpipe_threads,wayland_socket,services\n"
def generate(pid_change=False,soft=False):
    rows=[]
    for t in range(0,301,10):
        pid=201 if pid_change and t>=100 else 101
        ll=4 if soft and t>=100 else 0
        rows.append(f"2026-10-21T00:00:00Z,{t},{pid},{t*15},134000,102,{t*13},127000,,NA,NA,{ll},present,active\n")
    return header+cols+''.join(rows)
with tempfile.TemporaryDirectory() as td:
    p=Path(td)/"sample.csv"
    p.write_text(generate())
    r=m.analyze(p)
    assert r['seconds']==300 and abs(r['flick']['percent']-15)<1e-3
    assert abs(r['qml']['percent']-13)<1e-3
    assert "Combined sampled Flick+QML CPU" in m.format_report(r)
    p.write_text(generate(pid_change=True))
    try:m.analyze(p)
    except ValueError as e:assert "PID" in str(e)
    else:raise AssertionError("failed to detect PID change")
    p.write_text(generate(soft=True))
    try:m.analyze(p)
    except ValueError as e:assert "software" in str(e)
    else:raise AssertionError("failed to detect fallback")
    p.write_text(generate().split("2026-10-21T00:00:00Z,200",1)[0])
    try:m.analyze(p)
    except ValueError as e:assert "Incomplete" in str(e)
    else:raise AssertionError("failed to reject incomplete")
print("LIVE_FLICK_SOAK_PARSER_REGRESSIONS=PASS")
