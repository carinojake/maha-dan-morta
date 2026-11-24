#!/usr/bin/env python3
"""
Hybrid Rigging Monster & Boss Sheet Builder:
Combines smooth small-angle 2D bone skinning on torso/legs/cloak with rigid,
razor-sharp articulated weapon/arm layers and filled shoulder sockets so:
- Blades and fists NEVER swirl or bend like rubber even on 135-degree overhead swings.
- Shoulders, cloaks, and knees have ZERO cutout holes or detached pixel fragments.
- Every frame fits cleanly inside its cell with grounded feet.

Outputs:
1. `assets/monsters/shadow_cultist_sheet.png` (8 frames x 200x180)
   [0:Idle, 1:MoveA, 2:MoveB, 3:Windup, 4:Attack, 5:Recovery, 6:Hurt, 7:Death]
2. `assets/monsters/boss_ch1_sheet.png` (10 frames x 340x320)
   [0:Idle, 1:MoveA, 2:MoveB, 3:WindupSlam, 4:AtkSlam, 5:WindupWave, 6:AtkWave, 7:Recov, 8:Hurt, 9:Death]
"""
from collections import deque
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

MONSTERS_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/monsters")
SCRATCH_DIR = Path("/Users/jake/.gemini/antigravity/brain/2c2a760f-992e-4227-ab58-78b849405519/scratch")


