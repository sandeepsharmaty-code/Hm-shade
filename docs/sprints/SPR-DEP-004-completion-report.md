# Sprint Completion Report — SPR-DEP-004

**Objective:** Create the Knowledge Engine Foundation (business-rule
layer only — no image analysis, no AI model, no machine learning).

---

## Updated Project Tree

```
lib/engines/
├── engine_base.dart          (shared debug-logging base)
├── engine_result.dart        (EngineResult<T>: success/failure/
│                               warnings/confidence/messages/
│                               recommendedIds)
├── match_type.dart           (MatchType enum + SearchMatcher:
│                               Exact/Similar/Nearest/Alternative)
├── knowledge_engine.dart     (IKnowledgeEngine + KnowledgeEngine)
├── shade_engine.dart         (IShadeEngine + ShadeEngine)
└── recommendation_engine.dart (IRecommendationEngine +
                                RecommendationEngine + supporting
                                RecommendationRequest/
                                EngineRecommendation)

lib/models/raw_material_model.dart   (new — shared interface,
                                       implemented by the 6
                                       raw-material models so
                                       RecommendationEngine can read
                                       them polymorphically)
```

## Engine Folder

`lib/engines/` — 6 files, all pure Dart + `flutter/foundation.dart`
only (for `kDebugMode`/`debugPrint`/`@immutable`). Zero `sqflite`
imports, zero `screens/` imports — verified by grep (see Self Review).

## Engine Source Code

All 6 files are in the delivered zip in full. Summary of what each
does:

- **EngineBase** — one shared piece of behaviour (debug-only
  logging), nothing more. Engines otherwise differ enough that a
  heavier shared base would be pure indirection.
- **EngineResult\<T\>** — the standard envelope every engine method
  returns: `status` (success/failure), `data`, `warnings`, `messages`,
  `confidenceScore` (0.0–1.0), `recommendedIds`.
- **MatchType / SearchMatcher** — Exact (case-insensitive equality) /
  Similar (substring) / Nearest (≥50% token overlap) / Alternative
  (any token overlap) — pure string comparison, no ML.
- **KnowledgeEngine** — `searchKnowledge`, `searchApprovedFormulas`
  (trials with `status = 'approved'`), `searchApprovedShades` (shades
  with `status = 'approved'`). Reads via `KnowledgeRepository`,
  `TrialRepository`, `ShadeRepository` only.
- **ShadeEngine** — `detectShadeFamily`/`detectUndertone` via
  deterministic hex→HSL→hue-bucket colour math (trusts an
  already-recorded value first, only computes when missing);
  `detectFinish` via name-keyword rules; `validateProductCompatibility`
  via `ShadeRepository`/`ProductRepository` lookups.
