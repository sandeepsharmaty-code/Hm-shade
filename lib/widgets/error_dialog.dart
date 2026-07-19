/// Purpose      : Reusable error-message dialog.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Standard error prompt shown when a caught exception
///                needs to be surfaced to the user (per the
///                "never crash application" error-handling rule —
///                every database/file operation catches and reports
///                through this dialog instead of letting the app
///                crash).
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard error dialog. Prefer [ErrorDialog.show] over constructing
/// this widget directly.
class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    required this.message,
    super.key,
    this.title = 'Something Went Wrong',
  });

  final String title;
  final String message;

  /// Shows the dialog with a single "OK" dismiss action.
  static Future<void> show(
    BuildContext context, {
    required String message,
    String title = 'Something Went Wrong',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ErrorDialog(title: title, message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.error_outline, color: colorScheme.error),
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
