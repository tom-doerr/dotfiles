#!/home/tom/.local/opt/vsmlrt/bin/python
"""Build a TensorRT engine for vs-mlrt's trt.Model from an upscaler ONNX.

TensorRT 11 has no FP16 builder flag (networks are strongly typed), so half
precision is baked into the ONNX before parsing; the engine then takes and
returns float16 tensors, which vstrt feeds from an RGBH clip.

Engines are tied to the GPU, the TensorRT version and the shape profile, so
the output name encodes model, precision and shape.
"""
import argparse
import sys
import time
from pathlib import Path

import onnx
import tensorrt_bindings as trt

ENGINE_DIR = Path.home() / ".local/share/vsmlrt/engines"


def engine_path(onnx_path: Path, fp16: bool, shape: str) -> Path:
    prec = "fp16" if fp16 else "fp32"
    return ENGINE_DIR / f"{onnx_path.stem}.{prec}.{shape}.trt{trt.__version__}.engine"


def parse_wh(s: str) -> tuple[int, int]:
    w, h = s.lower().split("x")
    return int(w), int(h)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("onnx", type=Path)
    ap.add_argument("--size", required=True, help="WxH the engine is optimised for")
    ap.add_argument("--min", help="WxH lower bound (makes the engine dynamic)")
    ap.add_argument("--max", help="WxH upper bound (makes the engine dynamic)")
    ap.add_argument("--fp32", action="store_true", help="keep float32 (default: float16)")
    ap.add_argument("--opt-level", type=int, default=3, choices=range(6))
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()

    if bool(args.min) != bool(args.max):
        ap.error("--min and --max go together")
    fp16 = not args.fp32
    w, h = parse_wh(args.size)
    wmin, hmin = parse_wh(args.min) if args.min else (w, h)
    wmax, hmax = parse_wh(args.max) if args.max else (w, h)
    shape = f"{w}x{h}" if not args.min else f"dyn{wmin}x{hmin}-{w}x{h}-{wmax}x{hmax}"
    out = args.out or engine_path(args.onnx, fp16, shape)
    out.parent.mkdir(parents=True, exist_ok=True)

    if out.exists():  # callers use this as "make sure the engine exists"
        print(out)
        return 0

    model = onnx.load(str(args.onnx))
    if fp16:
        from onnxconverter_common import float16

        model = float16.convert_float_to_float16(model, keep_io_types=False)
    inp = model.graph.input[0].name

    logger = trt.Logger(trt.Logger.WARNING)
    builder = trt.Builder(logger)
    network = builder.create_network(
        1 << int(trt.NetworkDefinitionCreationFlag.STRONGLY_TYPED)
    )
    parser = trt.OnnxParser(network, logger)
    if not parser.parse(model.SerializeToString()):
        for i in range(parser.num_errors):
            print(parser.get_error(i), file=sys.stderr)
        raise SystemExit("ONNX parse failed")

    config = builder.create_builder_config()
    config.builder_optimization_level = args.opt_level
    profile = builder.create_optimization_profile()
    profile.set_shape(inp, (1, 3, hmin, wmin), (1, 3, h, w), (1, 3, hmax, wmax))
    config.add_optimization_profile(profile)

    t0 = time.time()
    plan = builder.build_serialized_network(network, config)
    if plan is None:
        raise SystemExit("engine build failed (see TensorRT log above)")
    out.write_bytes(bytes(plan))
    print(f"built in {time.time() - t0:.0f} s, {out.stat().st_size / 1e6:.1f} MB", file=sys.stderr)
    print(out)  # stdout carries only the engine path
    return 0


if __name__ == "__main__":
    sys.exit(main())
