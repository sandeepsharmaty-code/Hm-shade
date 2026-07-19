# SPR-DEP-011 — Release Candidate Report

**Objective:** Prepare the application as a Release Candidate.
Verification, optimization, bug fixes, performance, security,
production stability. No feature additions, no redesign.

---

## Before the sections: the fundamental blocker is unchanged

SPR-DEP-010 ended with a specific, concrete ask: run
`flutter pub get && flutter analyze && flutter test && flutter build
apk --debug/--release`, then verify on real devices. This sprint's
brief asks for the same class of things again (plus AAB builds and
Android 8-14 install verification), at higher stakes ("Release
Candidate"). I have no indication that checklist was run —
this sandbox still has no Flutter SDK and no internet access
(ENV-001, unchanged since SPR-DEP-001).

**What changed this sprint**: rather than repeat the same static
checks as SPR-DEP-010, I went one level deeper into categories I
hadn't rigorously audited before — unused imports (checked the
*opposite* direction this time: are any imports genuinely unused,
not just any missing), dead code, memory-leak patterns, and
`ServiceLocator`/`Provider` usage discipline. Every one of these came
back clean. That's a real, meaningful finding — it means four sprints
of incremental static-audit discipline held up — but it is still not
a substitute for a compiler.

---

## 1. Flutter Analyze Report

**Not executable.** This sprint's deeper substitute audit (in
addition to every check repeated from SPR-DEP-010: balance, import
resolution, duplicate classes, unused-catch-vars):
- **Unused imports** — checked every local (relative) import in
  every one of 96 `lib/` files by extracting the target file's
  exported symbols and confirming at least one is referenced.
  **0 found.**
- **Unused aliased imports** (`import '...' as x`) — checked every
  alias is actually used as `x.something`. **0 found.**
- **Dead private code** — every private class (`_Foo`) and private
  method (`_bar()`) checked for at least one reference beyond its own
  declaration. **0 found.**
- **`ServiceLocator` consistency** — every `ServiceLocator.instance.
  get<T>()` call site's `T` cross-checked against
  `registerSingleton<T>()` calls in `main.dart`. **0 mismatches** —
  every requested type is registered.
