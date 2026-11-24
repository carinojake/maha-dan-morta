#!/usr/bin/env python3
"""
Builds high-resolution HD-2D environment textures, glowing cyan Bagua/Domain decals,
crescent ice-sword slash VFX, corner brazier cyan flames, and extracts zero-halo
full-proportion character sprites for `scenes/test_hd2d_prototype.tscn`.
"""
import os
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

PROJECT_DIR = "/Users/jake/Downloads/rocg/maha-dan-morta"
HD2D_DIR = os.path.join(PROJECT_DIR, "assets", "hd2d")


def ensure_dir() -> None:
    os.makedirs(HD2D_DIR, exist_ok=True)


def build_floor_and_wall_textures() -> None:
    """Create crisp dark slate stone masonry textures matching the reference screenshot."""
    rng = np.random.default_rng(108)

    # 1. Floor Slate HD (256x256)
    w, h = 256, 256
    base = Image.new("RGBA", (w, h), (22, 33, 43, 255))
    draw = ImageDraw.Draw(base)

    rows = 4
    row_h = h // rows
    for r in range(rows):
        y0 = r * row_h
        y1 = y0 + row_h
        offset = (r % 2) * (w // 4)
        cols = 2
        col_w = w // cols
        for c in range(-1, cols + 1):
            x0 = c * col_w + offset
            x1 = x0 + col_w
            dx = int(rng.integers(-6, 7))
            sh = int(rng.integers(-4, 5))
            tile_col = (31 + sh, 45 + sh, 57 + sh, 255)
            bx0, by0 = max(0, x0 + dx), y0
            bx1, by1 = min(w, x1 + dx), y1
            if bx1 > bx0 + 4:
                draw.rectangle([bx0 + 2, by0 + 2, bx1 - 2, by1 - 2], fill=tile_col)
                # Subtle top highlight & dark mortar seam
                draw.line([(bx0 + 3, by0 + 3), (bx1 - 3, by0 + 3)], fill=(44 + sh, 62 + sh, 76 + sh, 255), width=2)
                draw.rectangle([bx0, by0, bx1, by1], outline=(14, 21, 28, 255), width=2)

    # Subtle stone cracks
    draw.line([(34, 28), (52, 46), (48, 61)], fill=(15, 22, 30, 255), width=2)
    draw.line([(160, 140), (185, 152), (196, 170)], fill=(15, 22, 30, 255), width=2)
    base.save(os.path.join(HD2D_DIR, "floor_slate_hd.png"))

    # 2. Wall Stone Brick HD (256x256)
    wall = Image.new("RGBA", (w, h), (16, 24, 33, 255))
    wdraw = ImageDraw.Draw(wall)
    w_rows = 4
    w_rh = h // w_rows
    for r in range(w_rows):
        y0 = r * w_rh
        y1 = y0 + w_rh
        offset = (r % 2) * (w // 4)
        col_w = w // 2
        for c in range(-1, 3):
            x0 = c * col_w + offset
            x1 = x0 + col_w
            sh = int(rng.integers(-5, 6))
            bcol = (34 + sh, 48 + sh, 60 + sh, 255)
            bx0, by0 = max(0, x0), y0
            bx1, by1 = min(w, x1), y1
            if bx1 > bx0 + 4:
                wdraw.rectangle([bx0 + 2, by0 + 2, bx1 - 2, by1 - 2], fill=bcol)
                wdraw.line([(bx0 + 3, by0 + 3), (bx1 - 3, by0 + 3)], fill=(48 + sh, 66 + sh, 82 + sh, 255), width=2)
                wdraw.rectangle([bx0, by0, bx1, by1], outline=(12, 18, 25, 255), width=2)
    wall.save(os.path.join(HD2D_DIR, "wall_stone_hd.png"))


def build_bagua_and_domain_textures() -> None:
    """Create glowing neon-cyan Bagua floor array and player domain ring matching reference image."""
    # 1. Neon Cyan Bagua Circle (512x512)
    size = 512
    cx, cy = size // 2, size // 2
    glow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    core_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow_layer)
    cdraw = ImageDraw.Draw(core_layer)

    cyan_glow = (40, 225, 255, 190)
    cyan_core = (165, 250, 255, 255)

    for draw_ctx, col, w_Scale in ((gdraw, cyan_glow, 2.2), (cdraw, cyan_core, 1.0)):
        w_outer = max(2, int(7 * w_Scale))
        w_inner = max(2, int(6 * w_Scale))
        w_spoke = max(2, int(5 * w_Scale))
        w_bar = max(2, int(6 * w_Scale))

        r_outer = 228
        r_mid_out = 205
        r_mid_in = 118
        r_inner = 104

        draw_ctx.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], outline=col, width=w_outer)
        draw_ctx.ellipse([cx - r_mid_out, cy - r_mid_out, cx + r_mid_out, cy + r_mid_out], outline=col, width=w_inner)
        draw_ctx.ellipse([cx - r_mid_in, cy - r_mid_in, cx + r_mid_in, cy + r_mid_in], outline=col, width=w_inner)
        draw_ctx.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], outline=col, width=w_outer)

        # 8 sector dividers & Bagua trigrams
        trigrams = [
            (1, 1, 1),
            (0, 1, 1),
            (1, 0, 1),
            (0, 0, 1),
            (1, 1, 0),
            (0, 1, 0),
            (1, 0, 0),
            (0, 0, 0),
        ]
        for i in range(8):
            ang = i * (np.pi / 4.0) + (np.pi / 8.0)
            x0 = cx + np.cos(ang) * r_mid_in
            y0 = cy + np.sin(ang) * r_mid_in
            x1 = cx + np.cos(ang) * r_mid_out
            y1 = cy + np.sin(ang) * r_mid_out
            draw_ctx.line([(x0, y0), (x1, y1)], fill=col, width=w_spoke)

            # Draw trigram bars centered in sector
            c_ang = i * (np.pi / 4.0)
            ux, uy = np.cos(c_ang), np.sin(c_ang)
            tx, ty = -uy, ux  # tangent vector
            tri = trigrams[i]
            radii = [140, 162, 184]
            half_len = 26.0
            gap_half = 6.5
            for b_idx, r_bar in enumerate(radii):
                bx = cx + ux * r_bar
                by = cy + uy * r_bar
                if tri[b_idx] == 1:
                    p0 = (bx - tx * half_len, by - ty * half_len)
                    p1 = (bx + tx * half_len, by + ty * half_len)
                    draw_ctx.line([p0, p1], fill=col, width=w_bar)
                else:
                    p0 = (bx - tx * half_len, by - ty * half_len)
                    p1 = (bx - tx * gap_half, by - ty * gap_half)
                    p2 = (bx + tx * gap_half, by + ty * gap_half)
                    p3 = (bx + tx * half_len, by + ty * half_len)
                    draw_ctx.line([p0, p1], fill=col, width=w_bar)
                    draw_ctx.line([p2, p3], fill=col, width=w_bar)

    glow_blurred = glow_layer.filter(ImageFilter.GaussianBlur(radius=9))
    out_bagua = Image.alpha_composite(glow_blurred, core_layer)
    out_bagua.save(os.path.join(HD2D_DIR, "bagua_neon_cyan.png"))

    # 2. Glowing Cyan Ring Under Hero / Domain Ring (512x512)
    ring_glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring_core = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rg_draw = ImageDraw.Draw(ring_glow)
    rc_draw = ImageDraw.Draw(ring_core)

    r_ring = 215
    rg_draw.ellipse([cx - r_ring, cy - r_ring, cx + r_ring, cy + r_ring], outline=(30, 230, 255, 220), width=22)
    rc_draw.ellipse([cx - r_ring, cy - r_ring, cx + r_ring, cy + r_ring], outline=(195, 252, 255, 255), width=8)

    ring_blurred = ring_glow.filter(ImageFilter.GaussianBlur(radius=11))
    out_ring = Image.alpha_composite(ring_blurred, ring_core)
    out_ring.save(os.path.join(HD2D_DIR, "domain_ring_cyan.png"))


