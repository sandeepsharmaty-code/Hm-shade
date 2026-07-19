/// Purpose      : Manages Trial_Formula lab-workflow status
///                transitions and their audit trail.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart,
///                models/trial_status.dart, models/trial_formula_model.dart,
///                repositories/trial_repository.dart,
///                repositories/trial_audit_repository.dart
/// Description  : Enforces the allowed-transition graph in
///                TrialStatus (Draft -> Ready for Lab -> Lab Testing
///                -> Approved/Rejected, any -> Archived, Rejected ->
///                Draft for rework). Every transition — including
///                rejected ones — is recorded via
///                TrialAuditRepository, satisfying "History of every
///                status transition must be preserved." Reads/writes
///                only through TrialRepository/TrialAuditRepository —
///                never SQLite directly.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import '../models/trial_audit_entry_model.dart';
import '../models/trial_formula_model.dart';
import '../models/trial_status.dart';
import '../repositories/repository_exception.dart';
import '../repositories/trial_audit_repository.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';

/// Contract for [TrialWorkflowManager].
abstract class ITrialWorkflowManager {
  Future<EngineResult<TrialFormulaModel>> transition({
    required int trialFormulaId,
    required TrialStatus to,
    String changedBy,
    String? reason,
    int? relatedRecommendationId,
  });

  Future<List<TrialAuditEntryModel>> history(int trialFormulaId);
}

/// Manages status transitions for trials moving through the lab
/// workflow.
class TrialWorkflowManager extends EngineBase
    implements ITrialWorkflowManager {
  TrialWorkflowManager({
    required TrialRepository trialRepository,
    required TrialAuditRepository auditRepository,
  })  : _trialRepository = trialRepository,
        _auditRepository = auditRepository;

  final TrialRepository _trialRepository;
  final TrialAuditRepository _auditRepository;

  @override
  String get engineName => 'TrialWorkflowManager';

  @override
  Future<EngineResult<TrialFormulaModel>> transition({
    required int trialFormulaId,
    required TrialStatus to,
    String changedBy = 'system',
    String? reason,
    int? relatedRecommendationId,
  }) async {
    try {
      final TrialFormulaModel? trial = await _trialRepository.readById(
        trialFormulaId,
      );
      if (trial == null) {
        return EngineResult<TrialFormulaModel>.failure(
          message: 'Trial $trialFormulaId not found.',
        );
      }

      final TrialStatus current =
          TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;

      if (current == to) {
        return EngineResult<TrialFormulaModel>.success(
          data: trial,
          confidenceScore: 1.0,
          messages: <String>['Trial is already ${to.label}.'],
        );
      }

      if (!current.canTransitionTo(to)) {
        final String allowed = current.allowedNextStatuses
            .map((TrialStatus s) => s.label)
            .join(', ');
        return EngineResult<TrialFormulaModel>.failure(
          message: 'Cannot move from ${current.label} to ${to.label}. '
              'Allowed next statuses: $allowed.',
        );
      }

      final TrialFormulaModel updated = await _trialRepository.update(
        trial.copyWith(status: to.storageKey),
      );

      await _auditRepository.create(
        TrialAuditEntryModel(
          trialFormulaId: trialFormulaId,
          statusFrom: current.storageKey,
          statusTo: to.storageKey,
          changedBy: changedBy,
          reason: reason,
          relatedRecommendationId: relatedRecommendationId,
        ),
      );

      logDebug(
        'Trial $trialFormulaId: ${current.storageKey} -> ${to.storageKey}',
      );

      return EngineResult<TrialFormulaModel>.success(
        data: updated,
        confidenceScore: 1.0,
        messages: <String>['Moved to ${to.label}.'],
      );
    } on RepositoryException catch (error) {
      logDebug('transition failed: $error');
      return EngineResult<TrialFormulaModel>.failure(
        message: 'Unable to transition trial $trialFormulaId.',
      );
    }
  }

  @override
  Future<List<TrialAuditEntryModel>> history(int trialFormulaId) {
    return _auditRepository.historyForTrial(trialFormulaId);
  }
}
