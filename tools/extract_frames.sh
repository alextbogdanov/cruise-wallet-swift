#!/usr/bin/env bash
#
# extract_frames.sh — sample a video into stills at a fixed cadence.
#
# Usage:  ./extract_frames.sh <video> [interval_seconds] [out_dir]
# Default: interval 0.3s, out_dir ./frames next to this script.
#
# Frames are named frame_0000_t0.00s.png … with the wall-clock timestamp baked
# into the filename so an analyst can talk about timing without a lookup table.

set -euo pipefail

VID="${1:?usage: extract_frames.sh <video> [interval] [out_dir]}"
INTERVAL="${2:-0.3}"
OUT="${3:-$(dirname "$0")/frames}"

rm -rf "$OUT"
mkdir -p "$OUT"

# fps = 1/interval → one frame every INTERVAL seconds.
FPS=$(echo "scale=6; 1/$INTERVAL" | bc)

# Pass 1: dump sampled frames as zero-padded sequence.
ffmpeg -hide_banner -loglevel error -i "$VID" \
  -vf "fps=${FPS}" -vsync 0 \
  "$OUT/seq_%04d.png"

# Pass 2: rename each to embed its timestamp (index * interval).
i=0
for f in "$OUT"/seq_*.png; do
  t=$(echo "scale=2; $i*$INTERVAL" | bc)
  printf -v idx "%04d" "$i"
  mv "$f" "$OUT/frame_${idx}_t${t}s.png"
  i=$((i+1))
done

echo "Extracted $i frames at ${INTERVAL}s into $OUT"