def clean_enclosed_white_pockets(im: Image.Image) -> Image.Image:
    rgba = np.array(im.convert("RGBA"))
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int16)
    max_c = np.maximum(np.maximum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
    min_c = np.minimum(np.minimum(rgb[:, :, 0], rgb[:, :, 1]), rgb[:, :, 2])
    sat = max_c - min_c
    white_hole = (rgba[:, :, 3] > 0) & (min_c >= 232) & (sat <= 16)

    seen = np.zeros((h, w), dtype=bool)
    kill = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if white_hole[y, x] and not seen[y, x]:
                comp = []
                q = deque([(y, x)])
                seen[y, x] = True
                while q:
                    cy, cx = q.popleft()
                    comp.append((cy, cx))
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and white_hole[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
                if len(comp) >= 8:
                    for cy, cx in comp:
                        kill[cy, cx] = True

    rgba[kill] = 0
    fringe = np.zeros((h, w), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        fringe |= np.roll(np.roll(kill, dy, axis=0), dx, axis=1)
    fringe &= (~kill) & (rgba[:, :, 3] > 0) & (min_c > 195) & (sat <= 24)
    rgba[fringe, 3] = np.clip((245 - min_c[fringe]) * 4, 0, 180).astype(np.uint8)
    return Image.fromarray(rgba)


def mask_poly(shape: tuple[int, int], pts: list[tuple[int, int]]) -> np.ndarray:
    m = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.array(m) > 127


def extract_part(arr: np.ndarray, mask: np.ndarray) -> Image.Image:
    out = np.zeros_like(arr)
    out[mask] = arr[mask]
    return Image.fromarray(out)


def paste_rigid(
    canvas: Image.Image,
    part: Image.Image,
    pivot: tuple[float, float],
    dest_pivot: tuple[float, float],
    angle_deg: float = 0.0,
    scale_xy: tuple[float, float] = (1.0, 1.0),
    flip_h: bool = False,
) -> None:
    w, h = part.size
    work = part
    px, py = pivot
    if flip_h:
        work = work.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        px = w - px
    if scale_xy != (1.0, 1.0):
        nw = max(1, int(round(w * scale_xy[0])))
        nh = max(1, int(round(h * scale_xy[1])))
        work = work.resize((nw, nh), Image.Resampling.BICUBIC)
        px *= scale_xy[0]
        py *= scale_xy[1]

    pad = int(math.hypot(work.width, work.height)) + 16
    buf = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    buf.paste(work, (int(round(pad - px)), int(round(pad - py))), work)
    if abs(angle_deg) > 0.05:
        buf = buf.rotate(-angle_deg, resample=Image.Resampling.BICUBIC)
    canvas.alpha_composite(buf, dest=(int(round(dest_pivot[0] - pad)), int(round(dest_pivot[1] - pad))))


def dist_point_to_segment_grid(gx: np.ndarray, gy: np.ndarray, p0: tuple[float, float], p1: tuple[float, float]) -> np.ndarray:
    vx = p1[0] - p0[0]
    vy = p1[1] - p0[1]
    l2 = vx * vx + vy * vy
    if l2 < 1e-6:
        return np.hypot(gx - p0[0], gy - p0[1])
    t = np.clip(((gx - p0[0]) * vx + (gy - p0[1]) * vy) / l2, 0.0, 1.0)
    return np.hypot(gx - (p0[0] + t * vx), gy - (p0[1] + t * vy))


def warp_body_gentle(
    src_arr: np.ndarray,
    canvas_size: tuple[int, int],
    base_offset: tuple[float, float],
    bones_rest: list[tuple[tuple[float, float], tuple[float, float], float]],
    bone_poses: list[tuple[float, float, float]],
) -> Image.Image:
    """Gentle small-angle LBS (<= 22 deg) for organic torso/head/leg motion with zero tearing."""
    cw, ch = canvas_size
    sh, sw, _ = src_arr.shape
    ox, oy = base_offset
    yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
    lx = xx - ox
    ly = yy - oy

    total_w = np.zeros((ch, cw), dtype=np.float32)
    src_x = np.zeros((ch, cw), dtype=np.float32)
    src_y = np.zeros((ch, cw), dtype=np.float32)

    for (p0, p1, sigma), (ang_deg, tx, ty) in zip(bones_rest, bone_poses):
        rad = math.radians(ang_deg)
        ca, sa = math.cos(rad), math.sin(rad)
        q0 = (p0[0] + tx, p0[1] + ty)
        vx, vy = p1[0] - p0[0], p1[1] - p0[1]
        q1 = (q0[0] + vx * ca - vy * sa, q0[1] + vx * sa + vy * ca)
        d = dist_point_to_segment_grid(lx, ly, q0, q1)
        w = 1.0 / (np.power(d / sigma, 3.0) + 1e-3)
        rx, ry = lx - q0[0], ly - q0[1]
        src_x += w * (p0[0] + rx * ca + ry * sa)
        src_y += w * (p0[1] - rx * sa + ry * ca)
        total_w += w

    src_x /= total_w
    src_y /= total_w

    valid = (src_x >= 0.0) & (src_x < sw - 1.001) & (src_y >= 0.0) & (src_y < sh - 1.001)
    x0 = np.clip(np.floor(src_x).astype(np.int32), 0, sw - 2)
    y0 = np.clip(np.floor(src_y).astype(np.int32), 0, sh - 2)
    fx = (src_x - x0)[..., None]
    fy = (src_y - y0)[..., None]

    pm = src_arr.astype(np.float32)
    pm[..., :3] *= pm[..., 3:4] / 255.0
    interp = (pm[y0, x0] * (1 - fx) + pm[y0, x0 + 1] * fx) * (1 - fy) + (pm[y0 + 1, x0] * (1 - fx) + pm[y0 + 1, x0 + 1] * fx) * fy

    out = np.zeros((ch, cw, 4), dtype=np.uint8)
    alpha = interp[..., 3]
    vis = valid & (alpha > 10.0)
    out[vis, 3] = np.clip(np.round(alpha[vis]), 0, 255).astype(np.uint8)
    for ci in range(3):
        out[vis, ci] = np.clip(np.round(interp[vis, ci] / np.maximum(alpha[vis] / 255.0, 0.04)), 0, 255).astype(np.uint8)
    return Image.fromarray(out)


def boost_lava(arr: np.ndarray, mult: float = 1.48) -> np.ndarray:
    f = arr.astype(np.float32)
    a = f[:, :, 3] > 20
    lava = a & (f[:, :, 0] > 145) & (f[:, :, 0] > f[:, :, 2] * 1.38)
    f[lava, 0] = np.clip(f[lava, 0] * mult + 15, 0, 255)
    f[lava, 1] = np.clip(f[lava, 1] * (mult * 0.95) + 26, 0, 255)
    f[lava, 2] = np.clip(f[lava, 2] + 24, 0, 255)
    return f.astype(np.uint8)


def dim_lava(arr: np.ndarray, factor: float = 0.36) -> np.ndarray:
    f = arr.astype(np.float32)
    a = f[:, :, 3] > 20
    lava = a & (f[:, :, 0] > 125) & (f[:, :, 0] > f[:, :, 2] * 1.30)
    f[lava, 0] = f[lava, 0] * factor + 36
    f[lava, 1] = f[lava, 1] * (factor * 0.65) + 28
    f[lava, 2] = f[lava, 2] * 0.7 + 28
    return np.clip(f, 0, 255).astype(np.uint8)


def add_soft_fx(base: Image.Image, draw_fn) -> Image.Image:
    fx = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(fx))
    out = base.copy()
    out.alpha_composite(fx)
    return out


def build_cultist_sheet() -> Image.Image:
    clean_im = clean_enclosed_white_pockets(Image.open(MONSTERS_DIR / "shadow_cultist.png"))
    clean_im.save(MONSTERS_DIR / "shadow_cultist.png")
    arr = np.array(clean_im)
    h, w, _ = arr.shape

    # Separate rigid steel scimitar + right forearm; fill cutout strictly inside original body silhouette
    m_sword = mask_poly((h, w), [(0, 18), (61, 28), (60, 56), (51, 88), (0, 88)])
    p_sword = extract_part(arr, m_sword)
    body_arr = arr.copy()
    # Fill removed arm region near torso (x >= 46) with dark cloak color ONLY where original silhouette had pixels
    arm_torso_overlap = m_sword & (np.arange(w)[None, :] >= 48) & (arr[:, :, 3] > 40)
    body_arr[arm_torso_overlap] = [28, 25, 36, 255]
    body_arr[m_sword & ~arm_torso_overlap] = 0

    bones = [
        ((72.0, 92.0), (74.0, 44.0), 22.0),    # 0: Torso
        ((78.0, 34.0), (80.0, 10.0), 15.0),    # 1: Head
        ((90.0, 48.0), (110.0, 56.0), 14.0),   # 2: Left claw arm
        ((50.0, 104.0), (30.0, 140.0), 18.0),  # 3: Back leg
        ((90.0, 100.0), (108.0, 138.0), 18.0), # 4: Front leg
    ]
    cw, ch = 200, 180
    ox, oy = 40.0, 18.0

    frames: list[Image.Image] = []

    # 0: Idle
    f0 = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    f0.paste(clean_im, (int(ox), int(oy)), clean_im)
    frames.append(f0)

    # 1: Move_A
    f1 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (6.0, 2.0, 1.0), (4.0, 3.0, 1.0), (14.0, 3.0, 1.0), (-22.0, 12.0, -2.0), (16.0, -8.0, 1.0)
    ])
    paste_rigid(f1, p_sword, (56, 46), (ox + 58, oy + 47), angle_deg=-12.0)
    frames.append(f1)

    # 2: Move_B
    f2 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (9.0, 3.0, 2.0), (5.0, 4.0, 2.0), (-14.0, 4.0, 2.0), (14.0, -5.0, 0.0), (-18.0, 7.0, -1.0)
    ])
    paste_rigid(f2, p_sword, (56, 46), (ox + 59, oy + 48), angle_deg=15.0)
    frames.append(f2)

    # 3: Windup (coils back, rigid scimitar raised sharply overhead + crimson glint!)
    f3 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (-11.0, -8.0, -1.0), (-8.0, -10.0, -1.0), (-20.0, -8.0, -2.0), (8.0, -4.0, 0.0), (-12.0, -5.0, -2.0)
    ])
    paste_rigid(f3, p_sword, (54, 48), (ox + 50, oy + 42), angle_deg=66.0)
    f3 = add_soft_fx(f3, lambda d: (
        d.ellipse([(68, 4), (92, 28)], fill=(239, 68, 68, 105)),
        d.line([(66, 16), (94, 16)], fill=(255, 232, 235, 240), width=2),
        d.line([(80, 2), (80, 30)], fill=(255, 232, 235, 240), width=2),
    ))
    frames.append(f3)

    # 4: Attack_Slash (lunges +14px forward, rigid scimitar flipped & slashed across front + bold crimson arc!)
    f4 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (16.0, 14.0, 3.0), (12.0, 17.0, 4.0), (24.0, 16.0, 5.0), (14.0, 6.0, 0.0), (-14.0, 12.0, 0.0)
    ])
    paste_rigid(f4, p_sword, (54, 48), (ox + 92, oy + 52), angle_deg=16.0, flip_h=True)
    f4 = add_soft_fx(f4, lambda d: (
        d.arc([(94, 18), (192, 150)], start=-56, end=50, fill=(220, 38, 56, 235), width=7),
        d.arc([(100, 24), (188, 144)], start=-46, end=40, fill=(255, 228, 232, 245), width=3),
    ))
    frames.append(f4)

    # 5: Recovery (hunched low forward, rigid scimitar resting low in front — clear punish window)
    f5 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (20.0, 10.0, 6.0), (18.0, 14.0, 8.0), (28.0, 12.0, 8.0), (10.0, 4.0, 0.0), (-8.0, 8.0, 0.0)
    ])
    paste_rigid(f5, p_sword, (54, 48), (ox + 88, oy + 62), angle_deg=44.0, flip_h=True)
    frames.append(f5)

    # 6: Hurt (recoils backward, scimitar knocked low-back)
    f6 = warp_body_gentle(body_arr, (cw, ch), (ox, oy), bones, [
        (-18.0, -10.0, -1.0), (-22.0, -14.0, -2.0), (-28.0, -10.0, -4.0), (-8.0, -6.0, 0.0), (18.0, -8.0, -3.0)
    ])
    paste_rigid(f6, p_sword, (54, 48), (ox + 44, oy + 46), angle_deg=-26.0)
    frames.append(f6)

    # 7: Death (collapsed horizontally inside 200x180 cell at y=162, dropped scimitar beside body)
    f7 = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    dead_body = Image.fromarray(dim_lava(body_arr, 0.5))
    paste_rigid(f7, dead_body, (74, 95), (92, 138), angle_deg=82.0, scale_xy=(0.94, 0.88))
    paste_rigid(f7, p_sword, (30, 56), (144, 152), angle_deg=-28.0)
    frames.append(f7)

    strip = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * cw, 0), fr)
    out_p = MONSTERS_DIR / "shadow_cultist_sheet.png"
    strip.save(out_p)
    print(f"Saved {out_p}: {strip.size}")
    return strip


