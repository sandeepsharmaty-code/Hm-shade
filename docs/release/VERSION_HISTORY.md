# Hue Muse Shade AI — Version History / Change Log

All changes are tracked as one commit per sprint in the local git
repository (`git log` in the delivered zip shows the full history).

| Sprint | Summary |
|---|---|
| SPR-DEP-001 | Flutter project foundation: scaffold, folder structure, `pubspec.yaml`, SQLite init (14 tables, foundation columns), splash screen, home placeholder |
| SPR-DEP-002 | Application shell: bottom navigation (5 tabs), routing, DI (`ServiceLocator`), 10 reusable widgets, 5 screens |
| SPR-DEP-003 | Data Layer: 13 models, 11 repositories, `BaseSqliteRepository` shared CRUD, full domain columns (schema v2) |
| SPR-DEP-004 | Knowledge Engine Foundation: `EngineResult`, `SearchMatcher`, `KnowledgeEngine`, `ShadeEngine`, `RecommendationEngine` (v1, weights hardcoded) |
| SPR-DEP-005 | Rule Engine Foundation: `RuleEngine`, `ShadeMatchingEngine`, `MaterialMatchingEngine`; `RecommendationEngine` refactored to be fully rule-driven (schema v3 — rules in `Settings`) |
| SPR-DEP-006 | Formula Recommendation Engine: `RecommendationConflictDetector`, `ReasonBuilder`, `Filter`, `Ranker`, `History`, `FormulaRecommendationEngine` (schema v4 — recommendation history in `Settings`) |
| SPR-DEP-007 | Trial Recommendation Workflow: `TrialGeneratorEngine`, `TrialValidationEngine`, `TrialComparisonEngine`, `TrialExplanationEngine`, `TrialWorkflowManager`, `TrialStatus` (6-state graph), audit trail (schema v5) |
| SPR-DEP-008 | Image Intelligence Foundation: `ColorConversionEngine`, `ImageProcessor`, `ColorSamplingEngine`, `DominantColorEngine`, `ColorExtractionEngine`, `ColorProfileBuilder`, `ImageAnalysisEngine`. New dependency: `image ^4.2.0` |
| SPR-DEP-009 | UI Integration: all 8 top-level engines wired into Home/New Shade/Search/Knowledge/Settings screens + new Trial screen (pushed route) |
| SPR-DEP-010 | QA & Beta Readiness: fixed unguarded release-build logging (3 sites) and unvalidated database restore; added repository-backed `RuleEngine` test and first widget test |
| SPR-DEP-011 | Release Candidate Audit: deeper static pass (unused imports, dead code, memory leaks, DI consistency) — 0 new defects found |
| SPR-DEP-012 | Production Release Package (this sprint): release documentation set; **no code changes** (nothing found to fix); explicit non-certification of the unverified build gate |
| R1 | Product Management: full Create/Edit/Delete UI for `Product_Master` — previously database-only |
| R2 | Formula Workflow: manual formula create/edit/search screens, ingredient editor with live Rule Compliance, one new repository method (`updateMaterialLine`) |
| R3 | Approved Formula Workflow: Approve/Reject/Request Revision/Create Revision, built entirely on the pre-existing `approveTrial()`/`approvalForTrial()`/`ApprovedFormulaModel` — zero new repository or engine code |
| R4 | End-to-End Integration & System Validation: full workflow trace found Shade and Raw Material creation had the same "no UI" gap R1 fixed for Products — zero code changes this sprint, pure verification |
| R5 | Missing Business Modules: Shade Management and one generic Raw Material Management screen (six tables, not six screens), closing R4's finding |
| R6 | Production Readiness & QA: widget tests for ten screens, unit tests for two previously-uncovered engines, a documented security review, and this documentation refresh — zero business-logic changes |

## Semantic versioning note (updated for R1-R6)

`pubspec.yaml` was bumped to `1.1.0+2` for this documentation/test
update — a minor version, since R1-R6 added functionality (Product/
Shade/Material Management, Formula and Approved Formula workflows)
without any breaking change to the existing schema or API surface,
and fixed zero defects that would justify a patch-only bump. This is
**still not a claim of production readiness** — see
`docs/release/R6_Production_Readiness_Report.md`'s Go/No-Go section.
The original 1.0.0 note below is preserved for history.

This project has used `0.1.0` as its `pubspec.yaml` version
throughout development. This sprint's brief asks for "Version 1.0.0"
— bumping to 1.0.0 is a statement that the software is
production-ready, which per this sprint's own report cannot yet be
certified (no real build has ever run). The version number in
`pubspec.yaml` has **not** been changed to 1.0.0 as part of this
sprint; see the SPR-DEP-012 completion report for the reasoning.
