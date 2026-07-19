/// Purpose      : Business-rule engine that ranks trial formulas as
///                recommendations for a product/shade/finish request.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : engine_base.dart, engine_result.dart, rule_engine.dart,
///                material_matching_engine.dart,
///                repositories/trial_repository.dart,
///                repositories/shade_repository.dart
/// Description  : Generates recommendations from Product, Shade
///                Family, Finish, Coverage, Approved Materials, and
///                Alternative Materials, ranked by a confidence score
///                that RuleEngine computes — no scoring weights are
///                hardcoded in this file (SPR-DEP-005's "NO
///                HARDCODED BUSINESS RULES" requirement). Reads only
///                through the Repository Layer plus the RuleEngine/
///                MaterialMatchingEngine interfaces. Defaults to a
///                top-5 result cap, matching the original approved
///                workflow's "Generate Five Trial Suggestions" step.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation. Scoring weights were
///           hardcoded inline in this file at that point.
///   2.0.0 - SPR-DEP-005 - Refactored to consume RuleEngine
///           (product/shade_family/finish/coverage rule types) and
///           MaterialMatchingEngine (material-line approval/
///           alternative logic) instead of embedding weights here.
///           Constructor dependencies changed: the six raw-material
///           repositories were replaced by IRuleEngine +
///           IMaterialMatchingEngine.
library;

import 'package:flutter/foundation.dart';

import '../models/formula_material_model.dart';
import '../models/rule_model.dart';
import '../models/trial_formula_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'material_matching_engine.dart';
import 'rule_engine.dart';
import 'rule_result.dart';

/// Input criteria for [RecommendationEngine.recommend].
@immutable
class RecommendationRequest {
  const RecommendationRequest({
    required this.productId,
    this.shadeFamily,
    this.finish,
    this.coverage,
    this.maxResults = 5,
  });

  /// Foreign key to Product_Master.id — required; recommendations are
  /// always scoped to one product.
  final int productId;

  /// Desired shade family, e.g. "Red" — optional matching hint.
  final String? shadeFamily;

  /// Desired finish, e.g. "Matte" — optional matching hint.
  final String? finish;

  /// Desired coverage, e.g. "Full", "Sheer" — optional matching hint,
  /// compared against each trial's free-text notes since there is no
  /// dedicated coverage column in the approved schema.
  final String? coverage;

  /// Maximum number of ranked recommendations to return. Defaults to
  /// 5, matching the approved workflow's "Generate Five Trial
  /// Suggestions" step.
  final int maxResults;
}

/// One ranked recommendation: a candidate trial formula plus its
/// confidence score and material-availability breakdown.
@immutable
class EngineRecommendation {
  const EngineRecommendation({
    required this.trialFormula,
    required this.confidence,
    this.approvedMaterialIds = const <int>[],
    this.alternativeMaterialIds = const <int>[],
    this.matchedRules = const <RuleModel>[],
    this.notes = const <String>[],
  });

  final TrialFormulaModel trialFormula;
  final double confidence;

  /// Formula_Material rows whose referenced raw material is active
  /// (available/approved for use).
  final List<int> approvedMaterialIds;

  /// Formula_Material rows whose referenced raw material is missing
  /// or inactive, and needs an alternative substituted.
  final List<int> alternativeMaterialIds;

  /// Every rule (across all evaluated rule types) that matched for
  /// this recommendation — the "Matched Rule List" requirement.
  final List<RuleModel> matchedRules;

  final List<String> notes;
}

/// Contract for [RecommendationEngine].
abstract class IRecommendationEngine {
  Future<EngineResult<List<EngineRecommendation>>> recommend(
    RecommendationRequest request,
  );
}

