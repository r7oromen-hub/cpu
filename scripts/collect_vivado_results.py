#!/usr/bin/env python3
"""Collect completed, non-stale remote FPGA results for this worktree."""
import hashlib
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "cdp_ede_local-master/mycpu_env"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xci_parameters(path):
    ns = '{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}'
    return {element.attrib[ns + 'referenceId']: element.text
            for element in ET.parse(path).iter(ns + 'configurableElementValue')}


def coe_words(path):
    text = path.read_text(encoding='ascii')
    if not re.search(r'memory_initialization_radix\s*=\s*16\s*;', text, re.I):
        raise ValueError('Expected hexadecimal COE: ' + str(path))
    vector = re.search(r'memory_initialization_vector\s*=\s*([^;]+);', text, re.I)
    if not vector:
        raise ValueError('COE vector missing: ' + str(path))
    return [int(word, 16) for word in re.split(r'[\s,]+', vector[1].strip())]


def verify_ram_images(project):
    hashes = {}
    for name in ['inst_ram', 'data_ram']:
        selected = ENV / 'func/obj' / (name + '.coe')
        ip_dir = project / 'ip' / name
        params = xci_parameters(ip_dir / (name + '.xci'))
        if params.get('PARAM_VALUE.Load_Init_File', '').lower() != 'true':
            raise ValueError(name + ': initialization disabled')
        configured = (ip_dir / params['PARAM_VALUE.Coe_File']).resolve()
        if configured != selected.resolve():
            raise ValueError(name + ': COE path does not match selected image')
        mif = ip_dir / (name + '.mif')
        lines = mif.read_text(encoding='ascii').splitlines()
        if not lines or any(not re.fullmatch(r'[01]{32}', line.strip()) for line in lines):
            raise ValueError(name + ': generated MIF has an invalid word')
        if [int(line.strip(), 2) for line in lines] != coe_words(selected):
            raise ValueError(name + ': generated MIF differs from selected COE')
        hashes[name] = {'selected_coe_sha256': sha256(selected),
                        'generated_mif_sha256': sha256(mif), 'words': len(lines)}
    matches = []
    for image in sorted((ROOT / 'for_test_obj').glob('ex*_obj')):
        if all(sha256(image / (name + '.coe')) == hashes[name]['selected_coe_sha256']
               for name in hashes):
            matches.append(image.name)
    return hashes, matches


def verify_clocks(project, timing):
    params = xci_parameters(project / 'ip/clk_pll/clk_pll.xci')
    actual = {name: float(params['PARAM_VALUE.' + key]) for name, key in
              [('input_clock_mhz', 'PRIM_IN_FREQ'),
               ('cpu_clock_mhz', 'CLKOUT1_REQUESTED_OUT_FREQ'),
               ('timer_clock_mhz', 'CLKOUT2_REQUESTED_OUT_FREQ')]}
    config = ROOT / 'config/clock.tcl'
    expected_cpu = 50.0
    if config.is_file():
        match = re.search(r'^\s*set\s+cpu_clock_mhz\s+(\d+(?:\.\d+)?)\s*$',
                          config.read_text(encoding='utf-8'), re.M)
        if not match:
            raise ValueError('Cannot read cpu_clock_mhz from config/clock.tcl')
        expected_cpu = float(match[1])
    if actual != {'input_clock_mhz': 50.0, 'cpu_clock_mhz': expected_cpu,
                  'timer_clock_mhz': 100.0}:
        raise ValueError('Generated PLL does not match requested clocks: ' + str(actual))
    for clock, expected in [('cpu_clk_clk_pll', expected_cpu),
                            ('timer_clk_clk_pll', 100.0), ('clk_50M', 50.0)]:
        match = re.search(r'^\s*' + clock + r'\s+\{[^}]+\}\s+(\d+\.\d+)\s+(\d+\.\d+)\s*$',
                          timing, re.M)
        if not match or abs(float(match[2]) - expected) > 0.001:
            raise ValueError('Routed clock missing or incorrect: ' + clock)
    return actual


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
        for name in ['synth_1', 'impl_1']:
            run_log = (runs / name / 'runme.log').read_text(errors='replace')
            if re.search(r'^(?:ERROR:|CRITICAL WARNING:)', run_log, re.M):
                raise ValueError(name + ': errors or critical warnings in run log')
        project = ROOT / 'build/vivado-remote'
        result.update(verify_clocks(project, timing))
        result['ram_images'], result['selected_images'] = verify_ram_images(project)
        inputs = list((ENV / "myCPU").glob("*.v"))
        inputs += list((ENV / "soc_verify/soc_bram/rtl").rglob("*.v"))
        inputs += list((ENV / "soc_verify/soc_bram/rtl").rglob("*.xci"))
        inputs += list((ROOT / "remote").glob("*.v"))
        inputs += list((ROOT / "remote").glob("*.xdc"))
        inputs += list((ENV / "func/obj").glob("*.coe"))
        inputs += list((ROOT / 'config').glob('*.tcl'))
        inputs += list((project / 'ip').rglob('*.xci'))
        stale = [str(p.relative_to(ROOT)) for p in inputs
                 if p.stat().st_mtime > bit.stat().st_mtime]
        if stale:
            raise ValueError("Inputs newer than bitstream: " + ", ".join(stale))
        result.update(status="PASS", drc_violations=0,
                      bitstream=str(bit.relative_to(ROOT)), bitstream_bytes=bit.stat().st_size,
                      bitstream_sha256=sha256(bit),
                      input_sha256={str(p.relative_to(ROOT)): sha256(p) for p in sorted(inputs)})
    except (OSError, ValueError, KeyError, ET.ParseError) as error:
        result["error"] = str(error)
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                                          encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "input_sha256"}, ensure_ascii=False))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
