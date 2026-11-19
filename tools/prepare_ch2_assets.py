import os
import math
from PIL import Image, ImageDraw
import numpy as np

BASE_DIR = "/Users/Shared/my_ai_project/01_ACTIVE_PROJECTS/6.game/maha_dan_morta"
ENV_DIR = os.path.join(BASE_DIR, "assets", "env")


def pixelate_crisp(img: Image.Image, factor: int = 2) -> Image.Image:
    w, h = img.size
    small = img.resize((max(1, w // factor), max(1, h // factor)), Image.Resampling.BILINEAR)
    return small.resize((w, h), Image.Resampling.NEAREST)


def build_ch1_props():
    # 1. Carved Daoist Bagua Floor Circle (192x192)
    bagua = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    d = ImageDraw.Draw(bagua)
    cx, cy = 96, 96
    d.ellipse([8, 8, 184, 184], fill=(24, 30, 38, 170), outline=(64, 80, 96, 220), width=3)
    d.ellipse([24, 24, 168, 168], outline=(52, 68, 82, 200), width=2)
    d.ellipse([54, 54, 138, 138], outline=(45, 212, 191, 110), width=2)
    for i in range(8):
        ang = i * (math.pi / 4.0)
        x1 = cx + math.cos(ang) * 56
        y1 = cy + math.sin(ang) * 56
        x2 = cx + math.cos(ang) * 82
        y2 = cy + math.sin(ang) * 82
        d.line([(x1, y1), (x2, y2)], fill=(56, 72, 86, 180), width=2)
        tx = cx + math.cos(ang + 0.39) * 68
        ty = cy + math.sin(ang + 0.39) * 68
        d.rectangle([tx - 5, ty - 2, tx + 5, ty + 2], fill=(45, 212, 191, 130))
    pixelate_crisp(bagua, 2).save(os.path.join(ENV_DIR, "prop_bagua_floor.png"))

    # 2. Carved Dragon Stone Pillar (64x144) - crisp pixel shading
    pil = Image.new("RGBA", (64, 144), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pil)
    pd.ellipse([10, 120, 54, 138], fill=(8, 10, 14, 180))
    pd.rectangle([14, 108, 50, 128], fill=(38, 44, 54, 255), outline=(14, 18, 24, 255))
    pd.rectangle([18, 22, 46, 110], fill=(46, 54, 66, 255), outline=(14, 18, 24, 255))
    pd.rectangle([20, 24, 26, 108], fill=(64, 74, 88, 255))  # Left highlight
    pd.rectangle([38, 24, 44, 108], fill=(30, 36, 46, 255))  # Right shadow
    for y in range(30, 102, 12):
        pd.arc([20, y, 44, y + 10], 0, 180, fill=(84, 102, 118, 255), width=2)
    pd.rectangle([14, 12, 50, 24], fill=(56, 66, 80, 255), outline=(14, 18, 24, 255))
    pd.rectangle([20, 94, 30, 108], fill=(36, 78, 62, 255))
    pixelate_crisp(pil, 2).save(os.path.join(ENV_DIR, "prop_dragon_pillar.png"))

    # 3. Bronze Incense Brazier (64x76)
    brz = Image.new("RGBA", (64, 76), (0, 0, 0, 0))
    bd = ImageDraw.Draw(brz)
    bd.ellipse([14, 58, 50, 72], fill=(8, 10, 14, 175))
    bd.polygon([(20, 62), (24, 46), (40, 46), (44, 62)], fill=(38, 56, 54, 255), outline=(16, 22, 22, 255))
    bd.ellipse([12, 26, 52, 52], fill=(48, 76, 70, 255), outline=(16, 24, 24, 255))
    bd.ellipse([16, 24, 48, 36], fill=(28, 36, 34, 255), outline=(72, 108, 98, 255))
    bd.ellipse([22, 26, 42, 34], fill=(255, 145, 45, 255))
    bd.ellipse([26, 27, 38, 32], fill=(255, 225, 120, 255))
    pixelate_crisp(brz, 2).save(os.path.join(ENV_DIR, "prop_brazier.png"))

    # 4. Tattered Martial Sect Banner (48x112)
    ban = Image.new("RGBA", (48, 112), (0, 0, 0, 0))
    nd = ImageDraw.Draw(ban)
    nd.ellipse([16, 98, 32, 108], fill=(8, 10, 14, 160))
    nd.rectangle([22, 10, 26, 102], fill=(68, 52, 38, 255))
    nd.rectangle([8, 16, 40, 20], fill=(165, 132, 52, 255))
    nd.polygon([(11, 20), (37, 20), (37, 82), (29, 72), (24, 86), (18, 72), (11, 82)], fill=(115, 28, 36, 255), outline=(185, 145, 60, 255))
    nd.ellipse([18, 34, 30, 46], outline=(230, 185, 75, 255), width=2)
    pixelate_crisp(ban, 2).save(os.path.join(ENV_DIR, "prop_banner.png"))


def build_ch2_bamboo_env():
    rng = np.random.default_rng(77)

    # 1. Moonlit Dark Mossy Earth & Slate Paver (64x64)
    earth = Image.new("RGBA", (64, 64), (18, 26, 24, 255))
    ed = ImageDraw.Draw(earth)
    for y in range(0, 64, 32):
        for x in range(0, 64, 32):
            s = int(rng.integers(-3, 4))
            ed.rectangle([x, y, x + 31, y + 31], fill=(20 + s, 30 + s, 28 + s, 255))
    ed.rounded_rectangle([8, 10, 28, 26], radius=4, fill=(32, 40, 44, 255), outline=(16, 22, 24, 255))
    ed.rounded_rectangle([36, 38, 56, 54], radius=4, fill=(30, 38, 42, 255), outline=(16, 22, 24, 255))
    ed.line([(16, 46), (22, 49)], fill=(45, 86, 62, 255), width=2)
    ed.line([(46, 14), (52, 12)], fill=(45, 86, 62, 255), width=2)
    earth.save(os.path.join(ENV_DIR, "floor_bamboo.png"))

    # 2. Bamboo Cliff / Fence Wall (64x64)
    bwall = Image.new("RGBA", (64, 64), (12, 18, 16, 255))
    bw = ImageDraw.Draw(bwall)
    bw.rectangle([0, 0, 63, 46], fill=(26, 38, 34, 255), outline=(12, 16, 16, 255))
    for x in range(4, 60, 12):
        bw.rectangle([x, 6, x + 8, 54], fill=(38, 74, 52, 255), outline=(18, 34, 26, 255))
        bw.line([(x, 22), (x + 8, 22)], fill=(64, 112, 82, 255), width=2)
        bw.line([(x, 40), (x + 8, 40)], fill=(64, 112, 82, 255), width=2)
    bwall.save(os.path.join(ENV_DIR, "wall_bamboo.png"))

    # 3. Tall Bamboo Clump Prop (72x148) - crisp pixelated leaves
    bam = Image.new("RGBA", (72, 148), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bam)
    bd.ellipse([12, 126, 60, 142], fill=(6, 10, 8, 175))
    stalks = [(22, 134, 26, 24), (36, 136, 38, 12), (48, 132, 52, 28)]
    for x0, y0, x1, y1 in stalks:
        bd.line([(x0, y0), (x1, y1)], fill=(30, 68, 44, 255), width=7)
        bd.line([(x0 + 1, y0), (x1 + 1, y1)], fill=(58, 118, 76, 255), width=2)
        for seg in range(y1 + 16, y0 - 10, 24):
            bd.line([(x0 - 3, seg), (x0 + 5, seg)], fill=(18, 36, 24, 255), width=2)
    for _ in range(36):
        lx = int(rng.integers(10, 62))
        ly = int(rng.integers(8, 56))
        bd.polygon([(lx - 6, ly), (lx, ly - 3), (lx + 7, ly + 1), (lx, ly + 3)], fill=(42, 98, 62, 245))
    pixelate_crisp(bam, 2).save(os.path.join(ENV_DIR, "prop_bamboo_clump.png"))

    # 4. Moonlit Gnarled Blossom Tree (128x148) - dithered pixel foliage, no cartoon circles!
    tree = Image.new("RGBA", (128, 148), (0, 0, 0, 0))
    td = ImageDraw.Draw(tree)
    td.ellipse([26, 124, 102, 142], fill=(8, 10, 14, 180))
    # Gnarled dark trunk & branches
    td.polygon([(56, 132), (60, 70), (72, 70), (78, 132)], fill=(42, 28, 30, 255), outline=(22, 14, 16, 255))
    td.line([(64, 80), (32, 54), (20, 44)], fill=(42, 28, 30, 255), width=6)
    td.line([(68, 74), (96, 52), (108, 46)], fill=(42, 28, 30, 255), width=6)
    td.line([(64, 72), (62, 42)], fill=(42, 28, 30, 255), width=5)
    # Pixelated blossom clusters (varied small organic leaves, dark outline + highlight)
    centers = [(28, 44, 20), (62, 30, 24), (96, 46, 20), (46, 52, 16), (80, 52, 16)]
    for cx, cy, rad in centers:
        for _ in range(95):
            ang = float(rng.uniform(0, math.tau))
            rr = float(rng.uniform(0, rad))
            px = int(cx + math.cos(ang) * rr)
            py = int(cy + math.sin(ang) * rr * 0.72)
            col = (118, 48, 78, 255) if py > cy + 4 else ((206, 124, 158, 255) if py < cy - 4 else (164, 76, 112, 255))
            td.rectangle([px - 2, py - 2, px + 2, py + 2], fill=col)
    pixelate_crisp(tree, 2).save(os.path.join(ENV_DIR, "prop_peach_tree.png"))


if __name__ == "__main__":
    build_ch1_props()
    build_ch2_bamboo_env()
    print("Rebuilt pixelated crisp props.")
