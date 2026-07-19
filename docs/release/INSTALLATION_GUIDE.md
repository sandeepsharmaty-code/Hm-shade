# Hue Muse Shade AI — Installation Guide

## For developers/build engineers (there is no pre-built APK yet)

**Important**: this repository has never been compiled by a real
Flutter toolchain (see `docs/sprints/SPR-DEP-012-completion-report.md`).
These are the exact steps to produce a real, verified build.

### Prerequisites
- Flutter SDK (latest stable channel)
- Android SDK / Android Studio, or a CI environment with both
- A physical device or emulator for testing (ideally spanning Android
  8 through 14, per the project's target range)

### Steps

```bash
# 1. Get dependencies
flutter pub get

# 2. Static analysis — must show 0 errors before continuing
flutter analyze

# 3. Run the test suite — ~70 test cases across 11 files
flutter test

# 4. Build a debug APK for device testing
flutter build apk --debug

# 5. Once debug testing passes, build the release artifacts
flutter build apk --release
flutter build appbundle
```

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
Release APK: `build/app/outputs/flutter-apk/app-release.apk`
App Bundle: `build/app/outputs/bundle/release/app-release.aab`

### Installing the debug/release APK

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or transfer the APK to a device and install manually (enable
"Install from unknown sources" if sideloading outside Google Play).

### App Bundle

The `.aab` file is the format expected by the Google Play Console for
production distribution — it is not directly installable on a device
the way an APK is; Play builds device-specific APKs from it.

## Permissions

The app requests camera and/or photo-library access (via the
`image_picker` package) the first time you try to select a shade
image. No other permissions are required — there is no network,
location, contacts, or storage-beyond-the-app-sandbox access.

## Data location

The local SQLite database and all backups/exports live inside the
app's own document storage — nothing outside the app's private
sandbox on the device.
