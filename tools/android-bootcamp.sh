#!/usr/bin/env bash
# Plays one bootcamp match in the Android emulator through real taps: main menu, Bootcamp,
# Start, the match to its results, Rematch. Saves screenshots, a screen recording and the log.
# A bot plays the player's toy (the app's hidden autoplay flag), since nobody holds the phone.
#
# Usage: tools/android-bootcamp.sh <apk> <out_dir>
# Env: ANDROID_HOME (~/Android/Sdk), AVD (bni), PORT (5562), GPU (host; needs DISPLAY),
#      EMULATOR_LOCK (a file to flock while the emulator runs), MATCH (match seconds, 60).
# Tap positions are for a 2400 x 1080 screen (the pixel_6 AVD) in landscape.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "${EMULATOR_LOCK:-}" ] && [ -z "${_BNI_LOCKED:-}" ]; then
  export _BNI_LOCKED=1
  "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" start-server >/dev/null 2>&1 || true
  exec flock -o -w 1800 "$EMULATOR_LOCK" "$0" "$@"
fi
APK="$1"; OUT="$2"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AVD="${AVD:-bni}"; PORT="${PORT:-5562}"; GPU="${GPU:-host}"; MATCH="${MATCH:-60}"
SERIAL="emulator-$PORT"
ADB=("$ANDROID_HOME/platform-tools/adb" -s "$SERIAL")
BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)"
PKG="$("$BT/aapt2" dump packagename "$APK")"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

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

start=$(date +%s)
timeout 300 "${ADB[@]}" wait-for-device
until [ "$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  sleep 3
  if [ $(( $(date +%s) - start )) -gt 420 ]; then log "boot timed out"; exit 1; fi
done
log "booted in $(( $(date +%s) - start )) s"
"${ADB[@]}" shell settings put system accelerometer_rotation 0 >/dev/null 2>&1 || true
"${ADB[@]}" shell settings put system user_rotation 1 >/dev/null 2>&1 || true
# Let the screen turn before the game starts: a turn during start relaunches the activity,
# and the engine does not survive a relaunch.
for _ in $(seq 1 15); do
  "${ADB[@]}" shell dumpsys window displays 2>/dev/null | grep -q "mCurrentRotation=ROTATION_90\|cur=2400x1080" && break
  sleep 1
done
sleep 2
"${ADB[@]}" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
"${ADB[@]}" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"${ADB[@]}" shell settings put secure immersive_mode_confirmations confirmed >/dev/null 2>&1 || true
# Right after boot the package manager can refuse an install with no reason given; try again.
for try in 1 2 3; do
  "${ADB[@]}" install -r -g "$APK" >"$OUT/install.log" 2>&1 && break
  log "install try $try failed: $(tail -n1 "$OUT/install.log")"
  [ "$try" = 3 ] && exit 1
  sleep 15
done
# The app's own settings: lessons already offered, a short bootcamp setup, autoplay on.
printf '[app]\n\nlessons_offered=true\nlast_bootcamp={"bots": 5, "length": %s.0, "mode": 0, "seed": 7, "skill": "normal"}\n\n[debug]\n\nautoplay=true\n' "$MATCH" \
  | "${ADB[@]}" shell "run-as $PKG sh -c 'mkdir -p files && cat > files/app.cfg'"
"${ADB[@]}" logcat -c
ACTIVITY="$("${ADB[@]}" shell cmd package resolve-activity --brief "$PKG" | tr -d '\r' | tail -n1)"
"${ADB[@]}" shell screenrecord --time-limit 180 --size 1280x576 /sdcard/bootcamp.mp4 >"$OUT/screenrecord.log" 2>&1 &
REC_PID=$!
"${ADB[@]}" shell am start -W -n "$ACTIVITY" >"$OUT/launch.log" 2>&1
shot() { "${ADB[@]}" exec-out screencap -p >"$OUT/$1.png"; log "screenshot $1"; }
tap() { "${ADB[@]}" shell input tap "$1" "$2"; log "tap $3"; }
wait_log() { # wait for a line in the game's log, up to $2 s
  local until=$(( $(date +%s) + $2 ))
  while [ "$(date +%s)" -lt "$until" ]; do
    "${ADB[@]}" logcat -d -s godot:I 2>/dev/null | grep -q -F "$1" && return 0
    sleep 2
  done
  return 1
}
sleep 10
shot 01-main-menu
tap 1200 531 Bootcamp
sleep 3
shot 02-bootcamp-setup
tap 1362 843 Start
wait_log "bni: match started" 30 && log "match started" || log "no match start in the log"
sleep 15
shot 03-match
wait_log "bni: match over" $(( MATCH * 4 )) && log "match over" || log "no match end in the log"
sleep 2
shot 04-results
sleep 3
tap 1569 879 Rematch
sleep 8
shot 05-rematch
"${ADB[@]}" shell pkill -INT screenrecord >/dev/null 2>&1 || true
wait "$REC_PID" 2>/dev/null || true
sleep 3
"${ADB[@]}" pull /sdcard/bootcamp.mp4 "$OUT/bootcamp.mp4" >/dev/null 2>&1 && log "recording bootcamp.mp4" || log "no recording"
"${ADB[@]}" logcat -d >"$OUT/logcat.txt" 2>&1 || true
grep -E 'bni: ' "$OUT/logcat.txt" | sed 's/^.*bni: /bni: /' || true
