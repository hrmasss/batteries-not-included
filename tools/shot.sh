#!/usr/bin/env bash
# Plays a scripted run in the game under a virtual display and saves screenshots, and with
# --movie a short mp4 of the whole run. Other tasks reuse it for their proof.
#
#   tools/shot.sh <run.json> <out dir> [--movie] [--size 1280x720] [--fps 30]
#
# Run files live in tools/shot/runs/ (format in tools/shot/shot_runner.gd).
# Needs xvfb-run and, for --movie, ffmpeg. GODOT points at Godot 4.7.2 (default: godot).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
[ $# -ge 2 ] || { sed -n '2,9p' "$0"; exit 2; }
RUN="$(realpath "$1")"; OUT="$(realpath -m "$2")"; shift 2
MOVIE=0; SIZE=1280x720; FPS=30
while [ $# -gt 0 ]; do
  case "$1" in
    --movie) MOVIE=1; shift ;;
    --size) SIZE="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"
timeout 600 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
ARGS=(--path . --rendering-driver opengl3 --resolution "$SIZE" --fixed-fps "$FPS" --disable-vsync --audio-driver Dummy)
FRAMES=""
if [ "$MOVIE" = 1 ]; then
  FRAMES="$(mktemp -d)"
  ARGS+=(--write-movie "$FRAMES/frame.png")
fi
timeout 900 xvfb-run -a -s "-screen 0 ${SIZE}x24" "$GODOT" "${ARGS[@]}" res://tools/shot/shot.tscn -- --run "$RUN" --out "$OUT"
if [ "$MOVIE" = 1 ]; then
  timeout 600 ffmpeg -y -loglevel error -framerate "$FPS" -i "$FRAMES/frame%08d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart "$OUT/run.mp4"
  rm -rf "$FRAMES"
  echo "movie $OUT/run.mp4"
fi