def build_slash_and_flame_vfx() -> None:
    """Create glowing cyan crescent sword slash wave and corner cyan flame sprite."""
    # 1. Crescent Slash Wave (512x512)
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    # Normalize to [-1, 1]
    nx = (xx - 220.0) / 185.0
    ny = (yy - 256.0) / 185.0
    r = np.sqrt(nx * nx + ny * ny)
    ang = np.arctan2(ny, nx)  # [-pi, pi]

    # Crescent arc centered around angle 0.15 rad (right-curving sweep)
    ang_center = 0.12
    ang_span = 1.65
    ang_diff = np.abs(np.arctan2(np.sin(ang - ang_center), np.cos(ang - ang_center)))
    t_ang = np.clip(1.0 - (ang_diff / ang_span) ** 1.8, 0.0, 1.0)

    # Outer edge at r = 1.0, inner cutout shifted right so crescent tapers at tips
    ix = nx + 0.24
    iy = ny - 0.03
    r_inner = np.sqrt(ix * ix + iy * iy)

    outer_mask = np.clip((1.02 - r) * 8.5, 0.0, 1.0)
    inner_mask = np.clip((r_inner - 0.78) * 6.5, 0.0, 1.0)
    blade = outer_mask * inner_mask * t_ang

    # Add wispy trailing streaks inside crescent
    streak1 = np.exp(-((r - 0.88) / 0.035) ** 2) * t_ang
    streak2 = np.exp(-((r - 0.74) / 0.025) ** 2) * (t_ang ** 1.5) * 0.75
    intensity = np.clip(blade * 1.15 + streak1 * 0.9 + streak2, 0.0, 1.0)

    arr = np.zeros((size, size, 4), dtype=np.uint8)
    # Color ramp: deep cyan glow -> bright ice cyan -> white hot core
    core = np.clip((intensity - 0.45) / 0.55, 0.0, 1.0)
    arr[..., 0] = np.clip(45 + core * 210, 0, 255).astype(np.uint8)
    arr[..., 1] = np.clip(225 + core * 30, 0, 255).astype(np.uint8)
    arr[..., 2] = 255
    arr[..., 3] = np.clip((intensity ** 0.85) * 255.0, 0, 255).astype(np.uint8)

    slash_img = Image.fromarray(arr, "RGBA").filter(ImageFilter.GaussianBlur(radius=1.5))
    slash_img.save(os.path.join(HD2D_DIR, "slash_crescent_cyan.png"))

    # 2. Corner Cyan Spirit Flame (128x160)
    fw, fh = 128, 160
    fy, fx = np.mgrid[0:fh, 0:fw].astype(np.float32)
    fnx = (fx - 64.0) / 34.0
    fny = (fy - 102.0) / 52.0  # base near bottom

    # Teardrop flame shape with 3 tongues
    taper = np.clip(1.0 - (108.0 - fy) / 96.0, 0.22, 1.15)
    wave = 0.14 * np.sin(fy * 0.11) * np.cos(fx * 0.15)
    dist_flame = np.sqrt(((fnx + wave) / taper) ** 2 + (fny * 0.85) ** 2)
    f_mask = np.clip(1.0 - dist_flame, 0.0, 1.0) ** 1.35

    farr = np.zeros((fh, fw, 4), dtype=np.uint8)
    fcore = np.clip((f_mask - 0.35) / 0.65, 0.0, 1.0)
    farr[..., 0] = np.clip(30 + fcore * 210, 0, 255).astype(np.uint8)
    farr[..., 1] = np.clip(235 + fcore * 20, 0, 255).astype(np.uint8)
    farr[..., 2] = 255
    farr[..., 3] = np.clip(f_mask * 255.0, 0, 255).astype(np.uint8)
    flame_img = Image.fromarray(farr, "RGBA").filter(ImageFilter.GaussianBlur(radius=1.2))
    flame_img.save(os.path.join(HD2D_DIR, "cyan_flame.png"))


