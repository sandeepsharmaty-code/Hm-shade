/// Purpose      : Root application shell — bottom navigation host.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, provider,
///                core/services/navigation_provider.dart,
///                widgets/app_common_bar.dart,
///                widgets/app_bottom_nav.dart,
///                screens/home_screen.dart,
///                screens/new_shade_screen.dart,
///                screens/knowledge_base_screen.dart,
///                screens/search_screen.dart,
///                screens/settings_screen.dart
/// Description  : Single Scaffold owning the shared AppCommonBar and
///                AppBottomNav; the five tabs are presentation-only
///                children shown via IndexedStack (which preserves
///                each tab's widget state across switches, unlike
///                rebuilding on every navigation).
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/navigation_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_common_bar.dart';
import 'home_screen.dart';
import 'knowledge_base_screen.dart';
import 'new_shade_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Root shell hosting all five bottom-navigation destinations.
class RootShellScreen extends StatelessWidget {
  const RootShellScreen({super.key});

  static const Map<AppTab, String> _titles = <AppTab, String>{
    AppTab.home: 'Hue Muse Shade AI',
    AppTab.newShade: 'New Shade',
    AppTab.knowledgeBase: 'Knowledge Base',
    AppTab.search: 'Search',
    AppTab.settings: 'Settings',
  };

  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    NewShadeScreen(),
    KnowledgeBaseScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final NavigationProvider navigation = context.watch<NavigationProvider>();

    return Scaffold(
      appBar: AppCommonBar(
        title: _titles[navigation.currentTab] ?? 'Hue Muse Shade AI',
      ),
      body: IndexedStack(
        index: navigation.currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
