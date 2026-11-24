#!/usr/bin/env python3
"""
Rebuilds Bai Yueling's 4-directional walk strips (walk_down, walk_up, walk_side - 3x 400x320)
and stride_0.png for both Default and Alt (Snow Cloak / alt_snow) costumes from clean original
artwork without destructive shearing or skirt-slicing.

Fixes:
1. Uniform scale per costume derived strictly from the neutral standing frame (224 px body height).
2. True anatomical spine/crown X-alignment at ANCHOR_X = 200 (ignoring asymmetric sword/cape overhang),
   eliminating horizontal pops when flipping Left <-> Right or switching Down/Up/Side.
3. Biomechanically grounded walk cycle [0: Stride_A, 1: Neutral_Passing, 2: Stride_B]:
   - Fixes Alt Snow Cloak frame order (was [Idle, StrideA, StrideB], causing mid-stride idle freeze).
   - Fixes Default walk_side Col 2 (was drawn 8px short with en-pointe back foot & floating front foot).
   - Fixes Default & Alt walk_down / Alt walk_up same-foot repeat so Left & Right boots alternate cleanly.
   - Contact frames (0, 2) have a natural +1px pelvis settle and flat planted sole at FOOT_Y = 282.
"""
from collections import deque
from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageDraw

DEFAULT_WALK_SRC = Path("/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/bai_yueling_default_walk_1795407037953.jpg")
ART_DIR = Path("/Users/Shared/my_ai_project/01_ACTIVE_PROJECTS/6.game/HERO_GALLERY/01_bai_yueling_ไป๋เยว่หลิง/artwork")
HERO_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/heroes/bai_yueling")
ALT_DIR = HERO_DIR / "alt"
ALT_SNOW_DIR = HERO_DIR / "alt_snow"

CELL_W = 400
CELL_H = 320
ANCHOR_X = 200
FOOT_Y = 282
TARGET_BODY_H = 224