/// Ranks candidate trial formulas for a recommendation request by
/// consuming RuleEngine and MaterialMatchingEngine results.
class RecommendationEngine extends EngineBase
    implements IRecommendationEngine {
  RecommendationEngine({
    required TrialRepository trialRepository,
    required ShadeRepository shadeRepository,
    required IRuleEngine ruleEngine,
    required IMaterialMatchingEngine materialMatchingEngine,
  })  : _trialRepository = trialRepository,
        _shadeRepository = shadeRepository,
        _ruleEngine = ruleEngine,
        _materialMatchingEngine = materialMatchingEngine;

  final TrialRepository _trialRepository;
  final ShadeRepository _shadeRepository;
  final IRuleEngine _ruleEngine;
  final IMaterialMatchingEngine _materialMatchingEngine;

  @override
  String get engineName => 'RecommendationEngine';

  @override
  Future<EngineResult<List<EngineRecommendation>>> recommend(
    RecommendationRequest request,
  ) async {
    try {
      final List<TrialFormulaModel> candidates = await _trialRepository
          .filter(<String, Object?>{'product_id': request.productId});

      if (candidates.isEmpty) {
        return EngineResult<List<EngineRecommendation>>.success(
          data: const <EngineRecommendation>[],
          confidenceScore: 0.0,
          messages: const <String>[
            'No trial formulas exist yet for this product.',
          ],
        );
      }

      final List<EngineRecommendation> scored = <EngineRecommendation>[];
      for (final TrialFormulaModel trial in candidates) {
        scored.add(await _score(trial, request));
      }

      scored.sort(
        (EngineRecommendation a, EngineRecommendation b) =>
            b.confidence.compareTo(a.confidence),
      );

      final List<EngineRecommendation> top =
          scored.take(request.maxResults).toList();
      final List<int> ids = <int>[
        for (final EngineRecommendation rec in top)
          if (rec.trialFormula.id != null) rec.trialFormula.id!,
      ];

      return EngineResult<List<EngineRecommendation>>.success(
        data: top,
        confidenceScore: top.isEmpty ? 0.0 : top.first.confidence,
        recommendedIds: ids,
        warnings: top.length < scored.length
            ? <String>[
                '${scored.length - top.length} lower-ranked candidate(s) '
                'omitted (maxResults: ${request.maxResults}).',
              ]
            : const <String>[],
      );
    } on RepositoryException catch (error) {
      logDebug('recommend failed: $error');
      return EngineResult<List<EngineRecommendation>>.failure(
        message: 'Unable to generate recommendations.',
      );
    }
  }

  Future<EngineRecommendation> _score(
    TrialFormulaModel trial,
    RecommendationRequest request,
  ) async {
    final List<String> notes = <String>[];
    final List<RuleModel> matchedRules = <RuleModel>[];
    double totalAbsWeight = 0.0;
    double matchedWeight = 0.0;

    // Product rule — confirms the candidate belongs to the requested
    // product (RuleEngine-driven, not an inline weight).
    final RuleResult productResult = await _ruleEngine.evaluate(
      ruleType: RuleType.product,
      facts: <String, Object?>{
        'productId': trial.productId,
        'productId_target': request.productId,
      },
    );
    matchedRules.addAll(productResult.matchedRules);
    totalAbsWeight += _absWeightOf(productResult);
    matchedWeight += _matchedWeightOf(productResult);

    ShadeFacts? shadeFacts;
    if (trial.shadeId != null) {
      final shade = await _shadeRepository.readById(trial.shadeId!);
      if (shade != null) {
        shadeFacts = ShadeFacts(
          shadeFamily: shade.shadeFamily,
          finish: shade.finish,
        );
      } else {
        notes.add('Linked shade ${trial.shadeId} not found.');
      }
    } else {
      notes.add('Trial has no linked shade to match family/finish against.');
    }

    if (request.shadeFamily != null && shadeFacts != null) {
      final result = await _ruleEngine.evaluate(
        ruleType: RuleType.shadeFamily,
        facts: <String, Object?>{
          'shadeFamily': shadeFacts.shadeFamily,
          'shadeFamily_target': request.shadeFamily,
        },
      );
      matchedRules.addAll(result.matchedRules);
      totalAbsWeight += _absWeightOf(result);
      matchedWeight += _matchedWeightOf(result);
    }

    if (request.finish != null && shadeFacts != null) {
      final result = await _ruleEngine.evaluate(
        ruleType: RuleType.finish,
        facts: <String, Object?>{
          'finish': shadeFacts.finish,
          'finish_target': request.finish,
        },
      );
      matchedRules.addAll(result.matchedRules);
      totalAbsWeight += _absWeightOf(result);
      matchedWeight += _matchedWeightOf(result);
    }

    if (request.coverage != null) {
      final result = await _ruleEngine.evaluate(
        ruleType: RuleType.coverage,
        facts: <String, Object?>{
          'notes': trial.notes,
          'notes_target': request.coverage,
        },
      );
      matchedRules.addAll(result.matchedRules);
      totalAbsWeight += _absWeightOf(result);
      matchedWeight += _matchedWeightOf(result);
    }

    final List<int> approvedMaterialIds = <int>[];
    final List<int> alternativeMaterialIds = <int>[];

    if (trial.id != null) {
      final List<FormulaMaterialModel> lines =
          await _trialRepository.materialsForTrial(trial.id!);
      for (final FormulaMaterialModel line in lines) {
        final materialResult = await _materialMatchingEngine.matchMaterial(
          materialTable: line.materialTable,
          materialId: line.materialId,
        );
        if (!materialResult.isSuccess || materialResult.data == null) {
          notes.add(
            materialResult.messages.isNotEmpty
                ? materialResult.messages.first
                : 'Unable to evaluate material line ${line.id}.',
          );
          continue;
        }

        final MaterialMatchResult material = materialResult.data!;
        matchedRules.addAll(material.matchedRules);
        totalAbsWeight += material.matchedRules
            .map((RuleModel r) => r.weight.abs())
            .fold<double>(0.0, (a, b) => a + b);
        if (material.isApproved) {
          approvedMaterialIds.add(line.materialId);
          matchedWeight += material.matchedRules
              .map((RuleModel r) => r.weight)
              .fold<double>(0.0, (a, b) => a + b);
        } else {
          alternativeMaterialIds.add(line.materialId);
          notes.add(
            'Material line ${line.id} needs an alternative '
            '(${material.alternativeMaterialIds.length} candidate(s) found).',
          );
        }
      }
    }

    final double confidence =
        totalAbsWeight == 0.0 ? 0.0 : (matchedWeight / totalAbsWeight).clamp(0.0, 1.0);

    return EngineRecommendation(
      trialFormula: trial,
      confidence: confidence,
      approvedMaterialIds: approvedMaterialIds,
      alternativeMaterialIds: alternativeMaterialIds,
      matchedRules: matchedRules,
      notes: notes,
    );
  }

  double _absWeightOf(RuleResult result) {
    return <RuleModel>[...result.matchedRules, ...result.failedRules]
        .map((RuleModel r) => r.weight.abs())
        .fold<double>(0.0, (a, b) => a + b);
  }

  double _matchedWeightOf(RuleResult result) {
    return result.matchedRules
        .map((RuleModel r) => r.weight)
        .fold(0.0, (double a, double b) => a + b);
  }
}

/// Minimal shade attributes RecommendationEngine needs for rule
/// facts, kept local to avoid pulling the full ShadeModel through
/// every call site.
@immutable
class ShadeFacts {
  const ShadeFacts({this.shadeFamily, this.finish});
  final String? shadeFamily;
  final String? finish;
}
