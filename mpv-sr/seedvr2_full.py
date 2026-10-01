#!/usr/bin/env python3
"""Queue full-length SeedVR2 renders, preserving source timestamps and audio."""
import argparse
from datetime import datetime
from decimal import Decimal
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def save(path, value):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_streams',
        '-show_frames', '-show_entries',
        'stream=width,height:frame=best_effort_timestamp_time', '-of', 'json', str(path)]))


def timestamps(info):
    return [Decimal(f['best_effort_timestamp_time']) for f in info['frames']]


def audio_hash(path):
    return subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0',
        '-c', 'copy', '-f', 'hash', '-hash', 'sha256', '-'], text=True).strip()


def encode(source, frames, output, timeline, size, log):
    """Publish only a fully decoded render with matching frame PTS and audio."""
    from PIL import Image
    if output.exists():
        raise FileExistsError(output)
    if len(frames) != len(timeline):
        raise ValueError(f'Expected {len(timeline)} images, found {len(frames)}')
    if len(timeline) < 2 or any(b <= a for a, b in zip(timeline, timeline[1:])):
        raise ValueError('Source timestamps must increase strictly')
    if any(t * 1000 != int(t * 1000) for t in timeline):
        raise ValueError('This Matroska renderer requires millisecond source timestamps')
    for path in frames:
        with Image.open(path) as im:
            if im.size != size:
                raise ValueError(f'Wrong dimensions in {path}: {im.size}')
            im.verify()
    manifest = frames[0].parent / 'encode.ffconcat'
    lines = ['ffconcat version 1.0']
    for i, path in enumerate(frames):
        if '\n' in str(path):
            raise ValueError('Newlines in image paths are unsupported')
        quoted = str(path.resolve()).replace("'", "'\\''")
        duration = (timeline[i + 1] - timeline[i] if i + 1 < len(timeline)
                    else timeline[-1] - timeline[-2])
        lines += [f"file '{quoted}'", 'option framerate 1000', f'duration {duration}']
    manifest.write_text('\n'.join(lines) + '\n')
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.stem + '.partial.mkv')
    if partial.exists():
        raise FileExistsError(f'Preserved interrupted encode: {partial}')
    # The source supplies the video clock and nominal frame rate. The blend
    # selects only generated pixels; matching per-frame PTS prevents repeats.
    filters = (f'[1:v]scale={size[0]}:{size[1]}:flags=neighbor,format=yuv444p10le[clock];'
               '[0:v]scale=iw:ih:out_color_matrix=bt709:out_range=tv,format=yuv444p10le[generated];'
               '[clock][generated]blend=all_expr=B:shortest=1:repeatlast=0[v]')
    command = ['ffmpeg', '-v', 'warning', '-n', '-copyts', '-filter_complex_threads', '2',
               '-itsoffset', str(timeline[0]), '-f', 'concat', '-safe', '0', '-i', str(manifest),
               '-i', str(source), '-filter_complex', filters, '-map', '[v]', '-map', '1:a:0',
               '-c:v', 'libx264', '-preset', 'fast', '-crf', '14', '-threads', '4',
               '-fps_mode', 'passthrough', '-enc_time_base', '1:1000',
               '-color_range', 'tv', '-colorspace', 'bt709', '-color_trc', 'bt709',
               '-color_primaries', 'bt709', '-c:a', 'copy', '-avoid_negative_ts', 'disabled',
               str(partial)]
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-threads', '2', '-i', str(partial),
                    '-f', 'null', '-'], stdout=log, stderr=subprocess.STDOUT, check=True)
    result = probe(partial)
    if timestamps(result) != timeline:
        raise ValueError('Output frame count or timestamps differ from source')
    stream = result['streams'][0]
    if (stream['width'], stream['height']) != size:
        raise ValueError('Output dimensions differ from target')
    digest = audio_hash(source)
    if audio_hash(partial) != digest:
        raise ValueError('Audio packets changed during remux')
    partial.rename(output)
    return dict(output=str(output), frames=len(timeline), width=size[0], height=size[1],
                full_decode_passed=True, max_video_pts_deviation_seconds=0,
                audio_sha256_matches_source=True, audio_hash=digest,
                output_sha256=sha256(output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    parser.add_argument('--models', nargs='+', choices=['3b', '7b'], default=['3b', '7b'])
    parser.add_argument('--drop-caches', action='store_true')
    args = parser.parse_args()
    root = args.project.resolve()
    source = root / 'source.mkv'
    work = root / 'work/seedvr-full'
    work.mkdir(parents=True, exist_ok=True)
    lock = (work / 'queue.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    repo = Path.home() / 'seedvr2-bench/ComfyUI-SeedVR2_VideoUpscaler'
    python = Path.home() / 'seedvr2-bench/venv/bin/python'
    runner = Path(__file__).with_name('seedvr2_run.py')
    source_info = probe(source)
    timeline = timestamps(source_info)
    stream = source_info['streams'][0]
    size = (stream['width'] * 2, stream['height'] * 2)
    source_hash = sha256(source)
    queue_path = work / 'status.json'
    queue = dict(status='running', source=str(source), source_sha256=source_hash,
                 source_frames=len(timeline), target_size=size,
                 tooling_commit=subprocess.check_output([
                     'git', '-C', str(runner.parent), 'rev-parse', 'HEAD'], text=True).strip(),
                 started_at=datetime.now().astimezone().isoformat(),
                 models={model: dict(status='queued', saved_frames=0) for model in args.models})
    save(queue_path, queue)
    metadata_path = root / 'comparison.json'
    metadata = json.loads(metadata_path.read_text())
    metadata['seedvr2_full_song_started'] = True
    metadata['seedvr2_full_song_status'] = str(queue_path.relative_to(root))
    save(metadata_path, metadata)
    for model in args.models:
        job = work / model
        job.mkdir(exist_ok=True)
        output = root / f'full/pink-seedvr2-{model}-2x.mkv'
        status = queue['models'][model]
        start = time.monotonic()
        try:
            checkpoint = repo / f'models/SEEDVR2/seedvr2_ema_{model}_fp16.safetensors'
            spec = dict(source_sha256=source_hash, model=checkpoint.name,
                        model_sha256=sha256(checkpoint), frames=len(timeline),
                        batch_size=33, chunk_size=91, temporal_overlap=4, seed=42,
                        resolution=size[1], attention='sdpa', color_correction='lab',
                        runner_sha256=sha256(runner))
            complete = output.with_suffix('.json')
            if complete.exists():
                previous = json.loads(complete.read_text())
                if (previous['spec'] == spec and previous['full_decode_passed']
                        and output.exists() and sha256(output) == previous['output_sha256']):
                    status.update(status='completed', saved_frames=len(timeline), output=str(output))
                    save(queue_path, queue)
                    continue
                raise ValueError(f'Existing completion record does not match this job: {complete}')
            if output.exists():
                raise FileExistsError(output)
            frame_root = job / 'frames'
            frame_dir = frame_root / source.stem
            inference_complete = job / 'inference-complete.json'
            if inference_complete.exists():
                if json.loads(inference_complete.read_text()) != spec:
                    raise ValueError('Saved inference uses different settings or input')
            else:
                if frame_dir.exists() and any(frame_dir.iterdir()):
                    raise FileExistsError(f'Preserved incomplete inference: {frame_dir}')
                if args.drop_caches:
                    session = subprocess.check_output([
                        'tmux', 'display-message', '-p', '-t', os.environ['TMUX_PANE'], '#S'], text=True).strip()
                    if session != 'base':
                        raise RuntimeError('sudo drop-caches must run in tmux base')
                    subprocess.run(['sudo', '-n', 'drop-caches'], check=True)
                command = [str(python), '-u', str(runner), str(source), '--output', str(frame_root),
                           '--output_format', 'png', '--dit_model', checkpoint.name,
                           '--attention_mode', 'sdpa', '--resolution', str(size[1]), '--batch_size', '33',
                           '--temporal_overlap', '4', '--chunk_size', '91', '--seed', '42',
                           '--color_correction', 'lab', '--load_cap', str(len(timeline)), '--debug']
                env = dict(os.environ, MALLOC_TRIM_THRESHOLD_='0', PYTHONDONTWRITEBYTECODE='1')
                status.update(status='rendering', command=command,
                              started_at=datetime.now().astimezone().isoformat(), spec=spec,
                              log=str(job / 'inference.log'))
                save(queue_path, queue)
                print(f'{model}: starting {len(timeline)}-frame render', flush=True)
                with (job / 'inference.log').open('w') as log:
                    proc = subprocess.Popen(['nice', '-n', '10', *command], cwd=repo,
                                            stdout=log, stderr=subprocess.STDOUT, env=env)
                    status['pid'] = proc.pid
                    save(queue_path, queue)
                    while proc.poll() is None:
                        saved = len(list(frame_dir.glob('*.png')))
                        if saved != status['saved_frames']:
                            print(f'{model}: {saved}/{len(timeline)} frames saved', flush=True)
                        status.update(saved_frames=saved,
                                      elapsed_seconds=round(time.monotonic() - start, 1))
                        save(queue_path, queue)
                        time.sleep(30)
                    if proc.returncode:
                        raise RuntimeError(f'Inference exited {proc.returncode}; see {job / "inference.log"}')
                save(inference_complete, spec)
            frames = sorted(frame_dir.glob('*.png'))
            expected = [f'{source.stem}_{i:06d}.png' for i in range(len(timeline))]
            if [path.name for path in frames] != expected:
                raise ValueError('PNG frame sequence is incomplete or out of order')
            status.update(status='encoding and validating', saved_frames=len(frames))
            save(queue_path, queue)
            print(f'{model}: inference complete; encoding and validating', flush=True)
            with (job / 'encoding.log').open('w') as log:
                result = encode(source, frames, output, timeline, size, log)
            result.update(spec=spec, tooling_commit=queue['tooling_commit'],
                          elapsed_seconds=round(time.monotonic() - start, 2),
                          completed_at=datetime.now().astimezone().isoformat())
            save(complete, result)
            playlist = root / 'full-versions.m3u'
            entries = playlist.read_text().splitlines() if playlist.exists() else ['#EXTM3U']
            entry = str(output.relative_to(root))
            if entry not in entries:
                entries.append(entry)
                playlist.write_text('\n'.join(entries) + '\n')
            metadata = root / 'comparison.json'
            data = json.loads(metadata.read_text())
            data.setdefault('full_song_seedvr2', {})[model] = result
            data['seedvr2_full_song_started'] = True
            save(metadata, data)
            status.update(status='completed', output=str(output), elapsed_seconds=result['elapsed_seconds'])
            print(f'{model}: validated and published {output}', flush=True)
        except Exception as error:
            status.update(status='failed', error=str(error))
            print(f'{model}: {error}', flush=True)
        save(queue_path, queue)
    queue['status'] = 'completed' if all(s['status'] == 'completed' for s in queue['models'].values()) else 'failed'
    queue['finished_at'] = datetime.now().astimezone().isoformat()
    save(queue_path, queue)
    print(f'Queue {queue["status"]}', flush=True)
    raise SystemExit(0 if queue['status'] == 'completed' else 1)


if __name__ == '__main__':
    main()
