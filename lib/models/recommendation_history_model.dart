/// Purpose      : Domain model for a recorded recommendation event.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Persisted as a `record_type = 'recommendation_history'`
///                row in Settings (see database_helper.dart header for
///                why — no dedicated history table exists in the
///                frozen schema). Captures exactly the fields this
///                sprint's Recommendation History requirement lists:
///                Recommendation ID (this row's `id`), Timestamp
///                (`created_at`, inherited), Input Parameters,
///                Selected Recommendation, Confidence, Reason.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// One recorded recommendation event.
@immutable
class RecommendationHistoryModel {
  const RecommendationHistoryModel({
    required this.inputParameters,
    this.id,
    this.name,
    this.selectedTrialFormulaId,
    this.confidenceScore,
    this.reasonText,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Optional human-readable label, e.g. "Recommendation for Ruby
  /// Red / Nail Polish".
  final String? name;

  /// JSON-encoded snapshot of the request that produced this
  /// recommendation (product id, shade family, finish, coverage) —
  /// kept as an opaque string here; FormulaRecommendationEngine owns
  /// encoding/decoding so this data-layer model has no dependency on
  /// the engine layer's request type.
  final String inputParameters;

  /// The Trial_Formula.id that was selected/top-ranked, if any.
  final int? selectedTrialFormulaId;

  /// The confidence score of the selected recommendation, 0.0–1.0.
  final double? confidenceScore;

  /// Human-readable reason text for the selection.
  final String? reasonText;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RecommendationHistoryModel.fromMap(Map<String, Object?> map) {
    return RecommendationHistoryModel(
      id: parseId(map['id']),
      name: map['name'] as String?,
      inputParameters: map['input_parameters'] as String? ?? '{}',
      selectedTrialFormulaId: parseId(map['selected_trial_formula_id']),
      confidenceScore: map['confidence_score'] == null
          ? null
          : parseReal(map['confidence_score']),
      reasonText: map['reason_text'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'record_type': 'recommendation_history',
      'input_parameters': inputParameters,
      'selected_trial_formula_id': selectedTrialFormulaId,
      'confidence_score': confidenceScore,
      'reason_text': reasonText,
      'is_active': isActive ? 1 : 0,
    };
  }

  RecommendationHistoryModel copyWith({
    int? id,
    String? name,
    String? inputParameters,
    int? selectedTrialFormulaId,
    double? confidenceScore,
    String? reasonText,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecommendationHistoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      inputParameters: inputParameters ?? this.inputParameters,
      selectedTrialFormulaId:
          selectedTrialFormulaId ?? this.selectedTrialFormulaId,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      reasonText: reasonText ?? this.reasonText,
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
    return other is RecommendationHistoryModel &&
        other.id == id &&
        other.name == name &&
        other.inputParameters == inputParameters &&
        other.selectedTrialFormulaId == selectedTrialFormulaId &&
        other.confidenceScore == confidenceScore &&
        other.reasonText == reasonText &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        inputParameters,
        selectedTrialFormulaId,
        confidenceScore,
        reasonText,
        isActive,
      );

  @override
  String toString() =>
      'RecommendationHistoryModel(id: $id, '
      'selectedTrialFormulaId: $selectedTrialFormulaId, '
      'confidenceScore: $confidenceScore, createdAt: $createdAt)';
}
