#!/usr/bin/env bash
# Builds the Android APK headless. Usage: tools/build-android.sh [debug|release] [out.apk]
#
# Needs: Godot 4.7.2 (GODOT, defaults to `godot` on PATH) with its export templates installed,
# the Android SDK (ANDROID_HOME, defaults to ~/Android/Sdk) with platform 36 and build-tools
# 36.1.0, and JDK 17 (JAVA_HOME or `java` on PATH). Gradle and its plugins download on the
# first build.
#
# Signing: a debug build uses GODOT_ANDROID_KEYSTORE_DEBUG_PATH, or ~/.android/debug.keystore,
# made here with the standard debug credentials when missing. A release build needs
# GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD set; no release key lives in git.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-debug}"
OUT="${2:-build/android/bni-${MODE}.apk}"
GODOT="${GODOT:-godot}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
PRESET="Android"

case "$MODE" in
  debug|release) ;;
  *) echo "usage: $0 [debug|release] [out.apk]" >&2; exit 2 ;;
esac

# Gradle needs a full JDK (javac), not only a Java runtime.
if [ -z "${JAVA_HOME:-}" ] && command -v javac >/dev/null; then
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
  export JAVA_HOME
fi

if [ "$MODE" = debug ] && [ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]; then
  ks="$HOME/.android/debug.keystore"
  if [ ! -f "$ks" ]; then
    mkdir -p "$(dirname "$ks")"
    keytool -genkeypair -keystore "$ks" -storepass android -keypass android \
      -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
      -keyalg RSA -keysize 2048 -validity 9999 >/dev/null
  fi
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ks"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
fi
if [ "$MODE" = release ] && [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  echo "release build needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD" >&2
  exit 2
fi

if [ -z "${JAVA_HOME:-}" ]; then
  echo "no JDK found: set JAVA_HOME to a JDK 17 (with javac)" >&2
  exit 2
fi

# Godot reads the SDK and JDK paths from its editor settings, not the environment. Give this
# build its own settings in .godot/ so it never touches the user's.
version="$("$GODOT" --version 2>/dev/null | head -n1)"
export XDG_CONFIG_HOME="$PWD/.godot/build-android-config"
settings="$XDG_CONFIG_HOME/godot/editor_settings-$(echo "$version" | cut -d. -f1-2).tres"
mkdir -p "$(dirname "$settings")"
cat > "$settings" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
EOF

mkdir -p "$(dirname "$OUT")"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT_ABS"

# Import first: a fresh checkout has no .godot/ yet.
timeout 600 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

# The Gradle build template (android/, not in git) comes from the export templates. Reinstall it
# when the engine version changes.
want="$(echo "$version" | sed -E 's/^([0-9.]+)\.([a-z]+).*/\1.\2/')"
have="$(cat android/.build_version 2>/dev/null || true)"
install_flag=()
if [ ! -d android/build ] || [ "$have" != "$want" ]; then
  rm -rf android
  install_flag=(--install-android-build-template)
fi

echo "Exporting $MODE APK to $OUT"
timeout 1800 "$GODOT" --headless --path . "${install_flag[@]}" "--export-$MODE" "$PRESET" "$OUT_ABS"

if [ ! -s "$OUT_ABS" ]; then
  echo "export failed: no APK at $OUT" >&2
  exit 1
fi

# Report size and check 16 KB alignment (Play's page-size rule for Android 15+).
bt="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)"
echo "APK: $OUT ($(du -h "$OUT_ABS" | cut -f1), $(stat -c %s "$OUT_ABS") bytes)"
if "$bt/zipalign" -c -P 16 4 "$OUT_ABS" >/dev/null; then
  echo "zipalign: native libraries aligned to 16 KB pages"
else
  echo "zipalign: NOT aligned to 16 KB pages" >&2
  exit 1
fi