def extract_charcoal_sprite(
    img: Image.Image,
    target_height: int = 560,
    unmat_cyan_glow: bool = False,
    unmat_gold_glow: bool = False,
) -> Image.Image:
    """
    Cleanly removes the uniform cool-charcoal (#151c23) background (including enclosed
    gaps inside chains/ribbons and soft outer glow halos) while preserving black hair,
    boots, and dark crimson armor.
    """
    rgba = img.convert("RGBA")
    arr = np.array(rgba, dtype=np.int32)
    h, w, _ = arr.shape

    # Sample background color from corners
    corners = np.array([arr[8, 8, :3], arr[8, w - 9, :3], arr[h - 9, 8, :3], arr[h - 9, w - 9, :3]])
    bg = np.median(corners, axis=0)  # ~ [21, 28, 35]

    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    diff = np.max(np.abs(arr[..., :3] - bg), axis=-1)
    euclid = np.sqrt(np.sum((arr[..., :3] - bg) ** 2, axis=-1))
    cool_tint = (b - r >= 6) & (b >= g)
    yy_grid, xx_grid = np.mgrid[0:h, 0:w]

    # 1. Exterior flood-fill from image borders
    can_flood = (diff <= 13) & cool_tint
    if unmat_cyan_glow:
        hand_zone = (xx_grid > int(w * 0.62)) & (yy_grid < int(h * 0.46))
        dark_cyan_halo = hand_zone & (r <= 115) & (b >= r + 8)
        can_flood = can_flood | dark_cyan_halo
    if unmat_gold_glow:
        gold_zone = (xx_grid > int(w * 0.58)) & (yy_grid < int(h * 0.46))
        # Dark charcoal blended with warm amber/gold glow around talismans or alchemy flame
        dark_gold_halo = gold_zone & (r <= 115) & (g <= 96) & (b <= 62) & ((r < 55) | (r - b <= 48))
        can_flood = can_flood | dark_gold_halo

    visited = np.zeros((h, w), dtype=bool)
    is_bg = np.zeros((h, w), dtype=bool)
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
        if can_flood[cy, cx]:
            is_bg[cy, cx] = True
            q.append((cy - 1, cx))
            q.append((cy + 1, cx))
            q.append((cy, cx - 1))
            q.append((cy, cx + 1))

    # 2. Enclosed background pockets (between chains / sleeves in upper/mid body y < 0.72*h)
    #    with area >= 90 px so dark boots/pants or hair highlights are never punctured.
    inner_candidate = (~is_bg) & (yy_grid < int(h * 0.70)) & (euclid <= 9.5) & (b - r >= 9) & (g - r >= 4)
    ic_visited = np.zeros((h, w), dtype=bool)
    for sy in range(h):
        for sx in range(w):
            if inner_candidate[sy, sx] and not ic_visited[sy, sx]:
                comp = []
                cq = deque([(sy, sx)])
                ic_visited[sy, sx] = True
                while cq:
                    py, px = cq.popleft()
                    comp.append((py, px))
                    for ny, nx in ((py - 1, px), (py + 1, px), (py, px - 1), (py, px + 1)):
                        if 0 <= ny < h and 0 <= nx < w and inner_candidate[ny, nx] and not ic_visited[ny, nx]:
                            ic_visited[ny, nx] = True
                            cq.append((ny, nx))
                if len(comp) >= 90:
                    for py, px in comp:
                        is_bg[py, px] = True

    # 3. Remove small disconnected speckles (< 80 px area) so bounding box fits tightly to feet
    fg = ~is_bg
    comp_visited = np.zeros((h, w), dtype=bool)
    for sy in range(h):
        for sx in range(w):
            if fg[sy, sx] and not comp_visited[sy, sx]:
                comp = []
                cq = deque([(sy, sx)])
                comp_visited[sy, sx] = True
                while cq:
                    py, px = cq.popleft()
                    comp.append((py, px))
                    for ny, nx in ((py - 1, px), (py + 1, px), (py, px - 1), (py, px + 1)):
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not comp_visited[ny, nx]:
                            comp_visited[ny, nx] = True
                            cq.append((ny, nx))
                if len(comp) < 80:
                    for py, px in comp:
                        is_bg[py, px] = True

    alpha = np.where(is_bg, 0, 255).astype(np.uint8)
    out_arr = arr.astype(np.uint8)
    out_arr[..., 3] = alpha

    out = Image.fromarray(out_arr)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)

    # Resize to target height while preserving aspect ratio
    if out.height > 0 and target_height > 0:
        scale = target_height / float(out.height)
        new_w = max(1, int(round(out.width * scale)))
        out = out.resize((new_w, target_height), Image.Resampling.LANCZOS)

    # Pad 4px transparent margin so billboard edges never clip
    padded = Image.new("RGBA", (out.width + 8, out.height + 8), (0, 0, 0, 0))
    padded.paste(out, (4, 4))
    return padded


