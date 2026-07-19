# SPR-DEP-010 — Quality Assurance & Beta Readiness Report

**Objective:** Prepare the application for Internal Beta. Verify all
completed modules, fix defects, improve reliability. No feature
expansion.

---

## A note on scope before anything else

This sprint's OUTPUT list asks for things that fall into two very
different categories:

- **Things a static code audit can genuinely verify**: architecture
  compliance (Repository Layer only, no SQL in UI), import/reference
  integrity, logic-level correctness of pure functions, presence and
  shape of error handling, security posture (offline-only, logging
  discipline).
- **Things that require an actual Flutter SDK, compiler, and/or
  device**: `flutter analyze` output, `flutter test` pass/fail
  results, APK builds (debug/release), Android-version compatibility,
  startup time, memory usage, database/image-analysis/recommendation
  timing.

This sandbox has never had a Flutter SDK or internet access
(ENV-001, raised in every sprint since SPR-DEP-001). For the first
category, this report gives real, substantive findings — including
two real defects found and fixed this sprint. For the second
category, this report says so plainly rather than inventing numbers.
Fabricated benchmarks or a fake "0 errors, 0 warnings" analyzer
output would be worse than admitting the gap — you'd be making a beta
go/no-go decision on invented data.

---

## 1. Test Summary

| Test file | Cases | Type |
|---|---|---|
| `database_helper_test.dart` | 3 | Repository/DB |
| `product_repository_test.dart` | 7 | Repository |
| `match_type_test.dart` | 7 | Engine (pure) |
| `shade_engine_test.dart` | 9 | Engine (pure) |
| `rule_evaluator_test.dart` | 6 | Engine (pure) |
| `recommendation_ranker_test.dart` | 3 | Engine (pure) |
| `color_conversion_engine_test.dart` | 12 | Engine (pure) |
| `dominant_color_engine_test.dart` | 4 | Engine (pure) |
| `trial_status_test.dart` | 8 | Model (pure) |
| `rule_engine_test.dart` | 4 | Engine (repository-backed) — **new this sprint** |
| `trial_status_chip_test.dart` | 7 (6 generated + 1) | Widget — **new this sprint, first in project** |
| **Total** | **~70** | |

