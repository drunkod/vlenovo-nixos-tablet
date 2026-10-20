#!/usr/bin/env python3
import importlib.util
from pathlib import Path
location=Path(__file__).with_name("analyze-flick-30min.py")
spec=importlib.util.spec_from_file_location("flick_analysis",location)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
header="# duration_s=1800 interval_s=15 hz=100 flick=1 qml=2 native=3\ntimestamp_utc,elapsed_s,flick_pid,flick_ticks,flick_rss_kb,qml_pid,qml_ticks,qml_rss_kb,native_pid,native_ticks,native_rss_kb,qml_llvmpipe_threads,wayland_socket,services\n"
def row(t,p=1,q=2,n=3):
    return f"2026-10-21T00:00:00Z,{t},{p},{t*100},102400,{q},{t*35},51200,{n},{t*5},20480,4,present,active\n"
good=header+row(0)+row(900)+row(1800)
# Synthetic 900s gaps should be blocked: use 15s samples for positive test
good=header+''.join(row(t) for t in range(0,1801,15))
out=module.summarize(good)
assert "30.0 minutes" in out and "100.0%" in out and "35.0%" in out
assert "min=4, max=4" in out
short=header+row(0)+row(15)
try:module.summarize(short)
except ValueError:pass
else:raise AssertionError("incomplete run accepted")
bad=header+''.join(row(t,p=1 if t<30 else 4) for t in range(0,1801,15))
try:module.summarize(bad)
except ValueError:pass
else:raise AssertionError("PID change accepted")
bad=header+''.join(row(t) for t in (0,15,1800))
try:module.summarize(bad)
except ValueError:pass
else:raise AssertionError("gap accepted")
print("FOUR_CPU_PARSER_REGRESSIONS_PASS")
