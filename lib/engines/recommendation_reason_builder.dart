/// Purpose      : Builds human-readable "Reason for Recommendation"
///                text from a scored candidate, its matched rules,
///                and any detected conflicts.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : recommendation_engine.dart (EngineRecommendation),
///                recommendation_conflict.dart, models/rule_model.dart
/// Description  : Pure formatting logic — no repository, no
///                database, no UI. Takes already-computed data
///                (matched rules' descriptions, conflict messages,
///                approved-formula reference) and turns it into an
///                ordered list of short, readable sentences. Does not
///                invent explanations beyond what the rules/conflicts
///                already say — this is presentation of existing
///                results, not new business logic.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import '../models/approved_formula_model.dart';
import '../models/rule_model.dart';
import 'recommendation_conflict.dart';
import 'recommendation_engine.dart';

/// Contract for [RecommendationReasonBuilder].
abstract class IRecommendationReasonBuilder {
  List<String> build({
    required EngineRecommendation candidate,
    List<RecommendationConflict> conflicts,
    ApprovedFormulaModel? approvedFormulaReference,
  });
}

/// Builds the ordered reason list shown alongside a recommendation.
class RecommendationReasonBuilder implements IRecommendationReasonBuilder {
  const RecommendationReasonBuilder();

  @override
  List<String> build({
    required EngineRecommendation candidate,
    List<RecommendationConflict> conflicts = const <RecommendationConflict>[],
    ApprovedFormulaModel? approvedFormulaReference,
  }) {
    final List<String> reasons = <String>[];

    reasons.add(
      'Confidence ${(candidate.confidence * 100).toStringAsFixed(0)}% '
      'based on ${candidate.matchedRules.length} matched rule'
      '${candidate.matchedRules.length == 1 ? '' : 's'}.',
    );

    for (final RuleModel rule in candidate.matchedRules) {
      if (rule.description != null && rule.description!.isNotEmpty) {
        reasons.add(rule.description!);
      }
    }

    if (candidate.approvedMaterialIds.isNotEmpty) {
      reasons.add(
        '${candidate.approvedMaterialIds.length} material line(s) use '
        'approved, in-stock materials.',
      );
    }
    if (candidate.alternativeMaterialIds.isNotEmpty) {
      reasons.add(
        '${candidate.alternativeMaterialIds.length} material line(s) '
        'need an alternative material.',
      );
    }

    if (approvedFormulaReference != null) {
      reasons.add(
        'Related to a previously approved formula '
        '(Approved_Formula #${approvedFormulaReference.id}).',
      );
    }

    for (final RecommendationConflict conflict in conflicts) {
      reasons.add('Caution: ${conflict.message}');
    }

    return reasons;
  }
}
