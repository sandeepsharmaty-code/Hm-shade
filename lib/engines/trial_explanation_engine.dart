/// Purpose      : Explains why a recommendation was selected, why its
///                confidence is what it is, which rules matched and
///                failed, what alternatives exist, and what conflicts
///                were found.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, rule_engine.dart,
///                material_matching_engine.dart,
///                recommendation_engine.dart, formula_recommendation_engine.dart,
///                models/shade_model.dart, models/rule_model.dart,
///                repositories/trial_repository.dart,
///                repositories/shade_repository.dart
/// Description  : SPR-DEP-006's RecommendationReasonBuilder produces
///                short reason strings; this goes further, per this
///                sprint's explicit "which rules FAILED" requirement
///                — data RecommendationReasonBuilder never had access
///                to. Rather than modify the already-approved/frozen
///                SPR-DEP-006 classes to carry failedRules through,
///                this engine re-evaluates the same product/
///                shade_family/finish/coverage rule types via
///                RuleEngine (the same facts pattern
///                RecommendationEngine uses) to recover them — a
///                deliberate, documented re-computation rather than a
///                retroactive change to frozen code.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/formula_material_model.dart';
import '../models/rule_model.dart';
import '../models/shade_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'formula_recommendation_engine.dart';
import 'material_matching_engine.dart';
import 'recommendation_conflict.dart';
import 'recommendation_engine.dart';
import 'rule_engine.dart';

/// The full explanation for one recommendation.
@immutable
class TrialExplanation {
  const TrialExplanation({
    required this.whySelected,
    required this.whyConfidence,
    required this.rulesMatched,
    required this.rulesFailed,
    required this.alternatives,
    required this.conflictsFound,
  });

  final String whySelected;
  final String whyConfidence;
  final List<RuleModel> rulesMatched;
  final List<RuleModel> rulesFailed;

  /// Human-readable alternative-material descriptions (not just ids).
  final List<String> alternatives;
  final List<RecommendationConflict> conflictsFound;
}

/// Contract for [TrialExplanationEngine].
abstract class ITrialExplanationEngine {
  Future<TrialExplanation> explain({
    required FormulaRecommendation recommendation,
    required RecommendationRequest request,
  });
}

