/// Purpose      : Minimal application-wide state holder for the
///                foundation sprint, exposed via Provider.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/foundation.dart
/// Description  : Tracks database-ready state so the UI (splash
///                screen) can react once SQLite initialization has
///                completed. Additional state (e.g. selected product,
///                active workflow step) will be added in later module
///                sprints per the Business Layer of the approved
///                architecture.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// Application-wide state for foundation concerns only.
class AppStateProvider extends ChangeNotifier {
  bool _isDatabaseReady = false;

  /// Whether the local SQLite database has finished initializing.
  bool get isDatabaseReady => _isDatabaseReady;

  /// Marks the database as ready and notifies listeners.
  void setDatabaseReady() {
    if (_isDatabaseReady) {
      return;
    }
    _isDatabaseReady = true;
    notifyListeners();
  }
}
