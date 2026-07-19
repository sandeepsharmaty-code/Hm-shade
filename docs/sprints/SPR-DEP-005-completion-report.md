# Sprint Completion Report — SPR-DEP-005

**Objective:** Rule Engine Foundation + Shade Matching Engine +
Material Matching Engine (deterministic business-rule processing —
not AI, not ML).

---

## Updated Project Tree

```
lib/models/rule_model.dart              (new — RuleModel, RuleType)
lib/repositories/rule_repository.dart   (new)
lib/repositories/base_repository.dart   (changed — filter() gained
                                          an optional orderBy param)

lib/engines/
├── rule_condition.dart        (new — RuleCondition, RuleOperator)
├── rule_evaluator.dart        (new — pure evaluate())
├── rule_result.dart           (new — RuleResult)
├── rule_engine.dart           (new — IRuleEngine + RuleEngine)
├── shade_matching_engine.dart (new — IShadeMatchingEngine +
│                                ShadeMatchingEngine)
├── material_matching_engine.dart (new — IMaterialMatchingEngine +
│                                   MaterialMatchingEngine)
└── recommendation_engine.dart (rewritten — consumes RuleEngine +
                                 MaterialMatchingEngine; zero
                                 hardcoded weights)

lib/core/database/database_helper.dart  (v3 schema — Settings gains
                                          rule-storage columns +
                                          default rule seeding)
```

## Rule Engine Source Code

- **RuleModel** (data layer) — persisted as `Settings` rows with
  `record_type = 'rule'` (see below for why). Carries `priority`,
  `weight`, `ruleVersion`, and reuses `is_active` for enabled/disabled
  — the full Rule Priority requirement set.
- **RuleCondition/RuleOperator** (engine layer) — evaluation-time
  shape derived from a `RuleModel`, kept separate so `models/` never
  depends on `engines/` (correct Clean Architecture direction).
- **RuleEvaluator** — pure `evaluate(condition, facts)`. Two
  comparison modes: fixed-value (`condition.value` non-empty, e.g.
  "isActive equals true") and dynamic-target (`condition.value`
  empty — compares against a caller-supplied `'${key}_target'` fact,
  used for request-relative rules like "category equals whatever was
  requested").
- **RuleResult** — success, confidenceScore, matchedRules,
  failedRules, alternativeSuggestions, recommendedMaterialIds,
  reasonMessages — every field this sprint's brief lists.
- **RuleEngine** — `evaluate({ruleType, facts})`: reads active rules
  of one type via `RuleRepository.findByRuleType` (priority-ordered),
  evaluates each with `RuleEvaluator`, computes confidence as
  matched-weight / total-absolute-weight (so a negative-weight
  penalty rule, like "Alternative Material Needed", correctly lowers
  confidence rather than being ignored).

### Where rules are stored — flagged decision

The approved 14-table schema has no dedicated rules table, and this
sprint's brief says the database stays frozen (no new tables). Rules
are stored as `Settings` rows, discriminated by a new
`record_type` column ('rule' vs 'setting'), added in schema v3.
**This is a judgment call, not a unilateral schema redesign** — see
Known Issues for the alternative if you'd rather have a dedicated
table (which would need de-freezing the database).

## Shade Matching Engine

`ShadeMatchingEngine.matchShades(query, shadeFamily?, finish?)`:
1. Text-matches every active shade's name/code/family against `query`
   via the existing `SearchMatcher` (SPR-DEP-004) — Exact/Similar/
   Nearest/Alternative, not reimplemented.
2. For each text match, evaluates `shade_family`/`finish` rules
   through `RuleEngine` if the caller supplied those criteria.
3. Blends text-match score and rule confidence (simple average) into
   one `confidence` per shade.
4. Builds `reasons` (Reason Generation) from the match-type label plus
   every matched rule's description, and `matchedRules` (Matched Rule
   List) from the rule evaluations.

## Material Matching Engine

`MaterialMatchingEngine.matchMaterial({materialTable, materialId})`:
one method dispatches across all six raw-material tables via the
`RawMaterialModel` interface (SPR-DEP-004) — not six near-identical
methods. Looks up the material, evaluates the matching rule type
(`pigment`/`dye`/`mica`/`pearl`/`filler`/`binder`), and — only when
the material is inactive — evaluates the `alternative_material` rule
and searches active materials in the same table via `SearchMatcher`
for the top-3 name-similar alternatives. `prioritizeApproved()`
implements Approved Material Priority: approved materials sort first,
then by confidence.

## RecommendationEngine — now rule-driven

