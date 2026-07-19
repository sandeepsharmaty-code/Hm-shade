# Hue Muse Shade AI — R2 (Formula Workflow) Implementation Report

**Environment constraint (same as R1):** this sandbox has no Flutter/Dart SDK and no
network access. `flutter analyze` / `flutter test` / `flutter build apk` could not be
executed here. Everything below is verified through manual code review, static
cross-referencing of every symbol against its real declaration, byte-level diffing,
and bracket-balance checks — not by running the toolchain. Your CI
(`.github/workflows/flutter_release.yml`) is the authoritative gate; nothing here
should be read as a substitute for a green CI run.

---

## R2-001 — Review Findings (read this first)

The brief asks to review "current FormulaModel, TrialFormulaModel and repositories."
**There is no `FormulaModel` or `FormulaRepository` in this codebase, and R2 does not
add one.** What the brief calls a "Formula" already exists, fully built, as three
things working together:

| Brief's term | Actual codebase entity | Repository |
|---|---|---|
| Formula (header: name, status, notes) | `TrialFormulaModel` (`Trial_Formula` table) | `TrialRepository` (standard CRUD via `BaseSqliteRepository`) |
| Ingredients + Percentages | `FormulaMaterialModel` (`Formula_Material` table) | `TrialRepository.addMaterialLine/materialsForTrial/removeMaterialLine` (documented in both models as a deliberate "child entity, no independent repository" pattern) |
| Approval record | `ApprovedFormulaModel` (`Approved_Formula` table) | `TrialRepository.approveTrial/approvalForTrial` |

Creating a separate `FormulaModel`/`FormulaRepository` would have duplicated this
exact logic and violated "Do NOT create duplicate repositories." Instead, every R2
screen builds directly on `TrialRepository`. This finding is also documented in-code
in each new screen's header comment.

**Also found during this review — one genuine gap:** `Formula_Material` had
`addMaterialLine()` and `removeMaterialLine()` but no way to *update* an existing
line in place. Editing a formula's ingredient percentage would otherwise require
removing and re-adding the line, discarding its `id`/`created_at`. See "Repository
Impact" below.

---

## 1. Files Added

| File | Purpose |
|---|---|
| `lib/screens/formula_list_screen.dart` | Formula List (R2-002): formulas grouped by product, search, refresh, empty state, optional single-product filter (R2-008) |
| `lib/screens/formula_details_screen.dart` | Formula Details (R2-003): product, shade, name, ingredients + percentages with per-line Rule Compliance (R2-009), notes, status, version/revision history, edit/status-change/archive/delete actions |
| `lib/screens/formula_form_screen.dart` | Create (R2-004) and Edit (R2-005) in one screen, plus the dynamic ingredients editor |

## 2. Files Modified

| File | Change | Why |
|---|---|---|
| `lib/repositories/trial_repository.dart` | Added `updateMaterialLine()` | The one repository change in R2 — see "Repository Impact" |
| `lib/core/routing/app_routes.dart` | Added `formulaList`, `formulaDetails`, `formulaEdit` route constants | Same push-not-tab pattern as `trial`/`productManagement` |
| `lib/core/routing/app_router.dart` | Dispatch the three new routes | — |
| `lib/screens/home_screen.dart` | Added a "Formulas" quick action | Entry point to Formula List (all formulas) |
| `lib/screens/product_management_screen.dart` | Added a "View Formulas" icon button per product row | R2-008 entry point (existing tap-to-edit behavior unchanged) |

## 3. Files Unchanged (verified by byte-level diff against the R1-verified baseline)

`lib/models/**`, `lib/core/database/**`, `lib/widgets/**`, `test/**`, `pubspec.yaml`,
`lib/main.dart`, `lib/engines/**` (Rule Engine, Shade Engine, Material Matching
Engine, Trial Workflow Manager, Trial Validation Engine — all of it), the navigation
shell (`root_shell_screen.dart`, `app_bottom_nav.dart`, `navigation_provider.dart`),
and every other repository (`ProductRepository`, `ShadeRepository`, the six
raw-material repositories, `RuleRepository`, etc.). Confirmed with `diff -rq`
against the delivered R1 zip — zero collateral changes.

