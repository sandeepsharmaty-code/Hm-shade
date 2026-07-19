/// Purpose      : Orchestrates reading, evaluating, and scoring
///                configurable business rules.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, rule_condition.dart,
///                rule_evaluator.dart, rule_result.dart,
///                repositories/rule_repository.dart,
///                repositories/repository_exception.dart
/// Description  : "Read rules / Evaluate rules / Score rules / Return
///                matching rules" per this sprint's brief. Reads only
///                through RuleRepository — never touches SQLite
///                directly, never imports a screen. This is the one
///                place business-rule *evaluation orchestration*
///                lives; ShadeMatchingEngine, MaterialMatchingEngine,
///                and RecommendationEngine all call this instead of
///                embedding their own scoring weights (the "NO
///                HARDCODED BUSINESS RULES" requirement).
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import '../models/rule_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/rule_repository.dart';
import 'engine_base.dart';
import 'rule_condition.dart';
import 'rule_evaluator.dart';
import 'rule_result.dart';

/// Contract for [RuleEngine].
abstract class IRuleEngine {
  Future<RuleResult> evaluate({
    required RuleType ruleType,
    required Map<String, Object?> facts,
  });
}

/// Reads and evaluates configurable rules of a given [RuleType]
/// against a caller-supplied facts map.
class RuleEngine extends EngineBase implements IRuleEngine {
  RuleEngine({required RuleRepository ruleRepository})
      : _ruleRepository = ruleRepository;

  final RuleRepository _ruleRepository;

  @override
  String get engineName => 'RuleEngine';

  @override
  Future<RuleResult> evaluate({
    required RuleType ruleType,
    required Map<String, Object?> facts,
  }) async {
    try {
      final List<RuleModel> rules = await _ruleRepository.findByRuleType(
        ruleType,
      );

      if (rules.isEmpty) {
        return RuleResult(
          success: false,
          confidenceScore: 0.0,
          reasonMessages: <String>[
            'No active ${ruleType.storageKey} rules are configured.',
          ],
        );
      }

      final List<RuleModel> matched = <RuleModel>[];
      final List<RuleModel> failed = <RuleModel>[];
      final List<String> reasons = <String>[];
      final List<String> alternatives = <String>[];
      double totalAbsoluteWeight = 0.0;
      double matchedWeight = 0.0;

      for (final RuleModel rule in rules) {
        final RuleCondition condition = RuleCondition.fromRuleModel(rule);
        final bool isMatch = RuleEvaluator.evaluate(condition, facts);
        totalAbsoluteWeight += rule.weight.abs();

        if (isMatch) {
          matched.add(rule);
          matchedWeight += rule.weight;
          reasons.add(rule.description ?? '${rule.name} matched.');
          if (rule.ruleType == RuleType.alternativeMaterial) {
            alternatives.add(
              rule.description ?? 'An alternative material is suggested.',
            );
          }
        } else {
          failed.add(rule);
        }
      }

      final double confidence = totalAbsoluteWeight == 0.0
          ? 0.0
          : (matchedWeight / totalAbsoluteWeight).clamp(0.0, 1.0);

      return RuleResult(
        success: matched.isNotEmpty,
        confidenceScore: confidence,
        matchedRules: matched,
        failedRules: failed,
        alternativeSuggestions: alternatives,
        reasonMessages: reasons,
      );
    } on RepositoryException catch (error) {
      logDebug('evaluate(${ruleType.storageKey}) failed: $error');
      return RuleResult(
        success: false,
        confidenceScore: 0.0,
        reasonMessages: <String>[
          'Unable to evaluate ${ruleType.storageKey} rules.',
        ],
      );
    }
  }
}
