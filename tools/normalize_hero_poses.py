import os
from collections import deque
from PIL import Image
import numpy as np

BASE_DIR = "/Users/Shared/my_ai_project/01_ACTIVE_PROJECTS/6.game/maha_dan_morta"
HEROES_DIR = os.path.join(BASE_DIR, "assets", "heroes")


def remove_opaque_bg(img: Image.Image, tolerance: int = 38) -> Image.Image:
    rgba = img.convert("RGBA")
    arr = np.array(rgba)
    h, w, _ = arr.shape
    if arr[0, 0, 3] <= 10 and arr[0, w - 1, 3] <= 10:
        return rgba
    bg = arr[2, 2, :3].astype(np.int32)
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
        if int(np.max(np.abs(px - bg))) <= tolerance:
            arr[y, x, 3] = 0
            q.append((y - 1, x))
            q.append((y + 1, x))
            q.append((y, x - 1))
            q.append((y, x + 1))
    return Image.fromarray(arr)


def normalize_all():
    poses = ["skill_1", "skill_2", "special", "ultimate", "dash", "hurt", "dead"]
    for hero in ("bai_yueling", "ye_shangye", "song_ren"):
        hdir = os.path.join(HEROES_DIR, hero)
        ref = Image.open(os.path.join(hdir, "stride_0.png")).convert("RGBA")
        ref_bbox = ref.getbbox()
        ref_h = (ref_bbox[3] - ref_bbox[1]) if ref_bbox else 220

        for pose in poses:
            path = os.path.join(hdir, f"{pose}.png")
            if not os.path.exists(path):
                continue
            im = Image.open(path).convert("RGBA")
            w, h = im.size
            arr = np.array(im)
            needs_bg = arr[0, 0, 3] > 10 or arr[0, w - 1, 3] > 10
            if (w, h) == (400, 320) and not needs_bg:
                continue

            clean = remove_opaque_bg(im) if needs_bg else im
            bbox = clean.getbbox()
            if not bbox:
                continue
            cropped = clean.crop(bbox)
            # Scale to match reference character height (cap width at 380)
            scale = min(ref_h / float(cropped.height), 380.0 / float(cropped.width))
            nw = max(1, int(cropped.width * scale))
            nh = max(1, int(cropped.height * scale))
            resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

            canvas = Image.new("RGBA", (400, 320), (0, 0, 0, 0))
            paste_x = 200 - nw // 2
            paste_y = max(0, 282 - nh)
            canvas.paste(resized, (paste_x, paste_y), resized)
            canvas.save(path)
            print(f"Normalized {hero}/{pose}.png -> (400, 320) from {(w, h)}")


if __name__ == "__main__":
    normalize_all()