## 4. Architecture Impact

**None.** No new architectural layer, no new state-management approach, no new
design language. Every screen follows the exact patterns already established in R1
(`ProductManagementScreen`) and the pre-existing `TrialScreen`:
- Pushed routes, not shell tabs (5-tab shell frozen).
- `ServiceLocator.instance.get<T>()` for every repository/engine — never
  constructed directly.
- Shared widgets only (`AppCard`, `AppButton`, `AppTextField`, `LoadingView`,
  `SearchBox`, `ConfirmationDialog`, `ErrorDialog`) — no new widget primitives.
- `FutureBuilder` + `mounted`-guarded `setState` for all async UI state, matching
  the lifecycle-safety pattern fixed during R1 verification.
- Status changes go through the existing `ITrialWorkflowManager.transition()` —
  the Formula workflow never writes `Trial_Formula.status` directly, so it never
  bypasses the existing audit trail.
- Rule compliance is shown by calling the existing `IMaterialMatchingEngine
  .matchMaterial()` per ingredient line (R2-009) — Rule Engine, Shade Engine, and
  Material Matching Engine source code is untouched (confirmed by diff).

## 5. Repository Impact

**One method added, nothing else touched.** `TrialRepository.updateMaterialLine()`:
- Mirrors `addMaterialLine()`'s exact shape (same table constant, same
  try/catch/`RepositoryException` pattern).
- Required because Edit Formula needs to correct an ingredient line's percentage/
  notes in place. The only alternative — `removeMaterialLine()` +
  `addMaterialLine()` — would silently discard the line's `id` and `created_at`
  instead of preserving them, which is a worse outcome than one small additive
  method.
- No other method in `TrialRepository`, and no other repository file, changed.
- All new screens otherwise use only pre-existing, public repository methods:
  `create()`, `readAll()`, `readById()`, `update()`, `softDelete()`, `search()`,
  `filter()` (used indirectly via `ShadeRepository.findByProduct()`),
  `materialsForTrial()`, `addMaterialLine()`, `removeMaterialLine()`.

## 6. Database Impact

**None.** No schema change, no migration, no new table, no new column. Confirmed
`lib/core/database/database_helper.dart` is byte-identical to the R1 baseline.

## 7. Manual Review Findings

Full review performed against R2's quality checklist (imports, null safety, widget
lifecycle, memory leaks, repository usage, exception handling, navigation, build
consistency). Everything below was checked by direct inspection since `flutter
analyze` could not run:

- **Imports:** every relative import in all 8 touched/added files resolves to a
  real file (scripted check, zero misses).
- **API signatures:** every repository/engine method call and every shared-widget
  constructor call cross-referenced against its actual declaration — all match.
