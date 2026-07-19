/// Purpose      : Reusable top app bar.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart
/// Description  : Standard AppBar used by RootShellScreen so every
///                tab shares one top-bar presentation (title,
///                optional actions) rather than each screen building
///                its own Scaffold/AppBar pair.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';

/// Standard application app bar, implementing [PreferredSizeWidget]
/// so it can be used directly as [Scaffold.appBar].
class AppCommonBar extends StatelessWidget implements PreferredSizeWidget {
  const AppCommonBar({
    required this.title,
    super.key,
    this.actions,
  });

  /// Title text shown in the bar.
  final String title;

  /// Optional trailing action widgets (e.g. icon buttons).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
