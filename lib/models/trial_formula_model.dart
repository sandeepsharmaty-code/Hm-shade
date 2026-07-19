/// Purpose      : Domain model for Trial_Formula.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents one of the up-to-five trial formula
///                suggestions generated for a shade, prior to lab
///                approval. Aggregate root for its Formula_Material
///                line items (see FormulaMaterialModel) and, once
///                approved, its ApprovedFormulaModel.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// A candidate formula under trial for a shade.
@immutable
class TrialFormulaModel {
  const TrialFormulaModel({
    required this.name,
    required this.trialCode,
    this.id,
    this.shadeId,
    this.productId,
    this.status = 'draft',
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Display name, e.g. "Trial 1 - Ruby Red".
  final String name;

  /// Unique short code, e.g. "TRL-0001".
  final String trialCode;

  /// Foreign key to Shade_Master.id.
  final int? shadeId;

  /// Foreign key to Product_Master.id.
  final int? productId;

  /// Workflow status: 'draft', 'in_review', 'approved', or
  /// 'rejected'.
  final String status;

  final String? notes;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrialFormulaModel.fromMap(Map<String, Object?> map) {
    return TrialFormulaModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      trialCode: map['trial_code'] as String? ?? '',
      shadeId: parseId(map['shade_id']),
      productId: parseId(map['product_id']),
      status: map['status'] as String? ?? 'draft',
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
      'trial_code': trialCode,
      'shade_id': shadeId,
      'product_id': productId,
      'status': status,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
    };
  }

  TrialFormulaModel copyWith({
    int? id,
    String? name,
    String? trialCode,
    int? shadeId,
    int? productId,
    String? status,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrialFormulaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trialCode: trialCode ?? this.trialCode,
      shadeId: shadeId ?? this.shadeId,
      productId: productId ?? this.productId,
      status: status ?? this.status,
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
    return other is TrialFormulaModel &&
        other.id == id &&
        other.name == name &&
        other.trialCode == trialCode &&
        other.shadeId == shadeId &&
        other.productId == productId &&
        other.status == status &&
        other.notes == notes &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        trialCode,
        shadeId,
        productId,
        status,
        notes,
        isActive,
      );

  @override
  String toString() =>
      'TrialFormulaModel(id: $id, name: $name, trialCode: $trialCode, '
      'status: $status, isActive: $isActive)';
}
