/// Purpose      : Generates the Top 5 Trial Recommendations,
///                filtering out duplicates before finalizing the set.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart,
///                formula_recommendation_engine.dart,
///                trial_validation_engine.dart, models/trial_formula_model.dart
/// Description  : Thin orchestration layer over
///                FormulaRecommendationEngine (SPR-DEP-006, listed as
///                this sprint's own "Formula Recommendation Engine"
///                input) — does not reimplement scoring/ranking, only
///                adds duplicate screening on top: exact Duplicate
///                Trial and Duplicate Material Combination results
///                are excluded from the final set; Near Duplicate
///                Trial results are kept but flagged via a warning,
///                since a near-duplicate might still be a genuinely
///                distinct, useful option.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import '../models/trial_formula_model.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'formula_recommendation_engine.dart';
import 'trial_validation_engine.dart';

/// Contract for [TrialGeneratorEngine].
abstract class ITrialGeneratorEngine {
  Future<EngineResult<List<FormulaRecommendation>>> generateTopFive(
    FormulaRecommendationRequest request,
  );
}

/// Produces a duplicate-screened Top 5 trial recommendation set.
class TrialGeneratorEngine extends EngineBase
    implements ITrialGeneratorEngine {
  TrialGeneratorEngine({
    required IFormulaRecommendationEngine formulaRecommendationEngine,
    required ITrialValidationEngine validationEngine,
  })  : _formulaRecommendationEngine = formulaRecommendationEngine,
        _validationEngine = validationEngine;

  final IFormulaRecommendationEngine _formulaRecommendationEngine;
  final ITrialValidationEngine _validationEngine;

  @override
  String get engineName => 'TrialGeneratorEngine';

  @override
  Future<EngineResult<List<FormulaRecommendation>>> generateTopFive(
    FormulaRecommendationRequest request,
  ) async {
    final EngineResult<List<FormulaRecommendation>> baseResult =
        await _formulaRecommendationEngine.recommend(request);

    if (!baseResult.isSuccess ||
        baseResult.data == null ||
        baseResult.data!.isEmpty) {
      return baseResult;
    }

    final List<FormulaRecommendation> candidates = baseResult.data!;
    final List<TrialFormulaModel> candidateTrials = <TrialFormulaModel>[
      for (final FormulaRecommendation r in candidates) r.trialFormula,
    ];
    final List<DuplicateFinding> duplicates = await _validationEngine
        .detectDuplicates(candidateTrials);

    final Set<int> excludedIds = <int>{};
    final List<String> warnings = <String>[];
    for (final DuplicateFinding finding in duplicates) {
      switch (finding.type) {
        case DuplicateType.duplicateTrial:
        case DuplicateType.duplicateMaterialCombination:
          excludedIds.add(finding.trialFormulaId);
          warnings.add(
            'Excluded trial #${finding.trialFormulaId}: ${finding.reason}',
          );
        case DuplicateType.nearDuplicateTrial:
        case DuplicateType.duplicateApprovedFormula:
          warnings.add(
            'Trial #${finding.trialFormulaId} flagged: ${finding.reason}',
          );
      }
    }

    final List<FormulaRecommendation> filtered = candidates
        .where(
          (FormulaRecommendation r) =>
              r.trialFormula.id == null ||
              !excludedIds.contains(r.trialFormula.id),
        )
        .toList();

    final List<FormulaRecommendation> top = filtered
        .take(request.maxResults)
        .toList();
    final List<FormulaRecommendation> reRanked = <FormulaRecommendation>[
      for (int i = 0; i < top.length; i++) _withRank(top[i], i + 1),
    ];

    return EngineResult<List<FormulaRecommendation>>.success(
      data: reRanked,
      confidenceScore:
          reRanked.isEmpty ? 0.0 : reRanked.first.confidenceScore,
      recommendedIds: <int>[
        for (final FormulaRecommendation r in reRanked)
          if (r.trialFormula.id != null) r.trialFormula.id!,
      ],
      warnings: warnings,
      messages: baseResult.messages,
    );
  }

  FormulaRecommendation _withRank(FormulaRecommendation r, int rank) {
    return FormulaRecommendation(
      trialFormula: r.trialFormula,
      rank: rank,
      confidenceScore: r.confidenceScore,
      reasons: r.reasons,
      matchedRules: r.matchedRules,
      alternativeMaterialIds: r.alternativeMaterialIds,
      conflicts: r.conflicts,
      approvedFormulaReference: r.approvedFormulaReference,
    );
  }
}
