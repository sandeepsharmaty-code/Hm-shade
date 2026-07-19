/// Purpose      : Reusable loading-state widget.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Standard centered spinner with optional message,
///                used any time a screen awaits an async operation
///                (SQLite queries in future module sprints, image
///                processing, etc.) instead of each screen building
///                its own loading layout.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard full-space loading indicator with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  /// Optional text shown below the spinner (e.g. "Loading shades...").
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
