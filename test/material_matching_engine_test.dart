/// Purpose      : Unit tests for MaterialMatchingEngine — previously
///                zero test coverage despite being the engine R2/R3's
///                Formula Details screen calls for every ingredient
///                line's Rule Compliance display (R2-009).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi,
///                core/database/database_helper.dart,
///                repositories/pigment_repository.dart,
///                repositories/rule_repository.dart,
///                engines/rule_engine.dart,
///                engines/material_matching_engine.dart
/// Description  : Same in-memory sqflite_ffi pattern as
///                product_repository_test.dart, scoped to the two
///                tables this engine and its RuleEngine dependency
///                actually touch (Pigment_Master, Settings — the
///                latter backing RuleRepository).
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/engines/engine_result.dart';
import 'package:hue_muse_shade_ai/engines/material_matching_engine.dart';
import 'package:hue_muse_shade_ai/engines/rule_engine.dart';
import 'package:hue_muse_shade_ai/models/pigment_model.dart';
import 'package:hue_muse_shade_ai/repositories/binder_repository.dart';
import 'package:hue_muse_shade_ai/repositories/dye_repository.dart';
import 'package:hue_muse_shade_ai/repositories/filler_repository.dart';
import 'package:hue_muse_shade_ai/repositories/mica_repository.dart';
import 'package:hue_muse_shade_ai/repositories/pearl_repository.dart';
import 'package:hue_muse_shade_ai/repositories/pigment_repository.dart';
import 'package:hue_muse_shade_ai/repositories/rule_repository.dart';

Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Pigment_Master (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            material_code TEXT NOT NULL,
            cas_number TEXT,
            supplier TEXT,
            unit TEXT NOT NULL DEFAULT 'g',
            cost_per_unit REAL NOT NULL DEFAULT 0,
            stock_quantity REAL NOT NULL DEFAULT 0,
            color_index TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE Settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            record_type TEXT NOT NULL DEFAULT 'setting',
            rule_type TEXT,
            condition_key TEXT,
            condition_operator TEXT,
            condition_value TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            weight REAL NOT NULL DEFAULT 1.0,
            rule_version INTEGER NOT NULL DEFAULT 1,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      },
    ),
  );
}

void main() {
  late Database db;
  late PigmentRepository pigmentRepository;
  late MaterialMatchingEngine engine;

  setUp(() async {
    db = await _openTestDatabase();
    final DatabaseHelper helper = DatabaseHelper.forTesting(db);
    pigmentRepository = PigmentRepository(databaseHelper: helper);
    final RuleRepository ruleRepository = RuleRepository(
      databaseHelper: helper,
    );
    final RuleEngine ruleEngine = RuleEngine(ruleRepository: ruleRepository);
    engine = MaterialMatchingEngine(
      ruleEngine: ruleEngine,
      pigmentRepository: pigmentRepository,
      dyeRepository: DyeRepository(databaseHelper: helper),
      micaRepository: MicaRepository(databaseHelper: helper),
      pearlRepository: PearlRepository(databaseHelper: helper),
      fillerRepository: FillerRepository(databaseHelper: helper),
      binderRepository: BinderRepository(databaseHelper: helper),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('MaterialMatchingEngine.matchMaterial', () {
    test('an active material is approved', () async {
      final PigmentModel created = await pigmentRepository.create(
        const PigmentModel(name: 'Iron Oxide Red', materialCode: 'PIG-0001'),
      );

      final EngineResult<MaterialMatchResult> result =
          await engine.matchMaterial(
        materialTable: 'Pigment_Master',
        materialId: created.id!,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.isApproved, isTrue);
      expect(result.data!.materialTable, 'Pigment_Master');
      expect(result.data!.materialId, created.id);
    });

    test('an inactive material is not approved and gets a warning', () async {
      final PigmentModel created = await pigmentRepository.create(
        const PigmentModel(
          name: 'Discontinued Red',
          materialCode: 'PIG-0002',
          isActive: false,
        ),
      );

      final EngineResult<MaterialMatchResult> result =
          await engine.matchMaterial(
        materialTable: 'Pigment_Master',
        materialId: created.id!,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.isApproved, isFalse);
      expect(
        result.warnings,
        contains('Material is inactive; alternatives suggested.'),
      );
    });

    test('confidence is 0.0 when no rules are configured for the type', () async {
      final PigmentModel created = await pigmentRepository.create(
        const PigmentModel(name: 'Iron Oxide Red', materialCode: 'PIG-0001'),
      );

      final EngineResult<MaterialMatchResult> result =
          await engine.matchMaterial(
        materialTable: 'Pigment_Master',
        materialId: created.id!,
      );

      // No rules seeded in this test's Settings table, so RuleEngine
      // returns 0 confidence (confirmed by reading rule_engine.dart's
      // own "rules.isEmpty" branch) rather than crashing or defaulting
      // to full confidence.
      expect(result.confidenceScore, 0.0);
    });

    test('an unknown material table fails gracefully', () async {
      final EngineResult<MaterialMatchResult> result =
          await engine.matchMaterial(
        materialTable: 'Not_A_Real_Table',
        materialId: 1,
      );

      expect(result.isFailure, isTrue);
      expect(result.messages, isNotEmpty);
    });

    test('a nonexistent material id fails gracefully', () async {
      final EngineResult<MaterialMatchResult> result =
          await engine.matchMaterial(
        materialTable: 'Pigment_Master',
        materialId: 999,
      );

      expect(result.isFailure, isTrue);
    });
  });
}
