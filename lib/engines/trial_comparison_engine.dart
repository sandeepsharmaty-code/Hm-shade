/// Purpose      : Compares multiple FormulaRecommendations field by
///                field and highlights differences.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : formula_recommendation_engine.dart
///                (FormulaRecommendation)
/// Description  : Pure comparison logic — no repository, no
///                database, no UI. Compares Recommendation Rank,
///                Confidence, Matched Rules, Alternative Materials,
///                Conflicts, and Approved Formula References across
///                however many recommendations are supplied, per this
///                sprint's Trial Comparison requirements.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'formula_recommendation_engine.dart';

/// One row of a [ComparisonReport]: a field name plus its display
/// value for each compared trial.
@immutable
class ComparisonRow {
  const ComparisonRow({
    required this.field,
    required this.valuesByTrialId,
    required this.hasDifference,
  });

  final String field;
  final Map<int, String> valuesByTrialId;

  /// True if not every trial has the same value for this field —
  /// the basis for "Highlight differences clearly."
  final bool hasDifference;
}

/// Side-by-side comparison of two or more recommendations.
@immutable
class ComparisonReport {
  const ComparisonReport({
    required this.trialFormulaIds,
    required this.rows,
  });

  final List<int> trialFormulaIds;
  final List<ComparisonRow> rows;

  List<ComparisonRow> get differingRows =>
      rows.where((ComparisonRow r) => r.hasDifference).toList();
}

/// Contract for [TrialComparisonEngine].
abstract class ITrialComparisonEngine {
  ComparisonReport compare(List<FormulaRecommendation> recommendations);
}

/// Builds a field-by-field comparison across recommendations.
class TrialComparisonEngine implements ITrialComparisonEngine {
  const TrialComparisonEngine();

  @override
  ComparisonReport compare(List<FormulaRecommendation> recommendations) {
    final List<FormulaRecommendation> withIds = recommendations
        .where((FormulaRecommendation r) => r.trialFormula.id != null)
        .toList();

    final List<int> ids = <int>[
      for (final FormulaRecommendation r in withIds) r.trialFormula.id!,
    ];

    ComparisonRow buildRow(
      String field,
      String Function(FormulaRecommendation r) valueOf,
    ) {
      final Map<int, String> values = <int, String>{
        for (final FormulaRecommendation r in withIds)
          r.trialFormula.id!: valueOf(r),
      };
      final bool differs = values.values.toSet().length > 1;
      return ComparisonRow(
        field: field,
        valuesByTrialId: values,
        hasDifference: differs,
      );
    }

    final List<ComparisonRow> rows = <ComparisonRow>[
      buildRow('Rank', (FormulaRecommendation r) => '#${r.rank}'),
      buildRow(
        'Confidence',
        (FormulaRecommendation r) =>
            '${(r.confidenceScore * 100).toStringAsFixed(0)}%',
      ),
      buildRow(
        'Matched Rules',
        (FormulaRecommendation r) => '${r.matchedRules.length}: '
            '${r.matchedRules.map((rule) => rule.name).join(', ')}',
      ),
      buildRow(
        'Alternative Materials',
        (FormulaRecommendation r) => r.alternativeMaterialIds.isEmpty
            ? 'None'
            : '${r.alternativeMaterialIds.length} needed',
      ),
      buildRow(
        'Conflicts',
        (FormulaRecommendation r) => r.conflicts.isEmpty
            ? 'None'
            : '${r.conflicts.length}: '
                '${r.conflicts.map((c) => c.type.name).join(', ')}',
      ),
      buildRow(
        'Approved Formula Reference',
        (FormulaRecommendation r) => r.approvedFormulaReference == null
            ? 'None'
            : '#${r.approvedFormulaReference!.id}',
      ),
    ];

    return ComparisonReport(trialFormulaIds: ids, rows: rows);
  }
}