def build_character_sprites() -> None:
    bai_sheet_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/bai_yueling_sheet_1795283909263.jpg"
    ye_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/ye_shangye_combat_v2_1795283949090.jpg"
    sheet_a_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/xianxia_sheet_a_three_characters_1795286116907.jpg"
    sheet_b_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/xianxia_sheet_b_two_characters_v3_1795286176905.jpg"

    if os.path.exists(bai_sheet_path):
        sheet = Image.open(bai_sheet_path)
        sw, sh = sheet.size
        mid_x = int(sw * 0.48)
        idle_crop = sheet.crop((0, 0, mid_x, sh))
        atk_crop = sheet.crop((mid_x, 0, sw, sh))

        bai_idle = extract_charcoal_sprite(idle_crop, target_height=540, unmat_cyan_glow=True)
        bai_atk = extract_charcoal_sprite(atk_crop, target_height=540, unmat_cyan_glow=False)
        bai_idle.save(os.path.join(HD2D_DIR, "bai_yueling_hd_idle.png"))
        bai_atk.save(os.path.join(HD2D_DIR, "bai_yueling_hd_attack.png"))
        print("Saved Bai Yueling HD sprites:", bai_idle.size, bai_atk.size)

    if os.path.exists(ye_path):
        ye_img = Image.open(ye_path)
        ye_idle = extract_charcoal_sprite(ye_img, target_height=560, unmat_cyan_glow=False)
        ye_idle.save(os.path.join(HD2D_DIR, "ye_shangye_hd_idle.png"))
        print("Saved Ye Shangye HD sprite:", ye_idle.size)

    if os.path.exists(sheet_a_path):
        sheet_a = Image.open(sheet_a_path).convert("RGB")
        aw, ah = sheet_a.size
        arr_a = np.array(sheet_a)
        bg_col = np.array([21, 28, 35], dtype=np.uint8)

        # 1. Song Ren (left third: x < 0.365 * aw)
        x_s1 = int(aw * 0.365)
        song_crop = sheet_a.crop((0, 0, x_s1, ah))
        song_idle = extract_charcoal_sprite(song_crop, target_height=548, unmat_gold_glow=False)
        song_idle.save(os.path.join(HD2D_DIR, "song_ren_hd_idle.png"))

        # 2. Chen Xi vs Yu Han diagonal separator lines:
        yy, xx = np.mgrid[0:ah, 0:aw]
        sep_x_chen = (0.672 - 0.092 * (yy / float(ah))) * aw
        sep_x_yu = (0.672 - 0.068 * (yy / float(ah))) * aw

        chen_arr = arr_a.copy()
        chen_arr[(xx < x_s1) | (xx >= sep_x_chen)] = bg_col
        chen_crop = Image.fromarray(chen_arr).crop((x_s1, 0, int(aw * 0.68), ah))
        chen_idle = extract_charcoal_sprite(chen_crop, target_height=548)
        chen_idle.save(os.path.join(HD2D_DIR, "chen_xi_hd_idle.png"))

        yu_arr = arr_a.copy()
        yu_arr[xx < sep_x_yu + 4] = bg_col
        yu_crop = Image.fromarray(yu_arr).crop((int(aw * 0.595), 0, aw, ah))
        yu_idle = extract_charcoal_sprite(yu_crop, target_height=548)
        yu_idle.save(os.path.join(HD2D_DIR, "yu_han_hd_idle.png"))
        print("Saved Sheet A heroes:", song_idle.size, chen_idle.size, yu_idle.size)

    if os.path.exists(sheet_b_path):
        sheet_b = Image.open(sheet_b_path).convert("RGB")
        bw, bh = sheet_b.size
        mid_b = int(bw * 0.48)

        zhao_crop = sheet_b.crop((0, 0, mid_b, bh))
        zhao_idle = extract_charcoal_sprite(zhao_crop, target_height=548, unmat_gold_glow=False)
        zhao_idle.save(os.path.join(HD2D_DIR, "zhao_yan_hd_idle.png"))

        hei_crop = sheet_b.crop((mid_b, 0, bw, bh))
        hei_idle = ImageOps.mirror(extract_charcoal_sprite(hei_crop, target_height=548))
        hei_idle.save(os.path.join(HD2D_DIR, "hei_shan_hd_idle.png"))
        print("Saved Sheet B heroes:", zhao_idle.size, hei_idle.size)

    # Extract 6 remaining hero Attack Poses from Attack Sheet 1 & Attack Sheet 2
    atk1_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/xianxia_attack_sheet_1_v3_1795288476592.jpg"
    atk2_path = "/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2/xianxia_attack_sheet_2_1795288426368.jpg"

    if os.path.exists(atk1_path):
        atk1 = Image.open(atk1_path).convert("RGB")
        w1, h1 = atk1.size
        arr1 = np.array(atk1)
        bg1 = np.array([21, 28, 35], dtype=np.uint8)
        yy1, xx1 = np.mgrid[0:h1, 0:w1]

        sep12 = np.interp(yy1, [0, 240, 384, 512, 768], [560, 542, 476, 473, 460])
        sep23 = np.interp(yy1, [0, 350, 448, 768], [1005, 990, 900, 900])

        ye_atk_arr = arr1.copy()
        ye_atk_arr[xx1 >= sep12] = bg1
        ye_atk = extract_charcoal_sprite(Image.fromarray(ye_atk_arr).crop((0, 0, 565, h1)), target_height=548)
        ye_atk.save(os.path.join(HD2D_DIR, "ye_shangye_hd_attack.png"))

        song_atk_arr = arr1.copy()
        song_atk_arr[(xx1 < sep12) | (xx1 >= sep23)] = bg1
        song_atk = extract_charcoal_sprite(Image.fromarray(song_atk_arr).crop((450, 0, 1010, h1)), target_height=548)
        song_atk.save(os.path.join(HD2D_DIR, "song_ren_hd_attack.png"))

        chen_atk_arr = arr1.copy()
        chen_atk_arr[xx1 < sep23] = bg1
        chen_atk = extract_charcoal_sprite(Image.fromarray(chen_atk_arr).crop((890, 0, w1, h1)), target_height=548)
        chen_atk.save(os.path.join(HD2D_DIR, "chen_xi_hd_attack.png"))
        print("Saved Attack Sheet 1 poses:", ye_atk.size, song_atk.size, chen_atk.size)

    if os.path.exists(atk2_path):
        atk2 = Image.open(atk2_path).convert("RGB")
        w2, h2 = atk2.size
        arr2 = np.array(atk2)
        bg2 = np.array([21, 28, 35], dtype=np.uint8)
        yy2, xx2 = np.mgrid[0:h2, 0:w2]

        # Narrow diagonal strip enclosing Yu Han's lower-right spear tip without touching Zhao Yan's flame or lower ribbon
        spear_y_center = 395.0 + (xx2 - 510.0) * 1.12
        spear_zone = (xx2 >= 510) & (xx2 <= 596) & (np.abs(yy2 - spear_y_center) <= 24.0)
        yu_base_mask = ((xx2 < 546) & ~((xx2 >= 515) & (yy2 >= 395) & (yy2 <= 438))) | spear_zone

        yu_atk_arr = arr2.copy()
        yu_atk_arr[~yu_base_mask] = bg2
        yu_atk = extract_charcoal_sprite(Image.fromarray(yu_atk_arr).crop((0, 0, 602, h2)), target_height=548)
        yu_atk.save(os.path.join(HD2D_DIR, "yu_han_hd_attack.png"))

        sep_23_b = np.interp(yy2, [0, 290, 340, 400, 768], [966, 964, 944, 910, 910])
        zhao_spear_cut = (yy2 >= 436) & (yy2 <= 502) & (xx2 < 515 + (yy2 - 395) * 0.88)
        zhao_atk_arr = arr2.copy()
        zhao_atk_arr[(xx2 < 547) | zhao_spear_cut | (xx2 >= sep_23_b)] = bg2
        # Reconstruct the tiny 20x20 triangle of Zhao Yan's crimson sash behind Yu Han's spear tip
        sash_edge_x = 619.0 - (yy2 - 470.0) * 1.65
        sash_fill = (yy2 >= 472) & (yy2 <= 503) & (xx2 >= sash_edge_x) & (xx2 < 515 + (yy2 - 395) * 0.88)
        sash_border = sash_fill & (xx2 <= sash_edge_x + 2.5)
        zhao_atk_arr[sash_fill] = np.array([96, 38, 36], dtype=np.uint8)
        zhao_atk_arr[sash_border] = np.array([18, 16, 18], dtype=np.uint8)
        zhao_atk = extract_charcoal_sprite(Image.fromarray(zhao_atk_arr).crop((545, 0, 970, h2)), target_height=548)
        zhao_atk.save(os.path.join(HD2D_DIR, "zhao_yan_hd_attack.png"))

        hei_atk_arr = arr2.copy()
        hei_atk_arr[xx2 < sep_23_b] = bg2
        hei_atk = extract_charcoal_sprite(Image.fromarray(hei_atk_arr).crop((900, 0, w2, h2)), target_height=548)
        hei_atk.save(os.path.join(HD2D_DIR, "hei_shan_hd_attack.png"))
        print("Saved Attack Sheet 2 poses:", yu_atk.size, zhao_atk.size, hei_atk.size)