/// Builds a full explanation for one recommendation.
class TrialExplanationEngine extends EngineBase
    implements ITrialExplanationEngine {
  TrialExplanationEngine({
    required IRuleEngine ruleEngine,
    required IMaterialMatchingEngine materialMatchingEngine,
    required TrialRepository trialRepository,
    required ShadeRepository shadeRepository,
  })  : _ruleEngine = ruleEngine,
        _materialMatchingEngine = materialMatchingEngine,
        _trialRepository = trialRepository,
        _shadeRepository = shadeRepository;

  final IRuleEngine _ruleEngine;
  final IMaterialMatchingEngine _materialMatchingEngine;
  final TrialRepository _trialRepository;
  final ShadeRepository _shadeRepository;

  @override
  String get engineName => 'TrialExplanationEngine';

  @override
  Future<TrialExplanation> explain({
    required FormulaRecommendation recommendation,
    required RecommendationRequest request,
  }) async {
    final String whySelected = _buildWhySelected(recommendation);
    final String whyConfidence = _buildWhyConfidence(recommendation);
    final List<RuleModel> rulesFailed = await _findFailedRules(
      recommendation,
      request,
    );
    final List<String> alternatives = await _describeAlternatives(
      recommendation,
    );

    return TrialExplanation(
      whySelected: whySelected,
      whyConfidence: whyConfidence,
      rulesMatched: recommendation.matchedRules,
      rulesFailed: rulesFailed,
      alternatives: alternatives,
      conflictsFound: recommendation.conflicts,
    );
  }

  String _buildWhySelected(FormulaRecommendation recommendation) {
    final int matchedCount = recommendation.matchedRules.length;
    final String approvedNote =
        recommendation.approvedFormulaReference != null
            ? ' It is linked to a previously approved formula.'
            : '';
    return 'Ranked #${recommendation.rank} with $matchedCount matched '
        'rule${matchedCount == 1 ? '' : 's'} and '
        '${(recommendation.confidenceScore * 100).toStringAsFixed(0)}% '
        'confidence.$approvedNote';
  }

  String _buildWhyConfidence(FormulaRecommendation recommendation) {
    final double score = recommendation.confidenceScore;
    final String level = score >= 0.7
        ? 'high'
        : score >= 0.4
            ? 'moderate'
            : 'low';
    final String altNote = recommendation.alternativeMaterialIds.isEmpty
        ? ''
        : ', and ${recommendation.alternativeMaterialIds.length} material '
            'line(s) needed an alternative, which lowers confidence';
    return 'Confidence is $level (${(score * 100).toStringAsFixed(0)}%) '
        'because ${recommendation.matchedRules.length} of the '
        'configured rules matched this trial$altNote.';
  }

  Future<List<RuleModel>> _findFailedRules(
    FormulaRecommendation recommendation,
    RecommendationRequest request,
  ) async {
    final List<RuleModel> failed = <RuleModel>[];
    try {
      final result1 = await _ruleEngine.evaluate(
        ruleType: RuleType.product,
        facts: <String, Object?>{
          'productId': recommendation.trialFormula.productId,
          'productId_target': request.productId,
        },
      );
      failed.addAll(result1.failedRules);

      final int? shadeId = recommendation.trialFormula.shadeId;
      ShadeModel? shade;
      if (shadeId != null) {
        shade = await _shadeRepository.readById(shadeId);
      }

      if (request.shadeFamily != null) {
        final result2 = await _ruleEngine.evaluate(
          ruleType: RuleType.shadeFamily,
          facts: <String, Object?>{
            'shadeFamily': shade?.shadeFamily,
            'shadeFamily_target': request.shadeFamily,
          },
        );
        failed.addAll(result2.failedRules);
      }

      if (request.finish != null) {
        final result3 = await _ruleEngine.evaluate(
          ruleType: RuleType.finish,
          facts: <String, Object?>{
            'finish': shade?.finish,
            'finish_target': request.finish,
          },
        );
        failed.addAll(result3.failedRules);
      }

      if (request.coverage != null) {
        final result4 = await _ruleEngine.evaluate(
          ruleType: RuleType.coverage,
          facts: <String, Object?>{
            'notes': recommendation.trialFormula.notes,
            'notes_target': request.coverage,
          },
        );
        failed.addAll(result4.failedRules);
      }
    } on RepositoryException catch (error) {
      logDebug('_findFailedRules failed: $error');
    }
    return failed;
  }

  Future<List<String>> _describeAlternatives(
    FormulaRecommendation recommendation,
  ) async {
    if (recommendation.alternativeMaterialIds.isEmpty ||
        recommendation.trialFormula.id == null) {
      return const <String>[];
    }
    try {
      final List<FormulaMaterialModel> lines = await _trialRepository
          .materialsForTrial(recommendation.trialFormula.id!);
      final List<String> descriptions = <String>[];
      for (final FormulaMaterialModel line in lines) {
        if (!recommendation.alternativeMaterialIds.contains(
          line.materialId,
        )) {
          continue;
        }
        final result = await _materialMatchingEngine.matchMaterial(
          materialTable: line.materialTable,
          materialId: line.materialId,
        );
        final int foundCount =
            result.data?.alternativeMaterialIds.length ?? 0;
        descriptions.add(
          foundCount > 0
              ? 'Material line ${line.id} (${line.materialTable}): '
                  '$foundCount alternative(s) found.'
              : 'Material line ${line.id} (${line.materialTable}): '
                  'no alternatives currently available.',
        );
      }
      return descriptions;
    } on RepositoryException catch (error) {
      logDebug('_describeAlternatives failed: $error');
      return const <String>[];
    }
  }
}
