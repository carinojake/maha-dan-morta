#!/usr/bin/env python3
"""
Builds high-resolution Xianxia HD-2D environment tiles (seamless + Sobel normal maps)
and clean transparent-background props from AI-generated sheets.
"""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

ARTIFACT_DIR = Path("/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2")
ENV_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/env")


def make_seamless_tile(img: Image.Image, size: int = 128, horizontal_only: bool = False) -> Image.Image:
    """Make an image seamlessly tileable via half-shift + cosine cross-fade."""
    im = img.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    arr = np.array(im, dtype=np.float32)

    # Horizontal seam blend
    half_w = size // 2
    shifted_x = np.roll(arr, shift=half_w, axis=1)
    x = np.linspace(0, np.pi * 2, size, endpoint=False)
    # 1 at center, 0 at edges of original (where seam was)
    wx = (1.0 - np.cos(x)) * 0.5
    wx = wx[None, :, None]
    # Actually at x=0 (edge of shifted = center of original), we want shifted; at x=half_w (center of shifted = edge of original), we want original?
    # Wait: in original `arr`, the seam is at x=0 and x=size-1.
    # In `shifted_x`, the original seam is moved to x=half_w, while x=0/size-1 is continuous!
    # So we want `shifted_x` near x=0/size-1 (wx=0) and `arr` near x=half_w (wx=1).
    # Note: (1 - cos(x))/2 is 0 at x=0 and 1 at x=pi (half_w). Perfect!
    blended = shifted_x * (1.0 - wx) + arr * wx

    if not horizontal_only:
        half_h = size // 2
        shifted_y = np.roll(blended, shift=half_h, axis=0)
        y = np.linspace(0, np.pi * 2, size, endpoint=False)
        wy = ((1.0 - np.cos(y)) * 0.5)[:, None, None]
        blended = shifted_y * (1.0 - wy) + blended * wy

    return Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8), "RGBA")


