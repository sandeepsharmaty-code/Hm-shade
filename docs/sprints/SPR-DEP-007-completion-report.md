# Sprint Completion Report — SPR-DEP-007

**Objective:** Trial Recommendation Workflow — prepares
laboratory-ready recommendation sets. No formulation chemistry, no
pigment percentages, no ingredient-ratio estimation; only organizes,
validates, compares, and prepares existing knowledge.

---

## Updated Project Tree

```
lib/models/trial_status.dart               (new — 6-status enum + transition graph)
lib/models/trial_audit_entry_model.dart     (new)
lib/repositories/trial_audit_repository.dart (new)

lib/engines/
├── trial_generator_engine.dart     (new — wraps FormulaRecommendationEngine
│                                     + duplicate screening)
├── trial_validation_engine.dart    (new — 8 validation checks +
│                                     4 duplicate-detection categories)
├── trial_comparison_engine.dart    (new)
├── trial_explanation_engine.dart   (new)
└── trial_workflow_manager.dart     (new — status transitions + audit trail)

lib/core/database/database_helper.dart  (v5 schema — Settings gains
                                          4 more columns for the audit
                                          trail)
```

## Trial Generator Engine

`TrialGeneratorEngine.generateTopFive(request)` — thin wrapper over
`FormulaRecommendationEngine` (SPR-DEP-006, explicitly listed as this
sprint's own input; not reimplemented). Adds duplicate screening:
`Duplicate Trial`/`Duplicate Material Combination` findings exclude a
candidate outright; `Near Duplicate Trial`/`Duplicate Approved
Formula` findings are kept but surfaced as warnings. Re-ranks the
survivors 1..N after exclusion so gaps never appear in the final Top
5.

## Trial Validation Engine

`TrialValidationEngine.validate()` — all 8 required checks (Product/
Shade/Finish/Coverage Compatibility, Required/Alternative Material
Availability, Recommendation Confidence, Rule Compliance), reframed
as a pass/fail `ValidationReport` built mostly from the
already-computed `FormulaRecommendation.conflicts`/`matchedRules`/
`confidenceScore` (SPR-DEP-006) rather than recomputed from scratch.

`TrialValidationEngine.detectDuplicates()` — all 4 required
categories:
- **Duplicate Trial** — identical `trialCode` or `name`.
- **Near Duplicate Trial** — `SearchMatcher.classify` (SPR-DEP-004,
  reused not reimplemented) returns `similar`/`nearest` on trial
  names.
- **Duplicate Material Combination** — identical
  `{materialTable}#{materialId}` signature sets across two trials'
  `Formula_Material` lines.
- **Duplicate Approved Formula** — a Duplicate Material Combination
  where both trials also have `status = 'approved'`.

Every finding carries a `reason` string, per "Return the reason for
every duplicate found."

## Trial Comparison Engine

`TrialComparisonEngine.compare()` — builds a `ComparisonReport` with
one row per required field (Rank, Confidence, Matched Rules,
Alternative Materials, Conflicts, Approved Formula Reference), each
row flagged `hasDifference` when not all compared trials share the
same value — `ComparisonReport.differingRows` is the direct answer to
"Highlight differences clearly."

## Trial Explanation Engine

`TrialExplanationEngine.explain()` — goes beyond SPR-DEP-006's
`RecommendationReasonBuilder` (which only had matched rules) by
re-evaluating the same product/shade_family/finish/coverage rule
types via `RuleEngine` to recover **failed** rules — data the frozen
SPR-DEP-006 `EngineRecommendation`/`FormulaRecommendation` shapes
never carried. Produces: why selected, why confidence is high/low
(with a plain-language level: high/moderate/low), rules matched,
rules failed, human-readable alternative-material descriptions
(re-checked via `MaterialMatchingEngine`, not just ids), and conflicts
found.

## Trial Workflow Manager

`TrialWorkflowManager.transition()` enforces `TrialStatus`'s
allowed-transition graph:

```
Draft -> Ready for Lab -> Lab Testing -> Approved
                                       -> Rejected -> Draft (rework)
(any non-Archived status) -> Archived
```

Every transition — success or the audit-worthy attempt itself — is
recorded via `TrialAuditRepository` before returning. `history()`
returns the full ordered transition log for a trial.

## Audit Trail Design

Persisted as `Settings` rows (`record_type = 'trial_audit'`, schema
v5 — same rationale and pattern as SPR-DEP-005's rules and
SPR-DEP-006's recommendation history: no dedicated table exists and
the database stays frozen). Captures every required field: Trial ID
(`selected_trial_formula_id`, reusing SPR-DEP-006's column rather than
adding a redundant one), Recommendation ID
(`related_recommendation_id`, new), Timestamp (`created_at`), Status
Change (`status_from`/`status_to`, new), Changed By (`changed_by`,
new — free-text placeholder, no auth exists in this project), Reason
(`reason_text`, reusing SPR-DEP-006's column).

## Engine Flow Diagram

```
FormulaRecommendationRequest
        |
        v
TrialGeneratorEngine
   -> FormulaRecommendationEngine.recommend()  (SPR-DEP-006, unchanged)
   -> TrialValidationEngine.detectDuplicates()
   -> exclude Duplicate Trial / Duplicate Material Combination
   -> flag Near Duplicate / Duplicate Approved Formula
   -> re-rank 1..N
        v
   Top 5 Trial Recommendations
        |
        |-- per recommendation -->
        v                                   v
TrialValidationEngine.validate()   TrialExplanationEngine.explain()
   -> ValidationReport                 -> re-queries RuleEngine for
      (8 pass/fail checks)                failedRules
                                        -> re-queries MaterialMatching
                                           Engine for alternative
                                           descriptions
                                        -> TrialExplanation
        |
        v
TrialComparisonEngine.compare([...FormulaRecommendation])
   -> ComparisonReport (6 rows, differingRows highlighted)

                    (separately, on lab action)
TrialWorkflowManager.transition(trialId, newStatus)
   -> validate against TrialStatus.canTransitionTo
   -> TrialRepository.update(status)
   -> TrialAuditRepository.create(entry)   [every transition logged]
```

## Testing Strategy

1. **Pure-function tests (delivered).**
   `test/trial_status_test.dart` covers the full transition graph
   (valid moves, invalid jumps, terminal Archived, storage-key
   round-trip). Carried forward: `match_type_test.dart`,
   `shade_engine_test.dart`, `rule_evaluator_test.dart`,
   `recommendation_ranker_test.dart`.
2. **Repository-backed tests (still a follow-up, now larger again).**
   `TrialGeneratorEngine`, `TrialValidationEngine.detectDuplicates`,
   `TrialExplanationEngine`, and `TrialWorkflowManager` all need
   seeded `sqflite_common_ffi` data (trials, materials, rules).
   Flagged every sprint since SPR-DEP-004; still open, still offering
   to close it without waiting for a new sprint number.
3. **Workflow integration test (future).** A test that drives a trial
   through the full Draft -> Ready for Lab -> Lab Testing -> Approved
   path and asserts the audit trail has exactly the expected 3
   entries would directly validate "History of every status
   transition must be preserved."

## Self Review

- OK **No UI dependency** — grep-verified zero `screens/` imports
  under `lib/engines/` (all 20 files).
- OK **No direct SQLite access** — grep-verified zero `sqflite`
  imports/`db.*` calls under `lib/engines/`.
- OK **Repository Layer only** — every new class takes repositories
  and/or engine interfaces, never `Database`.
- OK **Rule Engine integration complete** — `TrialExplanationEngine`
  calls `RuleEngine` directly for failed-rule recovery;
  `RecommendationEngine`/`MaterialMatchingEngine` (consumed
  transitively) remain rule-driven from SPR-DEP-005.
- OK **Recommendation Engine integration complete** —
  `TrialGeneratorEngine` consumes `FormulaRecommendationEngine`
  unchanged, adding only duplicate screening on top.
- OK **Duplicate detection working** — all 4 required categories
  implemented with reasons; grep/logic-verified via
  `trial_validation_engine.dart`'s structure (no automated DB-backed
  test yet — see Testing Strategy #2).
- OK **Audit trail complete** — all 6 required fields captured;
  `TrialWorkflowManager` records on every transition, not just
  successful lab-testing-to-approved ones.
- NOT CONFIRMED **Production Ready (compile-verified)** — **cannot
  confirm**, see ENV-001. Static checks (brace/paren balance, import
  resolution, package cross-check, duplicate-class scan,
  unused-catch-clause scan, chemistry/manufacturing-invention scan)
  across all 92 `.dart` files pass clean, including the 9 new/changed
  files this sprint.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** No Flutter SDK in this sandbox.
2. DB filename / SPR-DEP-003 schema / SPR-DEP-005 rule-weight /
   SPR-DEP-006 business-priority items — no response yet.
3. No repository-backed tests for the engine layer — now spans 5
   sprints' worth of engines untested beyond pure-logic pieces. This
   gap is getting large; genuinely recommend prioritizing it soon.

**New this sprint:**
4. **Settings now hosts 4 discriminated record types** (setting,
   rule, recommendation_history, trial_audit) via one `record_type`
   column and an increasingly wide set of reused/overloaded columns
   (e.g. `selected_trial_formula_id` means "the trial this
   recommendation picked" in history rows but "the trial this audit
   entry is about" in audit rows). Functionally correct and clearly
   documented in each file, but this is real accumulating complexity
   in a single physical table — if a future sprint needs a 5th
   record type, it's worth reconsidering whether the database-frozen
   constraint should be revisited instead of adding a 5th meaning to
   already-overloaded columns.
5. **TrialExplanationEngine's failed-rule recovery only covers
   product/shade_family/finish/coverage rule types**, not the six
   material rule types (pigment/dye/mica/pearl/filler/binder) — a
   material line's failed-rule detail isn't surfaced, only
   approved-vs-alternative status. Scoped this way to keep the
   re-computation bounded; flagging rather than silently omitting.
6. **TrialWorkflowManager's transition graph is my design**, not
   specified in the brief beyond the 6 status names. In particular:
   is "Rejected -> Draft for rework" correct, or should Rejected be
   terminal? Is "any status -> Archived" too permissive? These are
   real lab-process decisions in your domain.
7. **No `TrialWorkflowManager` UI hook exists yet** — same pattern as
   SPR-DEP-006's RecommendationHistory: the engine is complete and
   tested logically, but nothing in the app currently calls
   `transition()`.

## Ready For Approval

**Conditionally**, same basis as every prior sprint. Final sign-off
needs `flutter pub get && flutter analyze && flutter test` run
locally. Per the Stop Rule, not continuing to SPR-DEP-008 until you
approve.