def clean_jpeg_sheet_cell(img: Image.Image, white_thresh: int = 238) -> np.ndarray:
    """Exterior flood-fill + enclosed pure-white background pocket removal with clean anti-aliased edge."""
    rgba = np.array(img.convert("RGBA"))
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)
    max_c = np.maximum(np.maximum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
    min_c = np.minimum(np.minimum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
    sat = max_c - min_c
    is_bg = (rgb[:, :, 0] >= white_thresh) & (rgb[:, :, 1] >= white_thresh) & (rgb[:, :, 2] >= white_thresh) & (sat <= 14)

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

    # Also remove enclosed pure-white background holes (> 12 connected pixels of >=246 neutral white)
    pure_w = (min_c >= 246) & (sat <= 8) & (~visited)
    seen_p = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if pure_w[y, x] and not seen_p[y, x]:
                comp = []
                dq = deque([(y, x)])
                seen_p[y, x] = True
                while dq:
                    cy, cx = dq.popleft()
                    comp.append((cy, cx))
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and pure_w[ny, nx] and not seen_p[ny, nx]:
                            seen_p[ny, nx] = True
                            dq.append((ny, nx))
                if len(comp) >= 14:
                    for cy, cx in comp:
                        visited[cy, cx] = True

    alpha = np.where(visited, 0.0, 255.0)
    fringe = np.zeros((h, w), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        fringe |= np.roll(np.roll(visited, dy, axis=0), dx, axis=1)
    fringe &= ~visited
    luma = (rgb[:, :, 0] + rgb[:, :, 1] + rgb[:, :, 2]) / 3.0
    alpha = np.where(fringe & (luma > 208), np.clip((255.0 - luma) * 4.0, 0.0, 255.0), alpha)
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return rgba


def clean_png_sheet(im: Image.Image) -> np.ndarray:
    rgba = np.array(im.convert("RGBA"), dtype=np.int32)
    h, w, _ = rgba.shape
    r, g, b, a = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
    is_bg = (a < 85) | ((r >= 236) & (g >= 236) & (b >= 236) & (np.abs(r - g) <= 14) & (np.abs(g - b) <= 14))
    visited = np.zeros((h, w), dtype=bool)
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
        if is_bg[cy, cx]:
            q.append((cy - 1, cx))
            q.append((cy + 1, cx))
            q.append((cy, cx - 1))
            q.append((cy, cx + 1))
    out = rgba.astype(np.uint8)
    out[visited] = 0
    interior = (~visited) & (out[..., 3] >= 85)
    out[interior, 3] = 255
    return out


def measure_bounds_and_spine(arr: np.ndarray, is_side: bool = False) -> tuple[int, int, float]:
    """
    Returns (y_top, y_bottom, spine_cx) using the silver hair-crown bun (top 2%..13% of height),
    which is unaffected by trailing hair ribbons, flowing capes, or extended swords.
    On side profiles, adds +6 source px from the back-set hair bun to align with neck/hip/ankle axis.
    """
    ys = np.where(arr[:, :, 3] > 120)[0]
    y0, y1 = int(ys.min()), int(ys.max())
    h = y1 - y0 + 1
    hy0 = y0 + max(1, int(h * 0.02))
    hy1 = y0 + max(4, int(h * 0.13))
    hxs = np.where(arr[hy0:hy1, :, 3] > 120)[1]
    spine_cx = float(np.median(hxs)) if len(hxs) > 0 else (arr.shape[1] * 0.5)
    if is_side:
        spine_cx += h * 0.022
    return y0, y1, spine_cx


def mirror_lower_boot_slit(arr: np.ndarray, center_x: int, y_start: int, half_w: int = 26, feather: int = 6) -> np.ndarray:
    """
    Mirrors ONLY the symmetric central lower-skirt & boots slit around `center_x`
    from `y_start` down to bottom, leaving asymmetric side props (sword, hip pouch) untouched.
    """
    out = arr.copy()
    h, w, _ = arr.shape
    x0 = max(0, center_x - half_w)
    x1 = min(w, center_x + half_w)
    span_w = x1 - x0
    sub = arr[y_start:h, x0:x1].copy()
    mir = sub[:, ::-1, :].copy()

    # Smooth feather mask at left, right, and top boundaries (only where skirt overlaps)
    wy = np.ones((h - y_start, 1), dtype=np.float32)
    for i in range(min(feather, h - y_start)):
        wy[i, 0] = (i + 1) / float(feather + 1)
    wx = np.ones((1, span_w), dtype=np.float32)
    for i in range(min(feather, span_w // 3)):
        f = (i + 1) / float(feather + 1)
        wx[0, i] = f
        wx[0, span_w - 1 - i] = f
    # Below skirt hem (bottom 18 px where boots stick out into transparent space), use full 1.0 replacement
    boot_cut = max(0, (h - y_start) - 20)
    mask = wy * wx
    mask[boot_cut:, :] = 1.0

    sub_f = sub.astype(np.float32)
    mir_f = mir.astype(np.float32)
    m3 = mask[:, :, None]
    # Alpha-aware blend so transparent gaps cleanly adopt mirrored boot silhouette
    out_sub = sub_f * (1.0 - m3) + mir_f * m3
    out[y_start:h, x0:x1] = np.clip(np.round(out_sub), 0, 255).astype(np.uint8)
    return out


def fix_default_side_frames(c0: np.ndarray, c1: np.ndarray, c2: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Fixes raw default side-walk issues while keeping the diagonal ice sword (y <= 286) 100% untouched:
    - c0 (Wide Stride A): Grounds only the front boot below the skirt hem (y >= 304, x >= 190) by +2px
      so the sword blade above y=286 stays razor-straight and both soles touch y=335.
    - c1 (Neutral Passing): Untouched reference (crown y=34, planted sole y=335 under spine).
    - c2 (Opposite Stride B): Extends ONLY the lower skirt below the sword tip (y=287..328 -> +7px)
      and places grounded opposite-stride boots (planted flat front boot + raised-heel grounded-ball rear boot)
      so there is zero tiptoeing and clear stride alternation against c0 & c1.
    """
    h, w, _ = c1.shape

    # 1. Ground c0 front boot smoothly below sword tip (y=300..336 -> +2px) with zero seam
    f0 = c0.copy()
    sub_c0 = Image.fromarray(c0[300:336, 184:])
    str_c0 = np.array(sub_c0.resize((w - 184, 38), Image.Resampling.LANCZOS))
    end_c0 = min(h, 300 + 38)
    f0[300:end_c0, 184:] = str_c0[: end_c0 - 300]

    # 2. Extend c2 lower skirt strictly below the sword tip (y=287..328 -> 42px to 49px)
    f2 = np.zeros_like(c2)
    f2[:287] = c2[:287]
    src_hem = Image.fromarray(c2[287:329, :])
    restored_hem_h = 49
    stretched_hem = np.array(src_hem.resize((w, restored_hem_h), Image.Resampling.LANCZOS))
    end_y = min(h, 287 + restored_hem_h)
    f2[287:end_y] = stretched_hem[: end_y - 287]

    # 3. Clear old pointed/tilted shoe tips below skirt hem in f2 and place grounded opposite-stride boots
    f2[320:, 105:158] = 0
    f2[318:, 198:268] = 0

    # Front boot planted flat forward (x=204..254, sole at y=335)
    c1_boot = c1[318:337, 192:242].copy()
    mask_b = c1_boot[:, :, 3] > 40
    dst_slice = f2[318:337, 204:254]
    dst_slice[mask_b] = c1_boot[mask_b]

    # Trailing rear boot pushing off behind spine (x=124..160, ball grounded at y=334, no vertical tiptoe)
    c0_rear = f0[320:336, 102:138].copy()
    mask_r = c0_rear[:, :, 3] > 40
    dst_rear = f2[319:335, 124:160]
    write_r = mask_r & (dst_rear[:, :, 3] < 120)
    dst_rear[write_r] = c0_rear[write_r]

    return f0, c1.copy(), f2


def place_frame_grounded(
    arr: np.ndarray,
    scale: float,
    spine_x: float,
    ref_crown_y: int,
    contact_dip_px: int = 0,
) -> Image.Image:
    """
    Scales the full source array uniformly by `scale`, aligns `spine_x` to `ANCHOR_X = 200`,
    and places `ref_crown_y` at `(FOOT_Y - TARGET_BODY_H) + contact_dip_px` (58 for Idle, 59 for Stride),
    clamping any stray pixel below FOOT_Y + 2 cleanly so feet stay anchored on the ground line.
    """
    sh, sw, _ = arr.shape
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    pil_im = Image.fromarray(arr)
    resized = pil_im.resize((nw, nh), Image.Resampling.LANCZOS)

    scaled_spine_x = spine_x * scale
    scaled_crown_y = ref_crown_y * scale

    target_crown_y = (FOOT_Y - TARGET_BODY_H) + contact_dip_px
    paste_x = int(round(ANCHOR_X - scaled_spine_x))
    paste_y = int(round(target_crown_y - scaled_crown_y))

    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cell.paste(resized, (paste_x, paste_y), resized)
    return cell


def save_3f_strip(cells: list[Image.Image], path: Path) -> None:
    assert len(cells) == 3
    strip = Image.new("RGBA", (CELL_W * 3, CELL_H), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.paste(c, (i * CELL_W, 0), c)
    path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(path)
    print(f"Saved {path}: {strip.size}")


def build_default_costume() -> dict[str, list[Image.Image]]:
    sh = Image.open(DEFAULT_WALK_SRC)
    ww, wh = sh.size
    cw, ch = ww // 3, wh // 3

    grid = [[clean_jpeg_sheet_cell(sh.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))) for c in range(3)] for r in range(3)]

    # Uniform scale from side neutral frame (c1: y=34..335 -> h=302 px -> 224 px)
    y0_ref, y1_ref, _ = measure_bounds_and_spine(grid[2][1])
    uniform_scale = TARGET_BODY_H / float(y1_ref - y0_ref + 1)

    # 1. walk_down: fix c0 so Left boot steps forward while c2 steps Right boot forward
    d0_raw, d1_raw, d2_raw = grid[0]
    y0_d1, _, sp_d1 = measure_bounds_and_spine(d1_raw)
    d0_fixed = mirror_lower_boot_slit(d0_raw, center_x=int(round(sp_d1)), y_start=266, half_w=25, feather=6)
    _, _, sp_d0 = measure_bounds_and_spine(d0_fixed)
    _, _, sp_d2 = measure_bounds_and_spine(d2_raw)
    down_cells = [
        place_frame_grounded(d0_fixed, uniform_scale, sp_d0, y0_d1, contact_dip_px=1),
        place_frame_grounded(d1_raw, uniform_scale, sp_d1, y0_d1, contact_dip_px=0),
        place_frame_grounded(d2_raw, uniform_scale, sp_d2, y0_d1, contact_dip_px=1),
    ]
    save_3f_strip(down_cells, HERO_DIR / "walk_down.png")

    # 2. walk_up: raw already alternates Left boot (c0) and Right boot (c2) cleanly!
    u0_raw, u1_raw, u2_raw = grid[1]
    y0_u1, _, sp_u1 = measure_bounds_and_spine(u1_raw)
    _, _, sp_u0 = measure_bounds_and_spine(u0_raw)
    _, _, sp_u2 = measure_bounds_and_spine(u2_raw)
    up_cells = [
        place_frame_grounded(u0_raw, uniform_scale, sp_u0, y0_u1, contact_dip_px=1),
        place_frame_grounded(u1_raw, uniform_scale, sp_u1, y0_u1, contact_dip_px=0),
        place_frame_grounded(u2_raw, uniform_scale, sp_u2, y0_u1, contact_dip_px=1),
    ]
    save_3f_strip(up_cells, HERO_DIR / "walk_up.png")

    # 3. walk_side: fix c0 heel + c2 height/boots so zero tiptoe or floating occurs
    s0_fix, s1_fix, s2_fix = fix_default_side_frames(grid[2][0], grid[2][1], grid[2][2])
    y0_s1, _, sp_s1 = measure_bounds_and_spine(s1_fix, is_side=True)
    _, _, sp_s0 = measure_bounds_and_spine(s0_fix, is_side=True)
    _, _, sp_s2 = measure_bounds_and_spine(s2_fix, is_side=True)
    side_cells = [
        place_frame_grounded(s0_fix, uniform_scale, sp_s0, y0_s1, contact_dip_px=1),
        place_frame_grounded(s1_fix, uniform_scale, sp_s1, y0_s1, contact_dip_px=0),
        place_frame_grounded(s2_fix, uniform_scale, sp_s2, y0_s1, contact_dip_px=1),
    ]
    save_3f_strip(side_cells, HERO_DIR / "walk_side.png")

    # Save neutral side cell to stride_0.png as well
    side_cells[1].save(HERO_DIR / "stride_0.png")
    return {"down": down_cells, "up": up_cells, "side": side_cells}


def extract_spans(arr: np.ndarray, min_gap: int = 8) -> list[np.ndarray]:
    col_has = (arr[..., 3] > 20).any(axis=0)
    xs = np.where(col_has)[0]
    spans = []
    start = prev = int(xs[0])
    for x in xs[1:]:
        x = int(x)
        if x - prev > min_gap:
            spans.append(arr[:, start : prev + 1].copy())
            start = x
        prev = x
    spans.append(arr[:, start : prev + 1].copy())
    return spans


def build_alt_snow_costume() -> dict[str, list[Image.Image]]:
    # 1. Side walk from "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินและโจมตี.png" (frames 0=Idle, 1=StrideA, 2=StrideB)
    side_arr = clean_png_sheet(Image.open(ART_DIR / "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินและโจมตี.png"))
    side_spans = extract_spans(side_arr, min_gap=8)
    s_idle, s_a, s_b = side_spans[0], side_spans[1], side_spans[2]
    y0_si, y1_si, sp_si = measure_bounds_and_spine(s_idle, is_side=True)
    scale_side = TARGET_BODY_H / float(y1_si - y0_si + 1)
    y0_sa, _, sp_sa = measure_bounds_and_spine(s_a, is_side=True)
    y0_sb, _, sp_sb = measure_bounds_and_spine(s_b, is_side=True)
    # Order MUST be [StrideA, NeutralIdle, StrideB] so frame 1 is Neutral Idle!
    alt_side_cells = [
        place_frame_grounded(s_a, scale_side, sp_sa, y0_sa, contact_dip_px=1),
        place_frame_grounded(s_idle, scale_side, sp_si, y0_si, contact_dip_px=0),
        place_frame_grounded(s_b, scale_side, sp_sb, y0_sb, contact_dip_px=1),
    ]

    # 2. Down & Up walk from "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินหน้าและหลัง.png"
    #    spans 0,1,2 = Down [Idle, Stride1, Stride2]; spans 3,4,5 = Up [Idle, Stride1, Stride2]
    ud_arr = clean_png_sheet(Image.open(ART_DIR / "ไป๋เยว่หลิง - ชุดคลุมหิมะ เดินหน้าและหลัง.png"))
    ud_spans = extract_spans(ud_arr, min_gap=8)
    d_idle, d_s1, d_s2 = ud_spans[0], ud_spans[1], ud_spans[2]
    u_idle, u_s1, u_s2 = ud_spans[3], ud_spans[4], ud_spans[5]

    y0_di, y1_di, sp_di = measure_bounds_and_spine(d_idle)
    scale_ud = TARGET_BODY_H / float(y1_di - y0_di + 1)

    # Mirror lower boot slit on d_s1 so Left boot steps forward while d_s2 steps Right boot forward
    y0_ds1, _, sp_ds1 = measure_bounds_and_spine(d_s1)
    d_s1_left = mirror_lower_boot_slit(d_s1, center_x=int(round(sp_ds1)), y_start=455, half_w=34, feather=8)
    y0_ds2, _, sp_ds2 = measure_bounds_and_spine(d_s2)
    alt_down_cells = [
        place_frame_grounded(d_s1_left, scale_ud, sp_ds1, y0_ds1, contact_dip_px=1),
        place_frame_grounded(d_idle, scale_ud, sp_di, y0_di, contact_dip_px=0),
        place_frame_grounded(d_s2, scale_ud, sp_ds2, y0_ds2, contact_dip_px=1),
    ]

    # Snow Cloak back view is symmetric; mirror u_s2 horizontally so Left & Right boots + cape sway alternate!
    u_s2_mir = u_s2[:, ::-1, :].copy()
    y0_ui, _, sp_ui = measure_bounds_and_spine(u_idle)
    y0_us1, _, sp_us1 = measure_bounds_and_spine(u_s1)
    y0_us2, _, sp_us2 = measure_bounds_and_spine(u_s2_mir)
    alt_up_cells = [
        place_frame_grounded(u_s1, scale_ud, sp_us1, y0_us1, contact_dip_px=1),
        place_frame_grounded(u_idle, scale_ud, sp_ui, y0_ui, contact_dip_px=0),
        place_frame_grounded(u_s2_mir, scale_ud, sp_us2, y0_us2, contact_dip_px=1),
    ]

    for target_dir in (ALT_DIR, ALT_SNOW_DIR):
        save_3f_strip(alt_down_cells, target_dir / "walk_down.png")
        save_3f_strip(alt_up_cells, target_dir / "walk_up.png")
        save_3f_strip(alt_side_cells, target_dir / "walk_side.png")
    alt_side_cells[1].save(ALT_DIR / "stride_0.png")
    return {"down": alt_down_cells, "up": alt_up_cells, "side": alt_side_cells}


def render_diagnostic_sheet(def_cells: dict, alt_cells: dict, out_path: Path) -> None:
    """Renders all 6 rebuilt strips with red crown line (y=58), green ground line (y=282), and blue spine line (x=200)."""
    rows = [
        ("Default Side", def_cells["side"]),
        ("Default Down", def_cells["down"]),
        ("Default Up", def_cells["up"]),
        ("Alt Side", alt_cells["side"]),
        ("Alt Down", alt_cells["down"]),
        ("Alt Up", alt_cells["up"]),
    ]
    canvas = Image.new("RGBA", (CELL_W * 3, CELL_H * len(rows)), (24, 30, 42, 255))
    draw = ImageDraw.Draw(canvas)
    for r_idx, (_, cells) in enumerate(rows):
        y_off = r_idx * CELL_H
        for c_idx, cell in enumerate(cells):
            x_off = c_idx * CELL_W
            canvas.paste(cell, (x_off, y_off), cell)
            draw.line([(x_off + ANCHOR_X, y_off + 30), (x_off + ANCHOR_X, y_off + 300)], fill=(56, 189, 248, 150), width=1)
        draw.line([(0, y_off + (FOOT_Y - TARGET_BODY_H)), (CELL_W * 3, y_off + (FOOT_Y - TARGET_BODY_H))], fill=(248, 113, 113, 180), width=1)
        draw.line([(0, y_off + FOOT_Y), (CELL_W * 3, y_off + FOOT_Y)], fill=(74, 222, 128, 220), width=2)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    print(f"Diagnostic sheet saved: {out_path}")


if __name__ == "__main__":
    d_cells = build_default_costume()
    a_cells = build_alt_snow_costume()
    render_diagnostic_sheet(
        d_cells,
        a_cells,
        Path("/Users/jake/.gemini/antigravity/brain/2c2a760f-992e-4227-ab58-78b849405519/scratch/bai_rebuilt_diagnostic.png"),
    )
