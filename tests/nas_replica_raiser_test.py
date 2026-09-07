#!/usr/bin/env python3
"""Tests for the pure logic of scripts/nas-replica-raiser.

Run: python3 tests/nas_replica_raiser_test.py
"""
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "nas-replica-raiser")

spec = importlib.util.spec_from_loader("nas_replica_raiser", loader=None)
rr = importlib.util.module_from_spec(spec)
with open(SCRIPT) as f:
    code = compile(f.read(), SCRIPT, "exec")
rr.__dict__["__name__"] = "nas_replica_raiser"
exec(code, rr.__dict__)  # noqa: S102

HIPRI = """\
u64s 5 type set 2147706864:3052544:U32_MAX len 0 ver 0
u64s 5 type set 2147706864:3053056:U32_MAX len 0 ver 0
u64s 5 type set 6917529027641216822:512:U32_MAX len 0 ver 0
garbage line without the marker
"""

USAGE = """\
Filesystem: 3ab5c853-6fc9-4df8-b5f5-46a65dfa313d
Size:             209513462660096
Used:             148634303478272
Pending reconcile:           data  metadata
replicas:           2205763088384         0
erasure_code:       6745991892992         0
target:             1077937328128         0
high_priority:      2205763088384         0
"""


def F(ino, size, explicit, effective, path=None):
    return {"ino": ino, "size": size, "explicit": explicit, "effective": effective,
            "path": path or f"/pool/x/{ino}"}


class ParseTests(unittest.TestCase):
    def test_hipri_inodes(self):
        s = rr.parse_hipri_inodes(HIPRI.splitlines())
        self.assertEqual(s, {2147706864, 6917529027641216822})

    def test_usage(self):
        size, used, hipri = rr.parse_usage(USAGE)
        self.assertEqual((size, used, hipri), (209513462660096, 148634303478272, 2205763088384))
        # only nonzero rows are printed: no high_priority row == 0, not unknown
        self.assertEqual(rr.parse_usage("Size: 10\nUsed: 1\nPending reconcile: data metadata\ntarget: 5 0\n"), (10, 1, 0))
        with self.assertRaises(ValueError):
            rr.parse_usage("Pending reconcile:\nhigh_priority: 1 0\n")


class ClassifyTests(unittest.TestCase):
    def test_pending_wins(self):
        self.assertEqual(rr.classify(F(1, 10, None, 3), 3, {1}), "pending")

    def test_explicit_low_is_todo(self):
        self.assertEqual(rr.classify(F(1, 10, 1, 1), 3, set()), "todo")

    def test_inherited_low_is_todo(self):
        self.assertEqual(rr.classify(F(1, 10, None, 2), 3, set()), "todo")

    def test_at_target_is_done(self):
        self.assertEqual(rr.classify(F(1, 10, None, 3), 3, set()), "done")
        self.assertEqual(rr.classify(F(1, 10, 3, 3), 3, set()), "done")


class PlanTests(unittest.TestCase):
    def test_batch_respects_bytes_but_always_takes_one(self):
        todo = [F(1, 400, 1, 1), F(2, 400, 1, 1), F(3, 400, 1, 1)]
        batch, total = rr.plan_batch(todo, 500)
        self.assertEqual([f["ino"] for f in batch], [1])
        self.assertEqual(total, 400)
        batch, total = rr.plan_batch(todo, 900)
        self.assertEqual([f["ino"] for f in batch], [1, 2])
        big = [F(9, 5000, 1, 1)]
        self.assertEqual(len(rr.plan_batch(big, 500)[0]), 1)

    def test_empty(self):
        self.assertEqual(rr.plan_batch([], 500), ([], 0))


class GateTests(unittest.TestCase):
    def test_open(self):
        ok, why = rr.gate("ssd", "ssd", 0, 10e12, 1e12, False)
        self.assertTrue(ok, why)

    def test_hold_closes(self):
        self.assertFalse(rr.gate("ssd", "ssd", 0, 10e12, 1e12, True)[0])

    def test_fg_hdd_closes(self):
        ok, why = rr.gate("hdd", "ssd", 0, 10e12, 1e12, False)
        self.assertFalse(ok)
        self.assertIn("governor", why)

    def test_hipri_pending_or_unknown_closes(self):
        self.assertFalse(rr.gate("ssd", "ssd", 5, 10e12, 1e12, False)[0])
        self.assertFalse(rr.gate("ssd", "ssd", None, 10e12, 1e12, False)[0])

    def test_slack_tolerates_stuck_residual(self):
        self.assertFalse(rr.gate("ssd", "ssd", 5_000_000, 10e12, 1e12, False, slack=1_000_000)[0])
        ok, why = rr.gate("ssd", "ssd", 500_000, 10e12, 1e12, False, slack=1_000_000)
        self.assertTrue(ok)
        self.assertIn("residual", why)

    def test_free_space_closes(self):
        ok, why = rr.gate("ssd", "ssd", 0, 0.5e12, 1e12, False)
        self.assertFalse(ok)
        self.assertIn("peak", why)


if __name__ == "__main__":
    unittest.main(verbosity=1)
