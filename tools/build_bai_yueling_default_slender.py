#!/usr/bin/env python3
"""
Extracts Bai Yueling's default (uncloaked + ice sword) 4-dir walk and combat sheets
matching the exact 400x320 cell size, 224px character height, and (200, 282) foot anchor
of her alt/ (snow cloak) sprites.
"""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

ARTIFACT_DIR = Path("/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2")
OUT_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/heroes/bai_yueling")

CELL_W = 400
CELL_H = 320
TARGET_CHAR_H = 224
FOOT_Y = 282


def flood_fill_remove_white(img: Image.Image, white_thresh: int = 238) -> Image.Image:
    rgba = np.array(img.convert("RGBA"))
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)
    is_bg = (rgb[:, :, 0] >= white_thresh) & (rgb[:, :, 1] >= white_thresh) & (rgb[:, :, 2] >= white_thresh)

    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if is_bg[0, x]:
            visited[0, x] = True
            q.append((0, x))
        if is_bg[h - 1, x] and not visited[h - 1, x]:
            visited[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if is_bg[y, 0] and not visited[y, 0]:
            visited[y, 0] = True
            q.append((y, 0))
        if is_bg[y, w - 1] and not visited[y, w - 1]:
            visited[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

    alpha = np.where(visited, 0, 255).astype(np.float32)
    fringe = np.zeros((h, w), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        fringe |= np.roll(np.roll(visited, dy, axis=0), dx, axis=1)
    fringe &= ~visited
    luma = (rgb[:, :, 0] + rgb[:, :, 1] + rgb[:, :, 2]) / 3.0
    alpha = np.where(fringe & (luma > 205), np.clip((255.0 - luma) * 3.8, 40, 255), alpha)

    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    out = Image.fromarray(rgba)
    bb = out.getbbox()
    return out.crop(bb) if bb else out


def place_in_cell(sprite: Image.Image, scale: float) -> Image.Image:
    w, h = sprite.size
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    if nw > CELL_W - 16:
        fit = (CELL_W - 16) / float(nw)
        nw = int(round(nw * fit))
        nh = int(round(nh * fit))
    if nh > FOOT_Y - 6:
        fit = (FOOT_Y - 6) / float(nh)
        nw = int(round(nw * fit))
        nh = int(round(nh * fit))
    resized = sprite.resize((nw, nh), Image.Resampling.LANCZOS)
    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    px = (CELL_W - nw) // 2
    py = FOOT_Y - nh
    cell.paste(resized, (px, py), resized)
    return cell


def build_strip(frames: list[Image.Image], uniform_scale: float | None = None) -> Image.Image:
    strip = Image.new("RGBA", (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s = uniform_scale if uniform_scale is not None else (TARGET_CHAR_H / float(max(1, fr.height)))
        cell = place_in_cell(fr, s)
        strip.paste(cell, (i * CELL_W, 0), cell)
    return strip


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    walk_sheet = Image.open(ARTIFACT_DIR / "bai_yueling_default_walk_1795407037953.jpg")
    ww, wh = walk_sheet.size
    cw, ch = ww // 3, wh // 3

    walk_names = ["walk_down.png", "walk_up.png", "walk_side.png"]
    side_idle_cell = None
    for r_idx, fname in enumerate(walk_names):
        row_frames = []
        for c_idx in range(3):
            crop = walk_sheet.crop((c_idx * cw, r_idx * ch, (c_idx + 1) * cw, (r_idx + 1) * ch))
            row_frames.append(flood_fill_remove_white(crop))
        strip = build_strip(row_frames)
        strip.save(OUT_DIR / fname)
        if fname == "walk_side.png":
            side_idle_cell = strip.crop((0, 0, CELL_W, CELL_H))
        print(f"Saved {fname} {strip.size}")

    if side_idle_cell is not None:
        side_idle_cell.save(OUT_DIR / "stride_0.png")
        print("Updated stride_0.png to match slender default")

    combat_sheet = Image.open(ARTIFACT_DIR / "bai_yueling_default_combat_1795407051213.jpg")
    kw, kh = combat_sheet.size
    kcw, kch = kw // 4, kh // 2

    def split_row_by_gaps(sheet: Image.Image, y0: int, y1: int) -> list[Image.Image]:
        arr = np.array(sheet.crop((0, y0, kw, y1)).convert("RGB"))
        is_w = np.all(arr > 242, axis=(0, 2))
        splits = [0]
        for t in (0.25, 0.50, 0.75):
            cx = int(kw * t)
            whites = [x for x in range(max(0, cx - 120), min(kw, cx + 120)) if is_w[x]]
            splits.append((min(whites) + max(whites)) // 2 if whites else cx)
        splits.append(kw)
        return [
            flood_fill_remove_white(sheet.crop((splits[i], y0, splits[i + 1], y1)))
            for i in range(4)
        ]

    # Use neutral ready/follow-through frame (row 0, col 0) to determine uniform body scale
    attack_frames = split_row_by_gaps(combat_sheet, 0, kch)
    neutral_scale = TARGET_CHAR_H / float(max(1, attack_frames[0].height))

    attack_strip = build_strip(attack_frames, uniform_scale=neutral_scale)
    attack_strip.save(OUT_DIR / "attack_4f.png")
    print(f"Saved attack_4f.png {attack_strip.size}")

    skill_frames = split_row_by_gaps(combat_sheet, kch, kh)
    skill_scale = TARGET_CHAR_H / float(max(1, skill_frames[3].height))
    skill_strip = build_strip(skill_frames, uniform_scale=skill_scale)
    skill_strip.save(OUT_DIR / "skill_4f.png")
    print(f"Saved skill_4f.png {skill_strip.size}")


if __name__ == "__main__":
    main()
