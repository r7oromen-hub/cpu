"""Offline checks for RAM content and real-clock acceptance gates."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from xml.sax.saxutils import escape

MODULE = Path(__file__).resolve().parents[1] / 'scripts/collect_vivado_results.py'
SPEC = importlib.util.spec_from_file_location('collector', MODULE)
collector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(collector)


def write_xci(path, params):
    body = ''.join('<s:configurableElementValue s:referenceId="PARAM_VALUE.' + key
                   + '">' + escape(str(value)) + '</s:configurableElementValue>'
                   for key, value in params.items())
    path.write_text('<s:root xmlns:s="http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009">'
                    + body + '</s:root>', encoding='utf-8')


class CollectorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = self.root / 'environment'
        (self.env / 'func/obj').mkdir(parents=True)
        self.project = self.root / 'project'
        for name in ['inst_ram', 'data_ram', 'clk_pll']:
            (self.project / 'ip' / name).mkdir(parents=True)
        self.root_patch = patch.object(collector, 'ROOT', self.root)
        self.env_patch = patch.object(collector, 'ENV', self.env)
        self.root_patch.start()
        self.env_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.addCleanup(self.env_patch.stop)
        self.coe = 'memory_initialization_radix=16;\nmemory_initialization_vector=\n00000001\nffffffff'
        for name in ['inst_ram', 'data_ram']:
            path = self.env / 'func/obj' / (name + '.coe')
            path.write_text(self.coe, encoding='ascii')
            ip = self.project / 'ip' / name
            (ip / (name + '.mif')).write_text(format(1, '032b') + '\n' + format(0xffffffff, '032b') + '\n')
            write_xci(ip / (name + '.xci'), {'Load_Init_File': 'true', 'Coe_File': str(path)})
        write_xci(self.project / 'ip/clk_pll/clk_pll.xci',
                  {'PRIM_IN_FREQ': 50.0, 'CLKOUT1_REQUESTED_OUT_FREQ': 50.0,
                   'CLKOUT2_REQUESTED_OUT_FREQ': 100.0})
        self.timing = ('clk_50M {0.000 10.000} 20.000 50.000\n'
                       'cpu_clk_clk_pll {0.000 10.000} 20.000 50.000\n'
                       'timer_clk_clk_pll {0.000 5.000} 10.000 100.000\n')

    def test_original_coe_and_terminated_vector(self):
        path = self.env / 'func/obj/inst_ram.coe'
        self.assertEqual(collector.coe_words(path), [1, 0xffffffff])
        path.write_text(self.coe + ';\n', encoding='ascii')
        self.assertEqual(collector.coe_words(path), [1, 0xffffffff])

    def test_matching_generated_ram(self):
        hashes, matches = collector.verify_ram_images(self.project)
        self.assertEqual(hashes['inst_ram']['words'], 2)
        self.assertEqual(matches, [])

    def test_changed_coe_at_same_path_rejected(self):
        (self.env / 'func/obj/inst_ram.coe').write_text(self.coe.replace('00000001', '00000002'))
        with self.assertRaisesRegex(ValueError, 'differs'):
            collector.verify_ram_images(self.project)

    def test_incomplete_generated_mif_rejected(self):
        (self.project / 'ip/data_ram/data_ram.mif').write_text(format(1, '032b') + '\n')
        with self.assertRaisesRegex(ValueError, 'differs'):
            collector.verify_ram_images(self.project)

    def test_disabled_initialization_rejected(self):
        write_xci(self.project / 'ip/data_ram/data_ram.xci',
                  {'Load_Init_File': 'false', 'Coe_File': str(self.env / 'func/obj/data_ram.coe')})
        with self.assertRaisesRegex(ValueError, 'disabled'):
            collector.verify_ram_images(self.project)

    def test_actual_50mhz_clock_matches(self):
        self.assertEqual(collector.verify_clocks(self.project, self.timing)['cpu_clock_mhz'], 50)

    def test_config_changed_but_generated_pll_stale_rejected(self):
        (self.root / 'config').mkdir()
        (self.root / 'config/clock.tcl').write_text('set cpu_clock_mhz 25.0\n')
        with self.assertRaisesRegex(ValueError, 'PLL'):
            collector.verify_clocks(self.project, self.timing)

    def test_routed_clock_does_not_match_pll_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Routed clock'):
            collector.verify_clocks(self.project, self.timing.replace('20.000 50.000', '40.000 25.000'))


if __name__ == '__main__':
    unittest.main()
