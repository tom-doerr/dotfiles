#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "pdu-exporter.py"
SPEC = importlib.util.spec_from_file_location("pdu_exporter", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
PDU = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PDU
SPEC.loader.exec_module(PDU)

DEVICE_STATUS = """
Device Load : 1.42 A/ 295 W/ 324 VA
Power Factor : 0.91
Peak Load : 2.80A (at 2026/08/01 12:00:00)
Energy : 381.4kWh (from 2026/01/01 00:00:00)
Voltage : 228.3V
Frequency : 50.0Hz
"""

OUTLET_STATUS = """
# Name                 Status Load(A) Load(W)
1 Outlet1              On     0.71    151
2 Outlet2              Off    0.01    2
3 Outlet3              On     0.67    142
"""


class PduExporterTest(unittest.TestCase):
    def test_parse_device_status(self):
        parsed = PDU.parse_device_status(DEVICE_STATUS)
        self.assertEqual(parsed["power_watts"], 295.0)
        self.assertEqual(parsed["apparent_power_volt_amperes"], 324.0)
        self.assertEqual(parsed["power_factor_ratio"], 0.91)
        self.assertEqual(parsed["energy_kilowatt_hours"], 381.4)

    def test_parse_outlet_status(self):
        parsed = PDU.parse_outlet_status(OUTLET_STATUS)
        self.assertEqual(len(parsed), 3)
        self.assertEqual(parsed[1]["outlet"], 2)
        self.assertFalse(parsed[1]["status"])
        self.assertEqual(parsed[1]["power_watts"], 2.0)

    def test_render_success_uses_host_mapping(self):
        body = PDU.render_success(
            PDU.parse_device_status(DEVICE_STATUS),
            PDU.parse_outlet_status(OUTLET_STATUS),
            {1: "spark-1", 2: "spark-2", 3: "spark-3"},
            1234.0,
            0.25,
        )
        self.assertIn("pdu_up 1", body)
        self.assertIn("pdu_device_power_watts 295.0", body)
        self.assertIn(
            'pdu_outlet_power_watts{outlet="2",name="spark-2",pdu_name="Outlet2"} 2.0',
            body,
        )

    def test_failure_does_not_publish_stale_outlet_values(self):
        body = PDU.render_failure(1234.0, 0.5)
        self.assertIn("pdu_up 0", body)
        self.assertIn("pdu_last_success_unixtime_seconds 1234.000", body)
        self.assertNotIn("pdu_outlet_power_watts{", body)

    def test_rejects_bad_outlet_map(self):
        with self.assertRaises(ValueError):
            PDU.parse_outlet_map("not-a-mapping")

    def test_command_sends_one_terminal_newline(self):
        class FakeStdin:
            def __init__(self):
                self.data = b""

            def write(self, value):
                self.data += value

            def flush(self):
                pass

        class FakeProcess:
            def __init__(self):
                self.stdin = FakeStdin()

        session = PDU.PduSession("pdu", Path("/unused"))
        session.process = FakeProcess()
        session._read_until_prompt = lambda _timeout: "response"
        self.assertEqual(session.command("devsta show"), "response")
        self.assertEqual(session.process.stdin.data, b"devsta show\r")


if __name__ == "__main__":
    unittest.main()
