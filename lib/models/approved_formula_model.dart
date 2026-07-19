/// Purpose      : Domain model for Approved_Formula.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents the lab-approved outcome of a
///                TrialFormulaModel. Child entity with no independent
///                lifecycle outside its owning trial — created and
///                read through TrialRepository, not a standalone
///                repository, per the "no repositories for child
///                entities without independent lifecycle" convention.
///                `approvedBy` is a free-text name, not an
///                authenticated actor id — this project has no
///                login/authentication per its approved scope.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// The approved formula record for a trial.
@immutable
class ApprovedFormulaModel {
  const ApprovedFormulaModel({
    required this.trialFormulaId,
    this.id,
    this.name,
    this.approvedBy,
    this.approvalNotes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Optional display label, e.g. "Approved - Ruby Red v1".
  final String? name;

  /// Foreign key to Trial_Formula.id. One approval per trial.
  final int trialFormulaId;

  /// Free-text name of the approver. No authentication exists in
  /// this offline, single-user app, so this is not a verified
  /// identity — just a record-keeping field.
  final String? approvedBy;

  final String? approvalNotes;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ApprovedFormulaModel.fromMap(Map<String, Object?> map) {
    return ApprovedFormulaModel(
      id: parseId(map['id']),
      name: map['name'] as String?,
      trialFormulaId: parseId(map['trial_formula_id']) ?? 0,
      approvedBy: map['approved_by'] as String?,
      approvalNotes: map['approval_notes'] as String?,
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
      'approved_by': approvedBy,
      'approval_notes': approvalNotes,
      'is_active': isActive ? 1 : 0,
    };
  }

  ApprovedFormulaModel copyWith({
    int? id,
    String? name,
    int? trialFormulaId,
    String? approvedBy,
    String? approvalNotes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApprovedFormulaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trialFormulaId: trialFormulaId ?? this.trialFormulaId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvalNotes: approvalNotes ?? this.approvalNotes,
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
    return other is ApprovedFormulaModel &&
        other.id == id &&
        other.name == name &&
        other.trialFormulaId == trialFormulaId &&
        other.approvedBy == approvedBy &&
        other.approvalNotes == approvalNotes &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        trialFormulaId,
        approvedBy,
        approvalNotes,
        isActive,
      );

  @override
  String toString() =>
      'ApprovedFormulaModel(id: $id, trialFormulaId: $trialFormulaId, '
      'approvedBy: $approvedBy)';
}