Confirmed by grep: **zero hardcoded confidence-weight literals remain
in `recommendation_engine.dart`.** Every contribution to a
recommendation's confidence score now comes from a `RuleModel.weight`
read through `RuleEngine`/`MaterialMatchingEngine`, not an inline
number. Constructor dependencies changed from the six raw-material
repositories directly to `IRuleEngine` + `IMaterialMatchingEngine` —
this is the mandated change ("RecommendationEngine must consume
RuleEngine results"), not an unrequested redesign.

## Rule Flow Diagram

```
┌──────────────┐     ┌───────────────────┐
│ RuleRepository│────▶│  Settings table    │  (record_type='rule')
│ (Data Layer)  │     │  12 seeded rules,   │
└──────┬────────┘     │  one per rule type  │
       │              └────────────────────┘
       │ findByRuleType(type) -> active, priority DESC
       ▼
┌──────────────┐
│  RuleEngine   │  evaluate({ruleType, facts})
│               │   for each rule:
│               │     RuleCondition.fromRuleModel(rule)
│               │     RuleEvaluator.evaluate(condition, facts)
│               │     match? -> matchedWeight += rule.weight
│               │     always -> totalAbsWeight += |rule.weight|
│               │  confidence = matchedWeight / totalAbsWeight
└──────┬────────┘
       │ RuleResult (success, confidence, matchedRules,
       │             failedRules, reasonMessages, alternatives)
       │
   ┌───┴────────────────────────┬─────────────────────────────┐
   ▼                            ▼                              ▼
┌────────────────────┐  ┌──────────────────────┐   ┌─────────────────────┐
│ ShadeMatchingEngine │  │MaterialMatchingEngine │   │ RecommendationEngine │
│ (shade_family,      │  │ (pigment/dye/mica/     │   │  calls RuleEngine    │
│  finish rule types)  │  │  pearl/filler/binder/  │   │  directly for        │
│                      │  │  alternative_material) │   │  product/shade_family│
│ blends with          │  │                        │   │  /finish/coverage,   │
│ SearchMatcher score  │  │ + SearchMatcher for     │   │  and calls           │
│                      │  │   alternative search    │   │  MaterialMatchingEngine│
└──────────────────────┘  └────────────────────────┘   │  per Formula_Material │
                                                          │  line. No weights    │
                                                          │  hardcoded here.     │
                                                          └───────────────────────┘
```

## Testing Strategy

1. **Pure-function tests (delivered).** `test/rule_evaluator_test.dart`
   covers both comparison modes and all 3 operators — no DB needed.
   `test/match_type_test.dart`/`shade_engine_test.dart` carried
   forward from SPR-DEP-004, still valid (SearchMatcher/ShadeEngine's
   detect* methods are unchanged).
2. **RuleEngine / matching-engine tests (follow-up, not this sprint).**
   Need a seeded `sqflite_common_ffi` database with real `Settings`
   rule rows, similar to `product_repository_test.dart`'s pattern.
   Flagged in Known Issues rather than skipped silently — same as
   SPR-DEP-004's tier-2 gap, now also covering `RuleEngine`,
   `ShadeMatchingEngine`, `MaterialMatchingEngine`, and the rewritten
   `RecommendationEngine`.
3. **Seed-data regression (future).** Once real rule tuning happens,
   a fixed-rules-fixed-facts golden test would catch accidental
   scoring drift from a rule edit. Not applicable yet.

## Self Review

- ✓ **No UI dependency** — grep-verified zero `screens/` imports
  under `lib/engines/` (all 9 files, old and new).
- ✓ **No direct SQLite access** — grep-verified zero `sqflite`
  imports and zero `db.*`/SQL-literal calls under `lib/engines/`.
- ✓ **Repository Layer only** — `RuleEngine` takes `RuleRepository`;
  `ShadeMatchingEngine`/`MaterialMatchingEngine`/`RecommendationEngine`
  take repositories and/or engine interfaces, never `Database`.
- ✓ **Rules configurable** — every rule is a `Settings` row with
  `priority`/`weight`/`is_active`/`rule_version`, readable and
  writable through `RuleRepository`'s full CRUD (inherited from
  `BaseSqliteRepository`) — not compiled constants.
- ✓ **No duplicated logic** — text matching still lives only in
  `SearchMatcher` (reused, not reimplemented); material-table dispatch
  still lives only in the `RawMaterialModel`-typed maps (one
  implementation, both `RecommendationEngine`-via-
  `MaterialMatchingEngine` and `MaterialMatchingEngine` itself use it
  through the single engine, not two copies).
- ✗ **Production Ready (compile-verified)** — **cannot confirm**, see
  ENV-001. Static checks (brace/paren balance, import resolution,
  package cross-check, duplicate-class scan, unused-catch-clause
  scan) across all 73 `.dart` files pass clean, including the 8
  new/changed files this sprint.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** No Flutter SDK in this sandbox.
   `rule_evaluator_test.dart` is hand-verified logically but never
   run by `flutter test`.
2. DB filename / SPR-DEP-003 column-schema / v1→v2 migration items —
   no response yet.
3. SPR-DEP-004's scoring-weight judgment call is **superseded** by
   this sprint — weights now live in `Settings` rows (see
   `_defaultRuleSeeds` in `database_helper.dart`), still my starting
   guess, but now something you can edit directly through
   `RuleRepository` without a code change.

**New this sprint:**
4. **Rules stored in `Settings`, not a dedicated table** (see "Where
   rules are stored" above) — this is the single biggest judgment
   call in this sprint. If you'd rather have a real `Rule_Master`
   table, that requires de-freezing the database for one more table;
   I did not do that unilaterally since both this sprint and prior
   ones explicitly said the database stays frozen.
5. **No repository-backed tests for RuleEngine/ShadeMatchingEngine/
   MaterialMatchingEngine/RecommendationEngine** — same gap pattern
   as SPR-DEP-004, now larger. Offering to close this as a same-sprint
   follow-up if preferred over waiting for SPR-DEP-006.
6. **The 12 seeded rules' weights/conditions are my starting
   configuration**, not yours — genuinely editable now (that was the
   point of this sprint), but the *initial* values in
   `_defaultRuleSeeds` are still a judgment call in your domain.
7. **RuleEvaluator's dynamic-target convention** (`'${key}_target'`
   facts) is new, project-specific plumbing invented to make one
   persisted rule reusable across different requests. It's documented
   in the file header and covered by tests, but it's a design decision
   worth your awareness since nothing in the brief specified how
   request-relative comparisons should work.

## Ready For Approval

**Conditionally**, same basis as every prior sprint. Final sign-off
needs `flutter pub get && flutter analyze && flutter test` run
locally. Per the Stop Rule, not continuing to SPR-DEP-006 until you
approve.
