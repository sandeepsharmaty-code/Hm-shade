/// Purpose      : Unit tests for RecommendationRanker's composite
///                scoring and business-priority mapping.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/recommendation_ranker.dart,
///                engines/recommendation_engine.dart,
///                models/trial_formula_model.dart
/// Description  : Pure logic — RankingFactors.composite and
///                RecommendationRanker.rank/businessPriorityFor don't
///                touch a repository or database.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/engines/recommendation_engine.dart';
import 'package:hue_muse_shade_ai/engines/recommendation_ranker.dart';
import 'package:hue_muse_shade_ai/models/trial_formula_model.dart';

void main() {
  group('RankingFactors.composite', () {
    test('is the equal-weighted average of all five factors', () {
      const factors = RankingFactors(
        ruleConfidence: 1.0,
        approvedFormulaMatch: 1.0,
        materialAvailability: 1.0,
        alternativeMaterialQuality: 1.0,
        businessPriority: 0.0,
      );
      expect(factors.composite, closeTo(0.8, 0.0001));
    });
  });

  group('RecommendationRanker.businessPriorityFor', () {
    test('ranks approved above in_review above draft', () {
      final approved = RecommendationRanker.businessPriorityFor('approved');
      final inReview = RecommendationRanker.businessPriorityFor('in_review');
      final draft = RecommendationRanker.businessPriorityFor('draft');
      expect(approved, greaterThan(inReview));
      expect(inReview, greaterThan(draft));
    });
  });

  group('RecommendationRanker.rank', () {
    test('sorts candidates by composite score descending and assigns rank',
        () {
      const ranker = RecommendationRanker();

      final low = EngineRecommendation(
        trialFormula: const TrialFormulaModel(
          id: 1,
          name: 'Low',
          trialCode: 'T-1',
        ),
        confidence: 0.2,
      );
      final high = EngineRecommendation(
        trialFormula: const TrialFormulaModel(
          id: 2,
          name: 'High',
          trialCode: 'T-2',
        ),
        confidence: 0.9,
      );

      final result = ranker.rank(
        candidates: <EngineRecommendation>[low, high],
        factorsByCandidate: <EngineRecommendation, RankingFactors>{
          low: const RankingFactors(
            ruleConfidence: 0.2,
            approvedFormulaMatch: 0,
            materialAvailability: 0.2,
            alternativeMaterialQuality: 0.2,
            businessPriority: 0.2,
          ),
          high: const RankingFactors(
            ruleConfidence: 0.9,
            approvedFormulaMatch: 1,
            materialAvailability: 0.9,
            alternativeMaterialQuality: 0.9,
            businessPriority: 0.9,
          ),
        },
      );

      expect(result.first.candidate.trialFormula.name, 'High');
      expect(result.first.rank, 1);
      expect(result.last.candidate.trialFormula.name, 'Low');
      expect(result.last.rank, 2);
    });
  });
}
