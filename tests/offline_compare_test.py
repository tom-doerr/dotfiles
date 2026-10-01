"""Exercise real FFmpeg frame alignment with deliberately different input timestamps."""
import importlib.util
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from argparse import Namespace
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'mpv-sr/offline_compare.py'
spec = importlib.util.spec_from_file_location('offline_compare', SCRIPT)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class OfflineCompareTest(unittest.TestCase):
    def test_render_preserves_audio_and_signals_bt709(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'source.mkv'
            compare.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                         'testsrc2=size=160x120:rate=5:duration=1',
                         '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
                         '-c:v', 'ffv1', '-c:a', 'pcm_s16le', source])
            real_run = compare.run

            def without_gpu(command):
                if command[0] == 'fake-mpv':
                    output = next(x[4:] for x in command if str(x).startswith('--o='))
                    real_run(['ffmpeg', '-v', 'error', '-i', source, '-an',
                              '-vf', 'scale=320:240', '-c:v', 'libx264', output])
                else:
                    real_run(command)

            args = Namespace(source=source, output=root / 'result.mkv',
                             engine=root / 'model.engine', mode='rgb',
                             mpv='fake-mpv', title='Test')
            with patch.object(compare, 'run', side_effect=without_gpu):
                compare.render(args)
            import json
            info = json.loads(subprocess.check_output([
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=color_range,color_space,color_transfer,color_primaries',
                '-of', 'json', str(args.output)]))['streams'][0]
            self.assertEqual(info, dict(color_range='tv', color_space='bt709',
                                        color_transfer='bt709', color_primaries='bt709'))
            hashes = [subprocess.check_output([
                'ffmpeg', '-v', 'error', '-i', str(p), '-map', '0:a:0',
                '-c', 'copy', '-f', 'hash', '-hash', 'sha256', '-'])
                for p in (source, args.output)]
            self.assertEqual(*hashes)
            self.assertTrue(json.loads(args.output.with_suffix('.json').read_text())[
                'full_decode_passed'])

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
