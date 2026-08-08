#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from contextlib import nullcontext
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "spark-pdu-watchdog.py"
SPEC = importlib.util.spec_from_file_location("spark_pdu_watchdog", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
WATCHDOG = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = WATCHDOG
SPEC.loader.exec_module(WATCHDOG)

METRICS = """
pdu_up 1
pdu_last_success_unixtime_seconds 1786212400.500
pdu_outlet_status{outlet="1",name="spark-1",pdu_name="Outlet1"} 1
pdu_outlet_power_watts{outlet="1",name="spark-1",pdu_name="Outlet1"} 140
pdu_outlet_status{outlet="2",name="spark-2",pdu_name="Outlet2"} 1
pdu_outlet_power_watts{outlet="2",name="spark-2",pdu_name="Outlet2"} 2
pdu_outlet_status{outlet="3",name="spark-3",pdu_name="Outlet3"} 1
pdu_outlet_power_watts{outlet="3",name="spark-3",pdu_name="Outlet3"} 1
"""


class SparkPduWatchdogTest(unittest.TestCase):
    def setUp(self):
        self.settings = WATCHDOG.Settings(
            check_interval_seconds=1,
            startup_grace_seconds=1,
            failures_required=3,
            down_max_watts=5,
            metric_max_age_seconds=30,
            host_cycle_cooldown_seconds=1800,
            global_cycle_gap_seconds=300,
            ping_count=1,
            ping_timeout_seconds=1,
        )
        self.snapshot = WATCHDOG.parse_snapshot(METRICS)
        self.target = WATCHDOG.TARGET_BY_HOST["spark-2"]

    def test_parses_two_watts_as_valid_down_power(self):
        sample = self.snapshot.outlets["spark-2"]
        self.assertEqual(sample.outlet, 2)
        self.assertEqual(sample.pdu_name, "Outlet2")
        self.assertEqual(sample.power_watts, 2)
        self.assertTrue(
            WATCHDOG.snapshot_is_fresh(self.snapshot, 1786212420, 30)
        )

    def test_requires_consecutive_ping_and_low_power_failures(self):
        state = WATCHDOG.WatchdogState()
        first = WATCHDOG.evaluate_target(
            self.target, self.snapshot, False, state, self.settings, 10, 0
        )
        second = WATCHDOG.evaluate_target(
            self.target, self.snapshot, False, state, self.settings, 11, 0
        )
        third = WATCHDOG.evaluate_target(
            self.target, self.snapshot, False, state, self.settings, 12, 0
        )
        self.assertFalse(first.cycle)
        self.assertFalse(second.cycle)
        self.assertTrue(third.cycle)

    def test_successful_ping_resets_failures(self):
        state = WATCHDOG.WatchdogState()
        state.hosts["spark-2"].failures = 7
        decision = WATCHDOG.evaluate_target(
            self.target, self.snapshot, True, state, self.settings, 10, 0
        )
        self.assertFalse(decision.cycle)
        self.assertEqual(state.hosts["spark-2"].failures, 0)

    def test_high_power_never_qualifies_as_down(self):
        outlets = dict(self.snapshot.outlets)
        outlets["spark-2"] = WATCHDOG.OutletSample(2, "Outlet2", 1, 6)
        snapshot = WATCHDOG.Snapshot(True, self.snapshot.last_success, outlets)
        state = WATCHDOG.WatchdogState()
        state.hosts["spark-2"].failures = 20
        decision = WATCHDOG.evaluate_target(
            self.target, snapshot, False, state, self.settings, 20, 0
        )
        self.assertFalse(decision.cycle)
        self.assertEqual(state.hosts["spark-2"].failures, 0)

    def test_cooldown_resets_confirmation_count(self):
        state = WATCHDOG.WatchdogState()
        state.hosts["spark-2"].failures = 20
        state.hosts["spark-2"].last_cycle = 100
        state.last_any_cycle = 100
        decision = WATCHDOG.evaluate_target(
            self.target, self.snapshot, False, state, self.settings, 110, 0
        )
        self.assertFalse(decision.cycle)
        self.assertEqual(decision.reason, "host cycle cooldown")
        self.assertEqual(state.hosts["spark-2"].failures, 0)

    def test_command_builder_only_allows_literal_outlets_two_and_three(self):
        self.assertEqual(
            WATCHDOG.build_reboot_command(WATCHDOG.TARGET_BY_HOST["spark-2"]),
            "oltctrl index 2 act reboot",
        )
        self.assertEqual(
            WATCHDOG.build_reboot_command(WATCHDOG.TARGET_BY_HOST["spark-3"]),
            "oltctrl index 3 act reboot",
        )
        with self.assertRaises(WATCHDOG.SafetyError):
            WATCHDOG.build_reboot_command(WATCHDOG.Target("spark-2", 1, "Outlet1"))
        with self.assertRaises(WATCHDOG.SafetyError):
            WATCHDOG.build_reboot_command(WATCHDOG.Target("other", 4, "Outlet4"))

    def test_live_validation_rejects_wrong_name_or_power(self):
        row = {
            "outlet": 2,
            "pdu_name": "Outlet2",
            "status": True,
            "power_watts": 2.0,
        }
        self.assertEqual(
            WATCHDOG.validate_live_outlet(self.target, [row], 5), 2.0
        )
        wrong_name = dict(row, pdu_name="Outlet3")
        with self.assertRaises(WATCHDOG.CycleCancelled):
            WATCHDOG.validate_live_outlet(self.target, [wrong_name], 5)
        high_power = dict(row, power_watts=6.0)
        with self.assertRaises(WATCHDOG.CycleCancelled):
            WATCHDOG.validate_live_outlet(self.target, [high_power], 5)

    def test_control_path_sends_only_status_then_allowlisted_reboot(self):
        class FakeSession:
            def __init__(self):
                self.commands = []

            def connect(self):
                pass

            def command(self, value):
                self.commands.append(value)
                if value == "oltsta show":
                    return "2 Outlet2              On     0.01    2\n"
                return "OK"

            def close(self):
                pass

        session = FakeSession()
        attempts = []
        with self.assertLogs(WATCHDOG.LOGGER, level="WARNING"):
            with (
                patch.object(WATCHDOG, "ping_target", return_value=False),
                patch.object(WATCHDOG.PDU, "PduSession", return_value=session),
                patch.object(WATCHDOG.PDU, "pdu_lock", return_value=nullcontext()),
            ):
                WATCHDOG.cycle_target(
                    self.target, self.settings, False, lambda: attempts.append(True)
                )
        self.assertEqual(
            session.commands,
            ["oltsta show", "oltctrl index 2 act reboot"],
        )
        self.assertEqual(attempts, [True])


if __name__ == "__main__":
    unittest.main()
