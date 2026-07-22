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
///
///                Also provides settle() (R7.1 fix): LoadingView
///                (lib/widgets/loading_view.dart) uses an
///                *indeterminate* CircularProgressIndicator, which
///                repeats forever by design. tester.pumpAndSettle()
///                cannot tell "still loading" from "stuck forever" —
///                it just keeps pumping the spinner's frames until it
///                hits its own default timeout, which is exactly
///                Duration(minutes: 10). That is the literal source
///                of the "TimeoutException after 10 minutes" CI hit.
///                settle() wraps the exact same pumpAndSettle() call
///                with an explicit 10-second timeout instead, so any
///                future recurrence of this fails fast and clearly —
///                seconds, not the whole CI job's time budget — while
///                behaving identically to pumpAndSettle() for every
///                test that genuinely settles quickly, which is all
///                of them against this harness's fast in-memory
///                database.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
///   1.1.0 - R7.1 (Final Release Validation fix) - Added settle()
///           and ensureSqfliteFfiInitialized() — see the two notes
///           above. No change to what is registered or how.
///   1.2.0 - R7.2 (CI fix, first real toolchain run's findings) -
///           _openTestDatabase now passes singleInstance: false.
///           sqflite defaults singleInstance to true, keyed by path;
///           inMemoryDatabasePath is the fixed string ':memory:', so
///           every widget-test file plus product_repository_test.dart
///           and database_helper_test.dart (all three open ':memory:'
///           databases the same undocumented-default way) were
///           actually sharing one real connection once `flutter test`
///           ran them concurrently — not the isolated database each
///           file's own setUp() believed it had. That explains both
///           CI symptoms at once: "database has already been closed"
///           errors on tables unrelated to whatever test was
///           running (one file's tearDown closing "its" db actually
///           closed everyone's), and per-test hangs landing on
///           flutter_test's 10-minute default timeout roughly every
///           ten minutes (lock contention on that one shared native
///           connection from concurrent isolates). close() also now
///           tolerates an already-closed database rather than
///           throwing, as a non-load-bearing second line of defense.
///           Applied the same singleInstance: false fix to the other
///           two files independently. Written from log analysis of
///           this project's first-ever real `flutter test` run
///           (previously never executed — see README/KNOWN_ISSUES);
///           not verified against a second real run, since no Flutter
///           toolchain is available here either. Treat as a strong,
///           well-evidenced fix, not a confirmed one, until CI runs
///           green.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Same as `tester.pumpAndSettle()`, but with an explicit 60-second
/// timeout instead of pumpAndSettle()'s own 10-minute default — see
/// this file's header for why that default is the literal source of
/// the "TimeoutException after 10 minutes" CI hit. Behaves exactly
/// like pumpAndSettle() otherwise (same pump interval, same engine
/// phase) for any test that genuinely settles, which is every test
/// against this harness's fast in-memory database.
///
/// R7.4: was 10 seconds. On GitHub Actions' shared runners the very
/// first widget test in the whole suite pays a one-time cost (JIT
/// warm-up across the widget/rendering pipeline, native sqlite3
/// library load via FFI) that can genuinely exceed 10 real seconds on
/// a slow or contended runner — that is a false-positive "timed out",
/// not a real hang, and it was reproduced even with
/// `flutter test --concurrency=1` (no other file running) on the
/// simplest possible test (an empty-state screen, zero rows). 60
/// seconds gives real cold-start slowness room without reintroducing
/// pumpAndSettle's own default of a full 10 minutes.
Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 60),
  );
}

bool _sqfliteFfiInitialized = false;

/// Initializes the sqflite FFI loader once per test isolate instead
/// of once per test. sqfliteFfiInit() is safe to call repeatedly, but
/// every widget test file's setUp() (which runs before *each* test,
/// not once per file) calling it before every single test adds
/// redundant initialization overhead that compounds across a suite
/// this size.
void ensureSqfliteFfiInitialized() {
  if (!_sqfliteFfiInitialized) {
    sqfliteFfiInit();
    _sqfliteFfiInitialized = true;
  }
}

Future<Database> _openTestDatabase() async {
  ensureSqfliteFfiInitialized();
  return databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      // R7.2 fix — see this file's header. sqflite defaults
      // `singleInstance` to true, keyed by path. inMemoryDatabasePath
      // is the literal string ':memory:', so every test file in this
      // suite (and product_repository_test.dart /
      // database_helper_test.dart, which open their own ':memory:'
      // databases the same way) was handed back the *same* cached
      // connection instead of a private one. `flutter test` runs
      // files concurrently, so one file's tearDown closing "its" db
      // silently closed every other file's db mid-query — the exact
      // shape of the "database has already been closed" cascade and
      // the staggered ~10-minute per-test hangs seen in CI (contended
      // access to one shared native connection from concurrent
      // isolates). false forces a genuinely independent in-memory
      // database per open() call, matching this class's own doc
      // comment ("an isolated in-memory database").
      singleInstance: false,
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
    // R7.5 diagnostic instrumentation — see this file's header. Every
    // fix attempt so far (singleInstance: false, settle() 10s->60s)
    // measurably helped but did not eliminate a recurring pattern of
    // individual tests hanging the full real 10-minute
    // flutter_test default, roughly every ten minutes, each time on a
    // different test. Static reading of the suspect screens/
    // repositories hasn't found a logic bug. This prints real
    // wall-clock durations for open()/close() so the next CI log
    // shows directly whether a specific harness cycle is the one that
    // stalls (and how long it actually took), instead of another
    // inferred theory.
    final Stopwatch stopwatch = Stopwatch()..start();
    final Database db = await _openTestDatabase();
    final DatabaseHelper helper = DatabaseHelper.forTesting(db);
    final WidgetTestHarness harness = WidgetTestHarness._(db, helper);
    harness._registerAll();
    stopwatch.stop();
    if (stopwatch.elapsed > const Duration(seconds: 1)) {
      // Only log the slow ones — printing on every one of ~200 calls
      // would flood the log. Anything over 1 real second for opening
      // an in-memory database plus registering 16 objects is already
      // abnormal.
      debugPrint(
        '[R7.5 diag] WidgetTestHarness.open() took '
        '${stopwatch.elapsedMilliseconds}ms (real time)',
      );
    }
    return harness;
  }

  Future<void> close() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    ServiceLocator.instance.reset();
    // Defensive, not load-bearing now that singleInstance: false makes
    // each harness's database genuinely private: a stray unawaited
    // Future from a disposed widget (e.g. a fire-and-forget initState
    // load) could still resolve after this point and touch a closed
    // connection. That should no longer happen with real test
    // isolation, but swallowing "already closed" here means it can
    // never again cascade into a later test the way it did before
    // this fix, however it happens.
    try {
      await _db.close();
    } on Object catch (error) {
      if (!'$error'.contains('already been closed')) {
        rethrow;
      }
    }
    stopwatch.stop();
    if (stopwatch.elapsed > const Duration(seconds: 1)) {
      debugPrint(
        '[R7.5 diag] WidgetTestHarness.close() took '
        '${stopwatch.elapsedMilliseconds}ms (real time)',
      );
    }
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
