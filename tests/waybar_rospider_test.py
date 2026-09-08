"""Exercise the Waybar battery module with fresh, missing and stale telemetry."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'waybar/rospider.sh'


class BatteryTest(unittest.TestCase):
    def render(self, content=None, probe=None):
        with tempfile.TemporaryDirectory() as directory:
            metrics = Path(directory) / 'robot.prom'
            if content is not None:
                metrics.write_text(content)
            env = dict(os.environ, ROSPIDER_PROM_FILE=str(metrics), ROSPIDER_NOW_EPOCH='1000')
            env.pop('ROSPIDER_MV', None)
            if probe is not None:
                env['ROSPIDER_MV'] = probe
            result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True,
                                    text=True, check=True, timeout=2)
            self.assertEqual(result.stderr, '')
            return json.loads(result.stdout) if result.stdout else None

    def fixture(self, voltage='11.5', updated='999', up='1'):
        return (f'rospider_exporter_up {up}\n'
                f'rospider_exporter_last_sample_timestamp_seconds {updated}\n'
                + (f'rospider_battery_voltage_volts {voltage}\n' if voltage is not None else ''))

    def test_fresh_percentage_and_voltage(self):
        result = self.render(self.fixture())
        self.assertEqual(result['text'], '🕷 45% 11.50 V')
        self.assertEqual(result['percentage'], 45)
        self.assertEqual(result['class'], 'ok')
        self.assertIn('estimated', result['tooltip'])

    def test_missing_stale_disconnected_and_future_data_are_hidden(self):
        for content in [None, '', self.fixture(updated='989'),
                        self.fixture(up='0'), self.fixture(updated='1001')]:
            with self.subTest(content=content):
                result = self.render(content)
                self.assertIsNone(result)

    def test_connected_without_valid_battery(self):
        for voltage in [None, 'NaN', 'inf', '0']:
            with self.subTest(voltage=voltage):
                result = self.render(self.fixture(voltage=voltage))
                self.assertIsNone(result)

    def test_percentage_limits_and_warning_classes(self):
        for mv, percent, state in [('13000', 100, 'ok'), ('11100', 25, 'warning'),
                                   ('10336', 5, 'critical'), ('9500', 0, 'critical')]:
            with self.subTest(mv=mv):
                result = self.render(probe=mv)
                self.assertEqual(result['percentage'], percent)
                self.assertEqual(result['class'], state)


if __name__ == '__main__':
    unittest.main()
