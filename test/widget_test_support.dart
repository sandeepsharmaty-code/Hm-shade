/// Purpose      : Shared test infrastructure for widget tests that
///                pump a real screen (not just a leaf widget).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi,
///                core/database/database_helper.dart,
///                core/di/service_locator.dart, repositories/*,
///                engines/rule_engine.dart,
///                engines/material_matching_engine.dart,
///                engines/trial_workflow_manager.dart
/// Description  : trial_status_chip_test.dart (SPR-DEP-010) was this
///                project's first widget test and deliberately picked
///                a leaf widget needing no ServiceLocator wiring,
///                flagging "pumping a full screen would require
///                registering test doubles for the entire DI graph"
///                as a follow-up. This file is that follow-up.
///
///                Rather than a mocking framework (none is a project
///                dependency, and adding one is out of scope — "Do
///                NOT add dependencies"), this opens a real in-memory
///                SQLite database via sqflite_common_ffi (exactly
///                product_repository_test.dart's existing, already-
///                accepted pattern, extended to every table this
///                project's screens actually touch) and registers
///                real repository/engine instances against it via
///                ServiceLocator — the same objects production code
///                uses, just pointed at a throwaway database.
///                ServiceLocator.reset() in tearDown is the
///                "Intended for test teardown only" method already
///                present on ServiceLocator (SPR-DEP-002), not
///                something added for this file.
///
///                Only wires what the ten screens named in R6-003
///                actually call via ServiceLocator.get<T>() —
///                confirmed by grepping every one of those screen
///                files, not assumed. The full 30+-registration graph
///                in main.dart also wires the AI/image-analysis
///                engines, which none of those ten screens use
///                directly (only new_shade_screen.dart does, and it
///                isn't in the R6-003 list).
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/engines/material_matching_engine.dart';
import 'package:hue_muse_shade_ai/engines/rule_engine.dart';
import 'package:hue_muse_shade_ai/engines/trial_workflow_manager.dart';
import 'package:hue_muse_shade_ai/repositories/binder_repository.dart';
import 'package:hue_muse_shade_ai/repositories/dye_repository.dart';
import 'package:hue_muse_shade_ai/repositories/filler_repository.dart';
import 'package:hue_muse_shade_ai/repositories/knowledge_repository.dart';
import 'package:hue_muse_shade_ai/repositories/mica_repository.dart';
import 'package:hue_muse_shade_ai/repositories/pearl_repository.dart';
import 'package:hue_muse_shade_ai/repositories/pigment_repository.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/repositories/recommendation_history_repository.dart';
import 'package:hue_muse_shade_ai/repositories/rule_repository.dart';
import 'package:hue_muse_shade_ai/repositories/shade_repository.dart';
import 'package:hue_muse_shade_ai/repositories/trial_audit_repository.dart';
import 'package:hue_muse_shade_ai/repositories/trial_repository.dart';