None of these have been executed by a real `flutter test` run — see
ENV-001. Every test was written to pass based on hand-traced logic
(and, for `rule_engine_test.dart`, hand-computed weighted-confidence
arithmetic, shown in the test's own comments). This is not the same
guarantee as a green CI run.

## 2. Flutter Analyze Report

**Cannot produce a real one.** Substitute static audit performed this
sprint, across all 107 `.dart` files:
- Brace/parenthesis/**square-bracket** balance (added bracket checking
  this sprint, on top of prior sprints' brace/paren checks) — 0
  mismatches.
- Every local import resolves to an existing file, both `../`-style
  and same-directory (`'file.dart'`) forms — 0 missing.
- Every `package:` import is declared in `pubspec.yaml` — confirmed
  for `lib/` and `test/`.
- Identifier-to-defining-file cross-check (every capitalized
  class/enum/typedef reference verified against its source file being
  imported) across the entire `lib/` tree — 0 missing imports found
  after this sprint's fix (see Bug List #1).
- No duplicate class/enum definitions anywhere in `lib/`.
- Every `catch` clause's bound variable is either used or
  intentionally discarded as `_` — 0 unused-catch-variable issues.

This substitute catches a meaningful subset of what `flutter analyze`
would (missing imports, dead catch bindings, structural syntax
damage) but not type errors, unused-import warnings (as opposed to
missing ones), or Flutter/Dart-API misuse (e.g. wrong `package:image`
method signatures) — those need a real analyzer.

## 3. Widget Test Report

**One widget test file, new this sprint**:
`test/trial_status_chip_test.dart` — 6 generated cases (one per
`TrialStatus` value, asserting the correct label renders) + 1 case
asserting the chip's `Container` has rounded-corner decoration.
Chosen because `TrialStatusChip` needs no `ServiceLocator`/repository
wiring — it's the safest, most isolated widget to start coverage
with.

**Not covered**: every screen (`HomeScreen`, `NewShadeScreen`,
`SearchScreen`, `KnowledgeBaseScreen`, `SettingsScreen`,
`TrialScreen`) and every other widget. Screen-level widget tests need
test doubles registered into `ServiceLocator.instance` before
pumping, which is a larger, deliberate undertaking — flagged as the
top recommended follow-up in Known Issues rather than attempted
partially this sprint.

## 4. Repository Test Report

`database_helper_test.dart` (table existence) and
`product_repository_test.dart` (full CRUD/search/filter/exists/count/
soft-delete contract, representative of all 14 repositories since
they share `BaseSqliteRepository`) — both carried forward, unchanged,
still logically sound on re-read this sprint.

## 5. Engine Test Report

Pure-logic engine tests (7 files, unchanged, re-verified this sprint)
plus **one new repository-backed engine test**,
`rule_engine_test.dart`, which seeds real `Settings` rows and
exercises `RuleEngine.evaluate()` end-to-end — including a case that
specifically verifies a **disabled rule never participates in
evaluation** (relevant to this sprint's own "Invalid Rule" error-
handling category, see Section 9).

**Still untested**: `KnowledgeEngine`'s repository-backed methods,
`ShadeEngine.validateProductCompatibility`, all of
`RecommendationEngine`/`FormulaRecommendationEngine`/
`TrialGeneratorEngine`/`TrialValidationEngine`/
`TrialComparisonEngine`/`TrialExplanationEngine`/
`TrialWorkflowManager`, and the entire Image Intelligence engine set
(`ImageProcessor`, `ColorSamplingEngine`, `ColorExtractionEngine`,
`ImageAnalysisEngine` — these specifically need a real image file
fixture and `flutter test`'s asset-loading, not exercised here). This
is a large gap, flagged every sprint since SPR-DEP-004, still open.

## 6. Integration Test Report

**None exist.** No test in this project currently drives the full
pipeline (e.g. seed a product+shade+trial+rules in one in-memory DB,
call `TrialGeneratorEngine.generateTopFive`, assert on the real
ranked output) or the full navigation flow (Splash -> Shell -> New
Shade -> push Trial -> back). This is the single largest testing gap
in the project. A worked example exists as a pattern
(`rule_engine_test.dart`'s seed-then-call-then-assert structure) that
a future sprint could extend to a true end-to-end test.

## 7. Performance Report

**Cannot measure anything real** — Application Startup Time, Memory
Usage, Database Performance, Image Analysis Time, Recommendation
Time, and Navigation Performance all require a running app on a real
device or emulator. Nothing in this sandbox can produce a genuine
number for any of these. Reporting a fabricated millisecond figure
would be actively misleading for a beta go/no-go decision.

What can be said honestly from code inspection:
- `ImageProcessor.downscale` caps images at 200px on the longer side
  before sampling, which bounds `ColorSamplingEngine`'s per-image
  pixel-touch count regardless of the original photo's resolution —
  a deliberate performance safeguard from SPR-DEP-008, still in place.
- `RecommendationEngine`/`FormulaRecommendationEngine`/
  `TrialGeneratorEngine` each make multiple sequential `await`ed
  repository calls per candidate (not batched) — with a handful of
  trial formulas this is fine; with hundreds, this pipeline has not
  been load-tested and could show up as a real latency issue. Flagged
  as a genuine, plausible risk area for beta feedback to surface.

## 8. Security Report

- OK **Offline Only** — grep-verified zero `http`/`dio`/network-
  package imports anywhere in `lib/`. `pubspec.yaml` has no networking
  dependency.
- OK **Repository Layer Only** — grep-verified zero direct
  `db.query`/`insert`/`update`/`delete`/`rawQuery`/`execute` calls
  outside `lib/core/database/` and `lib/repositories/`.
- OK **No Direct SQLite in UI** — grep-verified zero
  `package:sqflite` imports and zero SQL keywords in `lib/screens/`
  and `lib/widgets/`.
- **No Sensitive Logging** — grep-verified no password/secret/token/
  key-related strings appear in any log statement. All log messages
  are operational (repository/engine names, operation names, error
  objects) — no user PII, no raw database rows, no file contents
  logged.
- **Release Logging Disabled — real defect found and fixed this
  sprint.** Three `debugPrint()` call sites (`splash_screen.dart`,
  `settings_screen.dart`, `image_picker_card.dart`) were **not**
  guarded by `kDebugMode`, meaning they would have printed in release
  builds too. Every other log call in the codebase (all
  `EngineBase.logDebug` calls, all `BaseSqliteRepository`/
  `TrialRepository` internal logging) was already correctly guarded —
  these three were the only exceptions, all from earlier sprints.
  Fixed this sprint; see Bug List #1. A repo-wide scan now confirms
  **0 unguarded `debugPrint` calls** anywhere in `lib/`.

## 9. Bug List

| # | Severity | Description | Status |
|---|---|---|---|
| 1 | Medium | Three `debugPrint()` calls (`splash_screen.dart`, `settings_screen.dart`, `image_picker_card.dart`) ran unconditionally, including in release builds — violates this sprint's explicit "Release Logging Disabled" security requirement. | **Fixed** — wrapped in `if (kDebugMode)`. |
| 2 | Medium | Settings' Restore Database action copied the chosen backup file directly over the live database with no validation — a corrupted or wrong-format file would silently produce an unopenable database on next launch (the "Corrupted Backup"/"Restore Failure" cases this sprint explicitly asks to verify). | **Fixed** — added SQLite file-header validation (checks the standard 16-byte "SQLite format 3\0" magic) before restoring; restore is cancelled with an explanatory dialog if the file fails validation, current data is left untouched. |
| 3 | Low | No safety snapshot existed before Restore overwrote the live database — if a *valid-looking* backup turned out to be the wrong one, there was no way back. | **Fixed** — Restore now copies the current live database to `backups/pre_restore_safety_snapshot.db` before overwriting it. |
| 4 | Low | `RuleModel.fromMap` silently defaults an unparseable `rule_type` value to `RuleType.product` rather than surfacing that the row is corrupted. In practice this is unreachable through normal app usage (nothing in the app ever writes an invalid `rule_type`) — it would only matter if `Settings` were edited outside the app. | **Not fixed** — see Known Issues #4 for why a proper fix was judged out of scope for a stabilization sprint. |

## 10. Known Issues

**Carried forward, unresolved:**
1. **ENV-001** — no Flutter SDK/network access in this sandbox.
   Blocks real `flutter analyze`/`test`/`build`, real performance
   measurement, and real Android-version verification. This is the
   central limiting factor of this entire sprint.
2. Every open question from SPR-DEP-003 through SPR-DEP-009 (DB
   filename, column schemas, rule/ranking weights, transition graph,
   `image` package confirmation, Trial-as-pushed-route decision) — no
   response received yet.
3. The large testing gaps in Sections 3, 5, and 6 above — no
   screen-level widget tests, no repository-backed tests for most
   engines, no integration tests at all.

**New this sprint:**
4. **`RuleModel`'s silent rule-type fallback** (Bug List #4) —
   judged not worth fixing in a stabilization sprint because the
   correct fix (making `RuleType` nullable end-to-end) touches
   `RuleEngine`, `RecommendationEngine`, `MaterialMatchingEngine`,
   `TrialExplanationEngine`, and every call site that reads
   `.ruleType` — a wide-blast-radius change in a sprint whose
   explicit goal is *stability*, not refactoring. Flagged for a
   dedicated, careful pass rather than a rushed fix here.
5. **Beta build artifacts (APKs) do not exist.** Section 11 below
   explains what's needed from you to actually produce them.

## 11. Beta Release Report

**This build is not yet a beta candidate**, for one concrete,
fixable-outside-this-sandbox reason: **no Debug or Release APK has
ever been built**, because no Flutter SDK is available here. Every
other gate this report can speak to (static code integrity, security
posture, defect fixes) is in reasonable shape for an internal beta,
conditional on a real build succeeding.

**What's needed to actually cut a beta build**, in order:
```
flutter pub get
flutter analyze                    # confirm 0 errors/warnings for real
flutter test                       # confirm all ~70 test cases pass
flutter build apk --debug          # Debug APK
flutter build apk --release        # Release APK
```
Then install the release APK on physical or emulated devices spanning
Android 8 through 14 (this sprint's required range) and walk the
critical paths: Splash -> Shell, New Shade's full image -> recommendation
flow, Trial Screen's comparison/validation/explanation/history sheets
and "Mark Ready for Lab", and Settings' Backup -> Restore round-trip
(the fix in Bug List #2/#3 specifically needs exercising with both a
valid and a deliberately corrupted backup file).

## 12. Sprint Completion Report

### Files changed this sprint

```
lib/screens/splash_screen.dart      (kDebugMode guard fix)
lib/screens/settings_screen.dart    (kDebugMode guard fix, backup
                                      validation, safety snapshot)
lib/widgets/image_picker_card.dart  (kDebugMode guard fix)
test/rule_engine_test.dart          (new — repository-backed engine test)
test/trial_status_chip_test.dart    (new — first widget test)
```

No engine, model, or repository logic was redesigned — matching this
sprint's explicit "no feature expansion" / "do not redesign" scope.
Every change is either a defect fix or new test coverage.

### Self Review

- OK **Zero Critical Bugs** — the two real defects found this sprint
  (unguarded logging, unvalidated restore) were both fixed, not just
  noted. No other critical-severity issue was found in this sprint's
  audit.
- OK **Zero Data Loss** — Restore now snapshots before overwriting;
  Reset Local Data still requires explicit confirmation (unchanged
  from SPR-DEP-002); Export/Import Knowledge don't delete existing
  data on failure (checked: `_handleImportKnowledge` skips malformed
  rows individually rather than aborting/corrupting the whole
  operation).
- NOT CONFIRMED **Navigation Stable** — logic traced by hand (route
  arguments, `TrialScreenArgs` cast-with-fallback in `AppRouter`), but
  never exercised in a real navigator. No regression found in review.
- NOT CONFIRMED **Recommendation Stable** / **Trial Workflow Stable**
  / **Image Analysis Stable** — same basis: reviewed, no defect
  found, never run.
- OK **Backup Restore Working** — genuinely improved this sprint
  (validation + safety snapshot are real, working code, traceable
  logic), though "working" here means "logically sound on review,"
  not "verified on a device."
- NOT CONFIRMED **Production Candidate** — see Section 11. Code-level
  readiness is reasonable; build/device verification is the
  explicit, named blocker.

## Ready For Approval

**This sprint's work (defect fixes, new tests) is complete and
correct to the best of static review.** Whether the **application** is
beta-ready depends on the real build/test/device pass described in
Section 11, which cannot happen in this sandbox. Per the Stop Rule,
not continuing to SPR-DEP-011 until you approve — and for this
sprint specifically, approval realistically means "I ran the Section
11 checklist and here's what happened," more than any other sprint so
far.
