/// Purpose      : Domain model for one audit-trail entry recording a
///                Trial_Formula status change.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Persisted as a `record_type = 'trial_audit'` row in
///                Settings (see database_helper.dart header — same
///                rationale as SPR-DEP-005's rules and SPR-DEP-006's
///                recommendation history: no dedicated table exists
///                and the database stays frozen). Captures exactly
///                the fields this sprint's Audit Trail requirement
///                lists: Trial ID, Recommendation ID, Timestamp,
///                Status Change, Changed By, Reason.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// One recorded status transition for a trial.
@immutable
class TrialAuditEntryModel {
  const TrialAuditEntryModel({
    required this.trialFormulaId,
    required this.statusFrom,
    required this.statusTo,
    this.id,
    this.relatedRecommendationId,
    this.changedBy = 'system',
    this.reason,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// The Trial_Formula.id this entry is about.
  final int trialFormulaId;

  /// Optional link to a RecommendationHistoryModel.id, when this
  /// transition was driven by accepting a recommendation.
  final int? relatedRecommendationId;

  /// Status transitioned from (storage key, e.g. "draft").
  final String statusFrom;

  /// Status transitioned to (storage key, e.g. "ready_for_lab").
  final String statusTo;

  /// Who/what made the change. This project has no authentication
  /// (see approved project scope), so this is a free-text
  /// system/user placeholder, not a verified identity.
  final String changedBy;

  final String? reason;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrialAuditEntryModel.fromMap(Map<String, Object?> map) {
    return TrialAuditEntryModel(
      id: parseId(map['id']),
      trialFormulaId: parseId(map['selected_trial_formula_id']) ?? 0,
      relatedRecommendationId: parseId(map['related_recommendation_id']),
      statusFrom: map['status_from'] as String? ?? '',
      statusTo: map['status_to'] as String? ?? '',
      changedBy: map['changed_by'] as String? ?? 'system',
      reason: map['reason_text'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  /// Converts to a Settings row map. Reuses the
  /// `selected_trial_formula_id`/`reason_text` columns added for
  /// recommendation history (SPR-DEP-006) since their meaning —
  /// "the trial this row is about" / "free text reason" — applies
  /// equally here, rather than adding duplicate columns.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'record_type': 'trial_audit',
      'selected_trial_formula_id': trialFormulaId,
      'related_recommendation_id': relatedRecommendationId,
      'status_from': statusFrom,
      'status_to': statusTo,
      'changed_by': changedBy,
      'reason_text': reason,
      'is_active': isActive ? 1 : 0,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TrialAuditEntryModel &&
        other.id == id &&
        other.trialFormulaId == trialFormulaId &&
        other.statusFrom == statusFrom &&
        other.statusTo == statusTo &&
        other.changedBy == changedBy &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(
        id,
        trialFormulaId,
        statusFrom,
        statusTo,
        changedBy,
        reason,
      );

  @override
  String toString() =>
      'TrialAuditEntryModel(id: $id, trialFormulaId: $trialFormulaId, '
      '$statusFrom -> $statusTo, changedBy: $changedBy, at: $createdAt)';
}
