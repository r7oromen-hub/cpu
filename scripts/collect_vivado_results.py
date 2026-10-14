#!/usr/bin/env python3
"""Collect completed, non-stale remote FPGA results for this worktree."""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "cdp_ede_local-master/mycpu_env"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    reports = ROOT / "test-results/vivado-remote"
    runs = ROOT / "build/vivado-remote/loongson.runs"
    bit = runs / "impl_1/looongson_remote_top.bit"
    result = {"status": "FAIL", "board_test": "NOT_RUN", "online_test": "NOT_RUN"}
    try:
        timing = (reports / "timing-summary.txt").read_text(errors="replace")
        drc = (reports / "drc.txt").read_text(errors="replace")
        log = (runs / "impl_1/runme.log").read_text(errors="replace")
        rows = re.findall(r"^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)"
                          r"\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)"
                          r"\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s*$",
                          timing, re.MULTILINE)
        if not rows:
            raise ValueError("Design Timing Summary row missing")
        row = rows[0]
        result.update(wns_ns=float(row[0]), tns_ns=float(row[1]),
                      whs_ns=float(row[4]), ths_ns=float(row[5]),
                      wpws_ns=float(row[8]), tpws_ns=float(row[9]))
        if any(result[key] < 0 for key in ["wns_ns", "whs_ns", "wpws_ns"]):
            raise ValueError("Setup, hold, or pulse-width timing failed")
        if any(result[key] != 0 for key in ["tns_ns", "ths_ns", "tpws_ns"]):
            raise ValueError("Timing has failing endpoints")
        if "Violations found: 0" not in drc:
            raise ValueError("DRC violations present or report incomplete")
        if not bit.is_file() or bit.stat().st_size < 1000:
            raise ValueError("Bitstream missing or incomplete")
        if "Bitgen Completed Successfully" not in log:
            raise ValueError("Successful bit generation marker missing")
        if not (runs / "impl_1/.vivado.end.rst").exists():
            raise ValueError("Implementation run has not completed")
        inputs = list((ENV / "myCPU").glob("*.v"))
        inputs += list((ENV / "soc_verify/soc_bram/rtl").rglob("*.v"))
        inputs += list((ENV / "soc_verify/soc_bram/rtl").rglob("*.xci"))
        inputs += list((ROOT / "remote").glob("*.v"))
        inputs += list((ROOT / "remote").glob("*.xdc"))
        inputs += list((ENV / "func/obj").glob("*.coe"))
        stale = [str(p.relative_to(ROOT)) for p in inputs
                 if p.stat().st_mtime > bit.stat().st_mtime]
        if stale:
            raise ValueError("Inputs newer than bitstream: " + ", ".join(stale))
        result.update(status="PASS", drc_violations=0,
                      bitstream=str(bit.relative_to(ROOT)), bitstream_bytes=bit.stat().st_size,
                      bitstream_sha256=sha256(bit),
                      input_sha256={str(p.relative_to(ROOT)): sha256(p) for p in sorted(inputs)})
    except (OSError, ValueError) as error:
        result["error"] = str(error)
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                                          encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "input_sha256"}, ensure_ascii=False))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
