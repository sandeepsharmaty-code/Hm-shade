# Hue Muse Shade AI — R5 (Missing Business Modules) Implementation Report

**Environment constraint (same as R1-R4):** no Flutter/Dart SDK or network access in
this sandbox. Everything below is **Manual Verification** — code review, API
cross-referencing against real declarations, scripted import-resolution and
bracket-balance sweeps across all 102 Dart files, and byte-level diffing. **Not**
**Executable Verification** — `flutter analyze`, `flutter test`, and
`flutter build apk` were not run. Per R5's own instruction, do not read anything
below as a substitute for that.

---

## 1. Executive Summary

R5 fills both gaps R4 found: Shade Management and Raw Material Management now exist,
built entirely on `ShadeRepository` and the six raw-material repositories — all
already fully capable (`create`/`update`/`softDelete`/`search`/`readAll`), just
never called by any screen before this sprint. Zero repository, engine, or schema
changes. Raw Material Management is genuinely one screen (not six), via a thin
per-table adapter pattern already precedented in R2's ingredient picker. Formula
Form (R5-D) and Search (R5-E) needed **no code changes at all** — both already read
through the same repositories these new screens now write to, confirmed by tracing
the actual call sites, not assumed. The Dashboard (R5-F) gained a Materials count.

Two field-mapping gaps were found identical in kind to R2/R3's "Version" gap
(brief-requested fields that don't exist in the frozen schema): Shade's
"Pantone"/"Coverage"/"Description" and Materials' "Colour"/"Notes"/"Status". Each is
handled the same honest way as before — closest real equivalent where one exists,
plainly documented omission where none does. See Known Issues.

---

## 2. Files Added

| File | Purpose |
|---|---|
| `lib/screens/shade_management_screen.dart` | R5-A: List/Add/Edit/Delete/Restore/Search/Filter-by-Product/Active-Inactive for Shade_Master |
| `lib/screens/material_management_screen.dart` | R5-B: ONE screen covering all six raw-material tables via a per-table adapter, not six screens |

## 3. Files Modified

| File | Change |
|---|---|
| `lib/core/routing/app_routes.dart` | Added `shadeManagement`, `materialManagement` route constants |
| `lib/core/routing/app_router.dart` | Dispatch for both new routes |
| `lib/screens/home_screen.dart` | R5-C: "Manage Shades"/"Manage Materials" quick actions. R5-F: added a Materials stat card (sum of all six repositories' `count()`); converted the top summary row from a fixed 3-card `Row` to a `Wrap` so a 4th card didn't need hand-tuned flex values |
| `lib/screens/product_management_screen.dart` | Added a "View Shades" icon button per product row, mirroring R2's "View Formulas" exactly |

## 4. Files Unchanged (verified by diff against the R4/R3 baseline)

Everything else — **all of** `lib/repositories/`, `lib/engines/`, `lib/models/`,
`lib/core/database/`, `test/`, `pubspec.yaml`, `lib/main.dart`, the navigation
shell, `lib/widgets/`, `search_screen.dart`, and all R2/R3 formula screens
(`formula_form_screen.dart`, `formula_details_screen.dart`,
`formula_list_screen.dart`). Confirmed byte-identical by `diff -rq` — this list is
not asserted, it's the direct output of that diff.

## 5. Architecture Impact

**None** — same pushed-route pattern, same `ServiceLocator.get<T>()` DI usage, same
shared-widget-only UI as every prior sprint. Raw Material Management's
adapter-per-table design isn't a new architectural layer — it's the exact shape R2's
`formula_form_screen.dart` already used for its ingredient-table dropdown
(`_kMaterialTableLabels` + a `Future.wait` fan-out across all six repositories),
extended here from read-only to full CRUD.

## 6. Repository Impact

**Zero new methods.** Every action in both new screens reuses pre-existing, public
methods: `create()`, `readAll()`, `update()`, `softDelete()`, `search()`,
`findByProduct()`. Restore needed no new method either — confirmed by reading
`update()`'s actual implementation: it writes every field from `toMap()`, including
`is_active`, so `update(model.copyWith(isActive: true))` reactivates a soft-deleted
row exactly as well as a dedicated `restore()` would, without adding one.

## 7. Database Impact

**None.** No schema change, no migration, no new table or column. Verified
`lib/core/database/database_helper.dart` is byte-identical to the R4 baseline.

## 8. Business Workflow Impact

The R4-001 break is closed: Product → **Shade** → Trial Formula → **Materials** →
Lab → Approval is now fully exercisable through the shipped UI alone, with no
external data population required. Traced concretely (not assumed) — both new
screens' `create()` calls write through `ShadeRepository`/the six material
repositories, and `formula_form_screen.dart`'s dropdowns already read through those
exact same repositories (`findByProduct()`, `readAll()`), so newly-added Shades and
Materials appear there with zero code change on that side (R5-D). Search (R5-E) also
needed no changes — `search_screen.dart` already searches Shades, Products,
Materials (fanned out across all six tables), Formulas (which includes Approved
Formulas, per R3/R4's established finding), and Knowledge Base, confirmed by
re-reading that file and diffing it as untouched.

## 9. Manual Review Findings

Full review against R5's checklist (imports, navigation, repository calls, null
safety, mounted checks, controller disposal, memory leaks, exception handling,
bracket balance, architecture consistency):

- **Imports:** all resolve, scripted check across all 6 touched/added files.
- **Navigation:** both new routes registered in `AppRoutes` and dispatched in
  `AppRouter` (wrapped in explicit `{}` blocks per the scoping-safety convention
  established in R2, since this switch statement now has several cases declaring a
  local `args` variable). Both new screens reachable from Home; Shade Management
  additionally reachable, pre-filtered, from Product Management.
- **Repository calls:** every call cross-referenced against `BaseSqliteRepository`'s
  actual signatures — `readAll({includeInactive})`, `search(query, {columns})`,
  `filter()`, `count()`, `update()`, `softDelete()` all match exactly.
- **Null safety:** all nullable dereferences guarded; `ShadeManagementScreenArgs`/
  filter defaults handled the same defensive-inclusion way R2/R3 established (a
  filtered-but-since-deleted product is still representable in the dropdown's
  value, avoiding `DropdownButtonFormField`'s assertion crash).
- **Mounted checks:** scripted + manual audit — every `await` preceding further
  `context`/`setState` use is guarded, across both new screens' full CRUD/Restore
  flows.
- **Controller disposal:** `ShadeFormSheet` (4 controllers) and
  `MaterialFormSheet` (7 controllers) both confirmed fully disposed.
- **Memory leaks:** none found; no controller or subscription created without a
  matching teardown.
- **Exception handling:** every repository call site wrapped in
  `on RepositoryException` with `ErrorDialog`, or degrades gracefully via
  `FutureBuilder`— consistent with every prior sprint.
- **Bracket balance:** verified programmatically, including full open/close depth
  tracing (not just a total-count comparison), across all 102 Dart files in the
  repository — zero imbalances anywhere, not just in the files touched this sprint.
- **Architecture consistency:** both new screens follow the identical shape as
  `ProductManagementScreen` (R1) — pushed route, `FutureBuilder`-driven list,
  bottom-sheet form, `ConfirmationDialog` before destructive actions.
- **DI registrations:** every `ServiceLocator.get<T>()` type used across all four
  touched files cross-checked against `main.dart`'s registrations — all present,
  none new (all six material repositories and `ShadeRepository` were already
  registered; R5 just started calling their unused methods).

## 10. Risk Assessment

**Low.** The pattern is well-precedented (R1's Product Management, extended
identically), the repository layer underneath was already fully built and tested by
its own prior existence, and the diff confirms zero collateral changes anywhere.
Specific residual items:

- **Not executed, only reviewed** — standing caveat, every report in this series.
- **Search + Active/Inactive/product filter combination limitation:** `search()` is
  always active-only (confirmed by reading its implementation) and has no
  product-scoping parameter, so Shade Management's "Inactive" view combined with a
  search term can only honestly show active matches — documented plainly in-code
  rather than silently producing a confusing result. This is a real, if narrow, UX
  edge case worth knowing about.
- **`DropdownButtonFormField.value` deprecation** (standing note from R1-R3) — used
  in a few more places here.
- **No automated tests** for either new screen, consistent with this project's
  established convention (no screen anywhere has widget tests).

## 11. Remaining Work for R6

Per the brief, R6 (Production Readiness & QA) begins immediately after R5 is
accepted. This sprint's job was to make sure R6 can start clean:

- **R6 can now exercise the full workflow end-to-end** without external data
  population — R4's blocking finding is resolved.
- Carried forward from every prior sprint: a live `flutter analyze`/`flutter test`/
  `flutter build apk`/`flutter build appbundle` run is still outstanding and is
  explicitly R6's job, not repeated here.
- Suggest R6's widget-test pass start with the two newest screens
  (`shade_management_screen.dart`, `material_management_screen.dart`) alongside
  `product_management_screen.dart`, since all three share close to the same shape
  and a shared test pattern would cover them efficiently.
- The Knowledge Base's non-tappable Approved Formulas rows and its
  `.catchError`-vs-`on RepositoryException` stylistic inconsistency (both flagged
  in R4) remain open, low-priority items.

## 12. Known Issues

- **Shade_Master has no Pantone, Coverage, or Description column.** Confirmed by
  reading `database_helper.dart` directly. `hex_color` ("Colour (Hex)") is shown as
  the closest real equivalent to "Pantone", under its actual name. Coverage and
  Description have no plausible stand-in anywhere in the schema and are simply not
  in the form — inventing them would mean writing to columns that don't exist,
  which isn't possible without a schema change (out of scope for R5).
- **None of the six raw-material tables has a Colour, Notes, or (text) Status
  column.** Confirmed identical across all six schema definitions. Only Pigment has
  a colour-*adjacent* field (`color_index`, a Colour Index reference code, not a
  colour value) — and it's Pigment-only, so surfacing it as a generic "Colour" for
  all six tables would misrepresent the other five. All three requested fields are
  omitted from the generic form rather than faked. "Status" is mapped to the real
  Active/Inactive flag every table does have.
- **Each material table's own unique extra field** (Pigment: color_index, Dye:
  solubility, Mica: particle_size, Pearl: pearl_type, Filler: filler_type, Binder:
  binder_type) is not editable through this generic screen, by design — a
  single generic form can't sensibly present six different, differently-named
  fields as one UI element without either becoming six screens (explicitly
  prohibited) or guessing at a false unification. Existing values in these columns
  are preserved untouched on update (the adapter's `update` path only writes the
  seven shared fields it manages).
- Search combined with the Inactive/All view filters (see Risk Assessment).

## 13. Overall Status

**Implemented, code-reviewed, not yet executable-verified — and, per the R4 finding
this sprint exists to close, the core workflow is now genuinely exercisable
end-to-end through the shipped UI.** Every R5 item (R5-A through R5-F) has a working,
traced code path built entirely on pre-existing repository methods — zero
repository additions, zero schema changes, zero engine modifications, confirmed by
diff to have touched exactly 4 files plus 2 new ones. Ready for R6's live toolchain
run, which remains the one step this sandbox cannot perform.
