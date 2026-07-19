# Sprint Completion Report — SPR-DEP-003

**Objective:** Implement the complete Data Layer.

---

## Updated Project Tree

```
hue_muse_shade_ai/
├── lib/
│   ├── main.dart                 (registers DatabaseHelper + 11 repos)
│   ├── app.dart
│   ├── core/
│   │   ├── database/database_helper.dart   (v2 schema + migration + forTesting)
│   │   ├── di/service_locator.dart
│   │   ├── routing/{app_routes,app_router}.dart
│   │   ├── theme/app_theme.dart
│   │   └── services/{app_state_provider,navigation_provider}.dart
│   ├── models/
│   │   ├── model_parsing_utils.dart
│   │   ├── product_model.dart
│   │   ├── shade_model.dart
│   │   ├── pigment_model.dart
│   │   ├── dye_model.dart
│   │   ├── mica_model.dart
│   │   ├── pearl_model.dart
│   │   ├── filler_model.dart
│   │   ├── binder_model.dart
│   │   ├── blend_template_model.dart
│   │   ├── trial_formula_model.dart
│   │   ├── formula_material_model.dart
│   │   ├── approved_formula_model.dart
│   │   └── knowledge_base_model.dart
│   ├── repositories/
│   │   ├── base_repository.dart
│   │   ├── repository_exception.dart
│   │   ├── product_repository.dart
│   │   ├── shade_repository.dart
│   │   ├── pigment_repository.dart
│   │   ├── dye_repository.dart
│   │   ├── mica_repository.dart
│   │   ├── pearl_repository.dart
│   │   ├── filler_repository.dart
│   │   ├── binder_repository.dart
│   │   ├── blend_repository.dart
│   │   ├── trial_repository.dart   (also owns Formula_Material + Approved_Formula)
│   │   └── knowledge_repository.dart
│   ├── screens/  (unchanged from SPR-DEP-002)
│   └── widgets/  (unchanged from SPR-DEP-002)
└── test/
    ├── database_helper_test.dart
    └── product_repository_test.dart   (new — CRUD contract test)
```

## All Models

13 files in `lib/models/`, each with `fromMap()`, `toMap()`,
`copyWith()`, `operator ==`/`hashCode`, `toString()`, full null
safety, and dartdoc — verified present in every file (see Self
Review). `ProductModel` and `ShadeModel` are hand-authored;
`PigmentModel`/`DyeModel`/`MicaModel`/`PearlModel`/`FillerModel`/
`BinderModel` share a structural template (common raw-material
fields + one distinguishing field each) since they're genuinely
parallel domain entities, not duplicated logic.

## All Repositories

`base_repository.dart` implements Create/Read/Update/soft-Delete/
Search/Filter/Exists/Count exactly once; all 11 concrete repositories
extend it and supply only `toMap`/`fromMap`/`idOf` plus table-specific
finder methods (e.g. `ProductRepository.findByCategory`). No SQL
appears outside `lib/core/database/` and `lib/repositories/` — no
screen touches SQLite. `Formula_Material` and `Approved_Formula` have
models but no dedicated repository, exactly matching this sprint's
own repository list (11, not 13) — both are child data managed
through `TrialRepository.addMaterialLine` /`materialsForTrial`/
`removeMaterialLine`/`approveTrial`/`approvalForTrial`, consistent
with "no repositories for child entities without independent
lifecycle."

## SQLite CRUD

- **Create** — `INSERT`, returns the row re-read by generated id.
- **Read** — `readById` (single), `readAll` (list), both active-only
  by default with an `includeInactive` override.
- **Update** — requires a non-null `id`; refreshes `updated_at`.
- **Delete** — soft only: `UPDATE ... SET is_active = 0`. Rows are
  never physically removed by repository code (only `resetDatabase()`
  on the Settings screen does a hard drop, by explicit user choice).
- **Search** — `LIKE` across configurable columns (defaults to
  `name`; `KnowledgeRepository` also searches `tags`/`content`).
- **Filter** — exact-match `WHERE` across a caller-supplied column map.
- **Exists** — active-row existence check by id.
- **Count** — `SELECT COUNT(*)`, active-only by default.
- **Trial approval** — `TrialRepository.approveTrial()` wraps the
  `Approved_Formula` insert and the `Trial_Formula.status` update in
  a single `db.transaction()` so they can't disagree on partial
  failure.

