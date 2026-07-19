/// Purpose      : Lightweight dependency injection container for
///                Hue Muse Shade AI.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Provides a single, explicit registration point for
///                app-wide singletons (DatabaseHelper today;
///                repositories and engines in future module sprints)
///                so that screens and widgets never construct core
///                services directly. Deliberately dependency-free
///                (no third-party service-locator package) since none
///                was in the previously approved dependency list —
///                adding one would be a scope change requiring
///                separate approval. Registered once in main.dart
///                before runApp().
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

/// Minimal type-keyed service locator.
///
/// Not a general-purpose DI framework by design: it only supports
/// singleton registration/lookup, which is all this project's
/// offline, single-process architecture requires.
class ServiceLocator {
  ServiceLocator._internal();

  static final ServiceLocator instance = ServiceLocator._internal();

  final Map<Type, Object> _registry = <Type, Object>{};

  /// Registers [service] as the singleton instance for type [T].
  void registerSingleton<T extends Object>(T service) {
    _registry[T] = service;
  }

  /// Returns the previously registered singleton for type [T].
  ///
  /// Throws a [StateError] if nothing was registered for [T], which
  /// surfaces missing wiring immediately during development rather
  /// than failing silently at runtime.
  T get<T extends Object>() {
    final Object? service = _registry[T];
    if (service == null) {
      throw StateError(
        'ServiceLocator: no registration found for type $T. '
        'Did you forget to call registerSingleton<$T>() in main.dart?',
      );
    }
    return service as T;
  }

  /// Clears all registrations. Intended for test teardown only.
  void reset() {
    _registry.clear();
  }
}
