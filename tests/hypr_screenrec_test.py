"""hypr/hypr-screenrec: capture geometry (numbers verified live on the portrait Dells) and loop detection."""
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

import pytest

loader = importlib.machinery.SourceFileLoader(
    "hypr_screenrec", str(Path(__file__).resolve().parents[1] / "hypr" / "hypr-screenrec"))
sr = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(sr)

DELL = {"name": "HDMI-A-1", "width": 3840, "height": 2160, "scale": 1.25, "transform": 1, "x": 3456, "y": 2160}


def test_full_monitor_is_cropped_inside_the_frame_then_rotated_upright():
    chain, cap = sr.capture_plan(DELL, (0, 0, *sr.logical_size(DELL)))
    assert cap == (9, 9, 2142, 3822)
    assert chain.startswith("crop=3822:2142:9:9,transpose=1,")


def test_region_maps_into_the_unrotated_buffer():
    chain, cap = sr.capture_plan(DELL, (44, 140, 800, 600))
    assert cap == (64, 184, 982, 732)
    assert chain.startswith("crop=732:982:184:1114,transpose=1,")


def test_unverified_transform_is_refused():
    with pytest.raises(sr.UserError):
        sr.capture_plan({**DELL, "transform": 3}, (0, 0, 100, 100))


def box_video(path, x_expr, seconds):
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", f"color=c=0x202830:s=320x240:r=60:d={seconds}",
         "-f", "lavfi", "-i", f"color=c=red:s=30x30:r=60:d={seconds}",
         "-filter_complex", f"[0][1]overlay=x='{x_expr}':y=100,noise=alls=4:allf=t+u",
         "-c:v", "libx264", "-preset", "superfast", "-crf", "16", "-pix_fmt", "yuv420p", str(path)],
        check=True)


def test_pendulum_loop_is_the_full_swing_not_the_mirrored_half(tmp_path):
    box_video(tmp_path / "swing.mp4", "140+120*sin(2*PI*t)", 3)
    loop = sr.make_loop(tmp_path / "swing.mp4", tmp_path / "loop.mp4")
    assert loop["found"] and loop["period_frames"] == 60
    assert sr.probe(tmp_path / "loop.mp4")["frames"] == 60


def test_fewer_than_two_cycles_is_not_a_loop(tmp_path):
    box_video(tmp_path / "slow.mp4", "140+120*sin(2*PI*t/2)", 3)  # 1.5 cycles
    assert not sr.find_loop(tmp_path / "slow.mp4")["found"]
