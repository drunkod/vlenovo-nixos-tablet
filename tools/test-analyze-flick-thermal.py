#!/usr/bin/env python3
import importlib.util
import tempfile
from pathlib import Path
p=Path(__file__).with_name("analyze-flick-thermal.py")
spec=importlib.util.spec_from_file_location("thermal_analysis",p)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as tmp:
    data=Path(tmp)/"thermal.csv"
    data.write_text("timestamp_utc,elapsed_s,tcpu_mc,soc0_mc,soc1_mc,cpu0_khz,cpu1_khz,cpu2_khz,cpu3_khz,ac_online,battery_percent,flick_pid\n"+
    "".join(f"2026-10-20T00:00:00Z,{t},68000,62000,64000,1866666,1866666,1866666,1866666,1,98,894\n" for t in range(0,1561,30)))
    s=mod.summarize(data)
    assert "68.0°C" in s and "1560 seconds" in s and "0.0%" in s
    data.write_text(data.read_text().replace(",68000,",",-273150,",1))
    try:mod.summarize(data)
    except ValueError as e:assert "Impossible" in str(e)
    else:raise AssertionError("invalid sensor accepted")
    data.write_text(data.read_text().replace("894\n","991\n",1))
    try:mod.summarize(data)
    except ValueError:pass
    else:raise AssertionError("changing PID accepted")
print("THERMAL_TRACE_REGRESSION_TESTS=PASS")