def build_furnace_guardian_sheet() -> Image.Image:
    src = Image.open(MONSTERS_DIR / "boss_ch1.png").convert("RGBA")
    arr = np.array(src)
    h, w, _ = arr.shape

    # Exact masks following the gap between fists and hip-tassets so zero hip armor detaches:
    m_rarm = mask_poly((h, w), [(0, 18), (64, 24), (60, 92), (55, 134), (55, 184), (0, 184)])
    m_larm = mask_poly((h, w), [(158, 28), (219, 28), (219, 188), (176, 188), (172, 134), (160, 92)])

    p_rarm = extract_part(arr, m_rarm)
    p_larm = extract_part(arr, m_larm)
    p_rarm_hot = Image.fromarray(boost_lava(np.array(p_rarm), 1.50))
    p_larm_hot = Image.fromarray(boost_lava(np.array(p_larm), 1.50))
    p_rarm_dim = Image.fromarray(dim_lava(np.array(p_rarm), 0.36))
    p_larm_dim = Image.fromarray(dim_lava(np.array(p_larm), 0.36))

    # Fill shoulder sockets strictly inside original silhouette so nothing pokes outside shoulders
    body_arr = arr.copy()
    r_sock = m_rarm & (np.arange(w)[None, :] >= 48) & (np.arange(h)[:, None] <= 98) & (arr[:, :, 3] > 40)
    l_sock = m_larm & (np.arange(w)[None, :] <= 172) & (np.arange(h)[:, None] <= 100) & (arr[:, :, 3] > 40)
    body_arr[r_sock | l_sock] = [56, 38, 38, 255]
    body_arr[(m_rarm | m_larm) & ~(r_sock | l_sock)] = 0
    body_hot = boost_lava(body_arr, 1.50)
    body_dim = dim_lava(body_arr, 0.36)

    bones = [
        ((112.0, 148.0), (114.0, 62.0), 34.0),  # 0: Torso + Furnace
        ((118.0, 48.0), (118.0, 12.0), 22.0),   # 1: Head
        ((76.0, 164.0), (62.0, 248.0), 24.0),   # 2: Viewer-Left Leg
        ((152.0, 164.0), (168.0, 248.0), 24.0), # 3: Viewer-Right Leg
    ]
    cw, ch = 360, 340
    ox, oy = 70.0, 62.0  # Feet at y = 62 + 259 = 321, zero clipping on overhead or side swings!

    def make_boss(
        b_arr: np.ndarray,
        ra: Image.Image,
        la: Image.Image,
        b_poses: list[tuple[float, float, float]],
        ra_ang: float,
        ra_ofs: tuple[float, float],
        la_ang: float,
        la_ofs: tuple[float, float],
    ) -> Image.Image:
        c = warp_body_gentle(b_arr, (cw, ch), (ox, oy), bones, b_poses)
        paste_rigid(c, la, (164, 58), (ox + 164 + la_ofs[0], oy + 58 + la_ofs[1]), angle_deg=la_ang)
        paste_rigid(c, ra, (56, 56), (ox + 56 + ra_ofs[0], oy + 56 + ra_ofs[1]), angle_deg=ra_ang)
        return c

    frames: list[Image.Image] = []

    # 0: Idle
    f0 = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    f0.paste(src, (int(ox), int(oy)), src)
    frames.append(f0)

    # 1: Move_A (Heavy titan stomp — right leg lifted, left arm swings forward)
    frames.append(make_boss(
        body_arr, p_rarm, p_larm,
        [(4.0, 2.0, 2.0), (3.0, 3.0, 2.0), (10.0, -4.0, 0.0), (-18.0, 6.0, -10.0)],
        ra_ang=-22.0, ra_ofs=(6, 2), la_ang=18.0, la_ofs=(-2, 2),
    ))

    # 2: Move_B (Opposite heavy stomp — left leg lifted, right arm swings forward)
    frames.append(make_boss(
        body_arr, p_rarm, p_larm,
        [(-3.0, -2.0, 2.0), (-2.0, -2.0, 2.0), (-18.0, 6.0, -10.0), (10.0, -4.0, 0.0)],
        ra_ang=18.0, ra_ofs=(-2, 2), la_ang=-24.0, la_ofs=(6, 2),
    ))

    # 3: Windup_Slam (BOTH massive molten fists raised HIGH overhead, blazing furnace core!)
    f3 = make_boss(
        body_hot, p_rarm_hot, p_larm_hot,
        [(-5.0, 0.0, 3.0), (-8.0, 0.0, 1.0), (6.0, -2.0, 0.0), (-6.0, 2.0, 0.0)],
        ra_ang=132.0, ra_ofs=(6, -6), la_ang=-132.0, la_ofs=(-6, -6),
    )
    f3 = add_soft_fx(f3, lambda d: (
        d.ellipse([(150, 132), (198, 180)], fill=(255, 195, 50, 105)),
        d.ellipse([(158, 140), (190, 172)], fill=(255, 250, 205, 145)),
    ))
    frames.append(f3)

    # 4: Attack_Slam (Deep crouch, BOTH fists smashed into stone floor + molten shockwave!)
    f4 = make_boss(
        body_hot, p_rarm_hot, p_larm_hot,
        [(14.0, 8.0, 18.0), (12.0, 12.0, 20.0), (14.0, -6.0, 0.0), (-14.0, 6.0, 0.0)],
        ra_ang=-44.0, ra_ofs=(22, 26), la_ang=-22.0, la_ofs=(10, 26),
    )
    f4 = add_soft_fx(f4, lambda d: (
        d.arc([(64, 270), (290, 312)], start=185, end=355, fill=(255, 110, 24, 235), width=7),
        d.arc([(82, 276), (272, 308)], start=192, end=348, fill=(255, 242, 165, 245), width=3),
    ))
    frames.append(f4)

    # 5: Windup_Wave (Coils torso back, cocks arm wide behind shoulder before flame sweep)
    frames.append(make_boss(
        body_hot, p_rarm_hot, p_larm_hot,
        [(-10.0, -6.0, 2.0), (-8.0, -8.0, 2.0), (6.0, -2.0, 0.0), (-6.0, 2.0, 0.0)],
        ra_ang=62.0, ra_ofs=(-8, -4), la_ang=-46.0, la_ofs=(4, -2),
    ))

    # 6: Attack_Wave (Sweeps molten arm forward +X with fiery claw arc!)
    f6 = make_boss(
        body_hot, p_rarm_hot, p_larm_hot,
        [(12.0, 10.0, 4.0), (10.0, 13.0, 5.0), (10.0, -2.0, 0.0), (-10.0, 6.0, 0.0)],
        ra_ang=-74.0, ra_ofs=(28, 6), la_ang=-64.0, la_ofs=(14, 2),
    )
    f6 = add_soft_fx(f6, lambda d: (
        d.arc([(172, 76), (318, 268)], start=-54, end=50, fill=(255, 92, 24, 225), width=9),
        d.arc([(180, 84), (312, 260)], start=-44, end=42, fill=(255, 236, 150, 245), width=4),
    ))
    frames.append(f6)

    # 7: Recovery_Overheat (Slumped down, arms hanging limp, furnace dimmed + steam vents — counter window!)
    f7 = make_boss(
        body_dim, p_rarm_dim, p_larm_dim,
        [(14.0, 6.0, 16.0), (22.0, 10.0, 22.0), (12.0, -4.0, 0.0), (-12.0, 4.0, 0.0)],
        ra_ang=-18.0, ra_ofs=(10, 18), la_ang=12.0, la_ofs=(4, 18),
    )
    f7 = add_soft_fx(f7, lambda d: (
        d.ellipse([(146, 66), (170, 90)], fill=(203, 213, 225, 95)),
        d.ellipse([(168, 48), (198, 78)], fill=(226, 232, 240, 110)),
        d.ellipse([(194, 70), (216, 92)], fill=(203, 213, 225, 85)),
    ))
    frames.append(f7)

    # 8: Hurt (Jolted backward, skull & chest snapped back, arms thrown wide)
    frames.append(make_boss(
        body_arr, p_rarm, p_larm,
        [(-15.0, -10.0, 2.0), (-20.0, -14.0, 0.0), (-6.0, -4.0, 0.0), (12.0, -6.0, -2.0)],
        ra_ang=38.0, ra_ofs=(-10, -4), la_ang=-42.0, la_ofs=(-6, -4),
    ))

    # 9: Death (Collapsed horizontally inside 360x340 cell at y=321, furnace cooled to dark charcoal stone)
    f9 = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    dead_full = Image.fromarray(dim_lava(arr, 0.16))
    paste_rigid(f9, dead_full, (110, 145), (178, 246), angle_deg=80.0, scale_xy=(0.90, 0.86))
    frames.append(f9)

    strip = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * cw, 0), fr)
    out_p = MONSTERS_DIR / "boss_ch1_sheet.png"
    strip.save(out_p)
    print(f"Saved {out_p}: {strip.size}")
    return strip


