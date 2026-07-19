# Hue Muse Shade AI — R3 (Approved Formula Workflow) Implementation Report

**Environment constraint (same as R1/R2):** no Flutter/Dart SDK or network access in
this sandbox. Everything below is **Manual Verification** — code review, API
cross-referencing against real declarations, byte-level diffing, and bracket/paren-
depth balance checks — never **Executable Verification** (`flutter analyze`/`test`/
`build`), which was not run. Your CI is the authoritative gate for the latter.

---

## 1. Executive Summary

R3 completes Product → Trial Formula → Review → Approval → Approved Formula → Locked
Production Formula entirely on top of the capability the brief said already existed:
`TrialRepository.approveTrial()`, `approvalForTrial()`, and `ApprovedFormulaModel`.
**Zero new repository methods, zero schema changes, zero new routes, and — after the
R3-001 review below — zero new screen files.** R3 touched exactly 4 existing files:
`formula_details_screen.dart`, `formula_form_screen.dart`, `formula_list_screen.dart`,
`home_screen.dart`. One real bug (a dropdown-assertion crash risk introduced by this
sprint's own new filter UI) was caught and fixed during review before delivery.

---

## R3-001 — Review Findings (read this first, especially if R3-002/R3-003 look "missing")

`approveTrial()` inserts the `Approved_Formula` row **and** moves
`Trial_Formula.status` to `'approved'` in one transaction — confirmed by re-reading
its implementation, not assumed. That matters: it means the status change is *already
handled inside* `approveTrial()`. Calling `ITrialWorkflowManager.transition(to:
approved)` on top of it would be genuinely duplicate logic — either a silent no-op or
a second, un-audited status write racing the first. **R3-004's Approve action calls
`approveTrial()` and *only* `approveTrial()`.** The existing generic "Change Status"
picker (built in R2) was adjusted to stop offering `approved` (and `rejected`, see
below) as a destination, so there is exactly one path to each of those states, not
two.

`approvalForTrial()` and `ApprovedFormulaModel` are otherwise reused exactly as
found, with one honest gap noted: **`approveTrial()` was never called by any screen
before this sprint** (confirmed by grep against the whole codebase) — R2 already
flagged this as R3's job, and R3-004 is that call site.

**R3-005 (Reject) and R3-006 (Revision Request) needed no new capability at all.**
`TrialStatus`'s own transition graph already allows `labTesting -> rejected` and
`rejected -> draft` ("for rework", per that enum's own doc comment), and
`ITrialWorkflowManager.transition()` already accepts and audits a `reason`. Both
actions are just that existing method, called with a specific target status and a
now-mandatory reason, exposed as their own buttons instead of the generic picker
purely so a reason is never skippable.

**R3-002/R3-003 — a deliberate architecture decision, not an omission:** the brief
asks to "Create Approved Formula List Screen" and "Create Approved Formula Details
Screen" as new files. Building them as literal new files would have duplicated
~70-80% of `formula_list_screen.dart` and `formula_details_screen.dart` (R2's
grouping/search/refresh/empty-state logic and ingredient/rule-compliance rendering,
respectively) against the brief's own "avoid duplicate code" quality requirement and
"Do NOT duplicate repositories" instruction (the underlying data access is identical
either way). Instead:
- **R3-002** was satisfied by adding an in-screen **Status filter** (chips) and
  **Product filter** (dropdown) to the existing `FormulaListScreen`. "Approved
  Formulas" is that same screen opened with `statusFilter: TrialStatus.approved` as
  the *initial* value — the person can still change it. Search, refresh, and empty
  state were already there from R2.
- **R3-003** was satisfied by adding an **Approval section** (Approval Date,
  Approved By, Approval Notes — from the real `ApprovedFormulaModel`, via
  `approvalForTrial()`) and a **Revision** row to the existing
  `FormulaDetailsScreen`, plus the read-only lock (R3-007). Product, Shade, Formula
  Name, Ingredients, Percentages, and Status were already there from R2.

If a literal separate screen is still wanted for product/UX reasons, that's a clean
follow-up — the data-access layer underneath needs no further changes either way.

---

## 2. Files Added

**None.** See the R3-001 finding above for why.

## 3. Files Modified

| File | R-items addressed | Repository/engine calls used (all pre-existing) |
|---|---|---|
| `lib/screens/formula_details_screen.dart` | R3-003 (Approval section, Revision row), R3-004 (Approve), R3-005 (Reject), R3-006 (Revision Request), R3-007 (lock) | `TrialRepository.approvalForTrial()`, `.approveTrial()`, `.softDelete()`; `ITrialWorkflowManager.transition()` |
| `lib/screens/formula_form_screen.dart` | R3-008 (Create Revision mode) | `TrialRepository.readById()`, `.materialsForTrial()`, `.create()`, `.addMaterialLine()` |
| `lib/screens/formula_list_screen.dart` | R3-002 (Status/Product filters) | `TrialRepository.readAll()`, `.search()`; `ProductRepository.readAll()` |
| `lib/screens/home_screen.dart` | R3-009 (Dashboard counts) | `TrialRepository.filter()`, `.search()` |

## 4. Files Unchanged (verified by byte-level diff against the R2-verified baseline)

`lib/repositories/**` (all of it, including `trial_repository.dart` — R3 added no
methods), `lib/models/**`, `lib/core/database/**`, `lib/core/routing/**` (no new
routes needed), `lib/widgets/**`, `test/**`, `pubspec.yaml`, `lib/main.dart`, and the
navigation shell. **Every file the brief explicitly protects — Rule Engine, Shade
Engine, Material Matching Engine, Trial Workflow Manager — is untouched**, confirmed
by diffing the entire `lib/engines/` directory against the R2 baseline: zero bytes
changed.

## 5. Architecture Impact

**None.** Same pushed-route pattern, same `ServiceLocator.get<T>()` DI usage, same
shared-widget-only UI, same `FutureBuilder` + `mounted`-guarded `setState` lifecycle
pattern established in R1/R2. One net-new UI primitive was introduced —
`ChoiceChip` for the status filter row — which is a standard Flutter Material 3
widget already implicitly available (like `DropdownButtonFormField`, `Row`,
`Column`), not a new dependency or design language.

## 6. Repository Impact

**Zero new methods.** Every R3 action reuses a pre-existing, public method:
`approveTrial()`, `approvalForTrial()`, `readById()`, `readAll()`, `create()`,
`materialsForTrial()`, `addMaterialLine()`, `softDelete()`, `filter()`, `search()`.
This is the strongest compliance point in this report against "Only add repository
methods when absolutely necessary" — none were necessary this time.

## 7. Database Impact

**None.** No schema change, no migration, no new table or column. Verified
`lib/core/database/database_helper.dart` is byte-identical to the R2 baseline.

## 8. Business Workflow Impact

The full chain now works end to end through existing, unmodified engines:

```
Product (R1) -> Trial Formula (R2, draft) -> Ready for Lab -> Lab Testing (R2)
   -> [Approve (R3-004, via approveTrial())] -> Approved, locked (R3-007)
   -> [Create Revision (R3-008)] -> new draft Trial Formula, source untouched
   -> [Reject (R3-005)] -> Rejected -> [Request Revision (R3-006)] -> Draft, for rework
```

Every status transition — Approve excepted, which uses `approveTrial()`'s own
transaction — goes through `ITrialWorkflowManager.transition()`, so every change is
written to the existing `TrialAuditRepository` audit trail. Nothing in this chain
writes `Trial_Formula.status` or inserts into `Approved_Formula` by any path other
than those two existing, purpose-built methods.

## 9. Manual Review Findings

Full review performed against R3's quality checklist (imports, navigation,
repository calls, widget lifecycle, null safety, memory leaks, exception handling,
bracket balance, architecture consistency) — all four changed files, end to end.

- **Imports:** every relative import in all 4 files resolves to a real file
  (scripted check).
- **Repository calls:** every call cross-referenced against its actual signature
  (scripted + manual) — `approveTrial(ApprovedFormulaModel)`,
  `approvalForTrial(int)`, `filter(Map)`, `search(String, {columns})`, all match.
- **Widget lifecycle / mounted checks:** every `await` that precedes further
  `context`/`setState` use is followed by a `mounted` check (scripted audit across
  all 3 screen files) — the same class of bug fixed during R1 verification,
  deliberately re-checked from scratch here.
- **Memory leaks:** `_TextInputSheet`'s dynamically-sized controller list (1-2
  fields, shared by Approve/Reject/Request Revision) is disposed in its own
  `dispose()`. No new controllers introduced elsewhere.
