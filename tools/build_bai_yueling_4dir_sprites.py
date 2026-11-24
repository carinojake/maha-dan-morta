#!/usr/bin/env python3
"""
Builds Bai Yueling 4-directional walk (walk_down, walk_up, walk_side - 3 frames each)
and 4-frame action strips (attack_4f, skill_4f - 4 frames each) for both Default
and Snow Cloak (alt / alt_snow) costumes.

Key guarantees:
1. Exterior-only flood-fill removes white/semi-transparent background from cell borders
   without touching white pixels inside the dress or snow-fur collar.
2. Uniform character height (TARGET_BODY_H = 224 px) and Center-Bottom Anchor
   (ANCHOR_X = 200, ANCHOR_Y = 282 on 400x320 cells) so switching between walk_down,
   walk_up, walk_side, attack_4f, and skill_4f never jitters or shifts the feet.
"""
import os
import shutil
from collections import deque
import numpy as np
from PIL import Image

ART_DIR = "/Users/Shared/my_ai_project/01_ACTIVE_PROJECTS/6.game/HERO_GALLERY/01_bai_yueling_ไป๋เยว่หลิง/artwork"
PROJECT_DIR = "/Users/jake/Downloads/rocg/maha-dan-morta"
HERO_DIR = os.path.join(PROJECT_DIR, "assets", "heroes", "bai_yueling")
ALT_DIR = os.path.join(HERO_DIR, "alt")
ALT_SNOW_DIR = os.path.join(HERO_DIR, "alt_snow")

CELL_W = 400
CELL_H = 320
ANCHOR_X = 200
ANCHOR_Y = 282
TARGET_BODY_H = 224


def flood_clean_exterior(im: Image.Image) -> np.ndarray:
    """
    Flood-fills from the outer image edges to remove white or faint-alpha background
    while preserving 100% of interior white clothing and snow-fur pixels.
    """
    rgba = im.convert("RGBA")
    arr = np.array(rgba, dtype=np.int32)
    h, w, _ = arr.shape
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]

    # Exterior background is either transparent/faint (a < 85) or near-white neutral
    is_bg_candidate = (a < 85) | (
        (r >= 235) & (g >= 235) & (b >= 235) & (np.abs(r - g) <= 14) & (np.abs(g - b) <= 14)
    )

    visited = np.zeros((h, w), dtype=bool)
    bg_mask = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        if cy < 0 or cy >= h or cx < 0 or cx >= w or visited[cy, cx]:
            continue
        visited[cy, cx] = True
        if is_bg_candidate[cy, cx]:
            bg_mask[cy, cx] = True
            q.append((cy - 1, cx))
            q.append((cy + 1, cx))
            q.append((cy, cx - 1))
            q.append((cy, cx + 1))

    out = arr.astype(np.uint8)
    out[bg_mask, 0] = 0
    out[bg_mask, 1] = 0
    out[bg_mask, 2] = 0
    out[bg_mask, 3] = 0

    # Ensure interior character pixels (not reached by exterior flood) are solid opaque
    interior = ~bg_mask & (out[..., 3] >= 85)
    out[interior, 3] = 255
    return out


def find_x_spans(alpha_mask: np.ndarray, min_gap: int = 8) -> list[tuple[int, int]]:
    col_has = alpha_mask.any(axis=0)
    xs = np.where(col_has)[0]
    if len(xs) == 0:
        return []
    spans: list[tuple[int, int]] = []
    start = prev = int(xs[0])
    for x in xs[1:]:
        x = int(x)
        if x - prev > min_gap:
            spans.append((start, prev + 1))
            start = x
        prev = x
    spans.append((start, prev + 1))
    return spans


def extract_frames_from_row(row_arr: np.ndarray, min_gap: int = 8) -> list[Image.Image]:
    spans = find_x_spans(row_arr[..., 3] > 20, min_gap=min_gap)
    frames: list[Image.Image] = []
    for x0, x1 in spans:
        sub = row_arr[:, x0:x1]
        ys = np.where(sub[..., 3] > 20)[0]
        if len(ys) == 0:
            continue
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        frames.append(Image.fromarray(sub[y0:y1, :]))
    return frames


