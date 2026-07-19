/// Purpose      : Reusable card summarizing one FormulaRecommendation.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, widgets/app_card.dart,
///                widgets/trial_status_chip.dart,
///                engines/formula_recommendation_engine.dart,
///                models/trial_status.dart
/// Description  : Standard rank/name/confidence/status summary used
///                by NewShadeScreen's Top 5 list and TrialScreen, so
///                a recommendation looks identical wherever it's
///                shown instead of two screens building their own
///                layout for the same data.
/// Change History:
///   1.0.0 - SPR-DEP-009 - Initial creation.
library;

import 'package:flutter/material.dart';

import '../engines/formula_recommendation_engine.dart';
import '../models/trial_status.dart';
import 'app_card.dart';
import 'trial_status_chip.dart';

/// Tappable card summarizing one ranked recommendation.
class RecommendationSummaryCard extends StatelessWidget {
  const RecommendationSummaryCard({
    required this.recommendation,
    super.key,
    this.onTap,
    this.selected = false,
  });

  final FormulaRecommendation recommendation;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TrialStatus status =
        TrialStatus.fromStorageKey(recommendation.trialFormula.status) ??
            TrialStatus.draft;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            child: Text(
              '#${recommendation.rank}',
              style: TextStyle(
                color:
                    selected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recommendation.trialFormula.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.insights,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(recommendation.confidenceScore * 100).toStringAsFixed(0)}% '
                      'confidence',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    TrialStatusChip(status: status),
                  ],
                ),
                if (recommendation.conflicts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${recommendation.conflicts.length} conflict'
                    '${recommendation.conflicts.length == 1 ? '' : 's'} found',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
