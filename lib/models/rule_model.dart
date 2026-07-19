/// Purpose      : Domain model for a configurable business rule,
///                persisted as a `record_type = 'rule'` row in
///                Settings (see database_helper.dart header for why).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : One rule = one condition ("key operator value") +
///                priority/weight/version/enabled metadata, per the
///                Rule Priority requirements (Priority, Weight,
///                Enabled/Disabled via the existing `is_active`
///                column, Future Version via `rule_version`).
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// The 12 rule categories this sprint's brief requires support for.
enum RuleType {
  product,
  shadeFamily,
  finish,
  coverage,
  pigment,
  dye,
  mica,
  pearl,
  filler,
  binder,
  alternativeMaterial,
  compatibility;

  /// The snake_case value stored in `Settings.rule_type`.
  String get storageKey => switch (this) {
        RuleType.product => 'product',
        RuleType.shadeFamily => 'shade_family',
        RuleType.finish => 'finish',
        RuleType.coverage => 'coverage',
        RuleType.pigment => 'pigment',
        RuleType.dye => 'dye',
        RuleType.mica => 'mica',
        RuleType.pearl => 'pearl',
        RuleType.filler => 'filler',
        RuleType.binder => 'binder',
        RuleType.alternativeMaterial => 'alternative_material',
        RuleType.compatibility => 'compatibility',
      };

  /// Parses a stored `rule_type` value back into a [RuleType], or
  /// null if unrecognized (e.g. a future rule type this build
  /// predates).
  static RuleType? fromStorageKey(String? value) {
    for (final RuleType type in RuleType.values) {
      if (type.storageKey == value) {
        return type;
      }
    }
    return null;
  }
}

/// A configurable, persisted business rule.
@immutable
class RuleModel {
  const RuleModel({
    required this.name,
    required this.ruleType,
    required this.conditionKey,
    required this.conditionOperator,
    required this.conditionValue,
    this.id,
    this.priority = 0,
    this.weight = 1.0,
    this.ruleVersion = 1,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Human-readable rule name, e.g. "Product Category Match".
  final String name;

  /// Which of the 12 approved rule categories this rule belongs to.
  final RuleType ruleType;

  /// The fact key this rule's condition inspects, e.g. "category".
  final String conditionKey;

  /// Stored operator key: "equals" | "not_equals" | "contains". Kept
  /// as raw text on the model (RuleEngine/RuleCondition, not this
  /// data-layer model, own the operator enum — see
  /// engines/rule_condition.dart — so this layer has no dependency on
  /// the engine layer).
  final String conditionOperator;

  /// The value the condition compares the fact against.
  final String conditionValue;

  /// Higher priority rules are considered more important. Used for
  /// ordering, not for changing whether a rule fires.
  final int priority;

  /// How much this rule contributes to the aggregate confidence score
  /// when it matches. Can be negative (a penalty rule, e.g.
  /// "Alternative Material Needed").
  final double weight;

  /// Rule definition version, so future edits can be tracked without
  /// losing the history of what a past recommendation was scored
  /// against.
  final int ruleVersion;

  /// Human-readable explanation, used for Reason Generation.
  final String? description;

  /// Enabled/disabled flag (reuses the standard soft-delete column;
  /// a disabled rule is simply excluded from evaluation, not deleted).
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RuleModel.fromMap(Map<String, Object?> map) {
    return RuleModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      ruleType: RuleType.fromStorageKey(map['rule_type'] as String?) ??
          RuleType.product,
      conditionKey: map['condition_key'] as String? ?? '',
      conditionOperator: map['condition_operator'] as String? ?? 'equals',
      conditionValue: map['condition_value'] as String? ?? '',
      priority: (map['priority'] as int?) ?? 0,
      weight: parseReal(map['weight']),
      ruleVersion: (map['rule_version'] as int?) ?? 1,
      description: map['description'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  /// Converts this model into a Settings row map, always tagged
  /// `record_type = 'rule'` so RuleRepository's rows never get
  /// confused with plain (non-rule) Settings entries.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'record_type': 'rule',
      'rule_type': ruleType.storageKey,
      'condition_key': conditionKey,
      'condition_operator': conditionOperator,
      'condition_value': conditionValue,
      'priority': priority,
      'weight': weight,
      'rule_version': ruleVersion,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }

  RuleModel copyWith({
    int? id,
    String? name,
    RuleType? ruleType,
    String? conditionKey,
    String? conditionOperator,
    String? conditionValue,
    int? priority,
    double? weight,
    int? ruleVersion,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ruleType: ruleType ?? this.ruleType,
      conditionKey: conditionKey ?? this.conditionKey,
      conditionOperator: conditionOperator ?? this.conditionOperator,
      conditionValue: conditionValue ?? this.conditionValue,
      priority: priority ?? this.priority,
      weight: weight ?? this.weight,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RuleModel &&
        other.id == id &&
        other.name == name &&
        other.ruleType == ruleType &&
        other.conditionKey == conditionKey &&
        other.conditionOperator == conditionOperator &&
        other.conditionValue == conditionValue &&
        other.priority == priority &&
        other.weight == weight &&
        other.ruleVersion == ruleVersion &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        ruleType,
        conditionKey,
        conditionOperator,
        conditionValue,
        priority,
        weight,
        ruleVersion,
        isActive,
      );

  @override
  String toString() =>
      'RuleModel(id: $id, name: $name, ruleType: ${ruleType.storageKey}, '
      'priority: $priority, weight: $weight, isActive: $isActive)';
}
