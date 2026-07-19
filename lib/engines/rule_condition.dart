/// Purpose      : Evaluation-time representation of a rule's
///                condition, derived from a persisted RuleModel.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : models/rule_model.dart
/// Description  : Kept separate from RuleModel (the persisted data
///                layer shape) so the engine layer owns its own
///                operator vocabulary without the models/ layer
///                depending on engines/ — correct Clean Architecture
///                dependency direction (engines depend on models,
///                never the reverse).
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/rule_model.dart';

/// The comparison a [RuleCondition] performs.
enum RuleOperator {
  equals,
  notEquals,
  contains;

  static RuleOperator fromStorageKey(String? value) {
    switch (value) {
      case 'not_equals':
        return RuleOperator.notEquals;
      case 'contains':
        return RuleOperator.contains;
      case 'equals':
      default:
        return RuleOperator.equals;
    }
  }
}

/// A single, evaluatable condition: "does fact[key] <operator> value?"
@immutable
class RuleCondition {
  const RuleCondition({
    required this.key,
    required this.operator,
    required this.value,
  });

  /// Builds a [RuleCondition] from a persisted [RuleModel].
  factory RuleCondition.fromRuleModel(RuleModel rule) {
    return RuleCondition(
      key: rule.conditionKey,
      operator: RuleOperator.fromStorageKey(rule.conditionOperator),
      value: rule.conditionValue,
    );
  }

  final String key;
  final RuleOperator operator;
  final String value;
}
