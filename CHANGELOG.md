# Changelog

All notable changes to Hue Muse Shade AI are documented here.
Source of truth for sprint-level detail: `docs/release/VERSION_HISTORY.md`
and the individual `docs/sprints/SPR-DEP-*-completion-report.md` and
`docs/release/R1_*.md` through `R6_*.md` files.

## [1.1.0] — Repair Sprints R1-R6

**Status: source-complete; build still not executed in a real
Flutter environment across any of R1-R6 either.** See
`docs/release/R6_Production_Readiness_Report.md` for the full
readiness assessment and Go/No-Go recommendation.

### Added
- Product Management screen (R1) — Create/Edit/Delete for
  `Product_Master`, previously database-only.
- Formula Workflow (R2) — manual formula create/edit/search,
  ingredient editor with per-line Rule Compliance;
  `TrialRepository.updateMaterialLine()` (the one new repository
  method across all of R1-R6).
- Approved Formula Workflow (R3) — Approve/Reject/Request Revision/
  Create Revision, built on the pre-existing `approveTrial()`/
  `approvalForTrial()`/`ApprovedFormulaModel`.
- Shade Management and Raw Material Management screens (R5) —
  closing the same "no creation UI" gap R1 fixed for Products,
  found by R4's end-to-end trace. Raw Material Management is one
  generic screen covering all six material tables, not six screens.
- Dashboard Materials count (R5); Approved/Awaiting Approval/
  Rejected/Revisions Pending counts (R3).
- Widget tests for ten screens and unit tests for two previously
  zero-coverage engines (`MaterialMatchingEngine`,
  `TrialWorkflowManager`) — R6, built on a shared in-memory-SQLite
  test harness rather than mocks (none is a project dependency).

### Changed
- `pubspec.yaml` version bumped `1.0.0+1` → `1.1.0+2`.
- This documentation set (Release Notes, Known Issues, User Manual,
  Architecture Summary, Version History) updated to reflect R1-R6.

### Fixed
- A widget-lifecycle bug in Product Management (`setState` after
  `dispose` risk) found and fixed during R1's own verification pass.
- A `DropdownButtonFormField` assertion-crash risk (editing a record
  whose linked product/shade/material had since been soft-deleted)
  found and fixed during R2/R3.
- A stale-dropdown bug in the R3 Formula List filter, found and fixed
  during R3's own review.

### Known limitations at this release
See `docs/release/KNOWN_ISSUES.md` for the complete, severity-ranked
list. Headline items, unchanged since the original release
candidate: no real `flutter build`/`flutter test` run has ever been
executed in a genuine Flutter/Android toolchain, in any sprint,
original or repair; Import Knowledge still has no file picker; a few
brief-requested fields across R2/R3/R5 have no backing database
column and were deliberately omitted rather than invented (see Known
Issues #19).

---

## [1.0.0] — Release Candidate (original audit)

**Status: source-complete; build newly unblocked, not yet executed
in a real Flutter environment.** See the Release Audit Report for
the full readiness assessment.

### Added
- `android/` platform folder (previously missing entirely across all
  12 development sprints — see Known Issues #1). Standard Flutter
  embedding v2 project: Gradle config, manifests, `MainActivity`,
  launcher icons in the app's brand color, release signing
  scaffold (`key.properties.example`) that falls back to debug
  signing until a real upload keystore is supplied.
- Root `VERSION`, `CHANGELOG.md` files.

### Changed
- `pubspec.yaml` version bumped `0.1.0+1` → `1.0.0+1`.
- `.gitignore` updated so `gradlew`/`gradlew.bat` are tracked (needed
  now that `android/` is a real, committed platform folder rather
  than something CI regenerates on every run).

### Carried forward from development (SPR-DEP-001 through SPR-DEP-012)
- SPR-DEP-001 — Flutter project foundation: scaffold, folder
  structure, SQLite init (14 tables), splash screen, home placeholder.
- SPR-DEP-002 — Application shell: 5-tab bottom navigation, routing,
  DI (`ServiceLocator`), reusable widgets.
- SPR-DEP-003 — Data Layer: models, repositories, shared CRUD base,
  full domain columns (schema v2).
- SPR-DEP-004 — Knowledge Engine Foundation: `KnowledgeEngine`,
  `ShadeEngine`, `RecommendationEngine` (v1).
- SPR-DEP-005 — Rule Engine Foundation: fully rule-driven
  recommendations (schema v3).
- SPR-DEP-006 — Formula Recommendation Engine: conflict detection,
  ranking, recommendation history (schema v4).
- SPR-DEP-007 — Trial Recommendation Workflow: 6-state trial
  lifecycle with full audit trail (schema v5).
- SPR-DEP-008 — Image Intelligence Foundation: deterministic offline
  colour extraction/classification (new dependency: `image ^4.2.0`).
- SPR-DEP-009 — UI Integration: all engines wired into Home, New
  Shade, Search, Knowledge, Settings, and Trial screens.
- SPR-DEP-010 — QA & Beta Readiness: fixed unguarded release-build
  logging and unvalidated database restore; added first
  repository-backed and widget tests.
- SPR-DEP-011 — Release Candidate Audit: static pass for unused
  imports, dead code, memory leaks, DI consistency — 0 new defects.
- SPR-DEP-012 — Production Release Package: full release
  documentation set; explicit non-certification of the (at that
  time) unverified build gate.

### Known limitations at this release
See `docs/release/KNOWN_ISSUES.md` for the complete, severity-ranked
list. Headline items: no real `flutter build`/`flutter test` run has
been executed yet in a genuine Flutter/Android toolchain (this audit
removed the `android/`-folder blocker to that but could not itself
run the toolchain — see Release Audit Report); no in-app product
creation UI; no file picker for knowledge import; no screen-level
widget/integration tests.