- **Null safety:** every nullable dereference is guarded (form validation makes
  the few `!` uses provably safe at the point they're used).
- **Widget lifecycle:** every `await` that precedes further `context`/`setState`
  use is followed by a `mounted` check (scripted check across all three new
  screens) — this is the exact class of bug found and fixed during R1
  verification, deliberately re-checked here from the start.
- **Memory leaks:** every `TextEditingController` (main form fields, and each
  dynamically-added ingredient line's controllers) is disposed — in
  `FormulaFormScreen.dispose()` for the form-level ones, and individually when a
  line is removed or replaced, not just at final widget disposal.
- **Two additional bugs found and fixed during this review, before delivery:**
  1. A `DropdownButtonFormField` assertion-crash risk: if a formula's linked
     product, shade, or an ingredient's material had been soft-deleted after the
     formula was created, editing that formula would have crashed (Flutter
     asserts a dropdown's current value must appear in its item list). Fixed by
     defensively including the currently-selected-but-inactive record in each
     dropdown's options, for products, shades, and materials.
  2. Two risky/unverifiable patterns were removed before they could cause
     problems: `firstOrNull` (an extension from `package:collection`, which isn't
     a declared dependency — replaced with plain null-safe loops) and `PopScope
     .onPopInvokedWithResult` (a newer Flutter API I couldn't verify is available
     on whatever SDK version CI's floating `stable` channel resolves to — removed
     entirely in favor of the existing in-form Cancel-button-with-confirmation,
     which needs no such API).
- **Exception handling:** every repository call site either sits inside a
  `FutureBuilder` (implicit `hasError` handling) or explicitly catches
  `RepositoryException` and surfaces it via `ErrorDialog` — never a bare `catch`.
- **Navigation:** all three new routes registered in both `AppRoutes` and
  `AppRouter`; `AppRouter`'s switch-case bodies that declare a local `args`
  variable were wrapped in explicit `{}` blocks to remove any ambiguity about
  per-case variable scoping (couldn't verify against a live compiler here, so
  chose the unambiguous form).
- **Build consistency:** bracket/brace/paren balance verified programmatically on
  every touched file; byte-diff confirms no unrelated file was touched.

## 8. Risk Assessment

**Low-to-moderate**, mostly concentrated in `formula_form_screen.dart` since it's
the most complex new file (dynamic ingredient editor, three dropdowns with
defensive-inclusion logic). Specific residual risks:

- **Not executed, only reviewed.** The standard caveat: nothing here replaces an
  actual `flutter analyze`/`flutter test`/`flutter build apk` run.
- **`DropdownButtonFormField.value` deprecation** (same note as the R1 report) —
  used in four more places here (Product, Shade, Material Type, Material
  dropdowns). Still just a possible warning, not an error, on newer Flutter
  versions.
- **No automated tests added** for the three new screens, consistent with this
  project's existing convention (no other screen has widget tests either — only
  models/repositories/engines do). `TrialRepository.updateMaterialLine()` is the
  one piece of new *repository* logic and currently has no unit test alongside
  it, unlike every other `TrialRepository` method exercised in
  `product_repository_test.dart`'s sibling coverage. Recommend adding one.
- **Percentage total is informational only** — the UI shows the ingredient
  percentage sum but doesn't block saving if it isn't ~100%. This was a
  deliberate choice (draft formulas may legitimately be incomplete) rather than
  an oversight, but worth confirming matches actual lab workflow expectations.

## 9. Remaining Work for R3

- **`TrialRepository.approveTrial()` is still never called by any screen** — this
  predates R2 (confirmed: it was unused in the codebase before this sprint too,
  only `approvalForTrial()` — the read side — is consumed internally by
  `FormulaRecommendationEngine`). Moving a formula's status to "Approved" via
  Formula Details' generic status picker updates `Trial_Formula.status` (audited)
  but does **not** create a formal `Approved_Formula` record (approver name,
  approval notes). A dedicated "Approve Formula" action wired to the existing
  `approveTrial()` would be a natural, low-risk R3 addition — the repository
  method already exists and needs no further change.
- **No widget/integration tests** for the R1 or R2 screens yet (see Risk
  Assessment). Recommend at minimum a unit test for
  `TrialRepository.updateMaterialLine()` alongside the existing
  `addMaterialLine`/`removeMaterialLine` coverage pattern.
- **Live `flutter analyze`/`flutter test`/`flutter build apk`** run in CI, per the
  standing caveat above.

## Overall Status

**Implemented, code-reviewed, not yet executable-verified.** Every R2 feature
(R2-002 through R2-009) has a working, traced code path built entirely on existing
repositories/engines, with one narrowly-scoped repository addition. Per the brief's
own instruction, this is **not** being marked complete outright — it's ready for a
live CI run, which is the remaining step before R2 can be closed the same way R1
was.