def build_normal_map(img: Image.Image, strength: float = 2.4) -> Image.Image:
    """Generate a tileable Sobel tangent-space normal map from luminance."""
    gray = np.array(img.convert("L"), dtype=np.float32) / 255.0
    # Wrap-around padding for seamless normals
    p = np.pad(gray, 1, mode="wrap")
    gx = (
        (p[0:-2, 2:] + 2.0 * p[1:-1, 2:] + p[2:, 2:])
        - (p[0:-2, 0:-2] + 2.0 * p[1:-1, 0:-2] + p[2:, 0:-2])
    ) * strength
    gy = (
        (p[2:, 0:-2] + 2.0 * p[2:, 1:-1] + p[2:, 2:])
        - (p[0:-2, 0:-2] + 2.0 * p[0:-2, 1:-1] + p[0:-2, 2:])
    ) * strength

    nx = -gx
    ny = -gy
    nz = np.ones_like(nx)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx /= norm
    ny /= norm
    nz /= norm

    rgb = np.stack(
        [
            ((nx * 0.5 + 0.5) * 255.0),
            ((ny * 0.5 + 0.5) * 255.0),
            ((nz * 0.5 + 0.5) * 255.0),
        ],
        axis=-1,
    )
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def flood_fill_remove_white(img: Image.Image, white_thresh: int = 236, glow_dehalo: bool = False) -> Image.Image:
    """Remove outer white background via BFS flood-fill without eating interior whites."""
    rgba = np.array(img.convert("RGBA"))
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)

    is_bg_candidate = (
        (rgb[:, :, 0] >= white_thresh)
        & (rgb[:, :, 1] >= white_thresh)
        & (rgb[:, :, 2] >= white_thresh)
    )

    visited = np.zeros((h, w), dtype=bool)
    q = deque()

    for x in range(w):
        if is_bg_candidate[0, x]:
            visited[0, x] = True
            q.append((0, x))
        if is_bg_candidate[h - 1, x] and not visited[h - 1, x]:
            visited[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if is_bg_candidate[y, 0] and not visited[y, 0]:
            visited[y, 0] = True
            q.append((y, 0))
        if is_bg_candidate[y, w - 1] and not visited[y, w - 1]:
            visited[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg_candidate[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

    alpha = np.where(visited, 0, 255).astype(np.float32)

    # Soften 1-2px fringe around visited background to remove white halo
    if glow_dehalo:
        # For glowing cyan props on white, convert near-white cyan glow to translucent cyan
        r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        min_c = np.minimum(np.minimum(r, g), b)
        max_c = np.maximum(np.maximum(r, g), b)
        sat = max_c - min_c
        # Bright + low-medium saturation near edge -> translucent glow
        near_bg = np.zeros((h, w), dtype=bool)
        for dy in range(-12, 13, 3):
            for dx in range(-12, 13, 3):
                shifted = np.roll(np.roll(visited, dy, axis=0), dx, axis=1)
                near_bg |= shifted
        glow_mask = (~visited) & near_bg & (min_c > 195) & (sat < 65)
        alpha = np.where(glow_mask, np.clip((255 - min_c) * 3.5, 0, 220), alpha)
        # Boost cyan saturation on glow pixels so they don't look washed white
        rgba[:, :, 0] = np.where(glow_mask, np.clip(r - (min_c - 160), 0, 255), r).astype(np.uint8)
    else:
        # 1px fringe softening for solid props
        fringe = np.zeros((h, w), dtype=bool)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            fringe |= np.roll(np.roll(visited, dy, axis=0), dx, axis=1)
        fringe &= ~visited
        luma = (rgb[:, :, 0] + rgb[:, :, 1] + rgb[:, :, 2]) / 3.0
        soft_a = np.where(fringe & (luma > 200), np.clip((255.0 - luma) * 3.8, 40, 255), alpha)
        alpha = soft_a

    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    return out


def resize_fit_height(img: Image.Image, target_h: int) -> Image.Image:
    w, h = img.size
    new_w = max(1, int(round(w * (target_h / float(h)))))
    return img.resize((new_w, target_h), Image.Resampling.LANCZOS)


def main():
    ENV_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Tiles (128x128 seamless + normal maps)
    tile_specs = [
        ("env_floor_bamboo_1795404771558.jpg", "floor_bamboo.png", "floor_bamboo_n.png", False, 2.2),
        ("env_floor_slate_1795404781817.jpg", "floor_slate.png", "floor_slate_n.png", False, 2.4),
        ("env_wall_bamboo_1795404793106.jpg", "wall_bamboo.png", "wall_bamboo_n.png", True, 2.2),
        ("env_wall_stone_1795404803106.jpg", "wall_stone.png", "wall_stone_n.png", True, 2.5),
    ]
    for src_name, diff_name, norm_name, horiz_only, strength in tile_specs:
        src = Image.open(ARTIFACT_DIR / src_name)
        diff = make_seamless_tile(src, size=128, horizontal_only=horiz_only)
        norm = build_normal_map(diff, strength=strength)
        diff.save(ENV_DIR / diff_name)
        norm.save(ENV_DIR / norm_name)
        print(f"Saved tile {diff_name} & {norm_name} ({diff.size})")

    # 2. Props from 2x2 sheets
    nature = Image.open(ARTIFACT_DIR / "xianxia_props_nature_1795404773855.jpg")
    nw, nh = nature.size
    nature_quads = [
        ((0, 0, nw // 2, nh // 2), "prop_peach_tree.png", 220, False),
        ((nw // 2, 0, nw, nh // 2), "prop_bamboo_clump.png", 220, False),
        ((0, nh // 2, nw // 2, nh), "prop_dragon_pillar.png", 210, False),
        ((nw // 2, nh // 2, nw, nh), "prop_jade_crystal.png", 140, True),
    ]
    for box, out_name, target_h, glow in nature_quads:
        crop = nature.crop(box)
        clean = flood_fill_remove_white(crop, white_thresh=236, glow_dehalo=glow)
        final = resize_fit_height(clean, target_h)
        final.save(ENV_DIR / out_name)
        print(f"Saved prop {out_name} ({final.size})")

    fixtures = Image.open(ARTIFACT_DIR / "xianxia_props_fixtures_1795404781992.jpg")
    fw, fh = fixtures.size
    fixture_quads = [
        ((0, 0, fw // 2, fh // 2), "prop_lantern.png", 150, False),
        ((fw // 2, 0, fw, fh // 2), "prop_brazier.png", 125, False),
        ((fw // 2, fh // 2, fw, fh), "prop_banner.png", 190, False),
    ]
    for box, out_name, target_h, glow in fixture_quads:
        crop = fixtures.crop(box)
        clean = flood_fill_remove_white(crop, white_thresh=236, glow_dehalo=glow)
        final = resize_fit_height(clean, target_h)
        final.save(ENV_DIR / out_name)
        print(f"Saved prop {out_name} ({final.size})")

    # Bagua floor seal: convert white background everywhere (including inner rings) to transparent cyan glow
    bagua_crop = fixtures.crop((0, fh // 2, fw // 2, fh)).convert("RGBA")
    arr = np.array(bagua_crop, dtype=np.float32)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    # Pure white (low sat, high r) -> transparent; cyan lines (higher sat or lower r) -> opaque glowing cyan
    a = np.clip((sat * 3.2) + np.clip(245.0 - r, 0, 255) * 1.4, 0, 235)
    # Where completely white (r>245 and sat<10), alpha=0
    a = np.where((r > 242) & (sat < 12), 0.0, a)
    arr[:, :, 3] = a
    bagua_clean = Image.fromarray(arr.astype(np.uint8))
    bbox = bagua_clean.getbbox()
    if bbox:
        bagua_clean = bagua_clean.crop(bbox)
    bagua_final = resize_fit_height(bagua_clean, 240)
    bagua_final.save(ENV_DIR / "prop_bagua_floor.png")
    print(f"Saved prop prop_bagua_floor.png ({bagua_final.size})")


if __name__ == "__main__":
    main()
