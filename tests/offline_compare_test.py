"""Exercise real FFmpeg frame alignment with deliberately different input timestamps."""
import importlib.util
import subprocess
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'mpv-sr/offline_compare.py'
spec = importlib.util.spec_from_file_location('offline_compare', SCRIPT)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class OfflineCompareTest(unittest.TestCase):
    def test_offsets_do_not_shift_panels_and_short_inputs_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # Every source has exactly the same changing pixels, different timestamps.
            for i in range(4):
                compare.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                             'testsrc2=size=160x120:rate=5:duration=1',
                             '-vf', f'setpts=PTS+{i}/TB', '-c:v', 'ffv1',
                             '-fps_mode', 'passthrough', root / f'{i}.mkv'])
            args = Namespace(input=[f'Same={root / str(i)}.mkv' for i in range(4)],
                             output=root / 'grid.mp4', columns=2, frames=5, fps='5',
                             crop=None, tile_width=None, audio=None, audio_start=0)
            compare.montage(args)
            info = compare.probe(args.output)
            self.assertEqual((info['width'], info['height'], int(info['nb_read_packets'])),
                             (320, 240, 5))
            raw = subprocess.check_output([
                'ffmpeg', '-v', 'error', '-i', str(args.output),
                '-pix_fmt', 'gray', '-f', 'rawvideo', '-'])
            self.assertEqual(len(raw), 320 * 240 * 5)
            # Compare changing pixels away from labels and codec block boundaries.
            for frame in range(5):
                for dx, dy in [(160, 0), (0, 120), (160, 120)]:
                    errors = [abs(raw[frame * 76800 + y * 320 + x] -
                                  raw[frame * 76800 + (y + dy) * 320 + x + dx])
                              for y in range(70, 110) for x in range(20, 140)]
                    self.assertLess(sum(errors) / len(errors), 3)
            args.frames = 6
            args.output = root / 'too-short.mp4'
            with self.assertRaisesRegex(ValueError, 'fewer'):
                compare.montage(args)
            self.assertFalse(args.output.exists())


if __name__ == '__main__':
    unittest.main()
