/// Purpose      : Repository for Trial_Formula, and aggregate root
///                for its Formula_Material and Approved_Formula child
///                data.
/// Author       : HMEOS Engineering
/// Version      : 1.1.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/trial_formula_model.dart,
///                models/formula_material_model.dart,
///                models/approved_formula_model.dart,
///                repository_exception.dart
/// Description  : Standard CRUD for Trial_Formula comes from
///                BaseSqliteRepository. Formula_Material and
///                Approved_Formula have no dedicated repository in
///                the approved Repository Layer list — they're child
///                entities with no independent lifecycle outside a
///                trial, so this class also owns their SQLite access
///                (addMaterialLine, updateMaterialLine,
///                materialsForTrial, removeMaterialLine, approveTrial,
///                approvalForTrial), consistent with "no repositories
///                for child entities without independent lifecycle."
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
///   1.1.0 - Repair Sprint R2 (Formula Workflow) - Added
///           updateMaterialLine(). R2's Edit Formula screen needs to
///           correct an existing ingredient line's percentage/notes
///           in place; without this, the only option was
///           removeMaterialLine() + addMaterialLine(), which
///           discards the line's id and created_at instead of
///           preserving them. Mirrors addMaterialLine()'s exact
///           shape — no other method changed.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/approved_formula_model.dart';
import '../models/formula_material_model.dart';
import '../models/trial_formula_model.dart';
import 'base_repository.dart';
import 'repository_exception.dart';

/// Repository for [TrialFormulaModel] and its child aggregate data.
class TrialRepository extends BaseSqliteRepository<TrialFormulaModel> {
  TrialRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        super(
          tableName: 'Trial_Formula',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  static const String _materialTable = 'Formula_Material';
  static const String _approvalTable = 'Approved_Formula';

  final DatabaseHelper _databaseHelper;

  @override
  Map<String, Object?> toMap(TrialFormulaModel entity) => entity.toMap();

  @override
  TrialFormulaModel fromMap(Map<String, Object?> map) =>
      TrialFormulaModel.fromMap(map);

  @override
  int? idOf(TrialFormulaModel entity) => entity.id;

  void _logDebug(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('TrialRepository: $operation failed: $error');
    }
  }

