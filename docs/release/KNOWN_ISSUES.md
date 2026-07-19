# Hue Muse Shade AI — Known Issues (Complete List)

Compiled from every sprint's report. Grouped by severity as best can
be judged without a real build.

## Blocking (must resolve before any real release)

1. **No real build has ever been produced.** No Flutter SDK has been
   available in the environment that wrote this code, across all 12
   development sprints, the v1.0.0 Release Readiness Audit, nor any
   of Repair Sprints R1 through R6. `flutter analyze`, `flutter
   test`, `flutter build apk`, and `flutter build appbundle` have
   never run. This is the single fact that makes every
   "stable"/"working"/"ready" claim in this project's history a
   code-review-level claim, not a verified one.
   **Update (Release Audit, RC-1.0.0):** the `android/` platform
   folder — previously missing entirely, which would have hard-failed
   step 1 of any real build regardless of code quality — has been
   added by hand (standard Flutter embedding v2 scaffold: Gradle
   config, manifests, `MainActivity`, launcher icons, signing
   fallback). This removes the one blocker that was guaranteed to
   fail before the Dart code was even reached, but it does not
   itself constitute a verified build.
   **Update (R6, Production Readiness & QA):** re-confirmed the same
   constraint one more time — still no `flutter`/`dart` binary and no
   network access in this environment. R6 added substantial test
   *code* (see item 4) precisely so that the first real
   `flutter test` run has meaningful coverage to execute, but that
   run itself remains outstanding. The very next required step is
   running the existing `.github/workflows/flutter_release.yml`
   pipeline (or `flutter pub get && flutter analyze && flutter test
   && flutter build apk --release && flutter build appbundle`
   locally) in an environment with a real Flutter SDK, and fixing
   whatever it surfaces.

## High — needs a decision before wide release

2. ~~**Product creation has no UI.**~~ **CLOSED (Repair Sprint R1).**
   `ProductManagementScreen` now provides full Create/Edit/Delete
   against `ProductRepository`. R4's later end-to-end trace found the
   *same class* of gap for two more entities — Shade and the six
   raw-material tables — neither of which any screen could create
   either. **CLOSED (Repair Sprint R5)** with `ShadeManagementScreen`
   and one generic `MaterialManagementScreen` covering all six
   tables. See the R1 and R5 reports for full detail.
3. **Import Knowledge has no file picker** — reads a fixed path
   (`Documents/imports/knowledge_import.json`). Real UX limitation
   for non-technical users. Untouched by R1-R6 (Settings/Import-
   Export was out of scope for every repair sprint).
4. ~~**No screen-level widget tests, no integration tests.**~~
   **PARTIALLY CLOSED (Repair Sprint R6).** Ten screens now have real
   widget tests (`test/*_widget_test.dart`) built on a shared
   in-memory-SQLite-plus-real-repositories harness
   (`test/widget_test_support.dart`) rather than mocks — no mocking
   library is a project dependency, and `ServiceLocator.reset()` was
   already present "intended for test teardown only" (SPR-DEP-002),
   confirming this was the anticipated approach. Two engines
   previously at zero coverage (`MaterialMatchingEngine`,
   `TrialWorkflowManager`) also gained unit tests. **None of this new
   test code has been executed** — same root cause as item 1. A
   proper integration-test *suite* (as opposed to the R4 report's
   manual code-trace of the same end-to-end flow) is still not
   written; see Remaining Work in the R6 report.
5. **Database filename discrepancy** — shipped as
   `hue_muse_shade_ai.db`; one sprint's brief said
   `huemuse_shade_ai.db`. Kept the original to avoid orphaning data;
   never confirmed which was intended.

## Medium

6. ~~`RuleModel.fromMap` silently defaults an unparseable `rule_type`
   to `RuleType.product`~~ **CLOSED (v1.0.1 planning, 2026-07-16):**
   reviewed against the codebase's convention — every other field in
   this same factory already coerces to a safe default rather than
   throwing, and no logging framework exists anywhere in `lib/` to
   "surface" corruption to. An alternative (`RuleType.unknown`) was
   considered and rejected. Intentional, not a defect. Not reachable
   through normal app usage; would only matter if `Settings` rows
   were edited outside the app.
7. **`RecommendationEngine`/`FormulaRecommendationEngine`/
   `TrialGeneratorEngine` make sequential (non-batched) repository
   calls per candidate trial** — untested at realistic data volumes;
   plausible performance risk if trial-formula counts grow large.
8. **`Settings` table hosts four discriminated record types** through
   one `record_type` column with some overloaded column meanings.
   Functionally correct and documented, but adding a fifth type would
   compound the complexity — worth reconsidering the frozen-database
   constraint if that need ever arises.
9. **Restore Database requires a manual app restart** — `sqflite`
   holds the live file open; there's no in-app restart mechanism.