def _warp_walk_frame(base_rgba: np.ndarray, phase: float) -> Image.Image:
    """
    Synthesizes one walk-cycle frame from a canonical right-facing RGBA character sprite:
    - Upper torso lean & counter-swing
    - Hair & robe sleeve billowing wave
    - Lower legs & hem alternating stride separation + stepping foot lift
    - Planted foot aligned to bottom edge
    """
    h, w, _ = base_rgba.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    yn = yy / max(float(h - 1), 1.0)
    xn = (xx - (w * 0.5)) / max(float(w * 0.5), 1.0)  # [-1, 1]

    s = float(np.sin(phase))
    c = float(np.cos(phase))

    # 1. Forward walk lean + flowing sleeve/hair wave
    lean_dx = 4.5 * (1.0 - yn) * (0.65 + 0.35 * s)
    sleeve_weight = np.clip((yn - 0.16) / 0.55, 0.0, 1.0) * (1.0 - np.clip((yn - 0.74) / 0.26, 0.0, 1.0))
    wave_dx = 9.5 * np.sin(phase - yn * 3.8) * sleeve_weight

    # 2. Lower body leg & hem stride expansion/contraction (y_norm in 0.54 .. 1.0)
    leg_weight = np.clip((yn - 0.54) / 0.46, 0.0, 1.0) ** 1.2
    stride_spread = 16.5 * s * xn * leg_weight
    stride_shift = 5.5 * c * (xn ** 2) * leg_weight

    # 3. Alternating foot lift on stepping side
    step_side = xn if s >= 0.0 else -xn
    foot_lift_mask = np.clip(step_side + 0.15, 0.0, 1.0) * (np.clip((yn - 0.66) / 0.34, 0.0, 1.0) ** 1.35)
    lift_dy = -13.5 * abs(s) * foot_lift_mask

    # Inverse mapping coordinates
    src_x = np.clip(np.rint(xx - (lean_dx + wave_dx + stride_spread + stride_shift)).astype(np.int32), 0, w - 1)
    src_y = np.clip(np.rint(yy - lift_dy).astype(np.int32), 0, h - 1)

    warped = base_rgba[src_y, src_x]
    return Image.fromarray(warped)


