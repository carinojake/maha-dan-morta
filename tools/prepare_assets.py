import os
import shutil
from collections import deque
from PIL import Image, ImageDraw
import numpy as np

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_SPRITES = "/Users/Shared/my_ai_project/01_ACTIVE_PROJECTS/6.game/_ARCHIVE_PROTOTYPES_20261114/ro_mmo/client/assets/sprites"
MONSTER_SHEET = "/Users/jake/.gemini/antigravity/brain/0abd22ec-3190-455d-a91e-76f1414aada7/concept_monsters_sheet_1794756522428.jpg"


def copy_heroes_and_vfx():
    heroes_dir = os.path.join(BASE_DIR, "assets", "heroes")
    vfx_dir = os.path.join(BASE_DIR, "assets", "vfx")
    os.makedirs(heroes_dir, exist_ok=True)
    os.makedirs(vfx_dir, exist_ok=True)

    for hero in ("bai_yueling", "ye_shangye", "song_ren"):
        src = os.path.join(SRC_SPRITES, hero)
        dst = os.path.join(heroes_dir, hero)
        os.makedirs(dst, exist_ok=True)
        for fname in os.listdir(src):
            if fname.endswith(".png"):
                shutil.copy2(os.path.join(src, fname), os.path.join(dst, fname))

    for fname in os.listdir(SRC_SPRITES):
        if fname.startswith("vfx_") and fname.endswith(".png"):
            shutil.copy2(os.path.join(SRC_SPRITES, fname), os.path.join(vfx_dir, fname))
    print("Copied 3 heroes + VFX sprites.")


