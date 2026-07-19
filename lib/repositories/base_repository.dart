/// Purpose      : Generic SQLite repository base class implementing
///                Create/Read/Update/soft-Delete/Search/Filter/
///                Exists/Count once, shared by every concrete
///                repository.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : sqflite, flutter/foundation.dart,
///                core/database/database_helper.dart,
///                repository_exception.dart
/// Description  : Centralizes all SQLite access so no concrete
///                repository (and certainly no screen) writes SQL
///                directly, per "No SQL inside UI. Centralize all
///                database logic." Concrete repositories only supply
///                a table name and a `fromMap`/`toMap` pair for their
///                model type — this eliminates the "duplicate
///                business logic" that would result from writing the
///                same CRUD code 11 times.
///
///                Delete is soft-delete only: it sets `is_active = 0`
///                rather than removing the row, per the Repository
///                Requirements. Read/search/filter/count exclude
///                inactive rows by default (see `includeInactive`).
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import 'repository_exception.dart';

/// Base class for all SQLite-backed repositories.
///
/// Type parameter [T] is the domain model. Subclasses implement
/// [toMap] and [fromMap] to translate between [T] and SQLite rows,
/// and pass their table's approved name to the constructor.
abstract class BaseSqliteRepository<T> {
  BaseSqliteRepository({
    required this.tableName,
    required DatabaseHelper databaseHelper,
  }) : _databaseHelper = databaseHelper;

  /// The approved table this repository reads and writes.
  final String tableName;

  final DatabaseHelper _databaseHelper;

  /// Converts [entity] into a SQLite row map. Implementations should
  /// omit the `id` key when the entity has not been persisted yet.
  @protected
  Map<String, Object?> toMap(T entity);

  /// Converts a SQLite row map into a domain model instance.
  @protected
  T fromMap(Map<String, Object?> map);

  /// Reads the `id` field from an already-persisted [entity], or
  /// null if it has never been saved.
  @protected
  int? idOf(T entity);

  Future<Database> get _db => _databaseHelper.database;

