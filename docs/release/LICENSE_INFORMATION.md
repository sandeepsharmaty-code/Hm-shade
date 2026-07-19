# Hue Muse Shade AI — License Information

**No license has been specified by the Project Director at any point
across all 12 sprints.** This is a genuine gap, not an oversight to
paper over.

## Default assumption, pending confirmation

Since this is an internal business tool for Hue Muse Beauty (an
in-house manufacturing/formulation system, not a public or
distributed product), the sensible default — **until you say
otherwise** — is:

**Proprietary / All Rights Reserved.** Copyright Hue Muse Beauty. Not
licensed for redistribution or external use.

No `LICENSE` file has been added to the repository, since adding one
would itself be asserting a license decision that hasn't actually
been made. This document exists to flag the gap explicitly rather
than leave it silently unaddressed in a "final" release package.

## Third-party dependencies

This app uses the following open-source packages (see
`pubspec.yaml`), each under its own license (all standard permissive
licenses — BSD/MIT/Apache 2.0-family, typical for the Flutter/Dart
ecosystem):

- `flutter`, `cupertino_icons` — BSD-3-Clause (Flutter/Dart team)
- `provider` — MIT
- `sqflite`, `sqflite_common_ffi` — MIT
- `path`, `path_provider` — BSD-3-Clause
- `image_picker` — BSD-3-Clause
- `image` — MIT
- `flutter_lints` — BSD-3-Clause

None of these licenses require this app's own source to be
open-sourced (none are copyleft). A full, exact license audit
(pulling each package's actual `LICENSE` file text) would need
`flutter pub get` to have run at least once — not done here, same
root cause as every other unverified item in this release package.
