#!/usr/bin/env python3
"""Gradual wallpaper transition based on time of day."""

from PIL import Image
import numpy as np
from datetime import datetime
import subprocess
import os
import hashlib

HOME = os.path.expanduser("~")
DAY_WALLPAPER = f"{HOME}/Pictures/anime-girl.png"
NIGHT_WALLPAPER = f"{HOME}/Pictures/wallpaper-night.png"
OUTPUT_WALLPAPER = f"{HOME}/Pictures/wallpaper-current.png"
SWWW = f"{HOME}/.local/bin/swww"

def get_blend_factor():
    """Calculate blend factor (0.0 = day, 1.0 = night)."""
    now = datetime.now()
    hour = now.hour
    minute = now.minute

    # Late evening: 22:00-00:00 (10pm to midnight) day -> night
    if hour == 22:
        return minute / 120.0
    elif hour == 23:
        return 0.5 + (minute / 120.0)

    # Morning: 06:00-07:00 (6am to 7am) night -> day
    elif hour == 6:
        return 1.0 - (minute / 60.0)

    # Evening: 18:00-20:00 (6pm to 8pm) - stays day
    elif hour in [18, 19]:
        return 0.0

    # Full night: 00:00-06:00
    elif 0 <= hour < 6:
        return 1.0

    # Full day: rest
    else:
        return 0.0

def blend_images(day_img, night_img, factor):
    """Blend two images. factor=0 is full day, factor=1 is full night."""
    day_arr = np.array(day_img, dtype=np.float32)
    night_arr = np.array(night_img, dtype=np.float32)

    blended = day_arr * (1 - factor) + night_arr * factor
    return Image.fromarray(blended.astype(np.uint8))

def main():
    factor = get_blend_factor()
    print(f"Blend factor: {factor:.2%}")

    day_img = Image.open(DAY_WALLPAPER)
    night_img = Image.open(NIGHT_WALLPAPER)

    blended = blend_images(day_img, night_img, factor)

    # Check if wallpaper changed
    new_hash = hashlib.md5(blended.tobytes()).hexdigest()
    try:
        old_img = Image.open(OUTPUT_WALLPAPER)
        old_hash = hashlib.md5(old_img.tobytes()).hexdigest()
    except:
        old_hash = None

    # Only rewrite the generated PNG when its pixels changed, but always tell swww
    # to apply it. After a login or daemon restart, swww may not have any image yet.
    if new_hash != old_hash:
        blended.save(OUTPUT_WALLPAPER)
        print("Wallpaper changed, updating...")
    else:
        print("Wallpaper unchanged, reapplying current image...")

    subprocess.run(
        [
            SWWW,
            "img",
            OUTPUT_WALLPAPER,
            "--resize",
            "crop",
            "--transition-type",
            "fade",
            "--transition-duration",
            "2",
        ],
        check=True,
    )

if __name__ == "__main__":
    main()
