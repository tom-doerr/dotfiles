# Offline super-resolution comparisons

`offline_compare.py` renders through an existing TensorRT engine, or assembles
labelled 2x2 and 3x3 comparisons. It does not change live playback configuration.
The source and engine must have matching dimensions and use SDR BT.709.

Render a complete video (original audio is copied):

```sh
python ~/git/dotfiles/mpv-sr/offline_compare.py render source.mkv \
  --engine ~/.local/share/vsmlrt/engines/2xLiveActionV1_SPAN_490000.fp16.852x480.trt11.3.0.99.engine \
  --title 'LiveAction SPAN 2x' --output full/liveaction.mkv
```

Outputs preserve the model's 10-bit 4:4:4 planes using H.264 CRF 14 in Matroska.
Use mpv for playback. The renderer checks exact 2x dimensions and source/output
video packet counts, decodes the deliverable, and writes an adjacent JSON
completion record. An interrupted render leaves `.video.partial.mkv`; it must not
be mistaken for a completed, verified output. Existing outputs are never replaced.

`--mode pad` mirror-pads 480..960 by 270..540 inputs to RTUS's fixed 960x540
input size, then crops back to exact 2x dimensions. RTUS uses the FP32 engine.
`--mode luma` supports ArtCNN; it scales chroma separately with Spline36.

Assemble equal-sized, frame-corresponding renders:

```sh
python ~/git/dotfiles/mpv-sr/offline_compare.py montage \
  --input 'Lanczos baseline=work/lanczos.mkv' \
  --input 'RTUS=work/rtus.mkv' \
  --input 'NomosUni ESRGAN=work/nomos_esrgan.mkv' \
  --input 'SeedVR2 3B=work/seedvr2.mkv' \
  --columns 2 --frames 301 --fps 30000/1001 \
  --audio source.mkv --audio-start 126.033 --output compare-2x2.mp4
```

Each input must contain at least the requested number of frames. The montage
uses frame index to assign one common timeline; different container start times
and inferred frame rates therefore cannot cause a panel to drift by one frame.
This assumes corresponding source frames: the tool cannot detect an upstream
model that dropped or invented frames. The integration test checks real FFmpeg
output with deliberately different timestamps and rejects short inputs.

Use nine inputs and `--columns 3` for a 3x3 grid. `--crop W:H:X:Y` applies the
same crop to every panel. Optional `--tile-width` rescales each panel; without it,
panels retain their native rendered resolution. Comparison MP4s use H.264 CRF 16,
8-bit 4:2:0 and AAC for wider playback compatibility.

## P!nk comparison, 2026-10-01

Artifacts: `~/Videos/sr-compare/pink-hyhOSLsNIvY/`.
Source: [U + Ur Hand (Explicit Version)](https://www.youtube.com/watch?v=hyhOSLsNIvY),
852x480, 6,393 video frames, about 3m33s. The downloaded video is VP9 from format
606, with Opus audio. `comparison.json` records the source hash and panel order.

The comparison excerpt starts at a 126-second input seek and contains 301
frames. Every model panel is 1704x960. The 3x3 rows are:

1. Lanczos, FSRCNNX, ArtCNN C4F32.
2. ArtCNN C4F32 DS, LiveAction SPAN, NomosUni SPAN.
3. RTUS, NomosUni ESRGAN, SeedVR2 3B.

The 2x2 uses Lanczos, RTUS, NomosUni ESRGAN and SeedVR2, in reading order.
The detail version uses a common 720x800 crop at output coordinate (640, 76).

The inherited 10-bit libplacebo FSRCNNX FFV1 render reported decoder errors even
with FFV1 v3 checksums. The comparison instead uses an 8-bit libplacebo render
that decoded cleanly; the downloaded source is also 8-bit. The erroneous earlier
files remain in `work/` and are not used by the comparison playlist.

SeedVR2's 301 PNG frames were recovered from spark-3 and verified sequential.
Its original job reported successful completion in 4,569.6 seconds while sharing
the GPU and under severe memory pressure. This is not an idle-GPU benchmark.
The sample has visibly stronger reconstructed detail; sharpness does not prove
that newly generated detail matches the original scene.

Full-song outputs are kept in `full/`. Only files with adjacent completion JSON
and `full_decode_passed: true` should be treated as verified deliverables.

Validation:

```sh
PYTHONDONTWRITEBYTECODE=1 python ~/git/dotfiles/tests/offline_compare_test.py
ffmpeg -v error -xerror -threads 2 -i compare-3x3.mp4 -f null -
```
