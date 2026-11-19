#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <input_mp4> <start_sec> <duration_sec> <out_prefix>"
  exit 1
fi

IN="$1"
START="$2"
DUR="$3"
OUT="$4"

mkdir -p "$(dirname "$OUT")"

# Compute dynamic fps so all 30 tiles (6x5) fill cleanly across DUR without trailing black cells
FPS="$(python3 -c "print(f'{30.5 / float(\"$DUR\"):.4f}')")"

# Extract 30 frames into a 6x5 sprite sheet at 240x426 per frame (1440x2130)
ffmpeg -y -v error -ss "$START" -t "$DUR" -i "$IN" \
  -vf "fps=${FPS},scale=240:426:flags=lanczos,tile=6x5" \
  -frames:v 1 -q:v 4 "${OUT}_sheet.jpg"

# Extract mono 22050Hz 16-bit WAV audio with gentle fade-in/out
FADE_OUT_START="$(python3 -c "print(f'{max(0.0, float(\"$DUR\") - 0.30):.2f}')")"
ffmpeg -y -v error -ss "$START" -t "$DUR" -i "$IN" \
  -vn -ac 1 -ar 22050 \
  -af "afade=t=in:st=0:d=0.08,afade=t=out:st=${FADE_OUT_START}:d=0.30" \
  -c:a pcm_s16le "${OUT}.wav"

ls -lh "${OUT}_sheet.jpg" "${OUT}.wav"
