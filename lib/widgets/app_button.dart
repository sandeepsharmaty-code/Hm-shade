/// Purpose      : Reusable primary/secondary button widget.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Wraps ElevatedButton/OutlinedButton with a
///                consistent API (label, icon, loading state,
///                disabled state) so no screen builds its own button
///                styling, per the "no duplicate widgets" performance
///                rule.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant { primary, secondary }

/// Standard application button.
///
/// Use [AppButtonVariant.primary] for the main action on a screen and
/// [AppButtonVariant.secondary] for supporting actions.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  /// Button text.
  final String label;

  /// Called when tapped. If null, the button renders disabled.
  final VoidCallback? onPressed;

  /// Primary (filled) or secondary (outlined) styling.
  final AppButtonVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner in place of the label and disables tapping.
  final bool isLoading;

  /// Whether the button should fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;
    final Widget child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              );

    final Widget button = variant == AppButtonVariant.primary
        ? ElevatedButton(onPressed: effectiveOnPressed, child: child)
        : OutlinedButton(onPressed: effectiveOnPressed, child: child);

    if (!expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