def build_normalized_strip(
    frames: list[Image.Image],
    out_path: str,
    is_action_strip: bool = False,
) -> None:
    """
    Scales all frames in the strip using a uniform character body scale (derived from
    Frame 0's standing height -> TARGET_BODY_H = 224 px) and places each frame on a
    (CELL_W, CELL_H) = (400, 320) cell anchored at Center-Bottom (ANCHOR_X, ANCHOR_Y).
    """
    assert len(frames) > 0, f"No frames provided for {out_path}"
    ref_h = float(frames[0].height)
    scale = TARGET_BODY_H / max(ref_h, 1.0)
    ref_body_w = int(round(frames[0].width * scale))

    strip = Image.new("RGBA", (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
    for idx, f_im in enumerate(frames):
        nw = max(1, int(round(f_im.width * scale)))
        nh = max(1, int(round(f_im.height * scale)))
        # Cap width to CELL_W - 8 only if a wide skill projectile exceeds cell width
        if nw > CELL_W - 8:
            shrink = (CELL_W - 8) / float(nw)
            nw = CELL_W - 8
            nh = max(1, int(round(nh * shrink)))
        resized = f_im.resize((nw, nh), Image.Resampling.LANCZOS)

        # Center-Bottom Anchor:
        # For directional walk strips, center each frame horizontally at ANCHOR_X.
        # For action strips (attack_4f / skill_4f) where sword/magic extends right,
        # align the character's left/body mass consistently with Frame 0 so her body
        # doesn't shift left when the sword beam extends right.
        if is_action_strip and nw > ref_body_w * 1.18:
            body_left = ANCHOR_X - (ref_body_w // 2) - 18
            paste_x = max(4, min(body_left, CELL_W - nw - 4))
        else:
            paste_x = ANCHOR_X - (nw // 2)
        paste_y = max(2, ANCHOR_Y - nh)

        strip.paste(resized, (idx * CELL_W + paste_x, paste_y), resized)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    strip.save(out_path)
    print(f"Saved {os.path.relpath(out_path, PROJECT_DIR)}: size={strip.size} ({len(frames)} frames)")


def process_default_costume() -> None:
    # 1. walk_down.png (3f) & walk_up.png (3f)
    im_ud = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - เดินหน้าและหลัง.png"))
    clean_ud = flood_clean_exterior(im_ud)
    frames_ud = extract_frames_from_row(clean_ud, min_gap=10)
    assert len(frames_ud) == 6, f"Expected 6 frames in เดินหน้าและหลัง, got {len(frames_ud)}"
    build_normalized_strip(frames_ud[:3], os.path.join(HERO_DIR, "walk_down.png"))
    build_normalized_strip(frames_ud[3:6], os.path.join(HERO_DIR, "walk_up.png"))

    # 2. walk_side.png (3f)
    im_side = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - เดินและโจมตี.png"))
    clean_side = flood_clean_exterior(im_side)
    frames_side = extract_frames_from_row(clean_side, min_gap=10)
    assert len(frames_side) >= 3, f"Expected >=3 frames in เดินและโจมตี, got {len(frames_side)}"
    build_normalized_strip(frames_side[:3], os.path.join(HERO_DIR, "walk_side.png"))

    # 3. attack_4f.png (Row 1 of แอ็กชัน สกิล และชุด) & skill_4f.png (Row 2 of แอ็กชัน สกิล และชุด)
    im_act = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - แอ็กชัน สกิล และชุด.png"))
    clean_act = flood_clean_exterior(im_act)
    h, w, _ = clean_act.shape
    rh = h // 3

    frames_atk = extract_frames_from_row(clean_act[0:rh, :], min_gap=6)
    assert len(frames_atk) == 4, f"Expected 4 frames in Row 1 (attack), got {len(frames_atk)}"
    build_normalized_strip(frames_atk, os.path.join(HERO_DIR, "attack_4f.png"), is_action_strip=True)

    frames_skl = extract_frames_from_row(clean_act[rh : 2 * rh, :], min_gap=6)
    assert len(frames_skl) == 4, f"Expected 4 frames in Row 2 (skill), got {len(frames_skl)}"
    build_normalized_strip(frames_skl, os.path.join(HERO_DIR, "skill_4f.png"), is_action_strip=True)


def process_alt_snow_costume() -> None:
    os.makedirs(ALT_DIR, exist_ok=True)
    os.makedirs(ALT_SNOW_DIR, exist_ok=True)

    # 1. walk_down.png (3f) & walk_up.png (3f)
    im_ud = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินหน้าและหลัง.png"))
    clean_ud = flood_clean_exterior(im_ud)
    frames_ud = extract_frames_from_row(clean_ud, min_gap=10)
    assert len(frames_ud) == 6, f"Expected 6 frames in ชุดคลุมหิมะ เดินหน้าและหลัง, got {len(frames_ud)}"
    build_normalized_strip(frames_ud[:3], os.path.join(ALT_DIR, "walk_down.png"))
    build_normalized_strip(frames_ud[3:6], os.path.join(ALT_DIR, "walk_up.png"))

    # 2. walk_side.png (3f) & attack_4f.png (4f: ready stance + 3 attack frames)
    im_sa = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินและโจมตี.png"))
    clean_sa = flood_clean_exterior(im_sa)
    frames_sa = extract_frames_from_row(clean_sa, min_gap=10)
    assert len(frames_sa) == 6, f"Expected 6 frames in ชุดคลุมหิมะ เดินและโจมตี, got {len(frames_sa)}"
    build_normalized_strip(frames_sa[:3], os.path.join(ALT_DIR, "walk_side.png"))
    atk_4_frames = [frames_sa[0], frames_sa[3], frames_sa[4], frames_sa[5]]
    build_normalized_strip(atk_4_frames, os.path.join(ALT_DIR, "attack_4f.png"), is_action_strip=True)

    # 3. skill_4f.png (4f)
    im_sk = Image.open(os.path.join(ART_DIR, "ไป๋เยว่หลิง - ชุดคลุมหิมะ สกิล.png"))
    clean_sk = flood_clean_exterior(im_sk)
    frames_sk = extract_frames_from_row(clean_sk, min_gap=10)
    assert len(frames_sk) == 4, f"Expected 4 frames in ชุดคลุมหิมะ สกิล, got {len(frames_sk)}"
    build_normalized_strip(frames_sk, os.path.join(ALT_DIR, "skill_4f.png"), is_action_strip=True)

    # Mirror into alt_snow/ so both alt/ and alt_snow/ paths have identical files
    for fname in ("walk_down.png", "walk_up.png", "walk_side.png", "attack_4f.png", "skill_4f.png"):
        shutil.copy2(os.path.join(ALT_DIR, fname), os.path.join(ALT_SNOW_DIR, fname))


if __name__ == "__main__":
    process_default_costume()
    process_alt_snow_costume()
    print("Successfully built all Bai Yueling 4-dir walk, attack_4f, and skill_4f sprite sheets.")
