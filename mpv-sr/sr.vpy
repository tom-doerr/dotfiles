# mpv vapoursynth filter: 2x neural upscale through vs-mlrt's TensorRT backend.
# Loaded by sr.lua, which passes "<mpv colormatrix>|<onnx path>" as user-data.
#
# mpv hands over YUV with no _Matrix prop and reuses the INPUT's colour params
# for what comes back, so the round trip must use the input's matrix both ways.
import subprocess
import sys
from importlib.metadata import version
from pathlib import Path

import vapoursynth as vs

core = vs.core

ZIMG_MATRIX = {"bt.601": "170m", "bt.709": "709"}
BUILD = Path(__file__).resolve().parent / "build_engine.py"
ENGINES = Path.home() / ".local/share/vsmlrt/engines"

mpv_matrix, onnx = user_data.split("|", 1)  # noqa: F821 (injected by mpv)
matrix = ZIMG_MATRIX[mpv_matrix]  # KeyError = a colour space the model was not trained on
onnx = Path(onnx)

clip = video_in  # noqa: F821 (injected by mpv)
w, h = clip.width, clip.height

# Static engines are fastest and build in ~10-30 s, so keep one per input size.
engine = ENGINES / f"{onnx.stem}.fp16.{w}x{h}.trt{version('tensorrt-cu13-libs')}.engine"
if not engine.exists():
    print(f"sr.vpy: building {engine.name} (one-off, playback starts after)", file=sys.stderr)
    subprocess.run(
        [str(BUILD), str(onnx), "--size", f"{w}x{h}", "--out", str(engine)],
        check=True, stdout=sys.stderr,
    )

rgb = core.resize.Bicubic(clip, format=vs.RGBH, matrix_in_s=matrix)
rgb = core.trt.Model([rgb], engine_path=str(engine), num_streams=1)
out = core.resize.Bicubic(rgb, format=vs.YUV444P10, matrix_s=matrix, dither_type="error_diffusion")
out.set_output()
