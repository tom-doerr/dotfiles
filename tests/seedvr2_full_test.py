"""Exercise actual variable frame timing and Opus packet preservation."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from PIL import Image

SCRIPT = Path(__file__).resolve().parents[1] / 'mpv-sr/seedvr2_full.py'
spec = importlib.util.spec_from_file_location('seedvr2_full', SCRIPT)
full = importlib.util.module_from_spec(spec)
spec.loader.exec_module(full)


class FullRenderTest(unittest.TestCase):
    def test_irregular_timestamps_and_opus_survive_encoding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source.mkv'
            subprocess.run([
                'ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                'testsrc2=size=80x60:rate=25:duration=0.16', '-f', 'lavfi', '-i',
                'sine=frequency=440:duration=0.3', '-vf',
                "settb=1/1000,setpts='if(eq(N,0),0,if(eq(N,1),33,if(eq(N,2),101,180)))'",
                '-c:v', 'ffv1', '-fps_mode', 'passthrough', '-enc_time_base', '1:1000',
                '-c:a', 'libopus', '-avoid_negative_ts', 'disabled', str(source)], check=True)
            timeline = full.timestamps(full.probe(source))
            self.assertEqual([str(t) for t in timeline], ['0.000000', '0.033000', '0.101000', '0.180000'])
            frames = []
            for i in range(4):
                path = root / f'frame_{i:06d}.png'
                Image.new('RGB', (160, 120), (20 + i * 60,) * 3).save(path)
                frames.append(path)
            output = root / 'render.mkv'
            with (root / 'encode.log').open('w') as log:
                try:
                    record = full.encode(source, frames, output, timeline, (160, 120), log)
                except Exception:
                    log.flush()
                    print((root / 'encode.log').read_text())
                    raise
            self.assertTrue(record['full_decode_passed'])
            self.assertTrue(record['audio_sha256_matches_source'])
            self.assertEqual(full.timestamps(full.probe(output)), timeline)
            raw = subprocess.check_output([
                'ffmpeg', '-v', 'error', '-i', str(output), '-vf', 'scale=1:1,format=gray',
                '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'])
            self.assertEqual(len(raw), 4)
            self.assertTrue(all(abs(actual - expected) <= 2
                                for actual, expected in zip(raw, [20, 80, 140, 200])))
            rates = json.loads(subprocess.check_output([
                'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                'stream=avg_frame_rate', '-of', 'json', str(output)]))
            self.assertEqual(rates['streams'][0]['avg_frame_rate'], '25/1')
            audio_pts = [subprocess.check_output([
                'ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries',
                'packet=pts_time', '-of', 'csv=p=0', str(path)]) for path in (source, output)]
            self.assertEqual(*audio_pts)
            self.assertFalse(output.with_name('render.partial.mkv').exists())
            with self.assertRaises(FileExistsError):
                full.encode(source, frames, output, timeline, (160, 120), None)
            with self.assertRaisesRegex(ValueError, 'Expected 4 images'):
                full.encode(source, frames[:-1], root / 'short.mkv', timeline, (160, 120), None)
            self.assertFalse((root / 'short.mkv').exists())


if __name__ == '__main__':
    unittest.main()
