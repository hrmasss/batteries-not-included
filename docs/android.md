# Android

The Android build: what it targets, how to build it, how to run it in an emulator.

## What the APK is

| Setting | Value | Why |
|---|---|---|
| Min SDK | 29 (Android 10) | NF-3 |
| Target SDK | 36 (Android 16) | What Google Play requires for new apps and updates |
| ABIs | arm64-v8a, x86_64 | Phones, and the emulator |
| Orientation | Landscape, either way up | |
| Package | `io.github.hrmasss.batteriesnotincluded` | Permanent once on the store |
| Native libraries | Stored uncompressed, 16 KB page aligned | Play's page-size rule for apps targeting Android 15+ |
| Permissions | Internet | LAN play |

Setting the min SDK needs Godot's Gradle build, so the export uses it. The Gradle project
(`android/`) is installed from the export templates by the build script and is not in git.

The preset is `export_presets.cfg`, preset `Android`. It holds no keystore or password.

## Build

```sh
GODOT=/path/to/godot tools/build-android.sh            # debug APK, build/android/bni-debug.apk
GODOT=/path/to/godot tools/build-android.sh release    # needs the release keystore env, below
```

Needs:

- Godot 4.7.2 and its export templates (Editor > Manage Export Templates, or unzip the `.tpz`
  into `~/.local/share/godot/export_templates/4.7.2.stable/`).
- The Android SDK (`ANDROID_HOME`, default `~/Android/Sdk`) with `platforms;android-36` and
  `build-tools;36.1.0`.
- A JDK 17 with `javac` (`JAVA_HOME`). A Java runtime alone is not enough for Gradle.

A debug build signs with `~/.android/debug.keystore`, made with the standard debug credentials
if missing. A release build reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and
`_PASSWORD`.

The script refuses an APK that lacks the ruleset files (Godot only packs files it knows as
resources; the `.cfg` rulesets come in through the preset's include filter) or whose native
libraries are not 16 KB aligned.

CI (`.github/workflows/android.yml`) builds the debug APK on every pull request and keeps it as
an artifact for 14 days.

## Run in an emulator

```sh
avdmanager create avd -n bni -k "system-images;android-35;google_apis;x86_64" -d pixel_6
DISPLAY=:99 tools/android-run.sh build/android/bni-debug.apk out/
```

Boots the AVD headless, installs and launches the game, drives the toy with keyboard events,
and saves screenshots, a 20 s screen recording, frame times from SurfaceFlinger and the log.
It stops the emulator at the end. `EMULATOR_LOCK=<file>` holds a lock while the emulator runs,
for machines that share it.

- **GPU.** The default is `-gpu host`, which needs a display; a virtual one under Xvfb works
  with Mesa. SwiftShader (`GPU=swiftshader_indirect`) shows a grey screen: its GLES allows 261
  fragment uniform vectors, fewer than Godot's 2D shader uses.
- **KVM.** A user just added to the `kvm` group keeps the old groups until a new login; the
  script then starts the emulator through `sg kvm`.

## What the emulator does not prove

- Frame time. The emulator renders on the CPU (Mesa llvmpipe), so its 12 to 25 fps says
  nothing about a phone's GPU. NF-1 needs the reference phone.
- Touch latency (NF-2, US-23.6), heat and battery (NF-5): only a real phone shows them.
- ARM. The emulator runs the x86_64 library; the arm64 one is built and aligned but not run.
- GPU drivers. Real Adreno, Mali and PowerVR drivers have their own limits and bugs.

## Size

Godot 4.7.2's own engine library is about 71 MB on arm64, so a stock build cannot meet NF-4's
67 MB install. A trimmed engine (a custom export template without the 3D and other unused
modules) is the usual fix; it is not done yet.