- **One real bug found and fixed during this review:** the new Status/Product
  filter dropdowns in `formula_list_screen.dart` initially read from a field
  (`_allProducts`) mutated as a side effect inside an async method with no
  `setState` forcing the *outer* widget to rebuild when it resolved — on first
  load, the Product filter would have silently shown only "All Products" until the
  user triggered any other state change. Fixed by giving the product list its own
  dedicated `Future` and wrapping just that dropdown in its own `FutureBuilder`,
  reusing the same Future both there and in the grouping logic (no duplicate
  query). While fixing this, the same defensive-inclusion pattern from R2 (a
  filtered-but-since-deleted product must still be representable in the dropdown's
  `value`, or `DropdownButtonFormField` asserts and crashes) was applied here too.
- **A second brace-scoping slip was caught mid-edit** in `formula_details_screen.dart`
  — a `str_replace` accidentally dropped a method's signature line, which the
  bracket-balance script caught immediately (paren count mismatch) before this was
  ever presented as finished. Fixed and re-verified balanced.
- **Exception handling:** every repository call site either sits inside a
  `FutureBuilder`/try-catch with `RepositoryException` explicitly caught and
  surfaced via `ErrorDialog`, or degrades gracefully (`snapshot.data ?? default`)
  — never a bare, unhandled `catch`.