  /// Adds a material line to a trial formula.
  Future<FormulaMaterialModel> addMaterialLine(
    FormulaMaterialModel material,
  ) async {
    try {
      final Database db = await _databaseHelper.database;
      final Map<String, Object?> map = material.toMap()..remove('id');
      final int id = await db.insert(_materialTable, map);
      final List<Map<String, Object?>> rows = await db.query(
        _materialTable,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      return FormulaMaterialModel.fromMap(rows.first);
    } catch (error) {
      _logDebug('addMaterialLine', error);
      throw RepositoryException(
        message: 'Unable to add material line to trial formula.',
        operation: 'addMaterialLine',
        cause: error,
      );
    }
  }

  /// Updates an existing material line in place (e.g. a corrected
  /// percentage or note). [material] must carry a non-null `id`.
  /// Added for R2 (Formula Workflow): editing a formula's ingredient
  /// list needs to change a line's percentage/notes without losing
  /// its identity or `created_at`, which a remove-then-re-add would
  /// do. Mirrors [addMaterialLine]'s existing style exactly — same
  /// table constant, same try/catch/RepositoryException shape — no
  /// other behaviour changes to this class.
  Future<FormulaMaterialModel> updateMaterialLine(
    FormulaMaterialModel material,
  ) async {
    final int? id = material.id;
    if (id == null) {
      throw const RepositoryException(
        message: 'Cannot update a material line without an id.',
        operation: 'updateMaterialLine',
      );
    }
    try {
      final Database db = await _databaseHelper.database;
      final Map<String, Object?> map = material.toMap()
        ..['updated_at'] = DateTime.now().toIso8601String();
      await db.update(
        _materialTable,
        map,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final List<Map<String, Object?>> rows = await db.query(
        _materialTable,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const RepositoryException(
          message: 'Material line could not be read back after update.',
          operation: 'updateMaterialLine',
        );
      }
      return FormulaMaterialModel.fromMap(rows.first);
    } catch (error) {
      _logDebug('updateMaterialLine', error);
      if (error is RepositoryException) {
        rethrow;
      }
      throw RepositoryException(
        message: 'Unable to update material line $id.',
        operation: 'updateMaterialLine',
        cause: error,
      );
    }
  }

  /// Returns all active material lines for [trialFormulaId].
  Future<List<FormulaMaterialModel>> materialsForTrial(
    int trialFormulaId,
  ) async {
    try {
      final Database db = await _databaseHelper.database;
      final List<Map<String, Object?>> rows = await db.query(
        _materialTable,
        where: 'trial_formula_id = ? AND is_active = 1',
        whereArgs: <Object?>[trialFormulaId],
        orderBy: 'id ASC',
      );
      return rows.map(FormulaMaterialModel.fromMap).toList();
    } catch (error) {
      _logDebug('materialsForTrial', error);
      throw RepositoryException(
        message: 'Unable to read material lines for trial formula.',
        operation: 'materialsForTrial',
        cause: error,
      );
    }
  }

  /// Soft-deletes a material line. Returns true if a row was
  /// affected.
  Future<bool> removeMaterialLine(int formulaMaterialId) async {
    try {
      final Database db = await _databaseHelper.database;
      final int affected = await db.update(
        _materialTable,
        <String, Object?>{
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[formulaMaterialId],
      );
      return affected > 0;
    } catch (error) {
      _logDebug('removeMaterialLine', error);
      throw RepositoryException(
        message: 'Unable to remove material line.',
        operation: 'removeMaterialLine',
        cause: error,
      );
    }
  }

  /// Records lab approval for a trial: inserts an Approved_Formula
  /// row and moves the trial's status to 'approved'. Runs both writes
  /// in a single transaction so the trial and its approval never
  /// disagree if one write fails.
  Future<ApprovedFormulaModel> approveTrial(
    ApprovedFormulaModel approval,
  ) async {
    try {
      final Database db = await _databaseHelper.database;
      late final int approvalId;

      await db.transaction((Transaction txn) async {
        final Map<String, Object?> map = approval.toMap()..remove('id');
        approvalId = await txn.insert(_approvalTable, map);

        await txn.update(
          tableName,
          <String, Object?>{
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: <Object?>[approval.trialFormulaId],
        );
      });

      final List<Map<String, Object?>> rows = await db.query(
        _approvalTable,
        where: 'id = ?',
        whereArgs: <Object?>[approvalId],
        limit: 1,
      );
      return ApprovedFormulaModel.fromMap(rows.first);
    } catch (error) {
      _logDebug('approveTrial', error);
      throw RepositoryException(
        message: 'Unable to record approval for trial formula.',
        operation: 'approveTrial',
        cause: error,
      );
    }
  }

  /// Returns the active approval record for [trialFormulaId], or
  /// null if the trial hasn't been approved.
  Future<ApprovedFormulaModel?> approvalForTrial(int trialFormulaId) async {
    try {
      final Database db = await _databaseHelper.database;
      final List<Map<String, Object?>> rows = await db.query(
        _approvalTable,
        where: 'trial_formula_id = ? AND is_active = 1',
        whereArgs: <Object?>[trialFormulaId],
        limit: 1,
      );
      return rows.isEmpty
          ? null
          : ApprovedFormulaModel.fromMap(rows.first);
    } catch (error) {
      _logDebug('approvalForTrial', error);
      throw RepositoryException(
        message: 'Unable to read approval for trial formula.',
        operation: 'approvalForTrial',
        cause: error,
      );
    }
  }

  /// Finds active trials for [shadeId].
  Future<List<TrialFormulaModel>> findByShade(int shadeId) {
    return filter(<String, Object?>{'shade_id': shadeId});
  }
}
