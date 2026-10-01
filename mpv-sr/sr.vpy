# mpv vapoursynth filter: 2x neural upscale through vs-mlrt's TensorRT backend.
# Loaded by sr.lua, which passes "<mpv colormatrix>|<engine path>" as user-data
# (the engine for this exact input size, made by build_engine.py).
#
# mpv hands over YUV with no _Matrix prop and reuses the INPUT's colour params
# for what comes back, so the round trip must use the input's matrix both ways.
import vapoursynth as vs

core = vs.core

ZIMG_MATRIX = {"bt.601": "170m", "bt.709": "709"}

mpv_matrix, engine = user_data.split("|", 1)  # noqa: F821 (injected by mpv)
matrix = ZIMG_MATRIX[mpv_matrix]  # KeyError = a colour space the model was not trained on

rgb = core.resize.Bicubic(video_in, format=vs.RGBH, matrix_in_s=matrix)  # noqa: F821
rgb = core.trt.Model([rgb], engine_path=engine, num_streams=1)
out = core.resize.Bicubic(rgb, format=vs.YUV444P10, matrix_s=matrix, dither_type="error_diffusion")
out.set_output()
