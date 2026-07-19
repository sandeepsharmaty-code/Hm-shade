/// Purpose      : Converts Rule Engine results into ranked
///                formulation recommendations (a Recommendation Layer
///                only — not formulation chemistry, not
///                manufacturing).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart,
///                recommendation_engine.dart, knowledge_engine.dart,
///                material_matching_engine.dart,
///                recommendation_conflict_detector.dart,
///                recommendation_reason_builder.dart,
///                recommendation_filter.dart, recommendation_ranker.dart,
///                recommendation_history.dart,
///                repositories/trial_repository.dart
/// Description  : Orchestrates: RecommendationEngine (already
///                rule-driven, SPR-DEP-005) for the base candidate
///                pool -> RecommendationConflictDetector per
///                candidate -> RecommendationFilter to drop severe
///                conflicts -> ranking-factor assembly (Rule
///                Confidence from RuleEngine via RecommendationEngine,
///                Approved Formula Match from TrialRepository's
///                approval record, Material Availability and
///                Alternative Material Quality from
///                MaterialMatchingEngine, Business Priority from
///                trial status) -> RecommendationRanker -> top 5 ->
///                RecommendationReasonBuilder per result ->
///                RecommendationHistory.record(). Never estimates
///                pigment ratios or invents cosmetic chemistry — it
///                only ranks and explains trial formulas that already
///                exist in Trial_Formula; it creates no new formula
///                content.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/approved_formula_model.dart';
import '../models/formula_material_model.dart';
import '../models/rule_model.dart';
import '../models/trial_formula_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'knowledge_engine.dart';
import 'material_matching_engine.dart';
import 'recommendation_conflict.dart';
import 'recommendation_conflict_detector.dart';
import 'recommendation_engine.dart';
import 'recommendation_filter.dart';
import 'recommendation_history.dart';
import 'recommendation_ranker.dart';
import 'recommendation_reason_builder.dart';

/// Input criteria for [FormulaRecommendationEngine.recommend].
@immutable
class FormulaRecommendationRequest {
  const FormulaRecommendationRequest({
    required this.productId,
    this.shadeId,
    this.shadeFamily,
    this.finish,
    this.coverage,
    this.maxResults = 5,
    this.minimumConfidence = 0.0,
    this.lowConfidenceThreshold = 0.3,
    this.excludeProductMismatch = true,
    this.recordHistory = true,
  });

  final int productId;

  /// Optional explicit shade to cross-check compatibility against, in
  /// addition to [shadeFamily]/[finish] matching hints.
  final int? shadeId;
  final String? shadeFamily;
  final String? finish;
  final String? coverage;

  /// Maximum recommendations returned. Defaults to 5 (Top 5
  /// Recommendations, per this sprint's Output requirement).
  final int maxResults;

  /// Candidates below this confidence are dropped by
  /// RecommendationFilter.
  final double minimumConfidence;

  /// Confidence below this is flagged as a Low Confidence conflict by
  /// RecommendationConflictDetector (does not exclude the candidate
  /// by itself — [minimumConfidence] does that).
  final double lowConfidenceThreshold;

  /// Whether RecommendationFilter drops candidates with a Product
  /// Mismatch conflict.
  final bool excludeProductMismatch;

  /// Whether to auto-log the top result to RecommendationHistory.
  final bool recordHistory;
}

/// One final, ranked, explained recommendation.
@immutable
class FormulaRecommendation {
  const FormulaRecommendation({
    required this.trialFormula,
    required this.rank,
    required this.confidenceScore,
    required this.reasons,
    required this.matchedRules,
    required this.alternativeMaterialIds,
    required this.conflicts,
    this.approvedFormulaReference,
  });

  final TrialFormulaModel trialFormula;

  /// 1-based rank, per RecommendationRanker's composite ordering.
  final int rank;

  /// Rule Confidence (RuleEngine-derived), 0.0–1.0.
  final double confidenceScore;

  final List<String> reasons;
  final List<RuleModel> matchedRules;
  final List<int> alternativeMaterialIds;
  final List<RecommendationConflict> conflicts;
  final ApprovedFormulaModel? approvedFormulaReference;
}

/// Contract for [FormulaRecommendationEngine].
abstract class IFormulaRecommendationEngine {
  Future<EngineResult<List<FormulaRecommendation>>> recommend(
    FormulaRecommendationRequest request,
  );
}

