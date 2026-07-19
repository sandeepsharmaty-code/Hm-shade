/// Purpose      : Reusable chip showing a trial's lab-workflow
///                status.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, models/trial_status.dart
/// Description  : Standard status indicator used by HomeScreen,
///                KnowledgeBaseScreen, and TrialScreen so every trial
///                status renders identically instead of each screen
///                picking its own colours/labels.
/// Change History:
///   1.0.0 - SPR-DEP-009 - Initial creation.
library;

import 'package:flutter/material.dart';

import '../models/trial_status.dart';

/// Colour-coded chip for a [TrialStatus].
class TrialStatusChip extends StatelessWidget {
  const TrialStatusChip({required this.status, super.key});

  final TrialStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      TrialStatus.draft => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
      TrialStatus.readyForLab => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      TrialStatus.labTesting => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      TrialStatus.approved => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      TrialStatus.rejected => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
      TrialStatus.archived => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
