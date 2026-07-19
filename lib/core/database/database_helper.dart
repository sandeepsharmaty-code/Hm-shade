/// Purpose      : Initializes and provides access to the local SQLite
///                database for Hue Muse Shade AI. Creates the full set
///                of approved tables, now with full domain columns for
///                the 13 Data Layer entities plus rule-storage,
///                recommendation-history, and audit-trail columns on
///                Settings.
/// Author       : HMEOS Engineering
/// Version      : 5.0.0
/// Dependencies : sqflite, path, path_provider
/// Description  : Singleton database helper following Repository
///                Pattern support requirements. This file owns schema
///                creation only; all data access goes through the
///                repositories/ layer per Clean Architecture rules.
///
///                Settings now hosts four discriminated record types
///                via `record_type`: 'setting' (default), 'rule'
///                (SPR-DEP-005), 'recommendation_history'
///                (SPR-DEP-006), and 'trial_audit' (SPR-DEP-007) —
///                the audit trail for Trial_Formula status
///                transitions. Same rationale each time: no dedicated
///                table exists in the frozen 14-table schema, and the
///                database stays frozen (no new tables), so this is
///                the only place left to persist configurable/
///                event-log data.
///
///                NOTE: the database file name remains
///                `hue_muse_shade_ai.db` (as approved and shipped in
///                SPR-DEP-001/002), not `huemuse_shade_ai.db` as
///                stated in SPR-DEP-003's brief — see Known Issues in
///                the SPR-DEP-003 report.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation. Foundation schema only.
///   1.1.0 - SPR-DEP-002 - Fixed header formatting. Added
///           resetDatabase() for the real Settings "reset local
///           data" action introduced in the application shell sprint.
///   2.0.0 - SPR-DEP-003 - Added full domain columns (version 2
///           schema) for all 13 Data Layer entities via
///           _tableColumnDefinitions. Added onUpgrade (v1 -> v2).
///           Added DatabaseHelper.forTesting() for repository tests.
///   3.0.0 - SPR-DEP-005 - Added rule-storage columns to Settings
///           (version 3 schema) and default rule seeding for the new
///           Rule Engine. Added onUpgrade (v2 -> v3).
///   4.0.0 - SPR-DEP-006 - Added recommendation-history columns to
///           Settings (version 4 schema). Added onUpgrade (v3 -> v4).
///   5.0.0 - SPR-DEP-007 - Added audit-trail columns to Settings
///           (version 5 schema). Added onUpgrade (v4 -> v5).
///   5.1.0 - SPR-DEP-009 - Added databaseFilePath getter for the
///           Settings screen's new Backup/Restore Database actions.
///           No schema change.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Provides a single, shared connection to the offline SQLite database
/// used by the entire application.
class DatabaseHelper {
  DatabaseHelper._internal();

  /// Test-only constructor wrapping an already-open [database], so
  /// repository tests can run against sqflite_common_ffi (an
  /// in-memory or temp-file database) without going through
  /// [getApplicationDocumentsDirectory], which requires a platform
  /// channel unavailable in plain `flutter_test`/CI environments.
  @visibleForTesting
  DatabaseHelper.forTesting(Database database) : _database = database;

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _databaseName = 'hue_muse_shade_ai.db';
  static const int _databaseVersion = 5;

  /// The complete, approved list of tables for this application.
  /// This list must not be modified without Project Director approval.
  static const List<String> approvedTables = <String>[
    'Product_Master',
    'Shade_Master',
    'Pigment_Master',
    'Dye_Master',
    'Mica_Master',
    'Pearl_Master',
    'Filler_Master',
    'Binder_Master',
    'Blend_Template_Master',
    'Trial_Formula',
    'Formula_Material',
    'Approved_Formula',
    'Knowledge_Base',
    'Settings',
  ];

  /// Full column definitions per table, used for fresh installs.
  /// Every table also implicitly gets the audit columns `is_active`,
  /// `created_at`, `updated_at` appended by [_createTableStatement]
  /// — they are not repeated in every entry.
  static const Map<String, List<String>> _domainColumns = <String, List<String>>{
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
    'Blend_Template_Master': <String>[
      'name TEXT NOT NULL',
      'template_code TEXT NOT NULL',
      'product_id INTEGER',
      'description TEXT',
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
    // Settings hosts four discriminated record types via
    // `record_type`: 'setting' (default), 'rule' (SPR-DEP-005),
    // 'recommendation_history' (SPR-DEP-006), 'trial_audit'
    // (SPR-DEP-007).
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

  Database? _database;

  /// Returns the open database, initializing it on first access.
  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) {
      return existing;
    }
    final Database opened = await _initDatabase();
    _database = opened;
    return opened;
  }

