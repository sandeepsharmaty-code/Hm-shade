/// Purpose      : Reusable labeled text field widget.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Wraps TextFormField with consistent decoration
///                (from core/theme/app_theme.dart's
///                InputDecorationTheme) and a standard API for label,
///                hint, validation, and obscured input, so forms
///                across future module sprints (e.g. formula naming,
///                settings fields) share one input presentation.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard application text input field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });

  /// Field label, shown above/inside the input per Material 3.
  final String label;

  /// Optional controller for reading/writing the field's value.
  final TextEditingController? controller;

  /// Optional placeholder text.
  final String? hint;

  /// Optional validation callback for use inside a [Form].
  final String? Function(String?)? validator;

  /// Whether input characters are hidden (e.g. for passwords).
  final bool obscureText;

  /// Optional keyboard type override (e.g. numeric fields).
  final TextInputType? keyboardType;

  /// Number of visible text lines. Defaults to a single line.
  final int maxLines;

  /// Whether the field accepts input.
  final bool enabled;

  /// Called on every change with the field's current value.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
