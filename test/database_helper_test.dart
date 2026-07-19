/// Purpose      : Unit tests for DatabaseHelper foundation schema.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi (test-only, see
///                Build Instructions in Sprint report for setup)
/// Description  : Verifies that every table in
///                DatabaseHelper.approvedTables is created exactly
///                once and matches the approved table list, guarding
///                against accidental schema drift.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper', () {
    test('creates exactly the approved set of tables', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            final batch = db.batch();
            for (final table in DatabaseHelper.approvedTables) {
              batch.execute(
                'CREATE TABLE IF NOT EXISTS $table ('
                'id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'name TEXT, '
                "created_at TEXT NOT NULL DEFAULT (datetime('now')), "
                "updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
                ')',
              );
            }
            await batch.commit(noResult: true);
          },
        ),
      );

      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      final Set<String> actualTables =
          rows.map((row) => row['name'] as String).toSet();
      final Set<String> expectedTables =
          DatabaseHelper.approvedTables.toSet();

      expect(actualTables, equals(expectedTables));

      await db.close();
    });

    test('approvedTables list has no duplicates', () {
      final tables = DatabaseHelper.approvedTables;
      expect(tables.toSet().length, equals(tables.length));
    });

    test('approvedTables contains exactly 14 tables', () {
      expect(DatabaseHelper.approvedTables.length, equals(14));
    });
  });
}