## Build Instructions

```
flutter pub get
flutter run
flutter build apk --release
```

## Testing Instructions

```
flutter pub get
flutter test
```
`test/product_repository_test.dart` is new this sprint: full CRUD/
search/filter/exists/count/soft-delete pass against an in-memory
`sqflite_common_ffi` database via the new
`DatabaseHelper.forTesting()` constructor (added specifically so
repositories are unit-testable without a device or `path_provider`).
Since every repository shares `BaseSqliteRepository`, this one test
file exercises the same code path all 11 repositories use.

## Self Review

- ✓ Repository Pattern — verified via grep: zero `db.query`/
  `db.insert`/`db.rawQuery`/SQL string literals exist outside
  `lib/core/database/` and `lib/repositories/`.
- ✓ Every model has `fromMap`/`toMap`/`copyWith`/`==`+`hashCode`/
  `toString` — checked programmatically across all 13 files (1 of
  each per file, no misses).
- ✓ Every repository extends `BaseSqliteRepository` and implements
  `toMap`/`fromMap`/`idOf` — checked programmatically across all 11.
- ✓ Null Safety — no `dynamic`, no unsound `!` outside guarded
  null-checks.
- ✓ No duplicate CRUD logic — one implementation in
  `base_repository.dart`, not 11.
- ✓ Exception handling — every repository method wraps its DB call
  in try/catch and throws `RepositoryException`; debug-mode-only
  logging via `kDebugMode` guard (satisfies "Logging in debug mode
  only").
- ✗ Flutter Analyze / Compile — **cannot confirm**, see ENV-001
  (unchanged, no SDK in this sandbox). Static checks across all 55
  `.dart` files (brace/paren balance, local import resolution,
  `package:` cross-check, unused-catch-clause scan, duplicate-class
  scan) all pass clean.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** Still can't run `flutter pub get`/
   `analyze`/`test`/`build` in this sandbox. `product_repository_test.dart`
   is written and self-reviewed line-by-line against the sqflite API
   but has not actually been executed by a real `flutter test` run.

**New this sprint — please confirm or correct:**
2. **Database filename kept as `hue_muse_shade_ai.db`**, not
   `huemuse_shade_ai.db` as stated in this sprint's brief. Changing it
   now would orphan the file already shipped in the SPR-DEP-001/002
   approval. If `huemuse_shade_ai.db` was intentional (not a typo),
   say so and I'll add a one-time migration that copies data across
   and deletes the old file.
3. **Column schemas are my domain judgment call**, not something you
   specified — see the "MODEL REQUIREMENTS"/table definitions in
   `database_helper.dart`'s `_domainColumns` map for the full list per
   table (e.g. Product: `product_code`/`category`/`base_type`;
   Pigment/Dye/Mica/Pearl/Filler/Binder: `material_code`/`cas_number`/
   `supplier`/`unit`/`cost_per_unit`/`stock_quantity` + one
   distinguishing field). Flagging for your review rather than
   treating it as silently final — cosmetics-domain columns are your
   area of expertise, not mine.
4. **Upgrade path (v1 -> v2) drops and recreates tables**, discarding
   any v1 foundation-schema data. Chosen because no real device has
   ever run this app outside this chat (ENV-001), so no real user
   data is at risk yet. If a build has already been installed
   somewhere with real data, tell me and I'll switch to an
   `ALTER TABLE ADD COLUMN`-based non-destructive migration instead.
5. **`FormulaMaterial`/`ApprovedFormula` have no standalone
   repository** — by design, matching this sprint's own repository
   list, but flagging explicitly in case that was an oversight in the
   brief rather than intentional.
6. Foundation-only-columns question from SPR-DEP-001/002 is now
   resolved by this sprint (superseded by #3 above).

## Ready For Approval

**Conditionally**, same basis as prior sprints: complete and
self-reviewed to the limit of what's checkable without a Flutter SDK.
Final sign-off needs `flutter pub get && flutter analyze && flutter
test` run locally. Per the Stop Rule, not continuing to SPR-DEP-004
until you approve.
