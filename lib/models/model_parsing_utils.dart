/// Purpose      : Shared SQLite row-parsing helpers for all Data
///                Layer models.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Small, pure functions used by every model's
///                fromMap() to avoid repeating the same
///                null/type-coercion logic 13 times (SQLite stores
///                booleans as 0/1 integers and dates as ISO-8601
///                text; every model needs to convert these back).
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

/// Parses a SQLite `is_active` integer column (0/1) into a bool.
/// Defaults to true (active) if the value is missing or malformed,
/// so a legacy row is never silently treated as deleted.
bool parseActiveFlag(Object? value) {
  if (value is int) {
    return value == 1;
  }
  if (value is bool) {
    return value;
  }
  return true;
}

/// Parses a SQLite ISO-8601 text timestamp column into a [DateTime],
/// or null if missing/unparseable.
DateTime? parseTimestamp(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Parses a SQLite `id`-style integer column, tolerant of the value
/// arriving as an `int` (the common case) or a numeric `String`.
int? parseId(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Parses a SQLite REAL column into a [double], defaulting to 0.
double parseReal(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