- **RecommendationEngine** — `recommend(RecommendationRequest)` scores
  every trial formula belonging to the requested product (base score
  for product match, + status weight, + shade-family/finish/coverage
  matches, − penalty per material line needing an alternative),
  ranks by confidence, returns the top `maxResults` (default 5 —
  matching the original approved workflow's "Generate Five Trial
  Suggestions"). For each material line, dispatches to the correct
  raw-material repository via `RawMaterialModel` (no dynamic calls)
  to classify it approved (active) vs needing an alternative
  (inactive/missing).

## Engine Interfaces

`IKnowledgeEngine`, `IShadeEngine`, `IRecommendationEngine` — abstract
contracts each concrete engine implements. `ServiceLocator` registers
by interface type (`registerSingleton<IShadeEngine>(ShadeEngine(...))`),
so any future caller depends on the interface, not the implementation
(Dependency Inversion).

## Engine Flow Diagram

```
                     ┌─────────────────────┐
                     │   Repository Layer   │
                     │ (Product/Shade/Trial/ │
                     │  Knowledge/6 material │
                     │     repositories)     │
                     └──────────┬───────────┘
                                │  (only access point to SQLite)
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐     ┌────────▼────────┐    ┌─────────▼─────────┐
│ KnowledgeEngine │     │   ShadeEngine    │    │RecommendationEngine│
│                 │     │                  │    │                    │
│ searchKnowledge │     │ detectShadeFamily│    │ recommend(request) │
│ searchApproved  │     │ detectUndertone  │    │  1. filter trials  │
│   Formulas      │     │ detectFinish     │    │     by productId   │
│ searchApproved  │     │ validateProduct  │    │  2. score each:    │
│   Shades        │     │   Compatibility  │    │   product+status+  │
│                 │     │                  │    │   shade/finish/    │
│ uses:           │     │ uses:            │    │   coverage match−  │
│  SearchMatcher  │     │  hex->HSL math    │    │   alt-material     │
│  (Exact/Similar/│     │  (pure functions,│    │   penalty          │
│   Nearest/Alt)  │     │  no repo needed  │    │  3. sort by conf.  │
│                 │     │  for detect*)    │    │  4. take top 5     │
└────────┬────────┘     └────────┬─────────┘    └─────────┬──────────┘
         │                       │                         │
         └───────────────────────┴─────────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │  EngineResult<T>  │
                        │ (status, data,    │
                        │  confidence,      │
                        │  warnings,        │
                        │  messages,        │
                        │  recommendedIds)  │
                        └───────────────────┘
                                 │
                     returned to caller (future
                     screens/use-cases — none of
                     these engines are wired into
                     a screen yet this sprint)
```

Engines never call each other directly in this sprint (no
cross-engine orchestration exists yet) and none are called from a
screen yet — this sprint is foundation only, per the brief ("This
sprint establishes the application's business intelligence layer,"
not "wire it into the UI").

## Testing Strategy

Three tiers, by how much setup each needs:

1. **Pure-function unit tests (delivered this sprint, no DB needed).**
   `test/match_type_test.dart` covers `SearchMatcher.classify`/
   `matchAll` — all 4 `MatchType` outcomes plus ranking. `test/
   shade_engine_test.dart` covers `detectShadeFamily`/`detectUndertone`/
   `detectFinish` with hand-verified hex→HSL arithmetic (worked by
   hand in this report's authoring, since `flutter test` can't run in
   this sandbox — see ENV-001).
2. **Repository-backed engine tests (follow-up, not in this sprint).**
   `KnowledgeEngine.searchApprovedFormulas`/`searchApprovedShades`,
   `ShadeEngine.validateProductCompatibility`, and the whole of
   `RecommendationEngine.recommend` need seeded repository data (an
   in-memory `sqflite_common_ffi` DB with rows inserted, similar to
   `product_repository_test.dart`). Not written this sprint — flagged
   in Known Issues rather than skipped silently.
3. **Golden-value regression (future).** Once real formulation data
   exists, a small fixed dataset with known expected recommendations
   would guard against silent scoring-formula drift. Not applicable
   yet — no real data exists outside this chat.

## Self Review

- ✓ **Repository Layer Only** — every engine constructor takes
  repository instances; none constructs `Database`/`DatabaseHelper`
  itself.
- ✓ **No UI Dependency** — grep-verified zero `screens/` imports
  under `lib/engines/`.
- ✓ **No Direct SQLite** — grep-verified zero `package:sqflite`
  imports and zero `db.query`/`INSERT`/`SELECT`/etc. under
  `lib/engines/`.
- ✓ **No Duplicate Logic** — matching logic lives once in
  `SearchMatcher`, used by `KnowledgeEngine`; material-lookup
  dispatch lives once in `RecommendationEngine` via the
  `RawMaterialModel` interface instead of six near-identical
  if/else branches.
- ✓ **Null Safety** — no `dynamic`, no unguarded `!`.
- ✗ **Production Ready (compile-verified)** — **cannot confirm**, see
  ENV-001 below. Static checks (brace/paren balance, import
  resolution, package cross-check, duplicate-class scan,
  unused-catch-clause scan) across all 64 `.dart` files in the repo
  pass clean, including the 8 new/changed files this sprint.

## Known Issues

**Carried forward, still open:**
1. **ENV-001 (High, unresolved).** No Flutter SDK in this sandbox —
   `match_type_test.dart` and `shade_engine_test.dart` are written and
   hand-verified (HSL arithmetic worked by hand for the 3 colour
   test cases) but never actually executed by `flutter test`.
2. DB filename / column-schema / v1→v2 migration items from
   SPR-DEP-003 — no response yet, still open.

**New this sprint:**
3. **No repository-backed engine tests yet** (Testing Strategy tier
   2 above) — `KnowledgeEngine`'s repository-backed methods,
   `ShadeEngine.validateProductCompatibility`, and all of
   `RecommendationEngine` are untested beyond manual code review.
   Offering to add these as a same-sprint follow-up (doesn't need a
   new sprint number) if you'd rather not wait.
4. **RecommendationEngine's scoring weights are my judgment call**
   (0.3 base + 0.3/0.15 status + 0.2 shade family + 0.1 finish + 0.1
   coverage − 0.05×alt-materials), not something specified in the
   brief. Same flag as the SPR-DEP-003 column-schema item — this is
   a business-rule decision in your domain, not mine; happy to
   retune once you've seen it against real formulas.
5. **Coverage has no dedicated column** — matched against
   `Trial_Formula.notes` free text since the approved schema has no
   `coverage` field. If coverage should be a real column (e.g. an
   enum: Sheer/Medium/Full), that's a schema change requiring your
   approval, not something I added unilaterally.
6. Engines are registered in `ServiceLocator` but **not called from
   any screen yet** — this sprint is foundation-only per the brief.

## Ready For Approval

**Conditionally**, same basis as every prior sprint: complete and
self-reviewed to the limit of what's checkable without a Flutter SDK.
Final sign-off needs `flutter pub get && flutter analyze && flutter
test` run locally. Per the Stop Rule, not continuing to SPR-DEP-005
until you approve.
