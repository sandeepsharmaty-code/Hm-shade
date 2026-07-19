/// Purpose      : Matches a single raw-material reference (from a
///                Formula_Material line) against configurable rules,
///                and finds alternatives when the material isn't
///                approved/available.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart, match_type.dart,
///                rule_engine.dart, models/raw_material_model.dart,
///                models/rule_model.dart, and the six raw-material
///                repositories
/// Description  : Implements Pigment/Dye/Mica/Pearl/Filler/Binder
///                Matching, Alternative Material Search, and Approved
///                Material Priority from this sprint's Material
///                Matching requirements. One `matchMaterial` method
///                handles all six tables via the RawMaterialModel
///                interface (SPR-DEP-004) dispatched by table name —
///                not six near-identical methods. Approval/rejection
///                scoring comes from RuleEngine's pigment/dye/mica/
///                pearl/filler/binder/alternative_material rule
///                types, not hardcoded here.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/raw_material_model.dart';
import '../models/rule_model.dart';
import '../repositories/binder_repository.dart';
import '../repositories/dye_repository.dart';
import '../repositories/filler_repository.dart';
import '../repositories/mica_repository.dart';
import '../repositories/pearl_repository.dart';
import '../repositories/pigment_repository.dart';
import '../repositories/repository_exception.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'match_type.dart';
import 'rule_engine.dart';

/// Function shapes shared by every raw-material repository's
/// `readById`/`readAll`, used to dispatch by table name without
/// dynamic calls (see RawMaterialModel, SPR-DEP-004).
typedef _MaterialReader = Future<RawMaterialModel?> Function(
  int id, {
  bool includeInactive,
});
typedef _MaterialLister = Future<List<RawMaterialModel>> Function({
  bool includeInactive,
});

/// One material's match outcome against its rule type, plus
/// alternatives if it isn't approved/available.
@immutable
class MaterialMatchResult {
  const MaterialMatchResult({
    required this.materialTable,
    required this.materialId,
    required this.isApproved,
    this.confidence = 0.0,
    this.alternativeMaterialIds = const <int>[],
    this.matchedRules = const <RuleModel>[],
    this.reasons = const <String>[],
  });

  final String materialTable;
  final int materialId;

  /// Whether the referenced material is active/approved for use.
  final bool isApproved;

  final double confidence;

  /// Suggested alternative material ids from the same table,
  /// text-similarity ranked, populated only when [isApproved] is
  /// false.
  final List<int> alternativeMaterialIds;

  final List<RuleModel> matchedRules;
  final List<String> reasons;
}

/// Contract for [MaterialMatchingEngine].
abstract class IMaterialMatchingEngine {
  Future<EngineResult<MaterialMatchResult>> matchMaterial({
    required String materialTable,
    required int materialId,
  });

  /// Sorts [results] with approved materials first, then by
  /// confidence descending — the "Approved Material Priority"
  /// requirement.
  List<MaterialMatchResult> prioritizeApproved(
    List<MaterialMatchResult> results,
  );
}

