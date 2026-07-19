/// Purpose      : Validates a recommendation against the 8 required
///                checks, and detects duplicate/near-duplicate trials.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart, match_type.dart,
///                rule_engine.dart, material_matching_engine.dart,
///                recommendation_engine.dart (FormulaRecommendation-
///                adjacent types), repositories/trial_repository.dart
/// Description  : Product/Shade/Finish/Coverage Compatibility,
///                Required/Alternative Material Availability,
///                Recommendation Confidence, and Rule Compliance —
///                mostly derived from the already-computed
///                FormulaRecommendation (conflicts, matchedRules,
///                confidenceScore) rather than recomputed from
///                scratch, since SPR-DEP-006's
///                RecommendationConflictDetector already did that
///                work; this engine reframes it as a pass/fail
///                Validation Report instead of a flat conflict list.
///                Duplicate Detection reuses SearchMatcher
///                (SPR-DEP-004) for name similarity — not
///                reimplemented — plus direct Formula_Material line
///                comparison for material-combination duplicates.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/formula_material_model.dart';
import '../models/trial_formula_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'formula_recommendation_engine.dart';
import 'match_type.dart';
import 'recommendation_conflict.dart';

/// One pass/fail check within a [ValidationReport].
@immutable
class ValidationCheckResult {
  const ValidationCheckResult({
    required this.name,
    required this.passed,
    required this.message,
  });

  final String name;
  final bool passed;
  final String message;
}

/// The full validation outcome for one recommendation.
@immutable
class ValidationReport {
  const ValidationReport({required this.checks});

  final List<ValidationCheckResult> checks;

  bool get allPassed => checks.every((ValidationCheckResult c) => c.passed);
  List<ValidationCheckResult> get failedChecks =>
      checks.where((ValidationCheckResult c) => !c.passed).toList();
}

/// The four duplicate categories this sprint's brief requires.
enum DuplicateType {
  duplicateTrial,
  nearDuplicateTrial,
  duplicateApprovedFormula,
  duplicateMaterialCombination,
}

/// One detected duplicate relationship between two trials.
@immutable
class DuplicateFinding {
  const DuplicateFinding({
    required this.type,
    required this.trialFormulaId,
    required this.duplicateOfTrialFormulaId,
    required this.reason,
  });

  final DuplicateType type;
  final int trialFormulaId;
  final int duplicateOfTrialFormulaId;
  final String reason;
}

/// Contract for [TrialValidationEngine].
abstract class ITrialValidationEngine {
  ValidationReport validate({
    required FormulaRecommendation recommendation,
    double confidenceThreshold,
  });

  Future<List<DuplicateFinding>> detectDuplicates(
    List<TrialFormulaModel> candidates,
  );
}

