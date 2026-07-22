/// Purpose      : Repository-backed unit test for RuleEngine —
///                closes a gap flagged in every sprint report since
///                SPR-DEP-004 ("no repository-backed engine tests").
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi,
///                core/database/database_helper.dart,
///                repositories/rule_repository.dart,
///                engines/rule_engine.dart, models/rule_model.dart
/// Description  : Seeds real Settings rows (record_type='rule') into
///                an in-memory sqflite_common_ffi database via
///                RuleRepository.create(), then exercises
///                RuleEngine.evaluate() end-to-end: rule loading,
///                fixed-value and dynamic-target condition
///                evaluation, weighted confidence, and — the specific
///                thing SPR-DEP-010's QA sprint asked to verify —
///                that a *disabled* rule (is_active=false) is
///                correctly excluded from evaluation by
///                RuleRepository.findByRuleType's SQL-level filter.
/// Change History:
///   1.0.0 - SPR-DEP-010 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/engines/rule_engine.dart';
import 'package:hue_muse_shade_ai/models/rule_model.dart';
import 'package:hue_muse_shade_ai/repositories/rule_repository.dart';

Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (Database db, int version) async {
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
  late RuleRepository ruleRepository;
  late RuleEngine ruleEngine;

  setUp(() async {
    db = await _openTestDatabase();
    ruleRepository = RuleRepository(
      databaseHelper: DatabaseHelper.forTesting(db),
    );
    ruleEngine = RuleEngine(ruleRepository: ruleRepository);
  });

  tearDown(() async {
    await db.close();
  });

  group('RuleEngine.evaluate (repository-backed)', () {
    test('matches a fixed-value rule and reports confidence 1.0',
        () async {
      await ruleRepository.create(
        const RuleModel(
          name: 'Pigment Available',
          ruleType: RuleType.pigment,
          conditionKey: 'isActive',
          conditionOperator: 'equals',
          conditionValue: 'true',
          weight: 0.5,
        ),
      );

      final result = await ruleEngine.evaluate(
        ruleType: RuleType.pigment,
        facts: <String, Object?>{'isActive': true},
      );

      expect(result.success, isTrue);
      expect(result.matchedRules, hasLength(1));
      expect(result.confidenceScore, closeTo(1.0, 0.0001));
    });

    test('matches a dynamic-target rule via the "_target" convention',
        () async {
      await ruleRepository.create(
        const RuleModel(
          name: 'Product Match',
          ruleType: RuleType.product,
          conditionKey: 'productId',
          conditionOperator: 'equals',
          conditionValue: '',
          weight: 0.3,
        ),
      );

      final result = await ruleEngine.evaluate(
        ruleType: RuleType.product,
        facts: <String, Object?>{
          'productId': 7,
          'productId_target': 7,
        },
      );

      expect(result.success, isTrue);
      expect(result.matchedRules.single.name, 'Product Match');
    });

    test('a disabled rule is excluded from evaluation entirely',
        () async {
      final RuleModel created = await ruleRepository.create(
        const RuleModel(
          name: 'Disabled Finish Rule',
          ruleType: RuleType.finish,
          conditionKey: 'finish',
          conditionOperator: 'equals',
          conditionValue: 'Matte',
          weight: 0.1,
        ),
      );
      await ruleRepository.softDelete(created.id!);

      final result = await ruleEngine.evaluate(
        ruleType: RuleType.finish,
        facts: <String, Object?>{'finish': 'Matte'},
      );

      // No active rules of this type -> RuleEngine reports failure
      // (not a match), since the only rule that would have matched
      // is disabled and never reached RuleEvaluator at all.
      expect(result.success, isFalse);
      expect(result.matchedRules, isEmpty);
    });

    test('confidence reflects a mix of matched and failed rules',
        () async {
      await ruleRepository.create(
        const RuleModel(
          name: 'Matches',
          ruleType: RuleType.coverage,
          conditionKey: 'notes',
          conditionOperator: 'contains',
          conditionValue: 'sheer',
          weight: 0.6,
        ),
      );
      await ruleRepository.create(
        const RuleModel(
          name: 'Does not match',
          ruleType: RuleType.coverage,
          conditionKey: 'notes',
          conditionOperator: 'contains',
          conditionValue: 'full-coverage-only-keyword',
          weight: 0.4,
        ),
      );

      final result = await ruleEngine.evaluate(
        ruleType: RuleType.coverage,
        facts: <String, Object?>{'notes': 'A light, sheer formula.'},
      );

      expect(result.matchedRules, hasLength(1));
      expect(result.failedRules, hasLength(1));
      // matchedWeight (0.6) / totalAbsWeight (0.6 + 0.4 = 1.0)
      expect(result.confidenceScore, closeTo(0.6, 0.0001));
    });
  });
}