/// Top-level Formula Recommendation Engine.
class FormulaRecommendationEngine extends EngineBase
    implements IFormulaRecommendationEngine {
  FormulaRecommendationEngine({
    required IRecommendationEngine recommendationEngine,
    required IKnowledgeEngine knowledgeEngine,
    required IMaterialMatchingEngine materialMatchingEngine,
    required TrialRepository trialRepository,
    required IRecommendationConflictDetector conflictDetector,
    required IRecommendationReasonBuilder reasonBuilder,
    required IRecommendationFilter filter,
    required IRecommendationRanker ranker,
    required IRecommendationHistory history,
  })  : _recommendationEngine = recommendationEngine,
        _knowledgeEngine = knowledgeEngine,
        _materialMatchingEngine = materialMatchingEngine,
        _trialRepository = trialRepository,
        _conflictDetector = conflictDetector,
        _reasonBuilder = reasonBuilder,
        _filter = filter,
        _ranker = ranker,
        _history = history;

  final IRecommendationEngine _recommendationEngine;
  final IKnowledgeEngine _knowledgeEngine;
  final IMaterialMatchingEngine _materialMatchingEngine;
  final TrialRepository _trialRepository;
  final IRecommendationConflictDetector _conflictDetector;
  final IRecommendationReasonBuilder _reasonBuilder;
  final IRecommendationFilter _filter;
  final IRecommendationRanker _ranker;
  final IRecommendationHistory _history;

  @override
  String get engineName => 'FormulaRecommendationEngine';

  @override
  Future<EngineResult<List<FormulaRecommendation>>> recommend(
    FormulaRecommendationRequest request,
  ) async {
    try {
      // Pull a larger candidate pool than maxResults so filtering and
      // ranking have room to reorder before truncating to Top 5.
      final RecommendationRequest baseRequest = RecommendationRequest(
        productId: request.productId,
        shadeFamily: request.shadeFamily,
        finish: request.finish,
        coverage: request.coverage,
        maxResults: request.maxResults < 5 ? 15 : request.maxResults * 3,
      );

      final EngineResult<List<EngineRecommendation>> baseResult =
          await _recommendationEngine.recommend(baseRequest);

      if (!baseResult.isSuccess ||
          baseResult.data == null ||
          baseResult.data!.isEmpty) {
        return EngineResult<List<FormulaRecommendation>>.success(
          data: const <FormulaRecommendation>[],
          confidenceScore: 0.0,
          messages: baseResult.messages.isNotEmpty
              ? baseResult.messages
              : const <String>['No candidate trial formulas found.'],
        );
      }
      final List<EngineRecommendation> candidates = baseResult.data!;

      // Optional context: other approved formulas matching the
      // query, for awareness even if not among this product's
      // candidates. Satisfies "Knowledge Engine Result" as an input.
      final List<String> contextMessages = <String>[];
      if (request.shadeFamily != null) {
        final knowledgeResult = await _knowledgeEngine.searchApprovedFormulas(
          request.shadeFamily!,
        );
        if (knowledgeResult.isSuccess &&
            (knowledgeResult.data?.isNotEmpty ?? false)) {
          contextMessages.add(
            '${knowledgeResult.data!.length} approved formula(s) exist '
            'matching "${request.shadeFamily}" across all products.',
          );
        }
      }

      final Map<EngineRecommendation, List<RecommendationConflict>>
          conflictsByCandidate =
          <EngineRecommendation, List<RecommendationConflict>>{};
      for (final EngineRecommendation candidate in candidates) {
        conflictsByCandidate[candidate] = await _conflictDetector.detect(
          candidate: candidate,
          request: baseRequest,
          lowConfidenceThreshold: request.lowConfidenceThreshold,
        );
      }

      final List<EngineRecommendation> filtered = _filter.apply(
        candidates: candidates,
        conflictsByCandidate: conflictsByCandidate,
        minimumConfidence: request.minimumConfidence,
        excludeProductMismatch: request.excludeProductMismatch,
      );

      if (filtered.isEmpty) {
        return EngineResult<List<FormulaRecommendation>>.success(
          data: const <FormulaRecommendation>[],
          confidenceScore: 0.0,
          warnings: const <String>[
            'All candidates were filtered out (minimumConfidence or '
            'excludeProductMismatch).',
          ],
          messages: contextMessages,
        );
      }

      final Map<EngineRecommendation, RankingFactors> factorsByCandidate =
          <EngineRecommendation, RankingFactors>{};
      final Map<EngineRecommendation, ApprovedFormulaModel?>
          approvedRefByCandidate =
          <EngineRecommendation, ApprovedFormulaModel?>{};

      for (final EngineRecommendation candidate in filtered) {
        final ApprovedFormulaModel? approvedRef = candidate.trialFormula.id ==
                null
            ? null
            : await _trialRepository.approvalForTrial(
                candidate.trialFormula.id!,
              );
        approvedRefByCandidate[candidate] = approvedRef;

        final int materialTotal = candidate.approvedMaterialIds.length +
            candidate.alternativeMaterialIds.length;
        final double materialAvailability = materialTotal == 0
            ? 1.0
            : candidate.approvedMaterialIds.length / materialTotal;

        final double alternativeQuality = await _alternativeMaterialQuality(
          candidate,
        );

        factorsByCandidate[candidate] = RankingFactors(
          ruleConfidence: candidate.confidence,
          approvedFormulaMatch: approvedRef != null ? 1.0 : 0.0,
          materialAvailability: materialAvailability,
          alternativeMaterialQuality: alternativeQuality,
          businessPriority: RecommendationRanker.businessPriorityFor(
            candidate.trialFormula.status,
          ),
        );
      }

      final List<RankedRecommendation> ranked = _ranker.rank(
        candidates: filtered,
        factorsByCandidate: factorsByCandidate,
      );
      final List<RankedRecommendation> top = ranked
          .take(request.maxResults)
          .toList();

      final List<FormulaRecommendation> results = <FormulaRecommendation>[
        for (final RankedRecommendation r in top)
          FormulaRecommendation(
            trialFormula: r.candidate.trialFormula,
            rank: r.rank,
            confidenceScore: r.candidate.confidence,
            reasons: _reasonBuilder.build(
              candidate: r.candidate,
              conflicts: conflictsByCandidate[r.candidate] ??
                  const <RecommendationConflict>[],
              approvedFormulaReference: approvedRefByCandidate[r.candidate],
            ),
            matchedRules: r.candidate.matchedRules,
            alternativeMaterialIds: r.candidate.alternativeMaterialIds,
            conflicts: conflictsByCandidate[r.candidate] ??
                const <RecommendationConflict>[],
            approvedFormulaReference: approvedRefByCandidate[r.candidate],
          ),
      ];

      if (request.recordHistory && results.isNotEmpty) {
        final FormulaRecommendation top1 = results.first;
        await _history.record(
          inputParameters: <String, Object?>{
            'productId': request.productId,
            'shadeId': request.shadeId,
            'shadeFamily': request.shadeFamily,
            'finish': request.finish,
            'coverage': request.coverage,
          },
          selectedTrialFormulaId: top1.trialFormula.id,
          confidenceScore: top1.confidenceScore,
          reasonText: top1.reasons.isNotEmpty ? top1.reasons.first : null,
        );
      }

      return EngineResult<List<FormulaRecommendation>>.success(
        data: results,
        confidenceScore:
            results.isEmpty ? 0.0 : results.first.confidenceScore,
        recommendedIds: <int>[
          for (final FormulaRecommendation r in results)
            if (r.trialFormula.id != null) r.trialFormula.id!,
        ],
        messages: contextMessages,
      );
    } on RepositoryException catch (error) {
      logDebug('recommend failed: $error');
      return EngineResult<List<FormulaRecommendation>>.failure(
        message: 'Unable to generate formula recommendations.',
      );
    }
  }

  /// Re-checks each material line that needs an alternative and
  /// scores how many real substitute candidates MaterialMatchingEngine
  /// actually found for it (not just whether one is needed).
  Future<double> _alternativeMaterialQuality(
    EngineRecommendation candidate,
  ) async {
    if (candidate.alternativeMaterialIds.isEmpty) {
      return 1.0;
    }
    if (candidate.trialFormula.id == null) {
      return 0.0;
    }

    final List<FormulaMaterialModel> lines = await _trialRepository
        .materialsForTrial(candidate.trialFormula.id!);
    final List<FormulaMaterialModel> needingAlternatives = lines
        .where(
          (FormulaMaterialModel line) =>
              candidate.alternativeMaterialIds.contains(line.materialId),
        )
        .toList();

    if (needingAlternatives.isEmpty) {
      return 0.5; // needs alternatives but lines couldn't be resolved
    }

    int linesWithGoodAlternatives = 0;
    for (final FormulaMaterialModel line in needingAlternatives) {
      final result = await _materialMatchingEngine.matchMaterial(
        materialTable: line.materialTable,
        materialId: line.materialId,
      );
      final int foundCount = result.data?.alternativeMaterialIds.length ?? 0;
      if (foundCount > 0) {
        linesWithGoodAlternatives++;
      }
    }

    return linesWithGoodAlternatives / needingAlternatives.length;
  }
}
