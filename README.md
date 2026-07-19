# Hue Muse Shade AI

Offline Android application for cosmetic colour shade development.
No internet, no cloud, no login, no API — fully local, SQLite-backed.

This repository is developed under strict enterprise governance:
**One Sprint → One Module → One Review → One Approval → Freeze.**
See `docs/sprints/SPR-DEP-001.md` (sprint report) for full details of
the current sprint.

## CI/CD Pipeline

`.github/workflows/flutter_release.yml` runs the full verification
sequence — `flutter doctor` → `pub get` → `analyze` → `test` →
`build apk --debug` → `build apk --release` → `build appbundle` — on
every push to `main` and every pull request, in a real GitHub-hosted
Flutter environment (something this local development sandbox has
never had). It fails fast on analyzer errors or test failures, caches
the Flutter SDK/pub packages/Gradle for speed, and uploads the
release APK, debug APK, AAB, test results, and analyze report as
downloadable workflow artifacts. A build summary (Flutter version,
test pass/fail counts, build sizes, durations) appears on the Actions
run page.

**Update (v1.0.0 Release Audit)**: the `android/` platform folder is
now committed to the repository (standard Flutter embedding v2
scaffold — Gradle config, manifests, `MainActivity`, brand-colored
launcher icons, release-signing fallback). The workflow's
auto-generate step is kept only as a defensive fallback; on a normal
run it will find `android/` already present and skip regeneration.
`applicationId` is set to `com.huemuse.hue_muse_shade_ai` as a
release-engineering default (no package name had been decided
anywhere in the docs before this audit) — confirm or rename before
any Play Store submission. `minSdkVersion` is set to 26 / `targetSdk`
34 to match the approved Android 8–14 device range (see
`docs/release/RELEASE_NOTES.md`). Release builds fall back to
Flutter's debug signing config until a real upload keystore is
supplied via `android/key.properties` (copy from
`android/key.properties.example`) — fine for internal sideload/
testing, **not** sufficient for Play Store submission.

No GitHub secrets are required for this workflow as configured (no
signing key is used). If a real release-signing keystore is added
later, the workflow will need `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, and `KEY_PASSWORD` secrets plus a corresponding
`android/key.properties` setup — not added now since no keystore
exists yet.

## Current Status

**Development: complete.** All 12 planned sprints (SPR-DEP-001
through SPR-DEP-012) delivered their stated scope. **Release: pending
final toolchain verification.** No Flutter SDK has ever been
available in any environment that has worked on this project,
including the environment that performed the v1.0.0 Release
Readiness Audit — `flutter analyze`, `flutter test`, and every build
command have never actually run. That audit did remove the one
blocker guaranteed to fail before any of that tooling even reached
the Dart code (the missing `android/` folder — see above). See
`docs/sprints/SPR-DEP-012-completion-report.md` for the original
unvarnished account and `docs/release/` for the complete
documentation set (Release Notes, User Manual, Installation Guide,
Architecture Summary, Database Documentation, Engine/API
Documentation, Known Issues, Risk Register, Version History, License
Information, Support Guide).

**To actually finish this project**, run:
```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle
```
(or push to `main`/open a PR and let `.github/workflows/flutter_release.yml`
do it), then verify installation across Android 8-14, then fix
whatever the analyzer/tests/build surface. `pubspec.yaml`'s version
was bumped to `1.0.0+1` as part of the Release Audit to prepare a
release candidate — this is a packaging label, not a certification
that the app builds; treat it as unverified until the command above
has actually been run. See `docs/release/VERSION_HISTORY.md` and the
Release Audit Report for the full reasoning.

## Build Instructions

1. Install Flutter (latest stable channel) and confirm setup:
   ```
   flutter doctor
   ```
2. Fetch dependencies:
   ```
   flutter pub get
   ```
3. Run on a connected device or emulator:
   ```
   flutter run
   ```
4. Build a release APK:
   ```
   flutter build apk --release
   ```

## Testing Steps

1. Fetch dependencies:
   ```
   flutter pub get
   ```
2. Run the unit test suite:
   ```
   flutter test
   ```
3. Expected result: all prior-sprint engine/repository tests pass
   unchanged (this sprint added no new pure-logic units — see Testing
   Strategy in the SPR-DEP-009 report for why UI integration isn't
   covered by `flutter test` here).

## Project Structure

```
lib/
  core/       -> database (v5 schema + databaseFilePath getter),
                 di (15 repos + 23 engines), routing (+ trial route),
                 theme, services
  models/     -> 13 Data Layer models + rule/trial_status/history/
                 audit models + raw_material_model.dart interface
  repositories/ -> base_repository.dart + 14 concrete repositories
  engines/    -> all 23 engines from SPR-DEP-004 through SPR-DEP-008,
                 unchanged this sprint (integration only, no engine
                 redesign)
  screens/    -> SplashScreen, RootShellScreen (unchanged/frozen),
                 HomeScreen, NewShadeScreen, KnowledgeBaseScreen,
                 SearchScreen, SettingsScreen (all rewritten this
                 sprint), TrialScreen (new — pushed route)
  widgets/    -> 10 prior widgets + trial_status_chip.dart,
                 recommendation_summary_card.dart (new)
  main.dart   -> bootstrap (unchanged registrations)
  app.dart    -> MultiProvider + MaterialApp + named routing
assets/
test/
  (all prior-sprint tests, unchanged)
```

## Approved Database Tables

`Product_Master`, `Shade_Master`, `Pigment_Master`, `Dye_Master`,
`Mica_Master`, `Pearl_Master`, `Filler_Master`, `Binder_Master`,
`Blend_Template_Master`, `Trial_Formula`, `Formula_Material`,
`Approved_Formula`, `Knowledge_Base`, `Settings`.

No table has been added, removed, or renamed. Full domain columns for
each table are intentionally deferred to their respective module
sprints (see Known Issues in the sprint report) — only foundation
columns (`id`, `name`, `created_at`, `updated_at`) exist today.
