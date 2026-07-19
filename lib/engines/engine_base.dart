/// Purpose      : Shared base class for all engines.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/foundation.dart
/// Description  : Provides the one piece of behaviour every engine
///                needs in common — debug-mode-only logging — so it
///                isn't reimplemented three times. Deliberately thin:
///                engines otherwise differ enough (different
///                repositories, different responsibilities) that a
///                heavier shared base would just be indirection.
///                Engines must never access SQLite directly, never
///                import screen classes, and never contain UI code —
///                this base class enforces none of that structurally
///                (Dart has no "cannot import" annotation), so it's
///                enforced by code review / self-review checklist
///                instead (see SPR-DEP-004 Self Review: grep-verified
///                zero sqflite/screens imports under lib/engines/).
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// Base class for all business-rule engines.
abstract class EngineBase {
  const EngineBase();

  /// Short name used in debug log lines, e.g. "ShadeEngine".
  String get engineName;

  /// Logs [message] via debugPrint, but only in debug builds.
  @protected
  void logDebug(String message) {
    if (kDebugMode) {
      debugPrint('$engineName: $message');
    }
  }
}