/// Validates recommendations and detects duplicates among candidate
/// trials.
class TrialValidationEngine extends EngineBase
    implements ITrialValidationEngine {
  TrialValidationEngine({required TrialRepository trialRepository})
      : _trialRepository = trialRepository;

  final TrialRepository _trialRepository;

  @override
  String get engineName => 'TrialValidationEngine';

  @override
  ValidationReport validate({
    required FormulaRecommendation recommendation,
    double confidenceThreshold = 0.3,
  }) {
    final List<RecommendationConflict> conflicts = recommendation.conflicts;

    bool hasConflict(ConflictType type) =>
        conflicts.any((RecommendationConflict c) => c.type == type);

    bool hasShadeMismatchMentioning(String keyword) => conflicts.any(
          (RecommendationConflict c) =>
              c.type == ConflictType.shadeMismatch &&
              c.message.toLowerCase().contains(keyword),
        );

    final List<ValidationCheckResult> checks = <ValidationCheckResult>[
      ValidationCheckResult(
        name: 'Product Compatibility',
        passed: !hasConflict(ConflictType.productMismatch),
        message: hasConflict(ConflictType.productMismatch)
            ? 'Trial belongs to a different product.'
            : 'Trial belongs to the requested product.',
      ),
      ValidationCheckResult(
        name: 'Shade Compatibility',
        passed: !hasShadeMismatchMentioning('family'),
        message: hasShadeMismatchMentioning('family')
            ? 'Shade family does not match the request.'
            : 'Shade family is compatible or unconstrained.',
      ),
      ValidationCheckResult(
        name: 'Finish Compatibility',
        passed: !hasShadeMismatchMentioning('finish'),
        message: hasShadeMismatchMentioning('finish')
            ? 'Finish does not match the request.'
            : 'Finish is compatible or unconstrained.',
      ),
      ValidationCheckResult(
        name: 'Coverage Compatibility',
        passed: !recommendation.reasons.any(
          (String r) =>
              r.toLowerCase().contains('coverage') &&
              r.toLowerCase().contains('caution'),
        ),
        message: 'Coverage compatibility inferred from matched rules '
            '(no dedicated coverage conflict was raised).',
      ),
      ValidationCheckResult(
        name: 'Required Material Availability',
        passed: !hasConflict(ConflictType.missingMaterial),
        message: hasConflict(ConflictType.missingMaterial)
            ? 'One or more required materials are missing.'
            : 'All required materials were found.',
      ),
      ValidationCheckResult(
        name: 'Alternative Material Availability',
        passed: recommendation.alternativeMaterialIds.isEmpty ||
            !hasConflict(ConflictType.missingMaterial),
        message: recommendation.alternativeMaterialIds.isEmpty
            ? 'No alternative materials were needed.'
            : '${recommendation.alternativeMaterialIds.length} material '
                "line(s) need an alternative; see the recommendation's "
                'conflict list for detail.',
      ),
      ValidationCheckResult(
        name: 'Recommendation Confidence',
        passed: recommendation.confidenceScore >= confidenceThreshold,
        message: 'Confidence '
            '${recommendation.confidenceScore.toStringAsFixed(2)} vs '
            'threshold ${confidenceThreshold.toStringAsFixed(2)}.',
      ),
      ValidationCheckResult(
        name: 'Rule Compliance',
        passed: recommendation.matchedRules.isNotEmpty,
        message: recommendation.matchedRules.isEmpty
            ? 'No configured rules matched this trial.'
            : '${recommendation.matchedRules.length} rule(s) matched.',
      ),
    ];

    return ValidationReport(checks: checks);
  }

  @override
  Future<List<DuplicateFinding>> detectDuplicates(
    List<TrialFormulaModel> candidates,
  ) async {
    final List<DuplicateFinding> findings = <DuplicateFinding>[];

    try {
      // Exact / near-duplicate trial names or codes.
      for (int i = 0; i < candidates.length; i++) {
        for (int j = i + 1; j < candidates.length; j++) {
          final TrialFormulaModel a = candidates[i];
          final TrialFormulaModel b = candidates[j];
          if (a.id == null || b.id == null) {
            continue;
          }

          if (a.trialCode == b.trialCode || a.name == b.name) {
            findings.add(
              DuplicateFinding(
                type: DuplicateType.duplicateTrial,
                trialFormulaId: b.id!,
                duplicateOfTrialFormulaId: a.id!,
                reason: a.trialCode == b.trialCode
                    ? 'Identical trial code "${a.trialCode}".'
                    : 'Identical trial name "${a.name}".',
              ),
            );
            continue;
          }

          final MatchType? matchType = SearchMatcher.classify(
            a.name,
            b.name,
          );
          if (matchType == MatchType.similar ||
              matchType == MatchType.nearest) {
            findings.add(
              DuplicateFinding(
                type: DuplicateType.nearDuplicateTrial,
                trialFormulaId: b.id!,
                duplicateOfTrialFormulaId: a.id!,
                reason: 'Trial names "${a.name}" and "${b.name}" are '
                    '${matchType?.name ?? "unknown"} matches.'
              ),
            );
          }
        }
      }

      // Material-combination duplicates (and, among those, duplicate
      // approved formulas specifically).
      final Map<int, Set<String>> materialSignatureByTrial =
          <int, Set<String>>{};
      for (final TrialFormulaModel trial in candidates) {
        if (trial.id == null) {
          continue;
        }
        final List<FormulaMaterialModel> lines = await _trialRepository
            .materialsForTrial(trial.id!);
        materialSignatureByTrial[trial.id!] = lines
            .map(
              (FormulaMaterialModel line) =>
                  '${line.materialTable}#${line.materialId}',
            )
            .toSet();
      }

      final List<int> trialIds = materialSignatureByTrial.keys.toList();
      for (int i = 0; i < trialIds.length; i++) {
        for (int j = i + 1; j < trialIds.length; j++) {
          final int idA = trialIds[i];
          final int idB = trialIds[j];
          final Set<String> sigA = materialSignatureByTrial[idA]!;
          final Set<String> sigB = materialSignatureByTrial[idB]!;
          if (sigA.isEmpty || sigB.isEmpty) {
            continue;
          }
          if (sigA.length == sigB.length && sigA.containsAll(sigB)) {
            findings.add(
              DuplicateFinding(
                type: DuplicateType.duplicateMaterialCombination,
                trialFormulaId: idB,
                duplicateOfTrialFormulaId: idA,
                reason: 'Identical set of ${sigA.length} material '
                    'reference(s).',
              ),
            );

            final TrialFormulaModel trialA = candidates.firstWhere(
              (TrialFormulaModel t) => t.id == idA,
            );
            final TrialFormulaModel trialB = candidates.firstWhere(
              (TrialFormulaModel t) => t.id == idB,
            );
            if (trialA.status == 'approved' && trialB.status == 'approved') {
              findings.add(
                DuplicateFinding(
                  type: DuplicateType.duplicateApprovedFormula,
                  trialFormulaId: idB,
                  duplicateOfTrialFormulaId: idA,
                  reason: 'Both trials are approved with an identical '
                      'material combination.',
                ),
              );
            }
          }
        }
      }
    } on RepositoryException catch (error) {
      logDebug('detectDuplicates failed: $error');
    }

    return findings;
  }
}
