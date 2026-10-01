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
  --input 'SeedVR2 3B FP16=work/seedvr2.mkv' \
  --input 'SeedVR2 7B FP16=work/seedvr7b.mkv' \
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

The updated 2x2 uses Lanczos, RTUS, SeedVR2 3B and SeedVR2 7B, in reading order.
The detail version uses a common 720x800 crop at output coordinate (640, 76).
The previous 2x2 comparisons, which included NomosUni ESRGAN, are preserved as
`compare-2x2-before-seedvr7b.mp4` and
`compare-detail-2x2-before-seedvr7b.mp4`. The 3x3 stays unchanged.

The inherited 10-bit libplacebo FSRCNNX FFV1 render reported decoder errors even
with FFV1 v3 checksums. The comparison instead uses an 8-bit libplacebo render
that decoded cleanly; the downloaded source is also 8-bit. The erroneous earlier
files remain in `work/` and are not used by the comparison playlist.

SeedVR2's 301 PNG frames were recovered from spark-3 and verified sequential.
Its original job reported successful completion in 4,569.6 seconds while sharing
the GPU and under severe memory pressure. This is not an idle-GPU benchmark.
The sample has visibly stronger reconstructed detail; sharpness does not prove
that newly generated detail matches the original scene.

The 7B FP16 run uses the same lossless input, 960-pixel target height, seed 42,
batch size 33, overlap 4, SDPA attention and LAB colour correction. It uses
91-frame streaming chunks to limit memory, whereas the inherited 3B run used
one chunk. The local PyTorch version also differs, so this is a practical visual
comparison rather than a controlled model-only benchmark. Commands, checkpoint
hashes and timings are recorded in `work/seedvr7b-run.json` and `comparison.json`.

`seedvr2_run.py` launches an existing installation at
`~/seedvr2-bench/ComfyUI-SeedVR2_VideoUpscaler`. It warms the transformers/diffusers
imports before SeedVR2 installs its FlashAttention stub, sets the CUDA allocator
before importing torch, and forces upstream deep memory cleanup after DiT and
VAE disposal. That returns unused allocator memory between phases on the Spark's
shared CPU/GPU memory system; it does not change model computation.

The tested upstream revision is `4490bd1f482e026674543386bb2a4d176da245b9`, with
local PyTorch 2.10.0+cu130, diffusers 0.39.0 and transformers 5.5.4 in the isolated
`~/seedvr2-bench/venv` environment. Run from the upstream repository, with the
FP16 7B and VAE checkpoints installed in `models/SEEDVR2/`:

```sh
MALLOC_TRIM_THRESHOLD_=0 ~/seedvr2-bench/venv/bin/python \
  ~/git/dotfiles/mpv-sr/seedvr2_run.py \
  ~/Videos/sr-compare/pink-hyhOSLsNIvY/work/clip_lossless.mp4 \
  --output ~/Videos/sr-compare/pink-hyhOSLsNIvY/work/seedvr7b_frames \
  --output_format png --dit_model seedvr2_ema_7b_fp16.safetensors \
  --attention_mode sdpa --resolution 960 --batch_size 33 \
  --temporal_overlap 4 --chunk_size 91 --seed 42 --color_correction lab --debug
```

The standalone 7B clip is `sample-seedvr2-7b-2x.mp4`. The comparison playlist uses
the updated canonical `compare-2x2.mp4` and `compare-detail-2x2.mp4` paths. Outputs
are published only after sequence, dimensions, frame-count, audio and full-decode
checks. `work/seedvr7b-alignment.json` checks temporal alignment against the input
over the whole excerpt and each streaming segment.

Full-song outputs are kept in `full/`. Only files with adjacent completion JSON
and `full_decode_passed: true` should be treated as verified deliverables.

Validation:

```sh
PYTHONDONTWRITEBYTECODE=1 python ~/git/dotfiles/tests/offline_compare_test.py
PYTHONDONTWRITEBYTECODE=1 python ~/git/dotfiles/tests/seedvr2_run_test.py
ffmpeg -v error -xerror -threads 2 -i compare-3x3.mp4 -f null -
```
