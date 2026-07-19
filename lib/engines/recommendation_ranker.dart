/// Purpose      : Ranks scored candidates using the five factors this
///                sprint's brief requires.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : recommendation_engine.dart (EngineRecommendation)
/// Description  : Rule Confidence, Approved Formula Match, Material
///                Availability, and Alternative Material Quality are
///                each already-computed 0.0–1.0 scores from earlier
///                pipeline stages (RuleEngine, KnowledgeEngine,
///                MaterialMatchingEngine) — this class only combines
///                them; it does not compute any of them itself, so it
///                has nothing SQLite- or UI-related to depend on.
///                Business Priority is a simple, transparent
///                trial-status ordinal (approved > in_review > draft)
///                — a ranking tie-breaker convention, not a domain
///                "business rule" in the RuleEngine sense (see Known
///                Issues in the SPR-DEP-006 report for why this
///                wasn't also routed through RuleEngine).
///                Combination is an equal-weighted average — a
///                transparent, documented algorithm, not hidden
///                scoring logic.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'recommendation_engine.dart';

/// The five ranking inputs for one candidate, each 0.0–1.0.
@immutable
class RankingFactors {
  const RankingFactors({
    required this.ruleConfidence,
    required this.approvedFormulaMatch,
    required this.materialAvailability,
    required this.alternativeMaterialQuality,
    required this.businessPriority,
  });

  final double ruleConfidence;
  final double approvedFormulaMatch;
  final double materialAvailability;
  final double alternativeMaterialQuality;
  final double businessPriority;

  /// Equal-weighted average of all five factors.
  double get composite =>
      (ruleConfidence +
          approvedFormulaMatch +
          materialAvailability +
          alternativeMaterialQuality +
          businessPriority) /
      5.0;
}

/// One candidate's final position after ranking.
@immutable
class RankedRecommendation {
  const RankedRecommendation({
    required this.candidate,
    required this.rank,
    required this.factors,
  });

  final EngineRecommendation candidate;

  /// 1-based position, 1 = highest ranked.
  final int rank;
  final RankingFactors factors;
}

/// Contract for [RecommendationRanker].
abstract class IRecommendationRanker {
  List<RankedRecommendation> rank({
    required List<EngineRecommendation> candidates,
    required Map<EngineRecommendation, RankingFactors> factorsByCandidate,
  });
}

/// Sorts candidates by their composite ranking factor and assigns
/// 1-based ranks.
class RecommendationRanker implements IRecommendationRanker {
  const RecommendationRanker();

  @override
  List<RankedRecommendation> rank({
    required List<EngineRecommendation> candidates,
    required Map<EngineRecommendation, RankingFactors> factorsByCandidate,
  }) {
    final List<EngineRecommendation> sorted = List<EngineRecommendation>.of(
      candidates,
    );
    sorted.sort((EngineRecommendation a, EngineRecommendation b) {
      final double scoreA = factorsByCandidate[a]?.composite ?? 0.0;
      final double scoreB = factorsByCandidate[b]?.composite ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return <RankedRecommendation>[
      for (int i = 0; i < sorted.length; i++)
        RankedRecommendation(
          candidate: sorted[i],
          rank: i + 1,
          factors: factorsByCandidate[sorted[i]] ??
              const RankingFactors(
                ruleConfidence: 0,
                approvedFormulaMatch: 0,
                materialAvailability: 0,
                alternativeMaterialQuality: 0,
                businessPriority: 0,
              ),
        ),
    ];
  }

  /// Maps a Trial_Formula `status` to a business-priority ordinal.
  /// Exposed as a static helper so FormulaRecommendationEngine builds
  /// [RankingFactors] consistently without duplicating this mapping.
  static double businessPriorityFor(String status) {
    switch (status) {
      case 'approved':
        return 1.0;
      case 'in_review':
        return 0.6;
      case 'draft':
        return 0.3;
      default:
        return 0.1;
    }
  }
}