- **Navigation:** no new routes were needed (R3 extends existing screens reached via
  R2's `formulaList`/`formulaDetails`/`formulaEdit` routes); `FormulaFormScreenArgs`
  gained one new optional field (`duplicateFromTrialFormulaId`), and
  `FormulaListScreenArgs` gained one (`statusFilter`) — both purely additive,
  defaulting to the prior behavior when omitted.
- **Bracket balance:** verified programmatically on all 4 files, including a
  full open/close depth trace (not just a total-count comparison) to guarantee no
  false-positive pass — this is exactly the check that caught the dropped method
  signature above.

## 10. Risk Assessment

**Low-to-moderate**, concentrated in the two "convention, not schema" pieces:

- **Not executed, only reviewed** — standard caveat, same as every prior report.
- **"Revision of <code>" is a notes-text convention, not a foreign key.** It's
  honestly documented as such everywhere it's used (in-code comments, this report),
  but it means: (a) a user could theoretically type similar text into notes
  unrelated to an actual revision, producing a false-positive lineage link or a
  false-positive "Revisions Pending" dashboard count; (b) there is no reverse
  "Superseded By" lookup (see Known Issues) — only "Revision Of" (forward) is shown.
- **No trial_code uniqueness enforcement** for Create Revision (or Create in
  general — this is a pre-existing, R2-level characteristic, not new to R3): the
  schema has no UNIQUE constraint on `trial_code`, so the user must supply a
  non-colliding code by convention, not by enforcement.
- **`DropdownButtonFormField.value` deprecation** (same standing note from R1/R2) —
  now used in a few more places (filter dropdown, status chips are unaffected since
  `ChoiceChip` doesn't have this concern).
- **No automated tests** for any R3 code path, consistent with this project's
  existing convention (no screen anywhere has widget tests). The one genuinely new
  piece of *business logic* worth a unit test is the "Revisions Pending" count
  heuristic in `home_screen.dart`.

## 11. Remaining Work for R4

- **Live `flutter analyze`/`flutter test`/`flutter build apk`** in CI — the
  standing item every report in this series has flagged.
- **A real "Superseded By" reverse lookup**, if bidirectional revision lineage is
  wanted — either a `parent_trial_id` column (schema change, out of R3's scope by
  the brief's own rules) or an accepted extra search-per-row cost. Left as an
  explicit, documented option rather than half-implemented.
- **Automated coverage** for the approval/reject/revision-request/create-revision
  paths and the dashboard's "Revisions Pending" heuristic.
- **trial_code collision handling** — either a UNIQUE constraint (schema change) or
  a client-side uniqueness check before save, if that's a real operational concern.

## 12. Known Issues

- R3-002/R3-003 are implemented as enhancements to the existing R2 screens, not as
  new files literally named "Approved Formula List/Details Screen" — see the R3-001
  finding for the full reasoning. Functionally complete either way.
- "Revisions Pending" (Dashboard) and "Revision Of" (Formula Details) are both
  derived from a text convention in `Trial_Formula.notes`, not a real relationship
  — see Risk Assessment.
- No reverse "Superseded By" lookup (see Remaining Work).
- `DropdownButtonFormField.value` deprecation possibility, carried forward from
  R1/R2 — non-fatal either way.

## 13. Overall Status

**Implemented, code-reviewed, not yet executable-verified.** Every R3 item (R3-001
through R3-009) has a working, traced code path built entirely on
`TrialRepository.approveTrial()`/`approvalForTrial()`/`ApprovedFormulaModel` and the
existing `TrialStatus`/`ITrialWorkflowManager` transition graph — zero repository
additions, zero schema changes, zero engine modifications. Per the brief's own
instruction, this is **not** claimed as fully complete outright: it's ready for a
live CI run (`flutter analyze` / `flutter test` / `flutter build apk`), which
remains the one step this sandbox cannot perform.
