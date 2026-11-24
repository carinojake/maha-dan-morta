#!/usr/bin/env python3
"""
Extracts 4-directional walk (walk_down, walk_up, walk_side 3f) + attack_4f + skill_4f
for the remaining 6 heroes in HeroData.HERO_ORDER, matching Bai Yueling's 400x320 cell
format, 224px target height, and (200, 282) center-bottom baseline.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps
from tools.build_bai_yueling_default_slender import (
    CELL_H,
    CELL_W,
    TARGET_CHAR_H,
    build_strip,
    flood_fill_remove_white,
)

ARTIFACT_DIR = Path("/Users/jake/.gemini/antigravity/brain/ec1a06a9-3ed5-4ec3-9aa9-7ee57ba9c1c2")
HEROES_DIR = Path("/Users/jake/Downloads/rocg/maha-dan-morta/assets/heroes")

HERO_SHEETS = {
    "ye_shangye": (
        "ye_shangye_walk_sheet_1795435628488.jpg",
        "ye_shangye_combat_sheet_1795435601789.jpg",
    ),
    "song_ren": (
        "song_ren_walk_v2_1795435608569.jpg",
        "song_ren_combat_sheet_1795435620420.jpg",
    ),
    "chen_xi": (
        "chen_xi_walk_sheet_1795419080691.jpg",
        "chen_xi_combat_sheet_1795419099038.jpg",
    ),
    "yu_han": (
        "yu_han_walk_sheet_1795419082209.jpg",
        "yu_han_combat_sheet_1795435594133.jpg",
    ),
    "zhao_yan": (
        "zhao_yan_walk_sheet_1795435649766.jpg",
        "zhao_yan_combat_sheet_1795435612718.jpg",
    ),
    "hei_shan": (
        "hei_shan_walk_sheet_1795435602457.jpg",
        "hei_shan_combat_sheet_1795435618176.jpg",
    ),
}


def split_row_by_gaps(sheet: Image.Image, y0: int, y1: int, cols: int) -> list[Image.Image]:
    w = sheet.width
    arr = np.array(sheet.crop((0, y0, w, y1)).convert("RGB"))
    is_w = np.all(arr > 240, axis=(0, 2))
    splits = [0]
    for c in range(1, cols):
        cx = int(w * (c / float(cols)))
        win = max(60, w // (cols * 4))
        whites = [x for x in range(max(0, cx - win), min(w, cx + win)) if is_w[x]]
        splits.append((min(whites) + max(whites)) // 2 if whites else cx)
    splits.append(w)
    return [
        flood_fill_remove_white(sheet.crop((splits[i], y0, splits[i + 1], y1)))
        for i in range(cols)
    ]


def process_hero(hid: str, walk_file: str, combat_file: str):
    out_dir = HEROES_DIR / hid
    out_dir.mkdir(parents=True, exist_ok=True)

    walk_sheet = Image.open(ARTIFACT_DIR / walk_file)
    ww, wh = walk_sheet.size
    rh = wh // 3

    walk_down_frames = split_row_by_gaps(walk_sheet, 0, rh, 3)
    walk_up_frames = split_row_by_gaps(walk_sheet, rh, 2 * rh, 3)
    walk_side_frames = split_row_by_gaps(walk_sheet, 2 * rh, wh, 3)

    if hid == "yu_han":
        walk_down_frames = [walk_down_frames[0], walk_down_frames[1], ImageOps.mirror(walk_down_frames[0])]
        walk_up_frames = [walk_up_frames[0], walk_up_frames[1], ImageOps.mirror(walk_up_frames[0])]

    for fname, frames in [
        ("walk_down.png", walk_down_frames),
        ("walk_up.png", walk_up_frames),
        ("walk_side.png", walk_side_frames),
    ]:
        strip = build_strip(frames)
        strip.save(out_dir / fname)

    combat_sheet = Image.open(ARTIFACT_DIR / combat_file)
    kw, kh = combat_sheet.size
    kch = kh // 2

    attack_frames = split_row_by_gaps(combat_sheet, 0, kch, 4)
    skill_frames = split_row_by_gaps(combat_sheet, kch, kh, 4)

    if hid == "yu_han":
        attack_frames[0] = walk_side_frames[0]
        attack_frames[3] = walk_side_frames[0]

    # Use neutral frame height for uniform body scale across combat row
    atk_ref_h = max(1, attack_frames[0].height)
    atk_scale = TARGET_CHAR_H / float(atk_ref_h)
    build_strip(attack_frames, uniform_scale=atk_scale).save(out_dir / "attack_4f.png")

    skl_ref_h = max(1, skill_frames[3].height)
    skl_scale = TARGET_CHAR_H / float(skl_ref_h)
    build_strip(skill_frames, uniform_scale=skl_scale).save(out_dir / "skill_4f.png")
    print(f"✅ {hid}: walk_down/up/side (1200x320) + attack_4f/skill_4f (1600x320) saved")


def main():
    for hid, (wf, cf) in HERO_SHEETS.items():
        process_hero(hid, wf, cf)


if __name__ == "__main__":
    main()
