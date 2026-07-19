/// Purpose      : Pure logic for evaluating a RuleCondition against a
///                set of facts.
/// Author       : HMEOS Engineering
/// Version      : 1.1.0
/// Dependencies : rule_condition.dart
/// Description  : Deterministic, side-effect-free — no repository, no
///                database, no UI. Takes whatever "facts" the caller
///                supplies (a Map<String, Object?> built by
///                RuleEngine/ShadeMatchingEngine/MaterialMatchingEngine
///                from already-loaded models) and answers true/false
///                for one condition.
///
///                Two comparison modes:
///                1. Fixed-value: `condition.value` is non-empty (e.g.
///                   "true" for "isActive equals true") — compares
///                   `facts[key]` against that literal.
///                2. Dynamic target: `condition.value` is empty (e.g.
///                   the seeded "Product Category Match" rule, which
///                   can't know the requested category in advance) —
///                   compares `facts[key]` against
///                   `facts['${key}_target']` instead, a second fact
///                   the caller supplies for exactly this purpose.
///                This lets one persisted rule compare "the
///                candidate's category" to "whatever category was
///                requested" without a rule row per possible category
///                value.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
///   1.1.0 - SPR-DEP-005 - Added the dynamic-target comparison mode,
///           needed once RecommendationEngine started calling this
///           for request-relative rules (product/shade_family/
///           finish/coverage/compatibility).
library;

import 'rule_condition.dart';

/// Evaluates [RuleCondition]s against a facts map.
class RuleEvaluator {
  const RuleEvaluator._();

  /// Returns true if `facts[condition.key]` satisfies
  /// `condition.operator` against either `condition.value` (fixed) or
  /// `facts['${condition.key}_target']` (dynamic — used when
  /// `condition.value` is empty). See file header for when each mode
  /// applies.
  static bool evaluate(RuleCondition condition, Map<String, Object?> facts) {
    final String actualText = _asComparableText(facts[condition.key]);

    final String expectedText = condition.value.isEmpty
        ? _asComparableText(facts['${condition.key}_target'])
        : condition.value.toLowerCase().trim();

    switch (condition.operator) {
      case RuleOperator.equals:
        return actualText == expectedText;
      case RuleOperator.notEquals:
        return actualText != expectedText;
      case RuleOperator.contains:
        return expectedText.isNotEmpty && actualText.contains(expectedText);
    }
  }

  static String _asComparableText(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().toLowerCase().trim();
  }
}
