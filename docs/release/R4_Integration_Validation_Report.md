# Hue Muse Shade AI — R4 (End-to-End Integration & System Validation) Report

**Environment constraint (same as R1-R3):** no Flutter/Dart SDK or network access in
this sandbox. `flutter analyze`, `flutter test`, and `flutter build apk` were **NOT
executed**. Every finding below is **Manual Verification** — full code tracing,
cross-referencing repository/engine signatures against their real implementations,
scripted bracket-balance and pattern sweeps across all 100 Dart files, and byte-level
diffing — labeled as such throughout, never presented as an executable-test result.

**Headline: R4 made zero code changes.** This sprint's mission was integration,
validation, and stabilization, not new features. Everything found was either
confirmed working-as-designed or a genuine gap that would require new features to
fix (out of R4's explicit scope) — so rather than quietly patch around that boundary,
every such gap is documented plainly below instead.

---

## 1. Executive Summary

The Product → Trial Formula → Lab → Approval → Approved Formula → Dashboard → Search
chain built across R1-R3 is internally sound: every repository call, status
transition, and dashboard count traces correctly to its source data, with no
duplicate logic, no orphan-record risk, and no bracket/import/lifecycle defects found
anywhere in the 100-file codebase. **However, the full workflow as literally
described in R4-001 cannot be exercised end-to-end starting from an empty database**,
because two upstream steps — Create Shade and Add/Manage Raw Materials — have no UI
implementation anywhere in R1, R2, or R3, and no seed data fills the gap. This is the
single most important finding in this report; see R4-001 below.

---

## 2. End-to-End Workflow Results (R4-001)

Traced step by step against actual code, not assumed:

| Step | Status | Evidence |
|---|---|---|
| Create Product | ✅ Works | `ProductManagementScreen` → `ProductRepository.create()` (R1) |
| **Create Shade** | ❌ **BREAK** | **No screen anywhere calls `ShadeRepository.create()`.** Confirmed by grepping the entire `lib/` tree — the only `ShadeRepository` usages are reads (`findByProduct`, `readById`, `search`, `count`, `filter`). `new_shade_screen.dart` only *classifies* a shade family from an image; it never persists a `ShadeModel`. No seed data exists either (`assets/` is empty except `.gitkeep`; `database_helper.dart`'s only seed routine populates the Rule table, not `Shade_Master`). |
| Create Trial Formula | ⚠️ Works, but degraded | `FormulaFormScreen` (R2) works correctly, but its Shade dropdown will always be empty for a product with no pre-existing Shade rows — a direct consequence of the break above. Product selection and Notes/Trial Code work fully. |
| **Add Materials** | ❌ **BREAK** | Same pattern as Shade: none of the six raw-material repositories (`Pigment/Dye/Mica/Pearl/Filler/BinderRepository`) has a `.create()` call anywhere in `lib/screens/`. They're only read (search, and the ingredient-picker dropdowns in `FormulaFormScreen`). No seed data. The ingredient dropdown in "Add Ingredient" will be empty on a fresh install. |
| Run Rule Validation | ⚠️ Partial | Per-ingredient Rule Compliance (via `IMaterialMatchingEngine.matchMaterial()`) is shown on Formula Details (R2/R3) for *any* formula, manual or AI-generated. A holistic formula-level validation pass (`ITrialValidationEngine.validate()`) exists but requires a `FormulaRecommendation`, which only the AI "New Shade" pipeline produces — it's not reachable for a manually-created formula. This is a pre-existing architecture characteristic (the engine was built for AI-candidate ranking), not something R1-R3 broke. |
| Lab Testing | ✅ Works | Formula Details' "Change Status" → `ITrialWorkflowManager.transition()` (R2), audited. |
| Approve Formula | ✅ Works | Formula Details' dedicated "Approve" → `TrialRepository.approveTrial()` (R3), confirmed to both write the approval record and flip status atomically. |
| Approved Formula | ✅ Works | Locked/read-only per R3-007; Approval section (date/by/notes) renders from the real `ApprovedFormulaModel`. |
| Dashboard Updated | ✅ Works | Traced the full return-navigation chain (Details → List → Home) — each screen calls its own `_refresh()` when the pushed route it opened returns, so the Home dashboard is guaranteed current by the time the user is back on it. See R4-002. |
| Search Updated | ✅ Works | `SearchScreen`'s "Formulas" category searches `TrialRepository.search()` with no status filter, so approved formulas appear automatically — no special-casing needed or found. See R4-003. |

**Practical impact:** the chain is fully exercisable *only* if Shade and raw-material
data already exists in the database by some means outside this app (direct SQLite
manipulation, a future import feature, etc.). Through the shipped UI alone, a fresh
install cannot progress past "Create Product" for the literal Product → Shade →
Formula → Materials sequence. This does not affect the *AI-generated* New Shade path
(image analysis → recommendation engine), which doesn't require pre-existing Shade
rows — only the manual Formula workflow (R2/R3) is affected.

---

## 3. Dashboard Verification (R4-002)

Traced every stat card's query against `BaseSqliteRepository`'s actual
implementations (not assumed):

| Stat | Query | Verified semantics |
|---|---|---|
| Products | `ProductRepository.count()` | Active-only by default (confirmed in `base_repository.dart`) — matches what Product Management's list shows |
| Shades | `ShadeRepository.count()` | Same active-only default |
| Pending | `filter({status: readyForLab})` + `filter({status: labTesting})` | `filter()` is **always** active-only (no override) — confirmed by reading its implementation |
| Approved | `filter({status: approved})` | Same |
| Awaiting Approval | `filter({status: labTesting})` (reused, not a duplicate query) | Same |
| Rejected | `filter({status: rejected})` | Same |
| Revisions Pending | `search('Revision of', columns: ['notes'])`, narrowed to `status == draft` client-side | `search()` is also always active-only |

**All counts are active-only, consistently.** A soft-deleted formula never inflates
any dashboard number. One consistency property worth noting: since R3 hides the
Delete button for approved/locked formulas, an approved formula can only ever become
inactive by... it can't — Archive keeps `is_active = 1`. So "Approved" is monotonic
in the sense that it never silently drops due to accidental deletion.

## 4. Search Verification (R4-003)

- **Products, Shades, Formulas** (including approved ones), **Materials** (fanned
  out across all 6 tables): all confirmed working, all delegate to the matching
  repository's `search()` — nothing hand-rolled.
- **Approved Formulas** specifically: confirmed reachable through the existing
  "Formulas" category — approved formulas are still `Trial_Formula` rows, so
  `TrialRepository.search()` returns them with no special-casing. The result row's
  subtitle (`'${trialCode} · ${status}'`) shows the status directly.
- **No duplicate search logic found.** Grepped for hand-rolled `.toLowerCase()
  .contains(query)`-style filtering outside the repository layer — the only hits are
  unrelated internal keyword classification in `trial_validation_engine.dart` and
  `recommendation_conflict_detector.dart` (pre-existing, not user-facing search).
- Knowledge Base search is verified separately below (R4-004) since it's a distinct
  screen/repository.

## 5. Knowledge Base Verification (R4-004)

- **Loading:** `LoadingView` while `snapshot.connectionState != done`, consistent
  with every other screen in the app.
- **Navigation:** 4-tab `DefaultTabController` (Knowledge, Approved Formulas, Rules,
  Recent Updates) — confirmed all 4 tabs render and switch correctly by reading
  `TabBarView`'s children list against the `TabBar`'s tabs list (matched 1:1).
- **Error handling:** uses `.catchError((_) => const <T>[])` directly on each
  Future in `initState()`, rather than the `on RepositoryException` pattern used
  elsewhere in R1-R3. This is **functionally safe** (never crashes, degrades to an
  empty list either way) but **stylistically inconsistent** — flagged as a Known
  Issue, not fixed (this file predates R1 and wasn't touched by R1-R3; "fixing"
  house-style here would be exactly the kind of unrelated-file edit R4's rules
  prohibit).
- **Minor pre-existing gap found:** the "Approved Formulas" tab's rows have no
  `onTap` — tapping one does nothing, unlike the equivalent row in R3's
  `FormulaListScreen` (which navigates to Formula Details). This predates R1-R3
  (from SPR-DEP-009) and is a minor UX inconsistency, not a crash or data issue.
  Documented as a Known Issue / R5 candidate, not fixed here.
- **Search:** the Knowledge Base's own records are searchable via the main
  `SearchScreen`'s "Knowledge" category (`KnowledgeRepository.searchEntries()`),
  confirmed distinct from and not duplicating the tab-based browsing here.

## 6. Rule Engine Verification (R4-005)

**Not modified** — read-only review, confirmed by diff against every prior
baseline (zero bytes changed in `lib/engines/` across R1→R4).

- **Input:** `evaluate({required RuleType ruleType, required Map<String, Object?>
  facts})` — a generic facts map, dispatched by rule type.
- **Output:** `RuleResult` — `success`, `confidenceScore` (weighted average,
  clamped 0.0-1.0), `matchedRules`/`failedRules`, `alternativeSuggestions`,
  `reasonMessages`. Confirmed by reading the actual weighting computation, not
  assumed.
- **Confidence:** computed as `matchedWeight / totalAbsoluteWeight`, clamped —
  verified this can never exceed 1.0 or go negative.
- **Recommendations:** `alternativeSuggestions` populated specifically for
  `RuleType.alternativeMaterial` matches.
- **Error handling:** wraps its repository call in `try`/`on RepositoryException`,
  logs via `logDebug`, and returns a graceful failure `RuleResult` (never rethrows,
  never crashes) — confirmed by reading the catch block directly.

## 7. Material Matching Verification (R4-006)

**Not modified** — same zero-byte-diff confirmation as the Rule Engine.

- **Matching:** `matchMaterial({materialTable, materialId})` dispatches to the
  correct one of six repositories via typed function references (`_MaterialReader`/
  `_MaterialLister` typedefs), not dynamic calls — confirmed this avoids any
  runtime type-dispatch risk.
- **Alternatives:** sourced from `RuleResult.alternativeSuggestions`, not
  recomputed or duplicated in this engine.
- **Compatibility:** delegated entirely to `RuleEngine.evaluate()` — this engine
  does no rule logic of its own, confirmed by its own header comment ("Approval/
  rejection scoring comes from RuleEngine's rule types, not hardcoded here").
- **Repository interaction:** read-only (`readById`), consistent with every other
  engine in this codebase — no write paths found.
- R2/R3's Formula Details screen consumes this engine's result directly per
  ingredient line (R2-009's "consume existing rule results" requirement),
  re-confirmed correct on this pass.

## 8. Navigation Audit (R4-007)

Cross-checked every `AppRoutes` constant against every `case` in `AppRouter` and
every actual `pushNamed()` call site in the app (not just a visual scan — scripted).

- **All 7 live routes** (`splash`, `shell`, `productManagement`, `formulaList`,
  `formulaDetails`, `formulaEdit`, `trial`) have a matching `case` and are correctly
  targeted by every `pushNamed()` call found in the codebase. **No broken navigation
  in practice.**
- **Two dead route constants found:** `AppRoutes.newShadeCapture` and
  `AppRoutes.knowledgeBaseDetail` are declared but have **no `case` in `AppRouter`
  and no caller anywhere** — confirmed by grep, not a single reference outside their
  own declaration. Harmless (nothing ever navigates to them, so the "unknown route"
  fallback screen is never actually hit), but dead code. Flagged for R4-011 /
  cleanup, not removed here per "Do NOT redesign."
- **Mapping the brief's R4-007 list to actual reachability** — Home/Knowledge/
  Search/Settings are shell tabs; Product/Formula/Trial are reached by push from
  Home or from within those screens; "Approval" has no separate destination by
  design (folded into Formula Details in R3, documented in that sprint's report).
  All 8 conceptual areas are reachable; not all are top-level tabs, which is a
  deliberate, previously-documented architecture decision (SPR-DEP-002's frozen
  5-tab shell), not a gap.

## 9. Data Consistency Audit (R4-008)

- **Soft delete never cascades** — confirmed by reading `BaseSqliteRepository
  .softDelete()` directly: it's a single-table `UPDATE ... SET is_active = 0`, full
  stop. No trigger, no cascade, anywhere in the schema (SQLite triggers would show
  up in `database_helper.dart`'s `onCreate`; none exist for this purpose).
- **No orphan records are possible in the destructive sense**, because nothing is
  ever hard-deleted. Deleting a Product doesn't remove its Shades/Formulas; deleting
  a Formula doesn't remove its Formula_Material lines or audit history — they
  simply stay in the database, readable by id, just excluded from default
  active-only list views. This matches the Delete confirmation dialog's own text in
  R2/R3 ("ingredient lines and audit history are kept").
  - Reads that resolve one specific record by id (`readById`) accept an
    `includeInactive` override used specifically for this — confirmed this is
    exactly how R2/R3's dropdowns avoid crashing when a referenced product/shade/
    material has since been soft-deleted (the defensive-inclusion pattern from R2's
    verification pass, re-applied consistently through R3).
- **R3's approved-formula lock (hiding Delete) specifically prevents the one
  scenario that could have produced a dangling reference** — an `Approved_Formula`
  row pointing at a soft-deleted `Trial_Formula`. Traced this deliberately: without
  that lock, deleting an approved formula would leave its approval record
  orphaned in a referential sense (still readable, but pointing at a hidden
  parent). Confirms the R3 design decision was correct, not just convenient.
- **Model mapping:** spot-checked `toMap()`/`fromMap()` round-trips for
  `TrialFormulaModel`, `FormulaMaterialModel`, `ApprovedFormulaModel` against their
  repositories' usage — consistent with what R2/R3 already exercised extensively.

## 10. Error Handling Audit (R4-009)

- **RepositoryException:** every R1-R3 screen either explicitly catches it and
  shows `ErrorDialog`, or lets it surface through a `FutureBuilder`'s `hasError`
  (with a plain-language fallback message) — confirmed no bare/silent catches
  anywhere in `lib/screens/`.
  - The one stylistic outlier is Knowledge Base's `.catchError` (see R4-004) —
    functionally safe, not fixed.
- **Dialogs:** `ConfirmationDialog` used consistently before every destructive or
  state-changing action (Delete, Archive, Approve, Reject, Request Revision) across
  R1-R3.
- **Validation:** every form (Product, Formula, ingredient lines, the R3
  Approve/Reject/Request-Revision text sheets) uses a `Form` + `GlobalKey<FormState>`
  with field-level validators — no silent/unvalidated saves found.
- **Empty states:** every list screen (Product Management, Formula List, Search,
  Knowledge Base's 4 tabs) has an explicit, honest empty-state message — none show a
  blank screen or a spinner that never resolves.
- **Loading states:** `LoadingView` used consistently everywhere a `FutureBuilder`
  is in its non-done state — confirmed no screen skips this.

## 11. Performance Review (R4-010)

- **Repeated queries:** scripted a check for repository/engine calls made directly
  inside a `build()` method body — **zero found** across all screens. Every
  `FutureBuilder`'s `future:` parameter references a stored field, never an inline
  call, confirmed for all 17 `future:` usages in the codebase — so nothing
  re-queries on every rebuild.
- **Duplicate FutureBuilders:** the one place two `FutureBuilder`s exist close
  together is R3's `formula_list_screen.dart` (one for the product-filter dropdown,
  one for the grouped formula list) — deliberate, not redundant: they watch
  genuinely different data, and this exact split was the fix for a real bug found
  during R3's own review (a single shared future caused the dropdown to render
  stale on first load). Re-confirmed correct on this pass, not flagged as an issue.
- **Memory leaks / controller disposal:** cross-checked every `TextEditingController`
  declaration against its file's `dispose()` method for the three files with
  controllers (`product_management_screen.dart`, `formula_form_screen.dart`,
  `formula_details_screen.dart`) — all confirmed fully disposed, including
  per-line/per-sheet controllers created and destroyed dynamically. `SearchBox`'s
  own internal controller is also confirmed disposed.
- **Mounted checks:** re-ran the full await-then-context/setState audit across
  every screen with async handlers — consistent with the pattern established (and
  bug-fixed) in R1's verification pass; no new violations found.

## 12. Regression Audit (R4-012)

**R4 made zero code changes**, so this is close to a formality, but verified
properly rather than assumed: `diff -rq` against the R3-delivered baseline shows
**no differences anywhere in `lib/`** — R1, R2, and R3 are byte-for-byte unchanged.
The only new file is this report, added under `docs/release/`, matching the
convention established in R1-R3's own reports.

---

## 13. Files Modified

**None.**

## 14. Files Unchanged

**Everything.** The entire `lib/` tree is byte-identical to the R3-delivered state,
confirmed by diff.

## 15. Architecture Impact

**None** — no code was written this sprint.

## 16. Risk Assessment

- **High-priority, pre-existing (not introduced this sprint):** the Shade-creation
  and Material-creation gaps identified in R4-001 mean the manual Formula workflow
  is untestable end-to-end on a fresh database without external data population.
  This is the most operationally significant finding in this report.
- **Low:** the two dead route constants, Knowledge Base's stylistic error-handling
  inconsistency, and its non-tappable Approved Formulas rows — all cosmetic/
  cleanliness items with no crash or data-integrity risk.
- **Standing item, every report in this series:** nothing in this sandbox has been
  verified by actually running `flutter analyze`/`flutter test`/`flutter build apk`.

## 17. Remaining Work for R5

In priority order:

1. **Shade Management screen** — mirroring R1's Product Management pattern exactly
   (`ShadeRepository.create()`/`update()`/`softDelete()` already exist and are
   fully unused). This is the single highest-value R5 item; without it the Shade
   step of the core workflow has no UI.
2. **Raw Material Management** — same pattern, for the six material tables. Second
   highest-value item, for the same reason (Add Materials has no create UI).
3. Wire up the Knowledge Base's Approved Formulas tab to navigate to Formula
   Details (small, low-risk fix once someone is touching that file for other
   reasons).
4. Standardize Knowledge Base's error handling to the `on RepositoryException`
   pattern used elsewhere, for consistency (cosmetic).
5. Remove or wire up the two dead route constants (`newShadeCapture`,
   `knowledgeBaseDetail`) — confirm with whoever owns the roadmap whether they were
   meant for a feature that never shipped, or can simply be deleted.
6. All items already carried forward from R1-R3's own "Remaining Work" sections
   (live CI run, automated test coverage, the `DropdownButtonFormField.value`
   deprecation watch, `trial_code` uniqueness, the "Superseded By" reverse lookup).

## 18. Overall Status

**Integration verified, system stable, zero regressions — with one significant,
clearly-documented workflow gap that predates and falls outside R4's scope to fix.**
Every claim in this report is traceable to a specific code read, a specific grep, or
a specific script output — nothing here is asserted without the evidence shown
alongside it. Consistent with every report in this series: this is Manual
Verification only. `flutter analyze`, `flutter test`, and `flutter build apk` were
**not executed** in this environment and remain the outstanding step before any of
R1-R4 can be called fully, executably verified.