- **No debug code** — 0 raw `print()` calls (only `debugPrint`, and
  now all `kDebugMode`-guarded per SPR-DEP-010's fix), 0 genuine
  TODO/FIXME markers (one false-positive grep hit on `toDouble()`
  containing the substring "todo", not an actual marker), 0
  hardcoded test/example values.

## 2. Flutter Test Report

**Not executable.** 11 test files, ~70 test cases (unchanged from
SPR-DEP-010 — no new tests were needed this sprint since the deeper
audit found no defects to write regression tests against). Every
test file re-read this sprint; no logic changes were made to any of
them, so their hand-traced correctness from SPR-DEP-010 still holds.

## 3. Widget Test Report

**Unchanged from SPR-DEP-010**: `trial_status_chip_test.dart`, 7
cases. Screen-level widget tests remain unwritten — still the
top-flagged testing gap (see Known Issues #2).

## 4. Repository Test Report

**Unchanged**: `database_helper_test.dart` (3 cases),
`product_repository_test.dart` (7 cases, representative of all 14
repositories via the shared `BaseSqliteRepository` contract).

## 5. Engine Test Report

**Unchanged**: 7 pure-logic engine test files +
`rule_engine_test.dart` (repository-backed, added SPR-DEP-010).
Coverage gap for `KnowledgeEngine`/`RecommendationEngine`/
`FormulaRecommendationEngine`/`TrialGeneratorEngine`/
`TrialValidationEngine`/`TrialComparisonEngine`/
`TrialExplanationEngine`/`TrialWorkflowManager`/all Image
Intelligence engines remains open.

## 6. Integration Test Report

**Still none.** Same gap as SPR-DEP-010. No end-to-end pipeline test,
no navigation-flow test exists.

## 7. Performance Benchmark

**Cannot measure anything real, at all** — Cold Startup Time, Warm
Startup Time, Memory Consumption, CPU Usage, SQLite Query
Performance, Image Processing Time, Recommendation Engine Time,
Navigation Performance all require a running app instance. There is
no code-level substitute for any of these eight metrics — unlike
Section 1's static analyzer substitute, there is no meaningful
"static performance audit." Reporting any number here would be
fabrication.

What remains true from code inspection (carried forward from
SPR-DEP-010, still accurate): `ImageProcessor` caps images at 200px
before sampling (bounded image-processing cost regardless of source
resolution); `RecommendationEngine`/`FormulaRecommendationEngine`/
`TrialGeneratorEngine` make sequential (not batched) repository calls
per candidate — untested at scale, flagged as a plausible risk if
trial-formula volume grows large.

## 8. Optimization Report

Real findings from this sprint's deeper pass (all clean — nothing
required fixing):
- **Widget rebuilds**: every `context.watch<T>()` call is inside a
  `build()` method (correct — triggers rebuild on change);
  every `context.read<T>()` call is inside an event handler /
  callback, never inside `build()` (correct — doesn't force
  unnecessary rebuilds). `RootShellScreen` still uses `IndexedStack`
  (preserves inactive tab state, avoids rebuilding hidden tabs) —
  unchanged since SPR-DEP-002.
- **`FutureBuilder` futures**: every `FutureBuilder`'s `future:`
  argument references a field cached in `initState`/constructor
  (`_summaryFuture`, `_productsFuture`, `_resultsFuture`, `_future`,
  etc.), never an inline call that would silently re-fetch on every
  rebuild — checked across all 6 screens using `FutureBuilder`.
- **Memory leaks**: every `TextEditingController`/`StreamSubscription`
  field checked for a matching `dispose()`/`cancel()` call. **0
  leaks found** (`SearchBox`'s controller was already correctly
  disposed since SPR-DEP-002).
- **Database queries**: unchanged from prior sprints — Repository
  Layer only, confirmed again this sprint (Section 9).
- **Service Locator usage**: confirmed consistent (Section 1).

No optimization changes were made this sprint because none of these
categories surfaced a real issue to fix.

## 9. Security Report

All items re-verified this sprint, all still hold:
- OK Offline Only — no networking dependency in `pubspec.yaml`.
- OK Release Logging Disabled — fixed in SPR-DEP-010, re-confirmed
  0 unguarded `debugPrint` calls this sprint.
- OK Repository Layer Only / No SQL in UI — re-confirmed via grep.
- OK No Debug Code — see Section 1.
- OK No Sensitive Logs — re-confirmed no password/secret/token/key
  strings in any log statement.
- OK Backup Validation / Restore Validation — fixed in SPR-DEP-010
  (SQLite header check + pre-restore snapshot), unchanged this
  sprint, re-read and still correct.
- OK Import Validation — `_handleImportKnowledge` validates the
  decoded JSON is a `List`, skips malformed rows individually rather
  than aborting.
- **Export Validation — not previously explicitly reviewed.**
  `_handleExportKnowledge` reads real `KnowledgeBaseModel` rows and
  `jsonEncode`s them; there's no user-controlled input to validate on
  the export path (it only ever writes data the app itself already
  holds), so there's no injection or malformed-input risk here by
  construction. Confirmed safe on review, no fix needed.

## 10. Release Candidate Checklist

Every item below was **traced through the code**, not exercised on a
device. "Traced" means: the code path exists, has been read
end-to-end, has appropriate error handling, and no defect was found
in it this sprint or last.

| Item | Status |
|---|---|
| Application Launch | Traced (Splash -> DB init -> Shell) |
| Navigation | Traced (named routes, tab switching, push/pop) |
| Image Selection | Traced (`ImagePickerCard`, real `image_picker`) |
| Image Analysis | Traced (`ImageAnalysisEngine` pipeline) |
| Color Profile | Traced (rendered in New Shade screen) |
| Recommendation Workflow | Traced (`RecommendationEngine` -> `FormulaRecommendationEngine` -> `TrialGeneratorEngine`) |
| Trial Workflow | Traced (`TrialWorkflowManager`, audit trail) |
| Knowledge Screen | Traced (4 tabs, all repository-backed) |
| Search | Traced (5 categories) |
| Settings | Traced (all 7 actions incl. Reset) |
| Backup | Traced + fixed this cycle (SPR-DEP-010) |
| Restore | Traced + fixed this cycle (SPR-DEP-010) |
| Import | Traced (fixed-path JSON import) |
| Export | Traced (Section 9) |

**None of these are device-verified.** This table is an honest
"code exists and looks correct on read-through," not a QA sign-off.

## 11. Known Issues

**Carried forward:**
1. **ENV-001** — still the central blocker for every item in
   Sections 1, 2, 7, and 10's real verification.
2. Testing gaps: no screen-level widget tests, no repository-backed
   tests for most engines, no integration tests (Sections 3, 5, 6).
3. All open schema/weight/design questions from SPR-DEP-003 through
   SPR-DEP-009 — no response yet.
4. `RuleModel`'s silent rule-type fallback (SPR-DEP-010 Bug #4) —
   still not fixed, still judged out of scope for a stabilization/RC
   sprint given its wide blast radius and unreachability through
   normal app usage.
5. `RecommendationEngine`'s sequential (non-batched) per-candidate
   repository calls — untested at scale (Section 7).

**New this sprint:** none — the deeper audit found no new defects.

## 12. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Code doesn't actually compile (never verified by a real compiler) | Unknown — genuinely can't estimate | High if true | Run Section 1's checklist before any release |
| Performance is unacceptable at real data volumes | Unknown | Medium-High | Load-test `RecommendationEngine`/`TrialGeneratorEngine` with realistic trial-formula counts once a device is available |
| Android-version-specific incompatibility (8-14 span) | Unknown | Medium | Install and smoke-test on real/emulated devices across the range |
| A corrupted `Settings.rule_type` value silently misclassifies a rule | Low (nothing in-app writes invalid data) | Low | Documented, not fixed (see Known Issues #4) |
| Restore/Backup fails on a real device's filesystem permissions model | Unknown (only logic-verified, not device-verified) | Medium | Device-test Backup -> Restore round-trip explicitly, including with Android's scoped-storage restrictions on newer versions |

## 13. Production Readiness Score

Split, because "one number" would hide the real situation:

- **Static code quality: high confidence.** Zero missing imports,
  zero unused imports, zero dead code, zero memory leaks, zero
  `ServiceLocator` mismatches, zero unguarded logging, zero direct
  SQL outside the repository layer, zero SQL in UI, consistent
  Provider watch/read discipline, consistent `FutureBuilder` caching.
  Four sprints of cumulative static discipline plus this sprint's
  deeper pass found nothing left to fix.
- **Runtime-verified readiness: cannot score.** Not "low" — genuinely
  unmeasured. No build has ever succeeded or failed in a way that's
  observable from this sandbox. Assigning any numeric score here
  (even a cautious one) would imply a confidence level that doesn't
  exist.

**Overall: not yet a Release Candidate**, specifically and only
because Section 1/2/7/10's real verification has never happened. The
codebase's static hygiene is in as good a state as static review can
put it.

## 14. Sprint Completion Report

### Files changed this sprint

**None.** This sprint's audit found no defects requiring a fix — a
different outcome from SPR-DEP-010 (which found and fixed two real
bugs), reported honestly rather than manufacturing changes to appear
active. ~13,400 lines across 96 `lib/` files re-read and
cross-checked; 0 issues found beyond what SPR-DEP-010 already fixed.

### Self Review

- OK **Zero Critical Bugs** / OK **Zero High Severity Bugs** — none
  found this sprint (see Section 1/8).
- NOT CONFIRMED **Flutter Analyze Clean** — no real analyzer run
  exists to confirm against (Section 1).
- NOT CONFIRMED **Flutter Test Pass** — no real test run exists
  (Section 2).
- NOT CONFIRMED **Widget Tests Pass** / **Engine Tests Pass** /
  **Repository Tests Pass** — same basis; written and logically
  traced, never executed.
- NOT CONFIRMED **Navigation Stable** / **Image Analysis Stable** /
  **Recommendation Stable** / **Trial Workflow Stable** / **Backup
  Restore Stable** — all traced by code review (Section 10), none
  device-verified.
- NOT CONFIRMED **Release Candidate Ready** — see Section 13.

## Ready For Approval

**This sprint's audit work is complete**: a genuinely deeper static
pass than SPR-DEP-010, covering categories not previously checked
(unused imports, dead code, leaks, DI consistency), with real,
specific findings (all clean) rather than a repeat of the same
surface checks. **The application itself is not yet a Release
Candidate** — that determination requires the Section 1/2/7/10 real
verification, which needs a Flutter SDK this sandbox has never had.
Per the Stop Rule, not continuing to SPR-DEP-012 until you approve.
