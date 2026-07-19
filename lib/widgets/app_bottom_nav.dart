/// Purpose      : Reusable bottom navigation bar for the application
///                shell.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, provider,
///                core/services/navigation_provider.dart
/// Description  : Material 3 NavigationBar wired to
///                [NavigationProvider], reading the current tab and
///                dispatching selection changes. Kept presentation-
///                only per the "UI should contain presentation only"
///                rule — all tab-switching logic lives in
///                NavigationProvider.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/navigation_provider.dart';

/// Bottom navigation bar for the five shell destinations.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationProvider navigation = context.watch<NavigationProvider>();

    return NavigationBar(
      selectedIndex: navigation.currentIndex,
      onDestinationSelected: (int index) {
        context.read<NavigationProvider>().selectIndex(index);
      },
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_photo_alternate_outlined),
          selectedIcon: Icon(Icons.add_photo_alternate),
          label: 'New Shade',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Knowledge',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