def flood_remove_bg(img: Image.Image, tolerance: int = 34) -> Image.Image:
    rgba = img.convert("RGBA")
    arr = np.array(rgba)
    h, w, _ = arr.shape
    bg = arr[5, 5, :3].astype(np.int32)

    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        if y < 0 or y >= h or x < 0 or x >= w or visited[y, x]:
            continue
        visited[y, x] = True
        px = arr[y, x, :3].astype(np.int32)
        dist = int(np.max(np.abs(px - bg)))
        if dist <= tolerance:
            arr[y, x, 3] = 0
            q.append((y - 1, x))
            q.append((y + 1, x))
            q.append((y, x - 1))
            q.append((y, x + 1))

    out = Image.fromarray(arr, "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    return out


def slice_monsters():
    monsters_dir = os.path.join(BASE_DIR, "assets", "monsters")
    os.makedirs(monsters_dir, exist_ok=True)
    sheet = Image.open(MONSTER_SHEET)
    w, h = sheet.size
    hw, hh = w // 2, h // 2

    quads = {
        "shadow_cultist.png": (0, int(hh * 0.14), hw, hh),
        "jade_golem.png": (hw, int(hh * 0.14), w, hh),
        "shadow_hound.png": (0, hh + int(hh * 0.14), hw, h),
        "boss_demon_general.png": (hw, hh + int(hh * 0.14), w, h),
    }

    for fname, box in quads.items():
        crop = sheet.crop(box)
        clean = flood_remove_bg(crop, tolerance=36)
        # Standardize height for clean Godot scaling (normal mobs ~140px, boss ~210px)
        target_h = 210 if "boss" in fname else 145
        ratio = target_h / clean.height
        target_w = max(1, int(clean.width * ratio))
        resized = clean.resize((target_w, target_h), Image.Resampling.LANCZOS)
        resized.save(os.path.join(monsters_dir, fname))
        print(f"Saved {fname}: {resized.size}")


def build_dark_jade_env():
    env_dir = os.path.join(BASE_DIR, "assets", "env")
    os.makedirs(env_dir, exist_ok=True)
    rng = np.random.default_rng(42)

    # 1. Muted Dark Slate Floor Tile (64x64)
    slate = Image.new("RGBA", (64, 64), (24, 30, 38, 255))
    draw = ImageDraw.Draw(slate)
    for y in range(0, 64, 32):
        for x in range(0, 64, 32):
            shade = int(rng.integers(-3, 4))
            c = (28 + shade, 35 + shade, 44 + shade, 255)
            draw.rectangle([x + 1, y + 1, x + 30, y + 30], fill=c, outline=(18, 22, 28, 255))
            draw.line([(x + 2, y + 2), (x + 29, y + 2)], fill=(38, 46, 56, 255))
    # Subtle cracks & moss specks
    draw.line([(12, 10), (18, 16), (16, 22)], fill=(15, 19, 24, 255), width=1)
    draw.point([(44, 48), (45, 49), (47, 48)], fill=(36, 62, 52, 255))
    slate.save(os.path.join(env_dir, "floor_slate.png"))

    # 2. Dark Ruined Stone Wall Block (64x64)
    wall = Image.new("RGBA", (64, 64), (16, 20, 26, 255))
    wdraw = ImageDraw.Draw(wall)
    wdraw.rectangle([0, 0, 63, 42], fill=(38, 44, 54, 255), outline=(14, 17, 22, 255))
    wdraw.rectangle([0, 42, 63, 63], fill=(24, 28, 36, 255), outline=(12, 14, 18, 255))
    wdraw.line([(0, 20), (63, 20)], fill=(20, 24, 30, 255), width=2)
    wdraw.line([(32, 0), (32, 20)], fill=(20, 24, 30, 255), width=2)
    wdraw.line([(16, 20), (16, 42)], fill=(20, 24, 30, 255), width=2)
    wdraw.line([(48, 20), (48, 42)], fill=(20, 24, 30, 255), width=2)
    # Moss accent
    wdraw.rectangle([6, 36, 16, 44], fill=(32, 66, 54, 255))
    wall.save(os.path.join(env_dir, "wall_stone.png"))

    # 3. Glowing Cyan-Jade Crystal Cluster (64x80)
    crys = Image.new("RGBA", (64, 80), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(crys)
    cdraw.ellipse([14, 62, 50, 76], fill=(10, 14, 18, 160))
    cdraw.polygon([(22, 66), (18, 36), (26, 20), (34, 38), (30, 66)], fill=(22, 168, 152, 255), outline=(120, 255, 235, 255))
    cdraw.polygon([(30, 68), (34, 26), (44, 14), (50, 38), (44, 68)], fill=(45, 212, 191, 255), outline=(180, 255, 245, 255))
    cdraw.polygon([(12, 68), (8, 48), (16, 38), (24, 52), (20, 68)], fill=(18, 130, 120, 255), outline=(90, 235, 215, 255))
    crys.save(os.path.join(env_dir, "prop_jade_crystal.png"))

    # 4. Warm Amber Stone Lantern (64x88)
    lant = Image.new("RGBA", (64, 88), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(lant)
    ldraw.ellipse([16, 72, 48, 84], fill=(10, 14, 18, 170))
    ldraw.rectangle([24, 44, 40, 76], fill=(46, 52, 60, 255), outline=(22, 26, 32, 255))
    ldraw.rectangle([18, 24, 46, 46], fill=(38, 44, 52, 255), outline=(20, 24, 30, 255))
    ldraw.rectangle([24, 28, 40, 42], fill=(255, 185, 65, 255), outline=(255, 230, 140, 255))
    ldraw.polygon([(12, 24), (32, 10), (52, 24)], fill=(54, 62, 72, 255), outline=(24, 28, 34, 255))
    lant.save(os.path.join(env_dir, "prop_lantern.png"))

    # 5. Soft Radial Glow Texture for PointLight2D (128x128)
    glow = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    garr = np.zeros((128, 128, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:128, 0:128]
    dist = np.sqrt((xx - 63.5) ** 2 + (yy - 63.5) ** 2) / 63.5
    alpha = np.clip((1.0 - dist) ** 2, 0.0, 1.0) * 255.0
    garr[..., 0] = 255
    garr[..., 1] = 255
    garr[..., 2] = 255
    garr[..., 3] = alpha.astype(np.uint8)
    Image.fromarray(garr, "RGBA").save(os.path.join(env_dir, "light_radial.png"))
    print("Built Dark Jade Ruin environment assets.")


def generate_normal_map(src_path: str, dst_path: str, strength: float = 3.2) -> None:
    """Generates a WebGL2-ready tangent-space normal map (*_n.png) from a diffuse tile."""
    if not os.path.exists(src_path):
        return
    im = Image.open(src_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32)
    # Luminance heightfield in [0, 1]
    gray = (0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]) / 255.0
    # Tile-seamless central differences using np.roll
    dx = (np.roll(gray, -1, axis=1) - np.roll(gray, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(gray, -1, axis=0) - np.roll(gray, 1, axis=0)) * 0.5 * strength
    dz = np.ones_like(gray)
    norm = np.sqrt(dx * dx + dy * dy + dz * dz)
    nx = -dx / norm
    ny = -dy / norm
    nz = dz / norm

    out = np.zeros_like(arr, dtype=np.uint8)
    out[..., 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    out[..., 1] = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    out[..., 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    Image.fromarray(out).save(dst_path)
    print(f"Saved normal map: {os.path.basename(dst_path)} {im.size}")


def build_normal_maps() -> None:
    env_dir = os.path.join(BASE_DIR, "assets", "env")
    for stem, strength in [
        ("floor_slate", 3.5),
        ("floor_bamboo", 3.2),
        ("wall_stone", 3.8),
        ("wall_bamboo", 3.4),
    ]:
        src = os.path.join(env_dir, f"{stem}.png")
        dst = os.path.join(env_dir, f"{stem}_n.png")
        generate_normal_map(src, dst, strength=strength)


if __name__ == "__main__":
    if os.path.exists(SRC_SPRITES):
        copy_heroes_and_vfx()
    if os.path.exists(MONSTER_SHEET):
        slice_monsters()
    build_dark_jade_env()
    build_normal_maps()
