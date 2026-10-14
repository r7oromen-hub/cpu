"""Mock Vivado API tests for project reuse; run with python tests/test_vivado_helpers.py."""
from pathlib import Path
import tempfile
import tkinter
import unittest

ROOT = Path(__file__).resolve().parents[1]


class VivadoHelpersTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cpu-lab-vivado-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.tcl = tkinter.Tcl()
        # Use the documented repository-root invocation. Old Windows Tcl may
        # misdecode a Chinese absolute __file__ path, just as Vivado 2018.3 does.
        self.tcl.call("source", "scripts/vivado_helpers.tcl")
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


if __name__ == "__main__":
    unittest.main()
