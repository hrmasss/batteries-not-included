#!/usr/bin/env bash
# Boots an Android emulator headless, installs and launches the APK, and collects proof:
# screenshots, a short screen recording, frame times and the log. Stops the emulator at the end.
#
# Usage: tools/android-run.sh [apk] [out_dir]
#   apk      defaults to build/android/bni-debug.apk (tools/build-android.sh makes it)
#   out_dir  defaults to build/android/run
#
# Env: ANDROID_HOME (default ~/Android/Sdk), AVD (default bni, an x86_64 image), PORT (5560),
#      GPU (emulator -gpu mode, default host, which needs DISPLAY),
#      EMULATOR_LOCK (a file to flock while the emulator runs, for shared machines),
#      PLAY_SECONDS (how long the scripted play lasts, default 20).
# Create the AVD once, for example:
#   avdmanager create avd -n bni -k "system-images;android-35;google_apis;x86_64" -d pixel_6
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${EMULATOR_LOCK:-}" ] && [ -z "${_BNI_LOCKED:-}" ]; then
  export _BNI_LOCKED=1
  # Start adb's server first and pass -o, so no long-lived child (adb, the emulator) inherits the
  # lock and keeps holding it after this script ends.
  "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" start-server >/dev/null 2>&1 || true
  exec flock -o -w 1800 "$EMULATOR_LOCK" "$0" "$@"
fi

APK="${1:-build/android/bni-debug.apk}"
OUT="${2:-build/android/run}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AVD="${AVD:-bni}"
PORT="${PORT:-5560}"
PLAY_SECONDS="${PLAY_SECONDS:-20}"
# host: the machine's GL through a display (a virtual one under Xvfb works with Mesa).
# swiftshader_indirect needs no display, but its GLES limits are too low for Godot's 2D shader.
GPU="${GPU:-host}"
if [ "$GPU" = host ] && [ -z "${DISPLAY:-}" ]; then
  echo "GPU=host needs a display: set DISPLAY or run under xvfb-run -a" >&2
  exit 2
fi
SERIAL="emulator-$PORT"
ADB=("$ANDROID_HOME/platform-tools/adb" -s "$SERIAL")
BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)"
PKG="$("$BT/aapt2" dump packagename "$APK")"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# KVM: a user newly added to the kvm group keeps the old groups until a new login; sg picks it up.
emu=("$ANDROID_HOME/emulator/emulator" -avd "$AVD" -port "$PORT" -no-window -no-audio
  -no-boot-anim -no-snapshot -gpu "$GPU" -accel on -memory 2048)
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  "${emu[@]}" >"$OUT/emulator.log" 2>&1 &
else
  sg kvm -c "$(printf '%q ' "${emu[@]}")" >"$OUT/emulator.log" 2>&1 &
fi
EMU_PID=$!
stop_emulator() {
  "${ADB[@]}" emu kill >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do kill -0 "$EMU_PID" 2>/dev/null || return 0; sleep 1; done
  kill "$EMU_PID" 2>/dev/null || true
}
trap stop_emulator EXIT

