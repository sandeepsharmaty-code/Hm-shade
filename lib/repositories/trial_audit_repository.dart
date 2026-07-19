/// Purpose      : Repository for trial audit-trail entries.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/trial_audit_entry_model.dart
/// Description  : Only entry point for audit-trail SQLite access.
///                Backed by `Settings` (see database_helper.dart
///                header), every row tagged
///                `record_type = 'trial_audit'`.
///
///                CONSTRAINT: shares the same cross-repository id
///                caveat as RuleRepository/
///                RecommendationHistoryRepository (see those files'
///                headers) — an id from this repository must never
///                be passed to either of the other two, or vice
///                versa.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/trial_audit_entry_model.dart';
import 'base_repository.dart';

/// Repository for [TrialAuditEntryModel] records.
class TrialAuditRepository
    extends BaseSqliteRepository<TrialAuditEntryModel> {
  TrialAuditRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Settings',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(TrialAuditEntryModel entity) => entity.toMap();

  @override
  TrialAuditEntryModel fromMap(Map<String, Object?> map) =>
      TrialAuditEntryModel.fromMap(map);

  @override
  int? idOf(TrialAuditEntryModel entity) => entity.id;

  /// Returns every audit entry for [trialFormulaId], oldest first —
  /// the full transition history for one trial.
  Future<List<TrialAuditEntryModel>> historyForTrial(
    int trialFormulaId,
  ) async {
    return filter(
      <String, Object?>{
        'record_type': 'trial_audit',
        'selected_trial_formula_id': trialFormulaId,
      },
      orderBy: 'id ASC',
    );
  }
}
