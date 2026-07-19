/// Purpose      : Unit tests for RuleEvaluator's fixed-value and
///                dynamic-target comparison modes.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/rule_condition.dart,
///                engines/rule_evaluator.dart
/// Description  : Pure logic, no repository or database involved.
///                Exercises both RuleEvaluator comparison modes (see
///                rule_evaluator.dart header) and all three operators.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/engines/rule_condition.dart';
import 'package:hue_muse_shade_ai/engines/rule_evaluator.dart';

void main() {
  group('RuleEvaluator — fixed-value mode', () {
    test('equals matches identical text case-insensitively', () {
      const condition = RuleCondition(
        key: 'isActive',
        operator: RuleOperator.equals,
        value: 'true',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'isActive': true,
        }),
        isTrue,
      );
    });

    test('equals rejects a non-matching value', () {
      const condition = RuleCondition(
        key: 'isActive',
        operator: RuleOperator.equals,
        value: 'true',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'isActive': false,
        }),
        isFalse,
      );
    });

    test('notEquals matches when values differ', () {
      const condition = RuleCondition(
        key: 'isActive',
        operator: RuleOperator.notEquals,
        value: 'false',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'isActive': true,
        }),
        isTrue,
      );
    });

    test('contains matches substrings', () {
      const condition = RuleCondition(
        key: 'notes',
        operator: RuleOperator.contains,
        value: 'sheer',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'notes': 'A light, Sheer coverage formula.',
        }),
        isTrue,
      );
    });
  });

  group('RuleEvaluator — dynamic-target mode (empty condition.value)', () {
    test('compares fact against the paired "_target" fact', () {
      const condition = RuleCondition(
        key: 'category',
        operator: RuleOperator.equals,
        value: '',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'category': 'Nail Polish',
          'category_target': 'Nail Polish',
        }),
        isTrue,
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'category': 'Nail Polish',
          'category_target': 'Lipstick',
        }),
        isFalse,
      );
    });

    test('missing target fact never false-positives on contains', () {
      const condition = RuleCondition(
        key: 'notes',
        operator: RuleOperator.contains,
        value: '',
      );
      expect(
        RuleEvaluator.evaluate(condition, <String, Object?>{
          'notes': 'Some notes',
        }),
        isFalse,
      );
    });
  });
}
