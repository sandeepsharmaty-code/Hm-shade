# Sprint Completion Report — SPR-DEP-006

**Objective:** Formula Recommendation Engine — converts Rule Engine
results into ranked formulation recommendations. Recommendation Layer
only: no formulation chemistry, no manufacturing, no pigment-ratio
estimation.

---

## Updated Project Tree

```
lib/models/recommendation_history_model.dart        (new)
lib/repositories/recommendation_history_repository.dart (new)
lib/repositories/base_repository.dart                (changed — readAll()
                                                        gained extraWhere/
                                                        extraWhereArgs)
lib/repositories/rule_repository.dart                (changed — added
                                                        findAllRules())

lib/engines/
├── recommendation_conflict.dart          (new — ConflictType,
│                                           RecommendationConflict)
├── recommendation_conflict_detector.dart (new)
├── recommendation_reason_builder.dart    (new)
├── recommendation_filter.dart            (new)
├── recommendation_ranker.dart            (new — RankingFactors,
│                                           RankedRecommendation)
├── recommendation_history.dart           (new)
└── formula_recommendation_engine.dart    (new — top-level orchestrator)

lib/core/database/database_helper.dart  (v4 schema — Settings gains
                                          4 more columns for
                                          recommendation history)
```

## Formula Recommendation Engine

`FormulaRecommendationEngine.recommend(FormulaRecommendationRequest)`
pipeline:
1. Calls `RecommendationEngine.recommend()` (SPR-DEP-005, already
   rule-driven) for a candidate pool 3x larger than `maxResults`, so
   filtering/ranking has room to reorder before truncating.
2. Calls `KnowledgeEngine.searchApprovedFormulas()` once for
   cross-product context messages (the "Knowledge Engine Result"
   input).
3. Runs `RecommendationConflictDetector` on every candidate.
4. Runs `RecommendationFilter` to drop severe conflicts.
5. Builds `RankingFactors` per surviving candidate — Rule Confidence
   (from step 1), Approved Formula Match (from
   `TrialRepository.approvalForTrial`), Material Availability
   (approved vs. total material-line ratio), Alternative Material
   Quality (re-checked via `MaterialMatchingEngine` — see below),
   Business Priority (trial status ordinal).
6. Runs `RecommendationRanker`, takes the top `maxResults` (default
   5 — "Top 5 Recommendations").
7. Builds reasons via `RecommendationReasonBuilder` per result.
8. Records the top pick via `RecommendationHistory.record()` (see
   Known Issues for the "auto-record top pick" interpretation).

Never computes a percentage, ratio, or new formula composition —
every `FormulaRecommendation.trialFormula` is an existing
`Trial_Formula` row; the engine only ranks and explains, per this
sprint's explicit constraints (grep-verified zero
"pigment ratio"/"manufactur*" logic in `lib/engines/`, matches shown
in Self Review are doc-comment mentions of what's *not* done).

## Recommendation Ranking Engine

`RecommendationRanker` — `RankingFactors.composite` is an
equal-weighted average of the five required factors. `Business
Priority` is a simple, transparent trial-status ordinal (approved >
in_review > draft), not routed through `RuleEngine` — flagged as a
judgment call in Known Issues rather than silently decided. The other
four factors are pre-computed by earlier pipeline stages;
`RecommendationRanker` combines, doesn't compute, them.

## Recommendation Reason Builder

`RecommendationReasonBuilder.build()` — pure formatting: confidence
summary sentence, each matched rule's description, material
approval/alternative counts, approved-formula cross-reference note,
and each conflict prefixed "Caution:". Presents existing data; invents
no new explanations.

## Conflict Detection Engine

`RecommendationConflictDetector.detect()` — all six required
categories:
- **Product Mismatch** — `trial.productId != request.productId`.
- **Shade Mismatch** — linked shade's family/finish vs. requested.
- **Inactive Material** — from `candidate.alternativeMaterialIds`
  (populated by `MaterialMatchingEngine` via `RecommendationEngine`).
