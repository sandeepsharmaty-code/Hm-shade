# Hue Muse Shade AI — Support Guide

## For end users (lab/formulation staff)

- **The app won't open / crashes on launch**: check Settings ->
  Restore Database if you recently restored a backup — you must
  restart the app afterward. If it still fails, the last-resort
  option is Settings -> Reset Local Data (this erases everything, so
  only use it if nothing else works and you understand the data
  loss).
- **My data seems to have disappeared**: check Settings -> Restore
  Database — a `backups/pre_restore_safety_snapshot.db` file is
  automatically saved there before every restore, in case a restore
  didn't do what you expected.
- **A recommendation looks wrong**: open its Explanation from the
  Trial screen — it lists exactly which rules matched, which failed,
  and why the confidence score is what it is. If the underlying rule
  weights need adjusting, that's a configuration change (see Rules
  tab in Knowledge), not a bug report.
- **Import Knowledge isn't working**: the file must be named exactly
  `knowledge_import.json` and placed in the app's
  `Documents/imports/` folder — there's no in-app file browser in
  this version.

## For developers / technical support

- **Where's the database?** App's private document storage,
  `hue_muse_shade_ai.db`. Never accessible to other apps or outside
  the device.
- **How do I inspect data for debugging?** Use `adb shell` +
  `run-as` to pull the `.db` file off a debug-signed build, then
  open with any SQLite browser. (Not possible on a release-signed
  build without root — by design, this is a security property, not a
  limitation to work around.)
- **Where do I report a bug?** This project has no external
  bug-tracker reference yet — route through whatever internal channel
  Hue Muse Beauty uses for this codebase. Include: Android version,
  steps to reproduce, and — if the app is still running — Settings ->
  About Application for the version string.
- **Where's the architecture/engine documentation?**
  `docs/release/ARCHITECTURE_SUMMARY.md`,
  `docs/release/ENGINE_API_DOCUMENTATION.md`,
  `docs/release/DATABASE_DOCUMENTATION.md`. Every sprint's own
  detailed report is in `docs/sprints/`.
- **The app has never been built by a real Flutter toolchain** — see
  `docs/release/INSTALLATION_GUIDE.md` for the exact commands to
  produce a real, verified build. This is the first thing any support
  engineer should confirm before debugging anything else.
