#!/usr/bin/env python3
"""
Enhances leg-stride visibility across all 7 heroes' 3-frame walk sheets
(walk_side, walk_down, walk_up) so steps are unmistakable at 0.42x game scale.
Frame 1 (center) remains the untouched neutral standing pose.
"""
from pathlib import Path
import numpy as np
from PIL import Image

HEROES_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/heroes")
HEROES = ["bai_yueling", "ye_shangye", "song_ren", "chen_xi", "yu_han", "zhao_yan", "hei_shan"]
CELL_W = 400
CELL_H = 320


def shear_side_frame(cell: Image.Image, shift_px: float, lift_px: int) -> Image.Image:
    """Apply smooth lower-body stride shear + subtle foot lift for side-walk frames."""
    arr = np.array(cell.convert("RGBA"))
    out = np.zeros_like(arr)
    # Waist starts around y=210, feet end at y=285
    for y in range(CELL_H):
        if y < 205:
            # Subtle upper-body forward lean
            dx = int(round((205 - y) * (-0.015 if shift_px > 0 else 0.015)))
            dy = -lift_px // 2
        elif y <= 286:
            t = (y - 205) / 81.0
            dx = int(round(shift_px * t))
            dy = -int(round(lift_px * t))
        else:
            dx = 0
            dy = 0
        ny = y + dy
        if not (0 <= ny < CELL_H):
            continue
        if dx == 0:
            out[ny] = arr[y]
        elif dx > 0:
            out[ny, dx:] = arr[y, : CELL_W - dx]
        else:
            k = -dx
            out[ny, : CELL_W - k] = arr[y, k:]
    return Image.fromarray(out)


def lift_front_back_leg(cell: Image.Image, side: str, lift_px: int = 7) -> Image.Image:
    """Lift left (x < 200) or right (x >= 200) leg smoothly for walk_down / walk_up."""
    arr = np.array(cell.convert("RGBA"))
    out = arr.copy()
    x0, x1 = (0, 200) if side == "left" else (200, CELL_W)
    # Clear lower leg area on stepping side and shift up with smooth ramp from y=225
    out[225:290, x0:x1] = 0
    for y in range(225, 290):
        t = (y - 225) / 65.0
        dy = int(round(lift_px * t))
        ny = y - dy
        if 0 <= ny < CELL_H:
            # Blend/overwrite only non-transparent pixels
            src = arr[y, x0:x1]
            mask = src[:, 3] > 0
            out[ny, x0:x1][mask] = src[mask]
    return Image.fromarray(out)


def process_dir(hero_dir: Path):
    side_p = hero_dir / "walk_side.png"
    if side_p.exists():
        im = Image.open(side_p).convert("RGBA")
        f0 = shear_side_frame(im.crop((0, 0, CELL_W, CELL_H)), shift_px=12.0, lift_px=4)
        f1 = im.crop((CELL_W, 0, 2 * CELL_W, CELL_H))
        f2 = shear_side_frame(im.crop((2 * CELL_W, 0, 3 * CELL_W, CELL_H)), shift_px=-12.0, lift_px=4)
        strip = Image.new("RGBA", (3 * CELL_W, CELL_H), (0, 0, 0, 0))
        strip.paste(f0, (0, 0))
        strip.paste(f1, (CELL_W, 0))
        strip.paste(f2, (2 * CELL_W, 0))
        strip.save(side_p)

    for fname in ("walk_down.png", "walk_up.png"):
        p = hero_dir / fname
        if p.exists():
            im = Image.open(p).convert("RGBA")
            f0 = lift_front_back_leg(im.crop((0, 0, CELL_W, CELL_H)), side="left", lift_px=8)
            f1 = im.crop((CELL_W, 0, 2 * CELL_W, CELL_H))
            f2 = lift_front_back_leg(im.crop((2 * CELL_W, 0, 3 * CELL_W, CELL_H)), side="right", lift_px=8)
            strip = Image.new("RGBA", (3 * CELL_W, CELL_H), (0, 0, 0, 0))
            strip.paste(f0, (0, 0))
            strip.paste(f1, (CELL_W, 0))
            strip.paste(f2, (2 * CELL_W, 0))
            strip.save(p)


def main():
    for h in HEROES:
        process_dir(HEROES_DIR / h)
        if h == "bai_yueling":
            for sub in ("alt", "alt_snow"):
                if (HEROES_DIR / h / sub).exists():
                    process_dir(HEROES_DIR / h / sub)
        print(f"Enhanced walk stride for {h}")


if __name__ == "__main__":
    main()