- **Missing Material** — from "not found" notes surfaced during
  scoring.
- **Low Confidence** — `candidate.confidence < lowConfidenceThreshold`
  (caller-supplied, default 0.3).
- **Disabled Rule** — via the new `RuleRepository.findAllRules()`
  (see the real bug fixed below).

### A real bug caught and fixed before shipping

`RuleRepository.readAll(includeInactive: true)` would have returned
**every** `Settings` row — plain settings and recommendation-history
rows included — and tried to parse each one as a `RuleModel`, since
the inherited `readAll()` has no way to know the table is shared
across three record types. Fixed by adding `extraWhere`/
`extraWhereArgs` to `BaseSqliteRepository.readAll()` and a new
`RuleRepository.findAllRules()` that correctly scopes to
`record_type = 'rule'`. Documented in both `rule_repository.dart` and
`recommendation_history_repository.dart` headers as a standing
constraint: an id from one of these two repositories must never be
passed to the other, since `readById`/`update`/`softDelete`/`exists`
are id-only and don't check `record_type`. Flagged in Known Issues as
a follow-up worth a deeper fix if this pattern gets reused again.

## Recommendation History

Stored as `Settings` rows (`record_type = 'recommendation_history'`,
schema v4 — same pattern as SPR-DEP-005's rule storage, same
rationale: no dedicated table exists and the database stays frozen).
Captures every required field: Recommendation ID (row `id`), Timestamp
(`created_at`), Input Parameters (JSON-encoded request), Selected
Recommendation (`selected_trial_formula_id`), Confidence, Reason.

## Recommendation Flow Diagram

```
FormulaRecommendationRequest
        |
        v
RecommendationEngine (SPR-DEP-005, already rule-driven)
   -> candidate pool (3x maxResults)
        |
        |-- KnowledgeEngine.searchApprovedFormulas() (context only)
        v
RecommendationConflictDetector (per candidate)
   Product/Shade Mismatch, Inactive/Missing Material,
   Disabled Rule, Low Confidence
        v
RecommendationFilter (drop severe conflicts)
        v
Build RankingFactors per candidate:
   RuleConfidence          <- step 1 (RecommendationEngine)
   ApprovedFormulaMatch    <- TrialRepository.approvalForTrial
   MaterialAvailability    <- candidate approved/total ratio
   AltMaterialQuality      <- MaterialMatchingEngine (re-checked)
   BusinessPriority        <- trial.status ordinal
        v
RecommendationRanker (composite, sort, assign rank 1..N)
        v (top 5)
RecommendationReasonBuilder (per result)
        v
RecommendationHistory.record() (top pick only)
        v
List<FormulaRecommendation>
   (rank, confidence, reasons, matchedRules,
    alternativeMaterialIds, conflicts, approvedFormulaReference)
```

## Testing Strategy

1. **Pure-function tests (delivered).**
   `test/recommendation_ranker_test.dart` covers `RankingFactors.
   composite`, `businessPriorityFor`, and `RecommendationRanker.rank`'s
   sort/rank-assignment — no DB needed. Carried forward from prior
   sprints: `match_type_test.dart`, `shade_engine_test.dart`,
   `rule_evaluator_test.dart`.
2. **Repository-backed tests (still a follow-up, now larger).**
   `FormulaRecommendationEngine`, `RecommendationConflictDetector`,
   and `RecommendationHistory` all need seeded `sqflite_common_ffi`
   data. This gap has been flagged every sprint since SPR-DEP-004;
   still offering to close it as a same-sprint follow-up rather than
   waiting.
3. **Integration/golden test (future).** Once `RecommendationEngine`
   and `FormulaRecommendationEngine` both have real seeded Trial_
   Formula/Formula_Material/rule data, an end-to-end golden test
   (fixed inputs -> expected Top 5 order) would catch pipeline
   regressions across all 11 engines at once.

