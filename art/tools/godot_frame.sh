#!/usr/bin/env bash
# Render the mock battle frame twice: librsvg (frame.py) and inside Godot (godot_frame.gd).
# usage: art/tools/godot_frame.sh <out_dir>   needs xvfb-run and Godot 4.7 (GODOT=path)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="${1:-$repo/art/previews}"
godot="${GODOT:-$HOME/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"
python3 "$here/frame.py" "$out/battle_frame.png" "$tmp/scene.json"
printf 'config_version=5\n[application]\nconfig/name="frame"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$tmp/project.godot"
cp "$here/godot_frame.gd" "$tmp/"
timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$godot" --rendering-method gl_compatibility \
  --resolution 1280x720 --path "$tmp" -s godot_frame.gd -- "$repo" "$tmp/scene.json" "$out/battle_frame_godot.png" \
  2>&1 | grep -E '^saved|SCRIPT ERROR' || true
test -s "$out/battle_frame_godot.png"
