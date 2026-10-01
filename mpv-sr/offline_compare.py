#!/usr/bin/env python3
"""Render a video through a vs-mlrt engine or assemble frame-aligned comparisons."""
import argparse
import json
from fractions import Fraction
from pathlib import Path
import subprocess
import time


def run(command):
    subprocess.run([str(x) for x in command], check=True)


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_packets',
        '-show_entries', 'stream=width,height,nb_read_packets', '-of', 'json', str(path),
    ]))['streams'][0]


def render(args):
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise FileExistsError(output)
    intermediate = output.with_name(output.stem + '.video.partial.mkv')
    if intermediate.exists():
        raise FileExistsError(intermediate)
    vpy = Path(__file__).with_name('offline.vpy').resolve()
    userdata = f'{args.mode}|{args.engine.resolve()}'
    vf = (f'vapoursynth=file=%{len(str(vpy).encode())}%{vpy}'
          f':buffered-frames=8:concurrent-frames=4'
          f':user-data=%{len(userdata.encode())}%{userdata}')
    start = time.monotonic()
    # Keep 10-bit 4:4:4 model output. Audio is copied from the source afterward.
    run([args.mpv, '--no-config', '--no-audio', '--msg-level=all=warn',
         '--vf=' + vf, '--ovc=libx264',
         '--ovcopts=crf=14,preset=fast,threads=4', '--of=matroska',
         '--o=' + str(intermediate), args.source])
    source_info, rendered_info = probe(args.source), probe(intermediate)
    if rendered_info['nb_read_packets'] != source_info['nb_read_packets']:
        raise RuntimeError(f'Frame count mismatch: {source_info} -> {rendered_info}')
    if (rendered_info['width'], rendered_info['height']) != (
            source_info['width'] * 2, source_info['height'] * 2):
        raise RuntimeError(f'Expected exact 2x dimensions: {rendered_info}')
    run(['ffmpeg', '-v', 'error', '-n', '-i', intermediate, '-i', args.source,
         '-map', '0:v:0', '-map', '1:a?', '-c', 'copy',
         '-color_range', 'tv', '-colorspace', 'bt709', '-color_trc', 'bt709',
         '-color_primaries', 'bt709', '-metadata', f'title={args.title}', output])
    # Decode the actual deliverable before publishing its completion record.
    run(['ffmpeg', '-v', 'error', '-xerror', '-threads', '2', '-i', output,
         '-f', 'null', '-'])
    record = dict(source=str(args.source.resolve()), engine=str(args.engine.resolve()),
                  mode=args.mode, output=str(output), stream=rendered_info,
                  elapsed_seconds=round(time.monotonic() - start, 2),
                  full_decode_passed=True)
    output.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n')
    intermediate.unlink()
    print(json.dumps(record), flush=True)


def montage(args):
    inputs = []
    for item in args.input:
        label, path = item.split('=', 1)
        # Labels are deliberately restricted to keep the filter expression literal.
        if not label or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_().' for c in label):
            raise ValueError(f'Unsupported label: {label!r}')
        inputs.append((label, Path(path)))
    if len(inputs) not in (4, 9) or args.columns ** 2 != len(inputs):
        raise ValueError('Use four inputs with two columns or nine with three columns')
    infos = [probe(p) for _, p in inputs]
    if any(int(i['nb_read_packets']) < args.frames for i in infos):
        raise ValueError('An input has fewer than the requested number of frames')
    if len({(i['width'], i['height']) for i in infos}) != 1:
        raise ValueError('Comparison inputs must have identical dimensions')
    rate = Fraction(args.fps)
    if rate <= 0 or args.frames <= 0:
        raise ValueError('Frame count and rate must be positive')
    duration = float(args.frames / rate)
    width, height = infos[0]['width'], infos[0]['height']
    crop = ''
    if args.crop:
        cw, ch, cx, cy = map(int, args.crop.split(':'))
        if min(cw, ch) <= 0 or min(cx, cy) < 0 or cx + cw > width or cy + ch > height:
            raise ValueError('Crop lies outside the frame')
        width, height = cw, ch
        crop = f'crop={cw}:{ch}:{cx}:{cy},'
    if args.tile_width:
        height = round(height * args.tile_width / width / 2) * 2
        width = args.tile_width
    command = ['ffmpeg', '-v', 'warning', '-n', '-filter_complex_threads', '2']
    for _, path in inputs:
        command += ['-threads', '2', '-i', path]
    if args.audio:
        command += ['-i', args.audio]
    filters = []
    for i, (label, _) in enumerate(inputs):
        filters.append(
            f'[{i}:v]trim=end_frame={args.frames},settb=AVTB,'
            f'setpts=N*{rate.denominator}/({rate.numerator}*TB),'
            f'{crop}scale={width}:{height}:flags=lanczos,setsar=1,format=yuv420p,'
            f'drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:'
            f'text={label}:x=12:y=12:fontsize={max(20, width // 42)}:'
            f'fontcolor=white:box=1:boxcolor=black@0.8:boxborderw=6[p{i}]')
    layout = '|'.join(f'{i % args.columns * width}_{i // args.columns * height}'
                      for i in range(len(inputs)))
    filters.append(''.join(f'[p{i}]' for i in range(len(inputs))) +
                   f'xstack=inputs={len(inputs)}:layout={layout}:shortest=1[v]')
    if args.audio:
        filters.append(f'[{len(inputs)}:a]atrim=start={args.audio_start}:'
                       f'duration={duration},asetpts=PTS-STARTPTS[a]')
    command += ['-filter_complex', ';'.join(filters), '-map', '[v]']
    if args.audio:
        command += ['-map', '[a]', '-c:a', 'aac', '-b:a', '192k']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    command += ['-c:v', 'libx264', '-preset', 'fast', '-crf', '16', '-threads', '4',
                '-pix_fmt', 'yuv420p', '-r', str(rate), '-frames:v', str(args.frames),
                '-t', str(duration), '-color_range', 'tv', '-colorspace', 'bt709',
                '-color_trc', 'bt709', '-color_primaries', 'bt709',
                '-movflags', '+faststart', args.output]
    run(command)
    info = probe(args.output)
    if int(info['nb_read_packets']) != args.frames:
        raise RuntimeError(f'Comparison lost frames: {info}')
    print(json.dumps(dict(output=str(args.output), stream=info)), flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='command', required=True)
    p = sub.add_parser('render')
    p.add_argument('source', type=Path)
    p.add_argument('--engine', type=Path, required=True)
    p.add_argument('--mode', choices=['rgb', 'pad', 'luma'], default='rgb')
    p.add_argument('--mpv', type=Path, default=Path.home() / '.local/opt/mpv-vs/bin/mpv')
    p.add_argument('--title', default='2x super-resolution')
    p.add_argument('--output', type=Path, required=True)
    p.set_defaults(func=render)
    p = sub.add_parser('montage')
    p.add_argument('--input', action='append', required=True, help='LABEL=PATH (repeat)')
    p.add_argument('--columns', type=int, choices=[2, 3], required=True)
    p.add_argument('--frames', type=int, required=True)
    p.add_argument('--fps', default='30000/1001')
    p.add_argument('--crop', help='W:H:X:Y, same output-pixel crop for every panel')
    p.add_argument('--tile-width', type=int)
    p.add_argument('--audio', type=Path)
    p.add_argument('--audio-start', type=float, default=0)
    p.add_argument('--output', type=Path, required=True)
    p.set_defaults(func=montage)
    args = ap.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