/// Matches raw-material references across all six approved material
/// tables.
class MaterialMatchingEngine extends EngineBase
    implements IMaterialMatchingEngine {
  MaterialMatchingEngine({
    required IRuleEngine ruleEngine,
    required PigmentRepository pigmentRepository,
    required DyeRepository dyeRepository,
    required MicaRepository micaRepository,
    required PearlRepository pearlRepository,
    required FillerRepository fillerRepository,
    required BinderRepository binderRepository,
  }) : _ruleEngine = ruleEngine {
    _readers = <String, _MaterialReader>{
      'Pigment_Master': pigmentRepository.readById,
      'Dye_Master': dyeRepository.readById,
      'Mica_Master': micaRepository.readById,
      'Pearl_Master': pearlRepository.readById,
      'Filler_Master': fillerRepository.readById,
      'Binder_Master': binderRepository.readById,
    };
    _listers = <String, _MaterialLister>{
      'Pigment_Master': pigmentRepository.readAll,
      'Dye_Master': dyeRepository.readAll,
      'Mica_Master': micaRepository.readAll,
      'Pearl_Master': pearlRepository.readAll,
      'Filler_Master': fillerRepository.readAll,
      'Binder_Master': binderRepository.readAll,
    };
    _ruleTypeByTable = <String, RuleType>{
      'Pigment_Master': RuleType.pigment,
      'Dye_Master': RuleType.dye,
      'Mica_Master': RuleType.mica,
      'Pearl_Master': RuleType.pearl,
      'Filler_Master': RuleType.filler,
      'Binder_Master': RuleType.binder,
    };
  }

  final IRuleEngine _ruleEngine;
  late final Map<String, _MaterialReader> _readers;
  late final Map<String, _MaterialLister> _listers;
  late final Map<String, RuleType> _ruleTypeByTable;

  @override
  String get engineName => 'MaterialMatchingEngine';

  @override
  Future<EngineResult<MaterialMatchResult>> matchMaterial({
    required String materialTable,
    required int materialId,
  }) async {
    final _MaterialReader? reader = _readers[materialTable];
    final RuleType? ruleType = _ruleTypeByTable[materialTable];

    if (reader == null || ruleType == null) {
      return EngineResult<MaterialMatchResult>.failure(
        message: 'Unknown material table "$materialTable".',
      );
    }

    try {
      final RawMaterialModel? material = await reader(
        materialId,
        includeInactive: true,
      );

      if (material == null) {
        return EngineResult<MaterialMatchResult>.failure(
          message: 'Material $materialId not found in $materialTable.',
        );
      }

      final Map<String, Object?> facts = <String, Object?>{
        'isActive': material.isActive,
      };
      final ruleResult = await _ruleEngine.evaluate(
        ruleType: ruleType,
        facts: facts,
      );

      List<int> alternatives = const <int>[];
      List<String> reasons = List<String>.of(ruleResult.reasonMessages);

      if (!material.isActive) {
        final altRuleResult = await _ruleEngine.evaluate(
          ruleType: RuleType.alternativeMaterial,
          facts: facts,
        );
        reasons = <String>[...reasons, ...altRuleResult.reasonMessages];
        alternatives = await _findAlternatives(materialTable, material);
      }

      final MaterialMatchResult result = MaterialMatchResult(
        materialTable: materialTable,
        materialId: materialId,
        isApproved: material.isActive,
        confidence: ruleResult.confidenceScore,
        alternativeMaterialIds: alternatives,
        matchedRules: ruleResult.matchedRules,
        reasons: reasons,
      );

      return EngineResult<MaterialMatchResult>.success(
        data: result,
        confidenceScore: ruleResult.confidenceScore,
        recommendedIds:
            material.isActive ? <int>[materialId] : alternatives,
        warnings: material.isActive
            ? const <String>[]
            : const <String>[
                'Material is inactive; alternatives suggested.',
              ],
      );
    } on RepositoryException catch (error) {
      logDebug('matchMaterial($materialTable, $materialId) failed: $error');
      return EngineResult<MaterialMatchResult>.failure(
        message: 'Unable to match material $materialId in $materialTable.',
      );
    }
  }

  Future<List<int>> _findAlternatives(
    String materialTable,
    RawMaterialModel inactiveMaterial,
  ) async {
    final _MaterialLister? lister = _listers[materialTable];
    if (lister == null) {
      return const <int>[];
    }
    final List<RawMaterialModel> activeMaterials = await lister();
    final List<MatchResult<RawMaterialModel>> matches =
        SearchMatcher.matchAll<RawMaterialModel>(
      query: inactiveMaterial.name,
      candidates: activeMaterials,
      textOf: (RawMaterialModel m) => m.name,
    );
    return <int>[
      for (final MatchResult<RawMaterialModel> match in matches.take(3))
        if (match.item.id != null) match.item.id!,
    ];
  }

  @override
  List<MaterialMatchResult> prioritizeApproved(
    List<MaterialMatchResult> results,
  ) {
    final List<MaterialMatchResult> sorted = List<MaterialMatchResult>.of(
      results,
    );
    sorted.sort((MaterialMatchResult a, MaterialMatchResult b) {
      if (a.isApproved != b.isApproved) {
        return a.isApproved ? -1 : 1;
      }
      return b.confidence.compareTo(a.confidence);
    });
    return sorted;
  }
}
