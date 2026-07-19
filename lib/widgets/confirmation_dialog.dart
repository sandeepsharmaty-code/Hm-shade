/// Purpose      : Reusable yes/no confirmation dialog.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Standard confirmation prompt for destructive or
///                consequential actions (e.g. Settings' database
///                reset), returning a bool via Navigator.pop so
///                calling code awaits a simple true/false result
///                instead of each screen building its own AlertDialog.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard confirmation dialog. Prefer [ConfirmationDialog.show]
/// over constructing this widget directly.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    required this.title,
    required this.message,
    super.key,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// When true, renders the confirm action in the theme's error
  /// colour to signal a destructive/irreversible action.
  final bool isDestructive;

  /// Shows the dialog and returns true if confirmed, false if
  /// cancelled, or null if dismissed (e.g. tap outside / back button).
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? TextButton.styleFrom(foregroundColor: colorScheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
