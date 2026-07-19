/// Purpose      : Detects the six conflict categories a candidate
///                recommendation might have.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, recommendation_conflict.dart,
///                recommendation_engine.dart (EngineRecommendation,
///                RecommendationRequest — reused, not duplicated),
///                repositories/trial_repository.dart,
///                repositories/shade_repository.dart,
///                repositories/rule_repository.dart,
///                repositories/repository_exception.dart
/// Description  : Inactive Material / Missing Material / Disabled
///                Rule / Low Confidence / Product Mismatch / Shade
///                Mismatch — exactly the six categories this sprint's
///                brief lists. Reads only through the Repository
///                Layer (TrialRepository, ShadeRepository,
///                RuleRepository) — never touches SQLite directly.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import '../models/rule_model.dart';
import '../models/shade_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/rule_repository.dart';
import '../repositories/shade_repository.dart';
import 'engine_base.dart';
import 'recommendation_conflict.dart';
import 'recommendation_engine.dart';

/// All rule types a recommendation could plausibly have consulted —
/// used to decide whether a disabled rule was actually relevant.
const List<RuleType> _allRuleTypes = RuleType.values;

/// Contract for [RecommendationConflictDetector].
abstract class IRecommendationConflictDetector {
  Future<List<RecommendationConflict>> detect({
    required EngineRecommendation candidate,
    required RecommendationRequest request,
    double lowConfidenceThreshold = 0.3,
  });
}

/// Detects conflicts in a scored [EngineRecommendation] candidate.
class RecommendationConflictDetector extends EngineBase
    implements IRecommendationConflictDetector {
  RecommendationConflictDetector({
    required ShadeRepository shadeRepository,
    required RuleRepository ruleRepository,
  })  : _shadeRepository = shadeRepository,
        _ruleRepository = ruleRepository;

  final ShadeRepository _shadeRepository;
  final RuleRepository _ruleRepository;

  @override
  String get engineName => 'RecommendationConflictDetector';

  @override
  Future<List<RecommendationConflict>> detect({
    required EngineRecommendation candidate,
    required RecommendationRequest request,
    double lowConfidenceThreshold = 0.3,
  }) async {
    final List<RecommendationConflict> conflicts = <RecommendationConflict>[];

    _checkProductMismatch(candidate, request, conflicts);
    await _checkShadeMismatch(candidate, request, conflicts);
    _checkMaterialConflicts(candidate, conflicts);
    _checkLowConfidence(candidate, lowConfidenceThreshold, conflicts);
    await _checkDisabledRules(conflicts);

    return conflicts;
  }

  void _checkProductMismatch(
    EngineRecommendation candidate,
    RecommendationRequest request,
    List<RecommendationConflict> conflicts,
  ) {
    if (candidate.trialFormula.productId != request.productId) {
      conflicts.add(
        const RecommendationConflict(
          type: ConflictType.productMismatch,
          message: 'Trial formula belongs to a different product than '
              'requested.',
        ),
      );
    }
  }

  Future<void> _checkShadeMismatch(
    EngineRecommendation candidate,
    RecommendationRequest request,
    List<RecommendationConflict> conflicts,
  ) async {
    if (request.shadeFamily == null && request.finish == null) {
      return;
    }
    final int? shadeId = candidate.trialFormula.shadeId;
    if (shadeId == null) {
      return;
    }
    try {
      final ShadeModel? shade = await _shadeRepository.readById(shadeId);
      if (shade == null) {
        return;
      }
      if (request.shadeFamily != null &&
          shade.shadeFamily != null &&
          !_equalsIgnoreCase(shade.shadeFamily, request.shadeFamily)) {
        conflicts.add(
          RecommendationConflict(
            type: ConflictType.shadeMismatch,
            message: 'Shade family "${shade.shadeFamily}" does not match '
                'requested "${request.shadeFamily}".',
          ),
        );
      }
      if (request.finish != null &&
          shade.finish != null &&
          !_equalsIgnoreCase(shade.finish, request.finish)) {
        conflicts.add(
          RecommendationConflict(
            type: ConflictType.shadeMismatch,
            message: 'Finish "${shade.finish}" does not match requested '
                '"${request.finish}".',
          ),
        );
      }
    } on RepositoryException catch (error) {
      logDebug('_checkShadeMismatch failed: $error');
    }
  }

  void _checkMaterialConflicts(
    EngineRecommendation candidate,
    List<RecommendationConflict> conflicts,
  ) {
    if (candidate.alternativeMaterialIds.isNotEmpty) {
      conflicts.add(
        RecommendationConflict(
          type: ConflictType.inactiveMaterial,
          message: '${candidate.alternativeMaterialIds.length} material '
              'line(s) reference an inactive material.',
        ),
      );
    }
    for (final String note in candidate.notes) {
      if (note.toLowerCase().contains('not found')) {
        conflicts.add(
          RecommendationConflict(
            type: ConflictType.missingMaterial,
            message: note,
          ),
        );
      }
    }
  }

  void _checkLowConfidence(
    EngineRecommendation candidate,
    double threshold,
    List<RecommendationConflict> conflicts,
  ) {
    if (candidate.confidence < threshold) {
      conflicts.add(
        RecommendationConflict(
          type: ConflictType.lowConfidence,
          message: 'Confidence ${candidate.confidence.toStringAsFixed(2)} '
              'is below the ${threshold.toStringAsFixed(2)} threshold.',
        ),
      );
    }
  }

  Future<void> _checkDisabledRules(
    List<RecommendationConflict> conflicts,
  ) async {
    try {
      final List<RuleModel> allRules = await _ruleRepository.findAllRules(
        includeInactive: true,
      );
      for (final RuleModel rule in allRules) {
        if (!rule.isActive && _allRuleTypes.contains(rule.ruleType)) {
          conflicts.add(
            RecommendationConflict(
              type: ConflictType.disabledRule,
              message: '"${rule.name}" (${rule.ruleType.storageKey}) is '
                  'currently disabled and was not considered.',
            ),
          );
        }
      }
    } on RepositoryException catch (error) {
      logDebug('_checkDisabledRules failed: $error');
    }
  }

  bool _equalsIgnoreCase(String? a, String? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}
