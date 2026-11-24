#!/usr/bin/env python3
"""Clean enclosed light-background pockets in prop_bamboo_clump.png, prop_peach_tree.png, and prop_brazier.png."""
from PIL import Image, ImageDraw
import numpy as np
import os

ENV_DIR = "/Users/jake/Downloads/rocg/maha-dan-morta/assets/env"
SCRATCH_OUT = "/Users/jake/.gemini/antigravity/brain/2c2a760f-992e-4227-ab58-78b849405519/scratch/props_after.png"

def clean_white_pockets(path: str, mode: str) -> int:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im).astype(np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 1.0, (mx - mn) / mx, 0.0)
    luma = 0.299 * r + 0.587 * g + 0.114 * b

    if mode == "bamboo":
        # Bamboo leaves are saturated green (g > r + 15); trapped pockets are near-white/pale-grey
        bg_mask = (a > 0) & (luma > 205.0) & (sat < 0.19) & ((g - r) < 18.0)
        fringe = (a > 0) & (~bg_mask) & (luma > 175.0) & (sat < 0.22) & ((g - r) < 22.0)
    elif mode == "peach":
        # Peach blossoms are pink (r - g > 22); trapped pockets are neutral white
        bg_mask = (a > 0) & (luma > 218.0) & (sat < 0.14) & ((r - g) < 22.0)
        fringe = (a > 0) & (~bg_mask) & (luma > 192.0) & (sat < 0.16) & ((r - g) < 20.0)
    elif mode == "brazier":
        # Flame core is warm yellow/orange (r > b + 35) in central bowl; white halo arch at top has low sat (r - b <= 28)
        h, w = r.shape
        yy, xx = np.mgrid[0:h, 0:w]
        top_zone = yy < 62
        bg_mask = top_zone & (a > 0) & (luma > 212.0) & ((r - b) < 32.0)
        fringe = top_zone & (a > 0) & (~bg_mask) & (luma > 188.0) & ((r - b) < 28.0)
    else:
        return 0

    removed = int(bg_mask.sum())
    arr[bg_mask, 3] = 0.0
    # Soften 1px anti-alias fringe adjacent to removed pockets so silhouettes look crisp on dark floors
    dilated = np.zeros_like(bg_mask)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            shifted = np.roll(np.roll(bg_mask, dy, axis=0), dx, axis=1)
            dilated |= shifted
    edge_fringe = fringe & dilated
    arr[edge_fringe, 3] *= 0.22
    arr[edge_fringe, 0] *= 0.55
    arr[edge_fringe, 1] *= 0.55
    arr[edge_fringe, 2] *= 0.55

    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    out.save(path)
    return removed

def main():
    for fname, mode in [
        ("prop_bamboo_clump.png", "bamboo"),
        ("prop_peach_tree.png", "peach"),
        ("prop_brazier.png", "brazier"),
    ]:
        p = os.path.join(ENV_DIR, fname)
        n = clean_white_pockets(p, mode)
        print(f"Cleaned {fname}: removed {n} background pocket pixels")

    import glob
    props = sorted(glob.glob(os.path.join(ENV_DIR, "prop_*.png")))
    canvas = Image.new("RGBA", (1100, 320), (18, 28, 34, 255))
    draw = ImageDraw.Draw(canvas)
    x = 16
    for p in props:
        im = Image.open(p).convert("RGBA")
        canvas.alpha_composite(im, (x, 280 - im.height))
        draw.text((x, 288), os.path.basename(p).replace("prop_", "").replace(".png", ""), fill=(220, 240, 255, 255))
        x += im.width + 18
    canvas.save(SCRATCH_OUT)
    print("Saved preview:", SCRATCH_OUT)

if __name__ == "__main__":
    main()