  Future<Database> _initDatabase() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce referential integrity for the Trial_Formula /
    // Formula_Material / Approved_Formula / *_Master relationships.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();
    for (final String tableName in approvedTables) {
      batch.execute(_createTableStatement(tableName));
    }
    await batch.commit(noResult: true);
    await _seedDefaultRules(db);
  }

  /// Upgrades an existing database to the current version.
  ///
  /// v1 -> v2: drops and recreates every approved table with the full
  /// domain schema (see SPR-DEP-003 report — no real device data was
  /// at risk at that point).
  ///
  /// v2 -> v3: adds the rule-storage columns to `Settings` via
  /// `ALTER TABLE ADD COLUMN` (non-destructive — existing Settings
  /// rows, if any, are preserved with `record_type` defaulting to
  /// 'setting'), then seeds the default rule set if none exist yet.
  ///
  /// v3 -> v4: adds the recommendation-history columns to `Settings`,
  /// also non-destructively.
  ///
  /// v4 -> v5: adds the audit-trail columns to `Settings`, also
  /// non-destructively.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final Batch batch = db.batch();
      for (final String tableName in approvedTables) {
        batch.execute('DROP TABLE IF EXISTS $tableName');
      }
      for (final String tableName in approvedTables) {
        batch.execute(_createTableStatement(tableName));
      }
      await batch.commit(noResult: true);
    }

    if (oldVersion < 3) {
      final Batch alterBatch = db.batch();
      // SQLite's ALTER TABLE ADD COLUMN cannot carry a NOT NULL +
      // DEFAULT clause safely across all versions, so columns are
      // added nullable here and backfilled explicitly below —
      // correct even if Settings already had rows before v3 (in
      // practice it never did, since nothing wrote to it before this
      // sprint, but this doesn't assume that).
      alterBatch.execute("ALTER TABLE Settings ADD COLUMN record_type TEXT");
      alterBatch.execute('ALTER TABLE Settings ADD COLUMN rule_type TEXT');
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN condition_key TEXT',
      );
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN condition_operator TEXT',
      );
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN condition_value TEXT',
      );
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN priority INTEGER',
      );
      alterBatch.execute('ALTER TABLE Settings ADD COLUMN weight REAL');
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN rule_version INTEGER',
      );
      alterBatch.execute(
        'ALTER TABLE Settings ADD COLUMN description TEXT',
      );
      await alterBatch.commit(noResult: true);

      // Backfill defaults for any rows that existed before v3.
      final Batch backfillBatch = db.batch();
      backfillBatch.execute(
        "UPDATE Settings SET record_type = 'setting' "
        'WHERE record_type IS NULL',
      );
      backfillBatch.execute(
        'UPDATE Settings SET priority = 0 WHERE priority IS NULL',
      );
      backfillBatch.execute(
        'UPDATE Settings SET weight = 1.0 WHERE weight IS NULL',
      );
      backfillBatch.execute(
        'UPDATE Settings SET rule_version = 1 WHERE rule_version IS NULL',
      );
      await backfillBatch.commit(noResult: true);

      await _seedDefaultRules(db);
    }

    if (oldVersion < 4) {
      final Batch batch = db.batch();
      batch.execute(
        'ALTER TABLE Settings ADD COLUMN input_parameters TEXT',
      );
      batch.execute(
        'ALTER TABLE Settings ADD COLUMN selected_trial_formula_id INTEGER',
      );
      batch.execute(
        'ALTER TABLE Settings ADD COLUMN confidence_score REAL',
      );
      batch.execute('ALTER TABLE Settings ADD COLUMN reason_text TEXT');
      await batch.commit(noResult: true);
    }

    if (oldVersion < 5) {
      final Batch batch = db.batch();
      batch.execute('ALTER TABLE Settings ADD COLUMN status_from TEXT');
      batch.execute('ALTER TABLE Settings ADD COLUMN status_to TEXT');
      batch.execute('ALTER TABLE Settings ADD COLUMN changed_by TEXT');
      batch.execute(
        'ALTER TABLE Settings ADD COLUMN related_recommendation_id INTEGER',
      );
      await batch.commit(noResult: true);
    }
  }

  /// Inserts the default Rule Engine configuration into `Settings` as
  /// `record_type = 'rule'` rows, but only if no rule rows exist yet
  /// — so upgrades/reinstalls never duplicate the seed set, and any
  /// rule the user has since edited or disabled is left alone.
  ///
  /// This is seed *data*, not business logic embedded in code that
  /// evaluates it — the actual matching/scoring logic lives in
  /// RuleEngine/RuleEvaluator (SPR-DEP-005) and reads these rows
  /// through RuleRepository like any other configurable rule.
  Future<void> _seedDefaultRules(Database db) async {
    final List<Map<String, Object?>> existing = await db.query(
      'Settings',
      where: "record_type = 'rule'",
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return;
    }

    final Batch batch = db.batch();
    for (final Map<String, Object?> rule in _defaultRuleSeeds) {
      batch.insert('Settings', rule);
    }
    await batch.commit(noResult: true);
  }

  /// Default rule set covering all 12 required rule types. Weights
  /// are a starting point — see Known Issues in the SPR-DEP-005
  /// report; expected to be retuned once real data exists.
  static final List<Map<String, Object?>> _defaultRuleSeeds = <Map<String, Object?>>[
    <String, Object?>{
      'name': 'Product Match', 'record_type': 'rule',
      'rule_type': 'product', 'condition_key': 'productId',
      'condition_operator': 'equals', 'condition_value': '',
      'priority': 10, 'weight': 0.30, 'rule_version': 1,
      'description': 'Candidate trial belongs to the requested product.',
    },
    <String, Object?>{
      'name': 'Shade Family Match', 'record_type': 'rule',
      'rule_type': 'shade_family', 'condition_key': 'shadeFamily',
      'condition_operator': 'equals', 'condition_value': '',
      'priority': 8, 'weight': 0.20, 'rule_version': 1,
      'description': 'Candidate shade family matches the request.',
    },
    <String, Object?>{
      'name': 'Finish Match', 'record_type': 'rule',
      'rule_type': 'finish', 'condition_key': 'finish',
      'condition_operator': 'equals', 'condition_value': '',
      'priority': 6, 'weight': 0.10, 'rule_version': 1,
      'description': 'Candidate finish matches the request.',
    },
    <String, Object?>{
      'name': 'Coverage Mentioned in Notes', 'record_type': 'rule',
      'rule_type': 'coverage', 'condition_key': 'notes',
      'condition_operator': 'contains', 'condition_value': '',
      'priority': 4, 'weight': 0.10, 'rule_version': 1,
      'description': 'Requested coverage is mentioned in the trial notes.',
    },
    <String, Object?>{
      'name': 'Pigment Available', 'record_type': 'rule',
      'rule_type': 'pigment', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced pigment is active/in stock.',
    },
    <String, Object?>{
      'name': 'Dye Available', 'record_type': 'rule',
      'rule_type': 'dye', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced dye is active/in stock.',
    },
    <String, Object?>{
      'name': 'Mica Available', 'record_type': 'rule',
      'rule_type': 'mica', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced mica is active/in stock.',
    },
    <String, Object?>{
      'name': 'Pearl Available', 'record_type': 'rule',
      'rule_type': 'pearl', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced pearl pigment is active/in stock.',
    },
    <String, Object?>{
      'name': 'Filler Available', 'record_type': 'rule',
      'rule_type': 'filler', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced filler is active/in stock.',
    },
    <String, Object?>{
      'name': 'Binder Available', 'record_type': 'rule',
      'rule_type': 'binder', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'true',
      'priority': 5, 'weight': 0.05, 'rule_version': 1,
      'description': 'Referenced binder is active/in stock.',
    },
    <String, Object?>{
      'name': 'Alternative Material Needed', 'record_type': 'rule',
      'rule_type': 'alternative_material', 'condition_key': 'isActive',
      'condition_operator': 'equals', 'condition_value': 'false',
      'priority': 1, 'weight': -0.05, 'rule_version': 1,
      'description':
          'Referenced material is inactive/missing; an alternative is '
          'needed (negative weight — this is a penalty, not a bonus).',
    },
    <String, Object?>{
      'name': 'Shade Assigned to Requested Product', 'record_type': 'rule',
      'rule_type': 'compatibility', 'condition_key': 'productId',
      'condition_operator': 'equals', 'condition_value': '',
      'priority': 9, 'weight': 0.10, 'rule_version': 1,
      'description': 'Shade is assigned to the product being matched against.',
    },
  ];

  /// Builds the full `CREATE TABLE` statement for [tableName]: its
  /// primary key, any domain columns from [_domainColumns], and the
  /// standard audit columns (`is_active`, `created_at`, `updated_at`).
  String _createTableStatement(String tableName) {
    final List<String> domainColumns = _domainColumns[tableName] ??
        const <String>['name TEXT'];

    final List<String> columns = <String>[
      'id INTEGER PRIMARY KEY AUTOINCREMENT',
      ...domainColumns,
      'is_active INTEGER NOT NULL DEFAULT 1',
      "created_at TEXT NOT NULL DEFAULT (datetime('now'))",
      "updated_at TEXT NOT NULL DEFAULT (datetime('now'))",
    ];

    return 'CREATE TABLE IF NOT EXISTS $tableName (${columns.join(', ')})';
  }

  /// Drops and recreates every approved table, permanently discarding
  /// all locally stored data, then reseeds the default rule set (a
  /// reset restores rules to their defaults, same as every other
  /// table returning to its empty starting state). Used by the
  /// Settings screen's "Reset Local Data" action.
  ///
  /// Wrapped by the caller in a try/catch (see SettingsScreen) per
  /// the "never crash application" error-handling rule; this method
  /// itself lets exceptions propagate so the caller can decide how
  /// to surface them to the user (e.g. via ErrorDialog).
  Future<void> resetDatabase() async {
    final Database db = await database;
    final Batch batch = db.batch();

    for (final String tableName in approvedTables) {
      batch.execute('DROP TABLE IF EXISTS $tableName');
    }
    for (final String tableName in approvedTables) {
      batch.execute(_createTableStatement(tableName));
    }

    await batch.commit(noResult: true);
    await _seedDefaultRules(db);
  }

  /// Full filesystem path to the live database file. Added for
  /// SPR-DEP-009's Backup/Restore Database settings actions — a
  /// minimal addition (one getter), not a redesign of this file's
  /// existing responsibilities.
  Future<String> get databaseFilePath async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  /// Closes the database connection. Intended for test teardown.
  Future<void> close() async {
    final Database? db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