def save_preview(cultist_strip: Image.Image, boss_strip: Image.Image) -> None:
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)
    c_prev = Image.new("RGBA", (cultist_strip.width, cultist_strip.height + 30), (22, 28, 38, 255))
    c_prev.paste(cultist_strip, (0, 24), cultist_strip)
    dc = ImageDraw.Draw(c_prev)
    dc.line([(0, 24 + 162), (cultist_strip.width, 24 + 162)], fill=(74, 222, 128, 200), width=2)
    for i, nm in enumerate(["0:Idle", "1:MoveA", "2:MoveB", "3:Windup", "4:Attack", "5:Recov", "6:Hurt", "7:Death"]):
        dc.text((i * 200 + 58, 6), nm, fill=(248, 250, 252, 255))
    c_prev.save(SCRATCH_DIR / "cultist_sheet_preview.png")

    b_prev = Image.new("RGBA", (360 * 5, 370 * 2), (22, 28, 38, 255))
    db = ImageDraw.Draw(b_prev)
    b_names = [
        "0:Idle", "1:MoveA", "2:MoveB", "3:WindupSlam", "4:AtkSlam",
        "5:WindupWave", "6:AtkWave", "7:Recov/Open", "8:Hurt", "9:Death",
    ]
    for i, nm in enumerate(b_names):
        col = i % 5
        row = i // 5
        cell = boss_strip.crop((i * 360, 0, (i + 1) * 360, 340))
        b_prev.paste(cell, (col * 360, row * 370 + 24), cell)
        db.text((col * 360 + 115, row * 370 + 6), nm, fill=(253, 224, 71, 255))
    db.line([(0, 24 + 321), (1800, 24 + 321)], fill=(74, 222, 128, 200), width=2)
    db.line([(0, 370 + 24 + 321), (1800, 370 + 24 + 321)], fill=(74, 222, 128, 200), width=2)
    b_prev.save(SCRATCH_DIR / "boss_ch1_sheet_preview.png")


if __name__ == "__main__":
    cs = build_cultist_sheet()
    bs = build_furnace_guardian_sheet()
    save_preview(cs, bs)
