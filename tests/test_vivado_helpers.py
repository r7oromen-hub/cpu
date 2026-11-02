"""Mock Vivado API tests; requires Python tkinter plus a matching Tcl runtime.

Run with an existing complete Python installation (Windows Anaconda works).
No Tk GUI/display is needed. Missing tkinter/init.tcl is a dependency error,
never a skipped or passing test. Search installed runtimes without installing.
"""
from pathlib import Path
import os
import shutil
import sys
import tempfile
try:
    import tkinter
except ImportError:
    tkinter = None
import unittest

ROOT = Path(__file__).resolve().parents[1]


def new_tcl_interpreter():
    if tkinter is None:
        raise RuntimeError("Python tkinter is missing. Use an existing Windows Python with Tcl, rather than the minimal WSL Python.")
    try:
        return tkinter.Tcl()
    except tkinter.TclError as original:
        # Relocated/bundled Python can include _tkinter without init.tcl. Look
        # only beside the current Python and installed PATH Python/Tcl tools.
        roots = {Path(sys.prefix), Path(sys.base_prefix), Path(sys.executable).parent}
        for command in ["python", "python3", "python.exe", "tclsh", "tclsh86"]:
            installed = shutil.which(command)
            if installed:
                directory = Path(installed).parent
                roots.update([directory, directory.parent])
        version = str(tkinter.TclVersion)
        previous = os.environ.get("TCL_LIBRARY")
        checked = []
        for root in sorted(roots):
            for subdir in [f"tcl{version}", f"tcl/tcl{version}", f"lib/tcl{version}",
                           f"Library/lib/tcl{version}", f"share/tcltk/tcl{version}"]:
                candidate = root / subdir
                if not (candidate / "init.tcl").is_file():
                    continue
                checked.append(str(candidate))
                os.environ["TCL_LIBRARY"] = str(candidate)
                try:
                    interpreter = tkinter.Tcl()
                    print("Using discovered Tcl runtime:", interpreter.eval("info library"))
                    return interpreter
                except tkinter.TclError:
                    # Tcl itself rejects incompatible patch-level libraries.
                    continue
        if previous is None:
            os.environ.pop("TCL_LIBRARY", None)
        else:
            os.environ["TCL_LIBRARY"] = previous
        raise RuntimeError("No usable Tcl init.tcl. Use an existing complete Python/Tcl installation; "
                           f"checked={checked}. Original initialization error: {original}") from original


class VivadoHelpersTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cpu-lab-vivado-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.tcl = new_tcl_interpreter()
        # Python reads the Unicode absolute path; Tcl evaluates the source text
        # and need not reinterpret a Chinese filename. Independent of cwd.
        self.tcl.eval((ROOT / "scripts/vivado_helpers.tcl").read_text(encoding="utf-8"))
        self.tcl.eval("""
            set ::properties [dict create clk_pll [dict create \
                CONFIG.PRIM_IN_FREQ 50.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 50.000 \
                CONFIG.CLKOUT2_REQUESTED_OUT_FREQ 100.000]]
            set ::reset_runs {}; set ::reset_targets {}; set ::generated {}
            proc get_ips {args} {return [lindex $args end]}
            proc get_runs {args} {return [lindex $args end]}
            proc get_property {property object} {return [dict get $::properties $object $property]}
            proc set_property {args} {
                foreach {property value} [lindex $args 1] {
                    dict set ::properties [lindex $args 2] $property $value
                }
            }
            proc reset_run {object} {lappend ::reset_runs $object}
            proc reset_target {target object} {lappend ::reset_targets $object}
            proc generate_target {target object} {lappend ::generated $object}
            proc get_files {args} {return {}}
            proc remove_files {args} {error {No stale COE should be removed in this fixture}}
            set ::violations {}
            proc get_drc_violations {args} {return $::violations}
        """)

    def test_default_clock_preserves_existing_ip(self):
        self.assertEqual(self.tcl.call("lab_configure_pll", str(self.repo), "remote", 1), 0)
        self.assertEqual(self.tcl.eval("llength $::reset_runs"), "0")

    def test_changed_clock_resets_only_pll(self):
        (self.repo / "config").mkdir()
        (self.repo / "config/clock.tcl").write_text("set cpu_clock_mhz 25.0\n")
        self.assertEqual(self.tcl.call("lab_configure_pll", str(self.repo), "remote", 1), 1)
        self.assertEqual(self.tcl.eval("set ::reset_runs"), "clk_pll_synth_1")
        self.assertEqual(self.tcl.eval("set ::generated"), "clk_pll")
        self.assertEqual(self.tcl.eval("dict get $::properties clk_pll CONFIG.CLKOUT2_REQUESTED_OUT_FREQ"), "100.0")
        self.assertEqual(self.tcl.call("lab_configure_pll", str(self.repo), "remote", 1), 0)
        self.assertEqual(self.tcl.eval("llength $::reset_runs"), "1")

    def make_ram_fixture(self):
        env = self.repo / "env"
        project = self.repo / "project"
        (env / "func/obj").mkdir(parents=True)
        for name in ["inst_ram", "data_ram"]:
            ip_dir = project / "ip" / name
            ip_dir.mkdir(parents=True)
            image = env / "func/obj" / f"{name}.coe"
            image.write_text("memory_initialization_radix=16;\nmemory_initialization_vector=\n00000001,ffffffff;\n")
            (ip_dir / f"{name}.mif").write_text("00000000000000000000000000000001\n11111111111111111111111111111111\n")
            self.tcl.call("dict", "set", "::properties", name, "CONFIG.Load_Init_File", "true")
            self.tcl.call("dict", "set", "::properties", name, "CONFIG.Coe_File", "../../../env/func/obj/" + name + ".coe")
        return env, project

    def test_existing_mif_seeds_snapshot_without_reset(self):
        env, project = self.make_ram_fixture()
        self.assertEqual(self.tcl.call("lab_restore_ram_images", str(env), str(project)), 0)
        self.assertEqual(self.tcl.eval("llength $::reset_runs"), "0")
        for name in ["inst_ram", "data_ram"]:
            self.assertEqual((project / "ip" / name / "init_snapshot.coe").read_bytes(),
                             (env / "func/obj" / f"{name}.coe").read_bytes())

    def test_same_path_changed_content_refreshes_only_affected_ram(self):
        env, project = self.make_ram_fixture()
        self.tcl.call("lab_restore_ram_images", str(env), str(project))
        (env / "func/obj/inst_ram.coe").write_text("memory_initialization_radix=16;\nmemory_initialization_vector=\n00000002,ffffffff;\n")
        # A mock generation product for the selected replacement image.
        (project / "ip/inst_ram/inst_ram.mif").write_text("00000000000000000000000000000010\n11111111111111111111111111111111\n")
        self.assertEqual(self.tcl.call("lab_restore_ram_images", str(env), str(project)), 1)
        self.assertEqual(self.tcl.eval("set ::reset_runs"), "inst_ram_synth_1")
        self.assertEqual(self.tcl.eval("set ::generated"), "inst_ram")
        self.assertEqual(self.tcl.call("lab_restore_ram_images", str(env), str(project)), 0)
        self.assertEqual(self.tcl.eval("llength $::reset_runs"), "1")

    def test_incomplete_generated_mif_cannot_seed_snapshot(self):
        env, project = self.make_ram_fixture()
        ip_dir = project / "ip/inst_ram"
        (ip_dir / "inst_ram.mif").write_text("00000000000000000000000000000001\n")
        with self.assertRaises(tkinter.TclError):
            self.tcl.call("lab_restore_ram_images", str(env), str(project))
        self.assertFalse((ip_dir / "init_snapshot.coe").exists())
        self.assertEqual(self.tcl.eval("set ::reset_runs"), "inst_ram_synth_1")

    def test_pulse_width_failure_and_missing_summary_are_rejected(self):
        report = self.repo / "timing.txt"
        report.write_text("    WNS(ns) WHS(ns) WPWS(ns)\n0.1 0.0 0 10 0.1 0.0 0 10 4.5 0.0 0 4\n")
        self.tcl.call("lab_check_pulse_width", str(report))
        report.write_text("    WNS(ns) WHS(ns) WPWS(ns)\n0.1 0.0 0 10 0.1 0.0 0 10 -0.1 -0.1 1 4\n")
        with self.assertRaises(tkinter.TclError):
            self.tcl.call("lab_check_pulse_width", str(report))
        report.write_text("Incomplete timing report\n")
        with self.assertRaises(tkinter.TclError):
            self.tcl.call("lab_check_pulse_width", str(report))

    def set_drc(self, check, severity):
        self.tcl.call("dict", "set", "::properties", "violation", "CHECK", check)
        self.tcl.call("dict", "set", "::properties", "violation", "SEVERITY", severity)
        self.tcl.eval("set ::violations {violation}")

    def test_unknown_drc_warning_is_rejected(self):
        self.tcl.call("lab_check_drc")
        self.set_drc("NSTD-1", "Warning")
        with self.assertRaises(tkinter.TclError):
            self.tcl.call("lab_check_drc")

    def test_only_reviewed_dsp_warning_severity_is_accepted(self):
        for check in ["DPIP-1", "DPOP-1", "DPOP-2"]:
            self.set_drc(check, "Warning")
            self.tcl.call("lab_check_drc")
            for severity in ["Error", "Critical Warning", "", "Unknown"]:
                self.set_drc(check, severity)
                with self.assertRaises(tkinter.TclError):
                    self.tcl.call("lab_check_drc")


if __name__ == "__main__":
    try:
        new_tcl_interpreter()
    except RuntimeError as error:
        print("TEST_DEPENDENCY_ERROR:", error, file=sys.stderr)
        sys.exit(2)
    unittest.main()