/// Every column set below is copied verbatim from
/// database_helper.dart's own schema (read directly, not assumed) —
/// this file can't import that map, since it's a private field of a
/// different library. Every table also gets the same
/// is_active/created_at/updated_at audit columns
/// database_helper.dart's _createTableStatement appends to all of
/// them.
const Map<String, List<String>> _kTestSchemaColumns = <String, List<String>>{
  'Product_Master': <String>[
    'name TEXT NOT NULL',
    'product_code TEXT NOT NULL',
    'category TEXT NOT NULL',
    'base_type TEXT',
    'description TEXT',
  ],
  'Shade_Master': <String>[
    'name TEXT NOT NULL',
    'shade_code TEXT NOT NULL',
    'product_id INTEGER',
    'hex_color TEXT',
    'shade_family TEXT',
    'finish TEXT',
    "status TEXT NOT NULL DEFAULT 'draft'",
  ],
  'Pigment_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'color_index TEXT',
  ],
  'Dye_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'solubility TEXT',
  ],
  'Mica_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'particle_size TEXT',
  ],
  'Pearl_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'pearl_type TEXT',
  ],
  'Filler_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'filler_type TEXT',
  ],
  'Binder_Master': <String>[
    'name TEXT NOT NULL',
    'material_code TEXT NOT NULL',
    'cas_number TEXT',
    'supplier TEXT',
    "unit TEXT NOT NULL DEFAULT 'g'",
    'cost_per_unit REAL NOT NULL DEFAULT 0',
    'stock_quantity REAL NOT NULL DEFAULT 0',
    'binder_type TEXT',
  ],
  'Trial_Formula': <String>[
    'name TEXT NOT NULL',
    'trial_code TEXT NOT NULL',
    'shade_id INTEGER',
    'product_id INTEGER',
    "status TEXT NOT NULL DEFAULT 'draft'",
    'notes TEXT',
  ],
  'Formula_Material': <String>[
    'name TEXT',
    'trial_formula_id INTEGER NOT NULL',
    'material_table TEXT NOT NULL',
    'material_id INTEGER NOT NULL',
    'percentage REAL NOT NULL DEFAULT 0',
    'notes TEXT',
  ],
  'Approved_Formula': <String>[
    'name TEXT',
    'trial_formula_id INTEGER NOT NULL',
    'approved_by TEXT',
    'approval_notes TEXT',
  ],
  'Knowledge_Base': <String>[
    'name TEXT NOT NULL',
    'approved_formula_id INTEGER',
    'tags TEXT',
    'content TEXT',
  ],
  // Backs RuleRepository, RecommendationHistoryRepository, and
  // TrialAuditRepository, discriminated by record_type — same
  // multi-purpose table database_helper.dart itself uses.
  'Settings': <String>[
    'name TEXT',
    "record_type TEXT NOT NULL DEFAULT 'setting'",
    'rule_type TEXT',
    'condition_key TEXT',
    'condition_operator TEXT',
    'condition_value TEXT',
    'priority INTEGER NOT NULL DEFAULT 0',
    'weight REAL NOT NULL DEFAULT 1.0',
    'rule_version INTEGER NOT NULL DEFAULT 1',
    'description TEXT',
    'input_parameters TEXT',
    'selected_trial_formula_id INTEGER',
    'confidence_score REAL',
    'reason_text TEXT',
    'status_from TEXT',
    'status_to TEXT',
    'changed_by TEXT',
    'related_recommendation_id INTEGER',
  ],
};

Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (Database db, int version) async {
        final Batch batch = db.batch();
        for (final MapEntry<String, List<String>> entry
            in _kTestSchemaColumns.entries) {
          final String columns = entry.value.join(', ');
          batch.execute('''
            CREATE TABLE ${entry.key} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              $columns,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        }
        await batch.commit(noResult: true);
      },
    ),
  );
}

/// Everything a widget test needs: an isolated in-memory database and
/// every repository/engine the ten R6-003 screens use, all pointed
/// at it. Call [WidgetTestHarness.open] in setUp and
/// [WidgetTestHarness.close] in tearDown.
class WidgetTestHarness {
  WidgetTestHarness._(this._db, this.databaseHelper);

  final Database _db;
  final DatabaseHelper databaseHelper;

  static Future<WidgetTestHarness> open() async {
    final Database db = await _openTestDatabase();
    final DatabaseHelper helper = DatabaseHelper.forTesting(db);
    final WidgetTestHarness harness = WidgetTestHarness._(db, helper);
    harness._registerAll();
    return harness;
  }

  Future<void> close() async {
    ServiceLocator.instance.reset();
    await _db.close();
  }

  void _registerAll() {
    final ProductRepository productRepository = ProductRepository(
      databaseHelper: databaseHelper,
    );
    final ShadeRepository shadeRepository = ShadeRepository(
      databaseHelper: databaseHelper,
    );
    final PigmentRepository pigmentRepository = PigmentRepository(
      databaseHelper: databaseHelper,
    );
    final DyeRepository dyeRepository = DyeRepository(
      databaseHelper: databaseHelper,
    );
    final MicaRepository micaRepository = MicaRepository(
      databaseHelper: databaseHelper,
    );
    final PearlRepository pearlRepository = PearlRepository(
      databaseHelper: databaseHelper,
    );
    final FillerRepository fillerRepository = FillerRepository(
      databaseHelper: databaseHelper,
    );
    final BinderRepository binderRepository = BinderRepository(
      databaseHelper: databaseHelper,
    );
    final TrialRepository trialRepository = TrialRepository(
      databaseHelper: databaseHelper,
    );
    final KnowledgeRepository knowledgeRepository = KnowledgeRepository(
      databaseHelper: databaseHelper,
    );
    final RuleRepository ruleRepository = RuleRepository(
      databaseHelper: databaseHelper,
    );
    final RecommendationHistoryRepository historyRepository =
        RecommendationHistoryRepository(databaseHelper: databaseHelper);
    final TrialAuditRepository trialAuditRepository = TrialAuditRepository(
      databaseHelper: databaseHelper,
    );

    final RuleEngine ruleEngine = RuleEngine(ruleRepository: ruleRepository);
    final MaterialMatchingEngine materialMatchingEngine =
        MaterialMatchingEngine(
      ruleEngine: ruleEngine,
      pigmentRepository: pigmentRepository,
      dyeRepository: dyeRepository,
      micaRepository: micaRepository,
      pearlRepository: pearlRepository,
      fillerRepository: fillerRepository,
      binderRepository: binderRepository,
    );
    final TrialWorkflowManager trialWorkflowManager = TrialWorkflowManager(
      trialRepository: trialRepository,
      auditRepository: trialAuditRepository,
    );

    ServiceLocator.instance
      ..registerSingleton<ProductRepository>(productRepository)
      ..registerSingleton<ShadeRepository>(shadeRepository)
      ..registerSingleton<PigmentRepository>(pigmentRepository)
      ..registerSingleton<DyeRepository>(dyeRepository)
      ..registerSingleton<MicaRepository>(micaRepository)
      ..registerSingleton<PearlRepository>(pearlRepository)
      ..registerSingleton<FillerRepository>(fillerRepository)
      ..registerSingleton<BinderRepository>(binderRepository)
      ..registerSingleton<TrialRepository>(trialRepository)
      ..registerSingleton<KnowledgeRepository>(knowledgeRepository)
      ..registerSingleton<RuleRepository>(ruleRepository)
      ..registerSingleton<RecommendationHistoryRepository>(historyRepository)
      ..registerSingleton<TrialAuditRepository>(trialAuditRepository)
      ..registerSingleton<IRuleEngine>(ruleEngine)
      ..registerSingleton<IMaterialMatchingEngine>(materialMatchingEngine)
      ..registerSingleton<ITrialWorkflowManager>(trialWorkflowManager);
  }
}