## Self Review

- OK **No UI dependency** — grep-verified zero `screens/` imports
  under `lib/engines/` (all 15 files).
- OK **No direct SQLite access** — grep-verified zero `sqflite`
  imports/`db.*` calls under `lib/engines/`.
- OK **Repository Layer only** — every new class takes repositories
  and/or engine interfaces in its constructor, never `Database`.
- OK **Rule Engine integration complete** — `RecommendationEngine`
  (consumed here unchanged) and `MaterialMatchingEngine` both still
  route through `RuleEngine`; `RecommendationConflictDetector` reads
  rule state via `RuleRepository` for the Disabled Rule check.
- OK **Knowledge Engine integration complete** —
  `FormulaRecommendationEngine` calls
  `KnowledgeEngine.searchApprovedFormulas()` for cross-reference
  context.
- OK **No hardcoded recommendation logic** — grep-verified zero
  "pigment ratio"/"manufactur*" computation in `lib/engines/`; the
  only literal numbers introduced this sprint are the ranking
  combination's equal weights (1/5 each) and `businessPriorityFor`'s
  ordinal mapping, both flagged explicitly below rather than silently
  passed off as "not hardcoded."
- NOT CONFIRMED **Production Ready (compile-verified)** — **cannot
  confirm**, see ENV-001. Static checks (brace/paren balance, import
  resolution, package cross-check, duplicate-class scan,
  unused-catch-clause scan) across all 83 `.dart` files pass clean,
  including the 10 new/changed files this sprint.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** No Flutter SDK in this sandbox.
2. DB filename / SPR-DEP-003 schema / SPR-DEP-005 rule-weight items —
   no response yet.
3. No repository-backed tests for the engine layer — now spans 4
   sprints' worth of engines untested beyond pure-logic pieces.

**New this sprint:**
4. **Business Priority is not RuleEngine-driven.** Unlike every other
   scoring input in this pipeline, `businessPriorityFor()` is a plain
   status-ordinal function, not a configurable rule. Reasoned in the
   file header as "a ranking tie-breaker convention, not a domain
   rule," but it's a real inconsistency with this sprint's "no
   hardcoded recommendation logic" spirit worth your judgment call —
   should it become a 13th `RuleType`?
5. **Ranking combination is an equal-weighted average**, not
   per-factor configurable weights. Same category of decision as
   SPR-DEP-005's rule weights, not extended to ranking-factor weights
   this sprint to keep scope bounded.
6. **Cross-repository id constraint** (see the real bug fixed above)
   — `RuleRepository` and `RecommendationHistoryRepository` share
   `Settings` and their ids must never cross. Safe under current
   usage (nothing in this codebase does that), but structurally
   fragile if a future sprint adds a fourth `record_type` without
   remembering this. A deeper fix (scoping every CRUD method by
   `record_type`, not just `readAll`) is possible but wasn't done
   this sprint to control scope.
7. **RecommendationHistory auto-records the top pick on every
   `recommend()` call**, not only on explicit user selection (no
   selection UI exists yet to call it from). This means calling
   `recommend()` twice logs two history entries even if nothing was
   "selected" by a person. Reasonable interim interpretation, flagged
   in case you want a `recordExplicitSelection()`-only model instead
   once a UI exists.
8. **`FormulaRecommendationRequest.shadeId` is accepted but not yet
   used** for a direct compatibility check (only `shadeFamily`/
   `finish` matching hints are consulted) — `ShadeEngine.
   validateProductCompatibility` (SPR-DEP-004) exists and could be
   wired in; not done this sprint to avoid adding yet another engine
   dependency to an already-large constructor list.

## Ready For Approval

**Conditionally**, same basis as every prior sprint. Final sign-off
needs `flutter pub get && flutter analyze && flutter test` run
locally. Per the Stop Rule, not continuing to SPR-DEP-007 until you
approve.
