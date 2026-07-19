/// Purpose      : Reusable content card widget.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Wraps Card with the app's standard padding, corner
///                radius, and optional tap handling so every screen
///                shares one card presentation instead of redefining
///                it, per the "no duplicate widgets" rule. Styling
///                itself (elevation, radius) comes from
///                core/theme/app_theme.dart's CardThemeData.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard application card with consistent internal padding.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  /// Card content.
  final Widget child;

  /// Optional tap handler. If provided, the card becomes an
  /// InkWell-wrapped tappable surface.
  final VoidCallback? onTap;

  /// Internal padding around [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final CardThemeData cardTheme = Theme.of(context).cardTheme;
    final ShapeBorder? shape = cardTheme.shape;

    final Widget content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Card(child: content);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}