log "booting $AVD on $SERIAL"
start=$(date +%s)
timeout 300 "${ADB[@]}" wait-for-device
until [ "$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  sleep 3
  if [ $(( $(date +%s) - start )) -gt 420 ]; then log "boot timed out"; exit 1; fi
done
log "booted in $(( $(date +%s) - start )) s, Android $("${ADB[@]}" shell getprop ro.build.version.release | tr -d '\r')"
"${ADB[@]}" shell settings put system user_rotation 1 >/dev/null 2>&1 || true
"${ADB[@]}" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
"${ADB[@]}" shell wm dismiss-keyguard >/dev/null 2>&1 || true
# Skip Android's one-time "Viewing full screen" notice, which would cover the game.
"${ADB[@]}" shell settings put secure immersive_mode_confirmations confirmed >/dev/null 2>&1 || true

log "installing $APK"
"${ADB[@]}" install -r -g "$APK" >"$OUT/install.log" 2>&1
"${ADB[@]}" logcat -c
launch_ms=$(date +%s%3N)
ACTIVITY="$("${ADB[@]}" shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -n1)"
"${ADB[@]}" shell am start -W -n "$ACTIVITY" >"$OUT/launch.log" 2>&1
log "launched: $(grep -E 'TotalTime|WaitTime' "$OUT/launch.log" | tr -d '\r' | tr '\n' ' ')"

shot() {
  "${ADB[@]}" exec-out screencap -p >"$OUT/$1.png"
  log "screenshot $1.png"
}
hold() { # hold a key for about $2 ms; older Android has only --longpress
  if "${ADB[@]}" shell input keyevent --duration "$2" "$1" 2>&1 | grep -q -i -E 'error|unknown|usage'; then
    "${ADB[@]}" shell input keyevent --longpress "$1" >/dev/null 2>&1 || true
  fi
}

sleep 8
shot 01-launched
"${ADB[@]}" shell dumpsys SurfaceFlinger --latency-clear >/dev/null 2>&1 || true
"${ADB[@]}" shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true

# Screen recording runs while a scripted play drives the toy with the keyboard keys the desktop
# input reads (D right, A left, W up, S down).
"${ADB[@]}" shell screenrecord --time-limit "$PLAY_SECONDS" --size 1280x576 /sdcard/bni-run.mp4 \
  >"$OUT/screenrecord.log" 2>&1 &
REC_PID=$!
sleep 1
hold KEYCODE_D 1200
hold KEYCODE_W 2500
shot 02-after-up
hold KEYCODE_A 1500
hold KEYCODE_W 2000
shot 03-after-left-up
hold KEYCODE_S 1500
shot 04-after-down
hold KEYCODE_D 800
# Then a real touch on the move stick: push up to fly, then right. The stick sits 100 x 80 units
# from the bottom left of a 360-unit-high screen (src/controls/touch_layout.gd).
size="$("${ADB[@]}" shell wm size | tr -d '\r' | grep -o -E '[0-9]+x[0-9]+' | tail -n1)"
long="${size%x*}"; short="${size#*x}"; [ "$long" -ge "$short" ] || { t=$long; long=$short; short=$t; }
u=$(( short * 1000 / 360 ))                      # pixels per unit, x1000
mx=$(( 100 * u / 1000 )); my=$(( short - 80 * u / 1000 )); r=$(( 40 * u / 1000 ))
touch() { "${ADB[@]}" shell input motionevent "$@" >/dev/null 2>&1 || true; }
touch DOWN "$mx" "$my"
touch MOVE "$mx" "$(( my - r ))"
sleep 2.5
shot 05-touch-flying
touch MOVE "$(( mx + r ))" "$(( my - r / 2 ))"
sleep 1.5
touch UP "$(( mx + r ))" "$(( my - r / 2 ))"
end=$(( $(date +%s) + PLAY_SECONDS ))
while [ "$(date +%s)" -lt "$end" ] && kill -0 "$REC_PID" 2>/dev/null; do sleep 1; done
wait "$REC_PID" 2>/dev/null || true
sleep 2
"${ADB[@]}" pull /sdcard/bni-run.mp4 "$OUT/run.mp4" >/dev/null 2>&1 && log "recording run.mp4" \
  || log "screenrecord produced nothing (see screenrecord.log)"
shot 06-end

# Frame times. SurfaceFlinger keeps the present times of the game's surface; gfxinfo covers
# only Android's own UI renderer, so it is kept for reference.
# Newer Android prints layers as RequestedLayerState{<name> parentId=..}; keep only the name.
layer="$("${ADB[@]}" shell dumpsys SurfaceFlinger --list | tr -d '\r' | grep -F "$PKG" \
  | grep -o -E 'SurfaceView\[[^]]*\]\(BLAST\)#[0-9]+' | head -n1 || true)"
echo "$layer" >"$OUT/sf-layer.txt"
"${ADB[@]}" shell dumpsys SurfaceFlinger --latency "\"$layer\"" | tr -d '\r' >"$OUT/sf-latency.txt" || true
"${ADB[@]}" shell dumpsys gfxinfo "$PKG" | tr -d '\r' >"$OUT/gfxinfo.txt" || true
python3 - "$OUT/sf-latency.txt" >"$OUT/frame-times.txt" <<'EOF'
import statistics, sys
rows = [l.split() for l in open(sys.argv[1]).read().splitlines()[1:]]
present = sorted(int(r[1]) for r in rows if len(r) == 3 and 0 < int(r[1]) < 2**62)
deltas = [(b - a) / 1e6 for a, b in zip(present, present[1:]) if b > a]
if not deltas:
    print("no frames recorded for the layer")
    sys.exit()
deltas.sort()
pct = lambda p: deltas[min(len(deltas) - 1, int(p * len(deltas)))]
print(f"frames {len(deltas) + 1}")
print(f"frame time ms: median {statistics.median(deltas):.1f}  mean {statistics.mean(deltas):.1f}"
      f"  p90 {pct(0.9):.1f}  p99 {pct(0.99):.1f}  max {deltas[-1]:.1f}")
print(f"fps from median: {1000 / statistics.median(deltas):.1f}")
print(f"frames over 33.3 ms: {sum(d > 33.4 for d in deltas)}")
EOF
log "frame times: $(tr '\n' ' ' <"$OUT/frame-times.txt")"

"${ADB[@]}" logcat -d >"$OUT/logcat.txt" 2>&1 || true
pid="$("${ADB[@]}" shell pidof "$PKG" | tr -d '\r' || true)"
if [ -n "$pid" ]; then
  log "game still running (pid $pid)"
else
  log "game is NOT running at the end: see logcat.txt"
  exit 1
fi
