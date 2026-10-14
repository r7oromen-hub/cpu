#!/usr/bin/env python3
"""Course-image regression with a separately compiled independent reference CPU.

Windows: python scripts/run_regression.py --image ex1_obj
Linux/WSL: python3 scripts/run_regression.py --image ex2_obj --mode stall
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "cdp_ede_local-master/mycpu_env"
POINT = re.compile(r"Number 8'd\s*(\d+) Functional Test Point PASS!!!")
EXPECTED_POINTS = {f"ex{i}_obj": count for i, count in enumerate([20, 20, 20, 29, 33, 39, 46], 1)}


def main():
    if os.name == "nt":
        # Let WSL perform compilation/simulation and use native Linux paths.
        script = subprocess.check_output(
            ["wsl", "-d", "Ubuntu", "--", "wslpath", "-u", str(Path(__file__).resolve())],
            text=True, encoding="utf-8").strip()
        return subprocess.call(["wsl", "-d", "Ubuntu", "--", "python3", script, *sys.argv[1:]])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", nargs="+", choices=[f"ex{i}_obj" for i in range(1, 10)], default=["ex1_obj"])
    parser.add_argument("--mode", choices=["forward", "stall"], default="forward")
    parser.add_argument("--timeout", type=int, default=240, help="Wall-clock seconds per subprocess")
    parser.add_argument("--define", action="append", default=[], help="Additional Verilog preprocessor macro")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    for name in ["iverilog", "vvp"]:
        if not shutil.which(name):
            parser.error(f"Required executable not found: {name}")
    results = []
    failed = False
    for image in args.image:
        out = ROOT / "test-results/raw" / f"{image}-{args.mode}"
        out.mkdir(parents=True, exist_ok=True)
        record = {"image": image, "mode": args.mode, "status": "FAIL"}
        start = time.monotonic()
        try:
            source = ROOT / "for_test_obj" / image
            obj = ENV / "func/obj"
            obj.mkdir(parents=True, exist_ok=True)
            hashes = {}
            for name in ["inst_ram.mif", "data_ram.mif", "inst_ram.coe", "data_ram.coe"]:
                shutil.copy2(source / name, obj / name)
                hashes[name] = hashlib.sha256((obj / name).read_bytes()).hexdigest()
            record["image_sha256"] = hashes
            golden = out / "golden_trace.txt"
            # Icarus packed-string file APIs reject non-ASCII bytes. Keep all
            # runtime file names relative to this ASCII-named output directory.
            inst_mif = os.path.relpath(obj / "inst_ram.mif", out)
            data_mif = os.path.relpath(obj / "data_ram.mif", out)
            if golden.exists():
                golden.unlink()
            ref_src = sorted((ENV / "gettrace/src").rglob("*.v"))
            soc = ENV / "soc_verify/soc_bram"
            dut_src = sorted((ENV / "myCPU").glob("*.v")) + sorted((soc / "rtl").glob("*.v"))
            dut_src += sorted((soc / "rtl/BRIDGE").glob("*.v")) + sorted((soc / "rtl/CONFREG").glob("*.v"))
            dut_src += [soc / "testbench/sync_ram.v", soc / "testbench/mycpu_tb.v"]
            defines = (["STALL_ONLY"] if args.mode == "stall" else []) + args.define

            def run(name, argv):
                log = out / f"{name}.log"
                try:
                    proc = subprocess.run(list(map(str, argv)), cwd=out, stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT, timeout=args.timeout)
                    data = proc.stdout
                except subprocess.TimeoutExpired as err:
                    data = err.stdout or b""
                    log.write_bytes(data[-2_000_000:])
                    raise RuntimeError(f"{name} timed out after {args.timeout}s") from err
                log.write_bytes(data[-2_000_000:])
                text = data.decode("utf-8", "replace")
                if proc.returncode:
                    raise RuntimeError(f"{name} returned {proc.returncode}; see {log.relative_to(ROOT)}")
                if re.search(r"\b(?:FATAL|ERROR|Error|Fail)\b", text):
                    raise RuntimeError(f"{name} reported an error; see {log.relative_to(ROOT)}")
                return text

            run("reference-compile", ["iverilog", "-g2012", "-Wall", "-s", "tb_top", "-o", out / "reference.vvp", *ref_src])
            ref_log = run("reference-run", ["vvp", "-n", "reference.vvp", f"+INST_MIF={inst_mif}", "+TRACE_FILE=golden_trace.txt"])
            if "----Succeed in generating trace file!" not in ref_log:
                raise RuntimeError("Reference completion marker missing")
            expected_points = list(map(int, POINT.findall(ref_log)))
            if not expected_points or expected_points != list(range(1, len(expected_points) + 1)):
                raise RuntimeError(f"Invalid reference point sequence: {expected_points}")
            if image in EXPECTED_POINTS and len(expected_points) != EXPECTED_POINTS[image]:
                raise RuntimeError(f"Reference completed {len(expected_points)} points; course image requires {EXPECTED_POINTS[image]}")
            trace_lines = golden.read_text().splitlines()
            expected_trace = sum(line.split()[0] == "1" for line in trace_lines if line.split())
            if not expected_trace:
                raise RuntimeError("Reference trace has no enabled writebacks")
            run("dut-compile", ["iverilog", "-g2012", "-Wall", "-s", "tb_top", "-I", ENV / "myCPU",
                                *[f"-D{macro}" for macro in defines], "-o", out / "dut.vvp", *dut_src])
            dut_log = run("dut-run", ["vvp", "-n", "dut.vvp", f"+INST_MIF={inst_mif}",
                                     f"+DATA_MIF={data_mif}", "+TRACE_FILE=golden_trace.txt"])
            actual_points = list(map(int, POINT.findall(dut_log)))
            count = re.search(r"TRACE_COMPARED=(\d+)", dut_log)
            if "----PASS!!!" not in dut_log or actual_points != expected_points:
                raise RuntimeError(f"DUT completion/point mismatch: {actual_points} vs {expected_points}")
            if not count or int(count[1]) != expected_trace:
                raise RuntimeError(f"Writeback count mismatch: {count[1] if count else 'missing'} vs {expected_trace}")
            record.update(status="PASS", functional_points=len(actual_points), compared_writebacks=expected_trace,
                          reference="gettrace/src/myCPU/SimpleLACoreWrapRAM.v (independent course reference)")
        except (OSError, RuntimeError, ValueError) as err:
            record["error"] = str(err)
            failed = True
        record["elapsed_seconds"] = round(time.monotonic() - start, 3)
        results.append(record)
        print(json.dumps(record, ensure_ascii=False), flush=True)
    summary = ROOT / "test-results" / f"regression-{args.mode}-{'-'.join(args.image)}.json"
    summary.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