10. ~~"Recent Analysis" on Home is really Recent Recommendations~~
    **CLOSED (v1.0.1 planning, 2026-07-16):** verified against
    `lib/screens/home_screen.dart:261` — the shipped UI label already
    reads "Recent Recommendations." This entry was documenting the
    naming rationale (no separate `ColorProfile` persistence exists),
    not describing a live mislabeling bug. No action needed.

## Low

11. Six raw-material models (`Pigment`/`Dye`/`Mica`/`Pearl`/`Filler`/
    `Binder`) and their repositories were code-generated from a
    shared template — intentional, not a defect, but worth knowing
    if one needs a field the others don't.
12. Several scoring/ranking constants (business-priority ordinal
    mapping, ranking-factor equal-weighting, sampling/downscaling
    parameters, dark/light brightness thresholds) are code-level
    defaults rather than `RuleEngine`-configurable — each is flagged
    in its introducing sprint's report as a judgment call in the
    business's domain, not the engineering's.
13. `ColorConversionEngine.rgbToHsl` duplicates hue/saturation/
    lightness math that also exists privately inside `ShadeEngine`
    (frozen since SPR-DEP-004) — a small, accepted duplication rather
    than modifying already-approved code.

## Open confirmation requests (not defects — judgment calls awaiting sign-off)

14. Full column schemas for all 13 Data Layer tables (defined
    SPR-DEP-003) — cosmetics-domain columns chosen from general
    knowledge, not specified in any brief.
15. The 12 seeded default business rules' weights/conditions
    (SPR-DEP-005) — starting configuration, genuinely editable
    afterward, but the initial values are a guess.
16. `TrialStatus`'s allowed-transition graph (SPR-DEP-007) — in
    particular whether Rejected should be able to return to Draft,
    and whether any status should be directly Archivable.
17. Whether Trial should be a pushed route or a 6th bottom-nav tab
    (SPR-DEP-009) — chose pushed route to avoid touching the frozen
    5-tab shell.
18. Whether `image: ^4.2.0` (added SPR-DEP-008 for pixel decoding) is
    an acceptable new dependency, or `dart:ui`'s built-in codec would
    have been preferred.

None of items 14-18 block a build — they're product/business
decisions that can be revisited independently of shipping.

## Discovered during Repair Sprints R1-R6

19. **Several brief-requested fields have no backing column and were
    deliberately not invented.** Confirmed by reading the schema
    directly each time, not assumed: Trial_Formula/Approved_Formula
    have no "version" integer (R2 — a Version/Revision History
    section reads the real audit trail instead); Shade_Master has no
    Pantone/Coverage/Description column (R5 — `hex_color` is shown
    honestly as the closest real equivalent to "Pantone", the other
    two are simply omitted from the form); none of the six
    raw-material tables has a Colour/Notes/text-Status column (R5 —
    mapped to the real Active/Inactive flag instead, nothing invented).
20. **Revision lineage is a text convention, not a real relationship.**
    R3's "Create Revision" writes "Revision of &lt;code&gt;" into the new
    row's `notes` field — the only free-text field available without
    a schema change — and Formula Details parses it back out for
    display. No reverse "Superseded By" lookup exists; that would
    need either a schema column or an accepted extra full-table-scan
    cost per row, and was left as a documented R4-era option rather
    than half-implemented.
21. **No `trial_code` uniqueness enforcement**, at the schema or
    application level — a user must supply a non-colliding code by
    convention when creating a formula or a revision of one.
22. **Knowledge Base's Approved Formulas tab rows aren't tappable**
    and its error handling uses `.catchError` rather than the
    `on RepositoryException` pattern used everywhere else (found in
    R4). Both are pre-existing (SPR-DEP-009), cosmetic, and were
    deliberately left alone rather than editing a file no repair
    sprint otherwise needed to touch.
23. **`DropdownButtonFormField`'s `value:` parameter** is used
    throughout the R1-R5 screens (Product/Shade/Material/Formula
    forms and filters). Recent Flutter stable releases added
    `initialValue:` as the preferred name and began deprecating
    `value:`, but did not remove it. Kept as `value:` deliberately —
    it works across a wider SDK range, and CI floats on
    `channel: stable` with no pinned version, so the safer choice was
    a possible deprecation *warning*, never a compile error. Worth a
    five-minute check the first time `flutter analyze` actually runs
    (item 1).
24. **`AppRoutes.newShadeCapture` and `AppRoutes.knowledgeBaseDetail`**
    are declared but dispatch to nothing in `AppRouter` — confirmed
    intentional by their own doc comment ("Reserved for future module
    sprints"), not dead code, despite looking that way from a pure
    grep. Flagged in R4 before that comment was re-read carefully;
    corrected here.
