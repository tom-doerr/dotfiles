#!/usr/bin/env python3
"""Parser tests for scripts/nas-bcachefs-exporter.py.

The risk this guards: `bcachefs fs usage` prints only NONZERO rows in the
Pending reconcile block, so any positional assumption silently relabels one
category as another the moment a category appears or drains.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "nas-bcachefs-exporter.py"
SPEC = importlib.util.spec_from_file_location("nas_bcachefs_exporter", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
EX = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = EX
SPEC.loader.exec_module(EX)

USAGE = """Filesystem: 3ab5c853-6fc9-4df8-b5f5-46a65dfa313d
Size:             209519616836608
Used:             145179662303744
Online reserved:         12959744


         undegraded
1x:   8873090101760
2x:  54693421672448
3x:  79289844318720
4x:   2323226625536

cached:    10101926400
reserved:     29138944


Pending reconcile:           data  metadata
replicas:               906182656         0
compression:         791269617664         0
target:             2591180926976         0


Device label             Device     State            Size            Used  Use%        Leaving
hdd.exos1 (device 2):    sdg        rw     27992446201856  24663088046080   88%
ssd.lexar1 (device 10):  nvme0n1p1  rw      1765185417216   1711409149952   97%  1556210864128
"""


class ParseTest(unittest.TestCase):
    def setUp(self):
        self.totals, self.repl, self.pending, self.devs = EX.parse(USAGE)

    def test_pending_is_keyed_by_name_with_both_columns(self):
        self.assertEqual(self.pending["compression"], [791269617664, 0])
        self.assertEqual(self.pending["target"], [2591180926976, 0])
        self.assertEqual(self.pending["replicas"], [906182656, 0])

    def test_absent_pending_rows_are_absent_not_misattributed(self):
        # checksum/erasure_code/high_priority/pending/stripes were all zero here,
        # so bcachefs omitted them entirely. They must not inherit another row.
        for missing in ("checksum", "erasure_code", "high_priority", "stripes"):
            self.assertNotIn(missing, self.pending)

    def test_pending_survives_a_reordered_subset(self):
        text = USAGE.replace(
            "replicas:               906182656         0\n"
            "compression:         791269617664         0\n"
            "target:             2591180926976         0\n",
            "erasure_code:              4096         8\n"
            "target:             2591180926976         0\n",
        )
        _t, _r, pending, _d = EX.parse(text)
        self.assertEqual(pending, {"erasure_code": [4096, 8], "target": [2591180926976, 0]})

    def test_replication_table_is_split_out_of_totals(self):
        self.assertEqual(self.repl, {"1x": 8873090101760, "2x": 54693421672448,
                                     "3x": 79289844318720, "4x": 2323226625536})
        self.assertNotIn("1x", self.totals)

    def test_totals(self):
        self.assertEqual(self.totals["size"], 209519616836608)
        self.assertEqual(self.totals["used"], 145179662303744)
        self.assertEqual(self.totals["cached"], 10101926400)
        self.assertEqual(self.totals["online_reserved"], 12959744)

    def test_devices_including_optional_leaving_column(self):
        by_label = {d["label"]: d for d in self.devs}
        self.assertEqual(by_label["hdd.exos1"]["dev"], "sdg")
        self.assertIsNone(by_label["hdd.exos1"]["leaving"])
        self.assertEqual(by_label["ssd.lexar1"]["leaving"], "1556210864128")

    def test_render_emits_zero_for_missing_leaving(self):
        lines = EX.render(self.totals, self.repl, self.pending, self.devs)
        self.assertIn('nas_bcachefs_device_leaving_bytes{fs="pool",label="hdd.exos1",'
                      'device="sdg",state="rw"} 0', lines)
        self.assertIn('nas_bcachefs_replicated_bytes{fs="pool",copies="3"} 79289844318720', lines)


if __name__ == "__main__":
    unittest.main()
