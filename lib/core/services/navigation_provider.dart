/// Purpose      : Tracks the selected bottom-navigation tab for the
///                application shell.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/foundation.dart
/// Description  : Business Layer state consumed by RootShellScreen
///                and AppBottomNav. Kept separate from
///                AppStateProvider (which owns database-readiness
///                state) so each provider has a single responsibility.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// Identifies each destination in the bottom navigation shell.
enum AppTab {
  home,
  newShade,
  knowledgeBase,
  search,
  settings,
}

/// Holds the currently selected [AppTab] for the application shell.
class NavigationProvider extends ChangeNotifier {
  AppTab _currentTab = AppTab.home;

  /// The currently selected tab.
  AppTab get currentTab => _currentTab;

  /// The currently selected tab's index, for use with
  /// [IndexedStack]/[NavigationBar] which are index-based.
  int get currentIndex => _currentTab.index;

  /// Switches the selected tab by [AppTab] value.
  void selectTab(AppTab tab) {
    if (_currentTab == tab) {
      return;
    }
    _currentTab = tab;
    notifyListeners();
  }

  /// Switches the selected tab by index. Ignores out-of-range values
  /// rather than throwing, so a stray index never crashes the shell.
  void selectIndex(int index) {
    if (index < 0 || index >= AppTab.values.length) {
      return;
    }
    selectTab(AppTab.values[index]);
  }
}
