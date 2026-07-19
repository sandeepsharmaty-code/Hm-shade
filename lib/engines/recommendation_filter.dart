/// Purpose      : Filters scored candidates before ranking.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : recommendation_engine.dart (EngineRecommendation),
///                recommendation_conflict.dart
/// Description  : Excludes candidates with severe conflicts (Product
///                Mismatch by default) or confidence below a
///                caller-supplied floor. Thresholds are parameters,
///                not constants baked into this class, so the caller
///                (FormulaRecommendationEngine) controls filtering
///                policy rather than it being hardcoded here.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'recommendation_conflict.dart';
import 'recommendation_engine.dart';

/// Contract for [RecommendationFilter].
abstract class IRecommendationFilter {
  List<EngineRecommendation> apply({
    required List<EngineRecommendation> candidates,
    required Map<EngineRecommendation, List<RecommendationConflict>>
        conflictsByCandidate,
    double minimumConfidence,
    bool excludeProductMismatch,
  });
}

/// Excludes candidates that fail baseline acceptance criteria.
class RecommendationFilter implements IRecommendationFilter {
  const RecommendationFilter();

  @override
  List<EngineRecommendation> apply({
    required List<EngineRecommendation> candidates,
    required Map<EngineRecommendation, List<RecommendationConflict>>
        conflictsByCandidate,
    double minimumConfidence = 0.0,
    bool excludeProductMismatch = true,
  }) {
    return candidates.where((EngineRecommendation candidate) {
      if (candidate.confidence < minimumConfidence) {
        return false;
      }
      if (excludeProductMismatch) {
        final List<RecommendationConflict> conflicts =
            conflictsByCandidate[candidate] ??
                const <RecommendationConflict>[];
        final bool hasProductMismatch = conflicts.any(
          (RecommendationConflict c) =>
              c.type == ConflictType.productMismatch,
        );
        if (hasProductMismatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}
