# Hue Muse Shade AI — Engine/API Documentation

All 23 engines live in `lib/engines/`. Each has an interface
(`IXxxEngine`) and one concrete implementation, registered by
interface type in `ServiceLocator` (see `lib/main.dart`).

## Foundation
- **`EngineBase`** — shared debug-only logging (`logDebug`, guarded by
  `kDebugMode`).
- **`EngineResult<T>`** — standard success/failure/warnings/confidence/
  messages/recommendedIds envelope every engine returns.
- **`SearchMatcher`** — Exact/Similar/Nearest/Alternative text
  matching, used across `KnowledgeEngine`, `ShadeMatchingEngine`,
  `MaterialMatchingEngine`, `TrialValidationEngine`.

## Knowledge & Shade
- **`KnowledgeEngine`** — `searchKnowledge`, `searchApprovedFormulas`,
  `searchApprovedShades`.
- **`ShadeEngine`** — `detectShadeFamily`, `detectUndertone`,
  `detectFinish` (hex-colour-based, pure math), and
  `validateProductCompatibility` (repository-backed).

## Rule Engine
- **`RuleCondition`/`RuleOperator`** — evaluation-time condition
  shape (equals/notEquals/contains), with a dynamic-target convention
  for request-relative comparisons (empty `conditionValue` means
  "compare against a `${key}_target` fact").
- **`RuleEvaluator`** — pure `evaluate(condition, facts) -> bool`.
- **`RuleResult`** — success/confidence/matchedRules/failedRules/
  alternativeSuggestions/reasonMessages.
- **`RuleEngine`** — `evaluate({ruleType, facts}) -> RuleResult`,
  reads active rules via `RuleRepository`, weighted by
  matched-weight/total-absolute-weight.

## Matching
- **`ShadeMatchingEngine`** — `matchShades(query, shadeFamily?,
  finish?)`, blends `SearchMatcher` text score with `RuleEngine`
  results.
- **`MaterialMatchingEngine`** — `matchMaterial({materialTable,
  materialId})` across all six raw-material tables via one dispatch
  map (no per-table duplication), `prioritizeApproved()`.

## Recommendation pipeline
- **`RecommendationEngine`** — `recommend(RecommendationRequest) ->
  List<EngineRecommendation>`, fully rule-driven (zero hardcoded
  weights, grep-verified).
- **`RecommendationConflictDetector`** — 6 conflict categories
  (product/shade mismatch, inactive/missing material, disabled rule,
  low confidence).
- **`RecommendationReasonBuilder`**, **`RecommendationFilter`**,
  **`RecommendationRanker`** — presentation/filtering/ranking of
  already-computed scores.
- **`RecommendationHistory`** — records/retrieves recommendation
  events.
- **`FormulaRecommendationEngine`** — top-level orchestrator combining
  all of the above, `recommend(FormulaRecommendationRequest) ->
  List<FormulaRecommendation>`.

## Trial workflow
- **`TrialGeneratorEngine`** — wraps `FormulaRecommendationEngine`,
  adds duplicate screening.
- **`TrialValidationEngine`** — `validate()` (8 pass/fail checks),
  `detectDuplicates()` (4 categories).
- **`TrialComparisonEngine`** — `compare()`, field-by-field diff
  across recommendations.
- **`TrialExplanationEngine`** — `explain()`, including failed-rule
  recovery (re-queries `RuleEngine` since the frozen
  `EngineRecommendation` shape doesn't carry failed rules).
- **`TrialWorkflowManager`** — `transition()` (validated against
  `TrialStatus`'s allowed-transition graph, records to
  `TrialAuditRepository`), `history()`.

## Image Intelligence
- **`ColorConversionEngine`** — RGB/HEX/HSV/HSL/XYZ/CIELAB, pure
  deterministic sRGB/D65 formulas.
- **`ImageProcessor`** — decode + deterministic downscale
  (`package:image`, pure Dart, no AI/ML).
- **`ColorSamplingEngine`** — Single Pixel/Grid/Multi-point sampling,
  noise reduction (3x3 mean filter), transparent-pixel exclusion.
- **`DominantColorEngine`** — deterministic colour quantization +
  frequency counting (not k-means).
- **`ColorExtractionEngine`** — orchestrates sampling + dominant +
  average colour + CIELAB colour-distance data.
- **`ColorProfileBuilder`** — assembles the final `ColorProfile`
  (id, timestamp, dominant colours, distribution, average colour,
  brightness, saturation, lightness, contrast estimate).
- **`ImageAnalysisEngine`** — top-level orchestrator:
  `analyzeImage(path)`, `analyzeAndRecommend(path, productId)`
  (bridges into `TrialGeneratorEngine`).

## Design principles that hold across all 23

- Constructor-injected dependencies only — nothing is looked up
  dynamically inside an engine.
- Every engine reads through the Repository Layer or another engine,
  never SQLite directly (grep-verified every sprint).
- No engine imports anything from `lib/screens/`.
- Confidence/weight values are configurable (`RuleModel.weight`) where
  the brief asked for "no hardcoded business rules"; a few
  ranking-combination and detection-threshold constants remain
  code-level defaults, explicitly flagged as such in their sprint
  reports rather than silently presented as configurable.
