/// Purpose      : Domain model for Formula_Material.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents one material line item within a
///                TrialFormulaModel (e.g. "12% Pigment_Master #4").
///                Child entity with no independent lifecycle outside
///                its owning trial — managed through TrialRepository,
///                not a standalone repository, per the "no
///                repositories for child entities without independent
///                lifecycle" convention.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// One material + percentage line within a trial formula.
@immutable
class FormulaMaterialModel {
  const FormulaMaterialModel({
    required this.trialFormulaId,
    required this.materialTable,
    required this.materialId,
    this.id,
    this.name,
    this.percentage = 0,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Optional display label for this line.
  final String? name;

  /// Foreign key to Trial_Formula.id — the owning trial.
  final int trialFormulaId;

  /// Which raw-material master table this line references, e.g.
  /// "Pigment_Master". Kept as text rather than a fixed enum so new
  /// material master tables can be referenced without a model change.
  final String materialTable;

  /// Foreign key into [materialTable]'s `id` column.
  final int materialId;

  /// Percentage of the total formula this material represents.
  final double percentage;

  final String? notes;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FormulaMaterialModel.fromMap(Map<String, Object?> map) {
    return FormulaMaterialModel(
      id: parseId(map['id']),
      name: map['name'] as String?,
      trialFormulaId: parseId(map['trial_formula_id']) ?? 0,
      materialTable: map['material_table'] as String? ?? '',
      materialId: parseId(map['material_id']) ?? 0,
      percentage: parseReal(map['percentage']),
      notes: map['notes'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'trial_formula_id': trialFormulaId,
      'material_table': materialTable,
      'material_id': materialId,
      'percentage': percentage,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
    };
  }

  FormulaMaterialModel copyWith({
    int? id,
    String? name,
    int? trialFormulaId,
    String? materialTable,
    int? materialId,
    double? percentage,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FormulaMaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trialFormulaId: trialFormulaId ?? this.trialFormulaId,
      materialTable: materialTable ?? this.materialTable,
      materialId: materialId ?? this.materialId,
      percentage: percentage ?? this.percentage,
      notes: notes ?? this.notes,
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
    return other is FormulaMaterialModel &&
        other.id == id &&
        other.name == name &&
        other.trialFormulaId == trialFormulaId &&
        other.materialTable == materialTable &&
        other.materialId == materialId &&
        other.percentage == percentage &&
        other.notes == notes &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        trialFormulaId,
        materialTable,
        materialId,
        percentage,
        notes,
        isActive,
      );

  @override
  String toString() =>
      'FormulaMaterialModel(id: $id, trialFormulaId: $trialFormulaId, '
      'materialTable: $materialTable, materialId: $materialId, '
      'percentage: $percentage)';
}
