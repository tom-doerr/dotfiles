#!/usr/bin/env python3
"""Tests for the pure decision/parsing logic of scripts/nas-fg-governor.

Run: python3 tests/nas_fg_governor_test.py
"""
import importlib.util
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "nas-fg-governor")

spec = importlib.util.spec_from_loader("nas_fg_governor", loader=None)
gov = importlib.util.module_from_spec(spec)
with open(SCRIPT) as f:
    code = compile(f.read(), SCRIPT, "exec")
gov.__dict__["__name__"] = "nas_fg_governor"
exec(code, gov.__dict__)  # noqa: S102 — load a script without .py suffix

ALLOC_DEBUG = """\
                     buckets         sectors      fragmented
free                   44323               0               0
sb                         2            4104            4088
journal                 8192               0               0
btree                  27015       106938880         3714660
user                  543833      1858592780       368956868
cached                 15764        22762219        41807275
need_gc_gens               0               0               0
"""

USAGE = """\
Filesystem: 3ab5c853-6fc9-4df8-b5f5-46a65dfa313d
Size:             209513462660096
Used:             186255926399488
Pending reconcile:           data  metadata
replicas:           2736177979392         0
erasure_code:       7261500993536         0
target:             1080569942016         0
high_priority:      2736177979392         0
"""


class ParseTests(unittest.TestCase):
    def test_alloc_debug_first_column(self):
        a = gov.parse_alloc_debug(ALLOC_DEBUG)
        self.assertEqual(a["free"], 44323)
        self.assertEqual(a["cached"], 15764)
        self.assertEqual(a["user"], 543833)
        self.assertNotIn("buckets", a)

    def test_headroom_pct(self):
        self.assertAlmostEqual(gov.headroom_pct(44323, 15764, 683729), 8.787, places=2)
        with self.assertRaises(ValueError):
            gov.headroom_pct(1, 1, 0)

    def test_hipri_pending(self):
        self.assertEqual(gov.parse_hipri_pending(USAGE), 2736177979392)
        with self.assertRaises(ValueError):
            gov.parse_hipri_pending("Size: 1\nUsed: 1\n")


class DecideTests(unittest.TestCase):
    LOW, HIGH, DWELL = 5.0, 9.0, 600.0

    def d(self, current, min_pct, hipri=0, now=10_000.0, last=0.0):
        return gov.decide(current, min_pct, self.LOW, self.HIGH, hipri, now, last,
                          self.DWELL, ssd_group="ssd", hdd_group="hdd")

    def test_ssd_flips_to_hdd_below_low(self):
        target, reason = self.d("ssd", 4.9)
        self.assertEqual(target, "hdd")
        self.assertIn("< low", reason)

    def test_ssd_safety_ignores_dwell(self):
        # just flipped to ssd 10 s ago, but headroom collapsed: still flip
        target, _ = self.d("ssd", 1.0, now=10.0, last=0.0)
        self.assertEqual(target, "hdd")

    def test_ssd_stays_between_watermarks(self):
        self.assertIsNone(self.d("ssd", 6.0)[0])
        self.assertIsNone(self.d("ssd", 50.0)[0])

    def test_hdd_stays_below_high(self):
        self.assertIsNone(self.d("hdd", 8.9)[0])

    def test_hdd_flips_back_when_all_conditions_hold(self):
        target, reason = self.d("hdd", 9.0)
        self.assertEqual(target, "ssd")
        self.assertIn("hipri 0", reason)

    def test_hdd_refuses_while_hipri_pending(self):
        target, reason = self.d("hdd", 20.0, hipri=1)
        self.assertIsNone(target)
        self.assertIn("high_priority pending", reason)

    def test_hdd_refuses_when_hipri_unknown(self):
        target, reason = self.d("hdd", 20.0, hipri=None)
        self.assertIsNone(target)
        self.assertIn("UNKNOWN", reason)

    def test_hdd_respects_dwell(self):
        target, reason = self.d("hdd", 20.0, now=100.0, last=0.0)
        self.assertIsNone(target)
        self.assertIn("dwell", reason)
        self.assertEqual(self.d("hdd", 20.0, now=600.0, last=0.0)[0], "ssd")

    def test_unmanaged_target_never_acts(self):
        for cur in ("none", "ssd.lexar1", ""):
            target, reason = self.d(cur, 0.0)
            self.assertIsNone(target)
            self.assertIn("not managed", reason)


if __name__ == "__main__":
    unittest.main(verbosity=1)