  void _logDebug(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('$tableName repository: $operation failed: $error');
    }
  }

  /// Inserts a new row for [entity] and returns the persisted entity
  /// (including its generated `id`).
  Future<T> create(T entity) async {
    try {
      final Database db = await _db;
      final Map<String, Object?> map = toMap(entity)..remove('id');
      final int id = await db.insert(tableName, map);
      final Map<String, Object?>? row = await _readRowById(db, id);
      if (row == null) {
        throw const RepositoryException(
          message: 'Record could not be read back after creation.',
          operation: 'create',
        );
      }
      return fromMap(row);
    } catch (error) {
      _logDebug('create', error);
      if (error is RepositoryException) {
        rethrow;
      }
     throw RepositoryException(
        message: 'Unable to create $tableName record.',
        operation: 'create',
        cause: error,
      );
    }
  }

  /// Reads a single active row by [id], or null if not found /
  /// inactive.
  Future<T?> readById(int id, {bool includeInactive = false}) async {
    try {
      final Database db = await _db;
      final Map<String, Object?>? row = await _readRowById(
        db,
        id,
        includeInactive: includeInactive,
      );
      return row == null ? null : fromMap(row);
    } catch (error) {
      _logDebug('readById', error);
      throw RepositoryException(
        message: 'Unable to read $tableName record $id.',
        operation: 'readById',
        cause: error,
      );
    }
  }

  Future<Map<String, Object?>?> _readRowById(
    Database db,
    int id, {
    bool includeInactive = false,
  }) async {
    final String where =
        includeInactive ? 'id = ?' : 'id = ? AND is_active = 1';
    final List<Map<String, Object?>> rows = await db.query(
      tableName,
      where: where,
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Reads all rows, active only by default.
  ///
  /// [extraWhere]/[extraWhereArgs] let a subclass narrow the read to
  /// its own discriminated rows (e.g. RuleRepository restricting to
  /// `record_type = 'rule'` when it shares a physical table with
  /// other record types) without exposing raw SQL to callers outside
  /// the Repository Layer.
  Future<List<T>> readAll({
    bool includeInactive = false,
    String? extraWhere,
    List<Object?>? extraWhereArgs,
  }) async {
    try {
      final Database db = await _db;
      final List<String> whereClauses = <String>[
        if (!includeInactive) 'is_active = 1',
        if (extraWhere != null) extraWhere,
      ];
      final List<Map<String, Object?>> rows = await db.query(
        tableName,
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: extraWhereArgs,
        orderBy: 'id DESC',
      );
      return rows.map(fromMap).toList();
    } catch (error) {
      _logDebug('readAll', error);
      throw RepositoryException(
        message: 'Unable to read $tableName records.',
        operation: 'readAll',
        cause: error,
      );
    }
  }

  /// Updates the row matching [entity]'s `id`. Throws
  /// [RepositoryException] if [entity] has no `id` (never persisted).
  Future<T> update(T entity) async {
    final int? id = idOf(entity);
    if (id == null) {
      throw RepositoryException(
        message: 'Cannot update a $tableName record without an id.',
        operation: 'update',
      );
    }
    try {
      final Database db = await _db;
      final Map<String, Object?> map = toMap(entity)
        ..['updated_at'] = DateTime.now().toIso8601String();
      await db.update(
        tableName,
        map,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final Map<String, Object?>? row = await _readRowById(
        db,
        id,
        includeInactive: true,
      );
      if (row == null) {
        throw const RepositoryException(
          message: 'Record could not be read back after update.',
          operation: 'update',
        );
      }
      return fromMap(row);
    } catch (error) {
      _logDebug('update', error);
      if (error is RepositoryException) {
        rethrow;
      }
      throw RepositoryException(
        message: 'Unable to update $tableName record $id.',
        operation: 'update',
        cause: error,
      );
    }
  }

  /// Soft-deletes the row with [id] by setting `is_active = 0`.
  /// Never removes the row, per the "Delete (Soft Delete Only)"
  /// requirement. Returns true if a row was affected.
  Future<bool> softDelete(int id) async {
    try {
      final Database db = await _db;
      final int affected = await db.update(
        tableName,
        <String, Object?>{
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return affected > 0;
    } catch (error) {
      _logDebug('softDelete', error);
      throw RepositoryException(
        message: 'Unable to delete $tableName record $id.',
        operation: 'softDelete',
        cause: error,
      );
    }
  }

  /// Searches active rows where any column in [columns] contains
  /// [query] (case-insensitive). Defaults to searching `name`.
  Future<List<T>> search(
    String query, {
    List<String> columns = const <String>['name'],
  }) async {
    if (query.trim().isEmpty) {
      return readAll();
    }
    try {
      final Database db = await _db;
      final String likeClause =
          columns.map((String column) => '$column LIKE ?').join(' OR ');
      final List<Object?> args = List<Object?>.filled(
        columns.length,
        '%$query%',
      );
      final List<Map<String, Object?>> rows = await db.query(
        tableName,
        where: 'is_active = 1 AND ($likeClause)',
        whereArgs: args,
        orderBy: 'id DESC',
      );
      return rows.map(fromMap).toList();
    } catch (error) {
      _logDebug('search', error);
      throw RepositoryException(
        message: 'Unable to search $tableName records.',
        operation: 'search',
        cause: error,
      );
    }
  }

  /// Filters active rows by exact-match [criteria] (column -> value).
  /// Results are ordered by [orderBy], which defaults to newest-first
  /// (matching every other read method in this class).
  Future<List<T>> filter(
    Map<String, Object?> criteria, {
    String orderBy = 'id DESC',
  }) async {
    try {
      final Database db = await _db;
      final List<String> whereClauses = <String>['is_active = 1'];
      final List<Object?> args = <Object?>[];
      criteria.forEach((String column, Object? value) {
        whereClauses.add('$column = ?');
        args.add(value);
      });
      final List<Map<String, Object?>> rows = await db.query(
        tableName,
        where: whereClauses.join(' AND '),
        whereArgs: args,
        orderBy: orderBy,
      );
      return rows.map(fromMap).toList();
    } catch (error) {
      _logDebug('filter', error);
      throw RepositoryException(
        message: 'Unable to filter $tableName records.',
        operation: 'filter',
        cause: error,
      );
    }
  }

  /// Returns true if an active row with [id] exists.
  Future<bool> exists(int id) async {
    try {
      final Database db = await _db;
      final Map<String, Object?>? row = await _readRowById(db, id);
      return row != null;
    } catch (error) {
      _logDebug('exists', error);
     throw RepositoryException(
        message: 'Unable to check existence of $tableName record $id.',
        operation: 'exists',
        cause: error,
      );
    }
  }

  /// Returns the count of rows, active only by default.
  Future<int> count({bool includeInactive = false}) async {
    try {
      final Database db = await _db;
      final String sql = includeInactive
          ? 'SELECT COUNT(*) AS total FROM $tableName'
          : 'SELECT COUNT(*) AS total FROM $tableName WHERE is_active = 1';
      final List<Map<String, Object?>> rows = await db.rawQuery(sql);
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (error) {
      _logDebug('count', error);
      throw RepositoryException(
        message: 'Unable to count $tableName records.',
        operation: 'count',
        cause: error,
      );
    }
  }
}
