/// Purpose      : Unit tests for TrialWorkflowManager — previously
///                zero test coverage despite being the audited
///                status-transition mechanism every Formula Details
///                action (R2's Change Status/Archive, R3's Reject/
///                Request Revision) relies on.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi,
///                core/database/database_helper.dart,
///                repositories/trial_repository.dart,
///                repositories/trial_audit_repository.dart,
///                engines/trial_workflow_manager.dart,
///                models/trial_status.dart
/// Description  : Same in-memory sqflite_ffi pattern as
///                product_repository_test.dart, scoped to Trial_Formula
///                and Settings (the latter backing
///                TrialAuditRepository).
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/engines/engine_result.dart';
import 'package:hue_muse_shade_ai/engines/trial_workflow_manager.dart';
import 'package:hue_muse_shade_ai/models/trial_audit_entry_model.dart';
import 'package:hue_muse_shade_ai/models/trial_formula_model.dart';
import 'package:hue_muse_shade_ai/models/trial_status.dart';
import 'package:hue_muse_shade_ai/repositories/trial_audit_repository.dart';
import 'package:hue_muse_shade_ai/repositories/trial_repository.dart';

Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Trial_Formula (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            trial_code TEXT NOT NULL,
            shade_id INTEGER,
            product_id INTEGER,
            status TEXT NOT NULL DEFAULT 'draft',
            notes TEXT,
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
            status_from TEXT,
            status_to TEXT,
            changed_by TEXT,
            reason_text TEXT,
            selected_trial_formula_id INTEGER,
            related_recommendation_id INTEGER,
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
  late TrialRepository trialRepository;
  late TrialWorkflowManager manager;

  setUp(() async {
    db = await _openTestDatabase();
    final DatabaseHelper helper = DatabaseHelper.forTesting(db);
    trialRepository = TrialRepository(databaseHelper: helper);
    manager = TrialWorkflowManager(
      trialRepository: trialRepository,
      auditRepository: TrialAuditRepository(databaseHelper: helper),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TrialWorkflowManager.transition', () {
    test('an allowed transition succeeds and updates status', () async {
      final TrialFormulaModel trial = await trialRepository.create(
        const TrialFormulaModel(name: 'Ruby Trial 1', trialCode: 'TRL-0001'),
      );

      final EngineResult<TrialFormulaModel> result = await manager.transition(
        trialFormulaId: trial.id!,
        to: TrialStatus.readyForLab,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.status, TrialStatus.readyForLab.storageKey);

      final TrialFormulaModel? reloaded = await trialRepository.readById(
        trial.id!,
      );
      expect(reloaded!.status, TrialStatus.readyForLab.storageKey);
    });

    test('a disallowed transition fails and does not change status', () async {
      final TrialFormulaModel trial = await trialRepository.create(
        const TrialFormulaModel(name: 'Ruby Trial 1', trialCode: 'TRL-0001'),
      );

      // draft -> approved is not in the allowed-transitions graph
      // (only labTesting -> approved is).
      final EngineResult<TrialFormulaModel> result = await manager.transition(
        trialFormulaId: trial.id!,
        to: TrialStatus.approved,
      );

      expect(result.isFailure, isTrue);
      expect(result.messages.first, contains('Cannot move from Draft'));

      final TrialFormulaModel? reloaded = await trialRepository.readById(
        trial.id!,
      );
      expect(reloaded!.status, TrialStatus.draft.storageKey);
    });

    test('transitioning to the current status is a no-op success', () async {
      final TrialFormulaModel trial = await trialRepository.create(
        const TrialFormulaModel(name: 'Ruby Trial 1', trialCode: 'TRL-0001'),
      );

      final EngineResult<TrialFormulaModel> result = await manager.transition(
        trialFormulaId: trial.id!,
        to: TrialStatus.draft,
      );

      expect(result.isSuccess, isTrue);
      expect(result.messages.first, contains('already Draft'));
    });

    test('a successful transition is recorded in the audit trail', () async {
      final TrialFormulaModel trial = await trialRepository.create(
        const TrialFormulaModel(name: 'Ruby Trial 1', trialCode: 'TRL-0001'),
      );

      await manager.transition(
        trialFormulaId: trial.id!,
        to: TrialStatus.readyForLab,
        reason: 'Formulation complete.',
        changedBy: 'QA Lead',
      );

      final List<TrialAuditEntryModel> history = await manager.history(
        trial.id!,
      );

      expect(history, hasLength(1));
      expect(history.first.statusFrom, TrialStatus.draft.storageKey);
      expect(history.first.statusTo, TrialStatus.readyForLab.storageKey);
      expect(history.first.reason, 'Formulation complete.');
      expect(history.first.changedBy, 'QA Lead');
    });

    test('transitioning a nonexistent trial fails gracefully', () async {
      final EngineResult<TrialFormulaModel> result = await manager.transition(
        trialFormulaId: 999,
        to: TrialStatus.readyForLab,
      );

      expect(result.isFailure, isTrue);
    });
  });
}