def build_walk_sheets() -> None:
    """
    Builds 4-frame horizontal walk sprite sheets `<hero_id>_hd_walk.png`
    (left step -> pass -> right step -> pass) with equal cell size and feet
    aligned at the bottom baseline for all 7 heroes.
    """
    heroes = ["bai_yueling", "ye_shangye", "song_ren", "chen_xi", "yu_han", "zhao_yan", "hei_shan"]
    phases = [0.32 * np.pi, 0.85 * np.pi, 1.32 * np.pi, 1.85 * np.pi]

    for hid in heroes:
        idle_path = os.path.join(HD2D_DIR, f"{hid}_hd_idle.png")
        if not os.path.exists(idle_path):
            continue
        base_im = Image.open(idle_path).convert("RGBA")
        # Orient right-facing for uniform walk sheet (ye_shangye_hd_idle faces left)
        if hid == "ye_shangye":
            base_im = ImageOps.mirror(base_im)

        bbox = base_im.getbbox()
        if bbox:
            base_im = base_im.crop(bbox)

        cell_h = 548
        target_body_h = cell_h - 8
        scale = target_body_h / max(float(base_im.height), 1.0)
        body_w = max(1, int(round(base_im.width * scale)))
        base_im = base_im.resize((body_w, target_body_h), Image.Resampling.LANCZOS)

        # Pad horizontal working canvas by 24px each side so stride warp never clips
        cell_w = body_w + 48
        work_canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        work_canvas.paste(base_im, (24, cell_h - 4 - target_body_h))
        work_arr = np.array(work_canvas)

        sheet = Image.new("RGBA", (cell_w * 4, cell_h), (0, 0, 0, 0))
        for f_idx, ph in enumerate(phases):
            frame_im = _warp_walk_frame(work_arr, ph)
            fb = frame_im.getbbox()
            if fb:
                # Align lowest opaque pixel (planted foot) to y = cell_h - 4
                cropped_f = frame_im.crop((0, fb[1], cell_w, fb[3]))
                paste_y = (cell_h - 4) - cropped_f.height
                sheet.paste(cropped_f, (f_idx * cell_w, max(0, paste_y)))
            else:
                sheet.paste(frame_im, (f_idx * cell_w, 0))

        out_path = os.path.join(HD2D_DIR, f"{hid}_hd_walk.png")
        sheet.save(out_path)
        print(f"Saved 4-frame walk sheet {hid}_hd_walk.png:", sheet.size)


if __name__ == "__main__":
    ensure_dir()
    build_floor_and_wall_textures()
    build_bagua_and_domain_textures()
    build_slash_and_flame_vfx()
    build_character_sprites()
    build_walk_sheets()
    print("Built HD-2D environment, VFX & character textures in assets/hd2d/")
