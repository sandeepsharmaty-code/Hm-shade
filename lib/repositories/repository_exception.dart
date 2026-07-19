/// Purpose      : Exception type for Repository Layer failures.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Wraps lower-level SQLite/sqflite exceptions in a
///                single, repository-domain exception type so callers
///                (screens, future use-cases) can catch one type
///                instead of depending on sqflite's exception classes
///                directly, keeping the Repository Layer as the only
///                place that knows it's backed by SQLite.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

/// Thrown by repository methods when a database operation fails.
///
/// Always carries a human-readable [message] and the [operation] that
/// failed (e.g. "create", "softDelete"), and preserves the original
/// [cause] for debug-mode logging without leaking sqflite types to
/// callers.
class RepositoryException implements Exception {
  const RepositoryException({
    required this.message,
    required this.operation,
    this.cause,
  });

  /// Human-readable description safe to show in an ErrorDialog.
  final String message;

  /// The repository operation that failed (e.g. "create", "update").
  final String operation;

  /// The original underlying exception, if any. Not shown to the
  /// user; useful for debug-mode logging only.
  final Object? cause;

  @override
  String toString() =>
      'RepositoryException(operation: $operation, message: $message)';
}
