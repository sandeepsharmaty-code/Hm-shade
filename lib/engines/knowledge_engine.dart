/// Purpose      : Business-rule engine for searching approved
///                knowledge, formulas, and shades.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart, match_type.dart,
///                repositories/knowledge_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/shade_repository.dart,
///                models/knowledge_base_model.dart,
///                models/trial_formula_model.dart,
///                models/shade_model.dart
/// Description  : Implements the "Search Knowledge Base" /
///                "Search approved formulas" / "Search approved
///                shades" workflow steps. Reads only through the
///                Repository Layer (KnowledgeRepository,
///                TrialRepository, ShadeRepository) — never touches
///                SQLite directly, never imports a screen. Matching
///                is pure string/token comparison via SearchMatcher;
///                no ML, no image processing, no external calls.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import '../models/knowledge_base_model.dart';
import '../models/shade_model.dart';
import '../models/trial_formula_model.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'match_type.dart';

/// Contract for [KnowledgeEngine], so callers (and tests) can depend
/// on the interface rather than the concrete implementation.
abstract class IKnowledgeEngine {
  Future<EngineResult<List<KnowledgeBaseModel>>> searchKnowledge(
    String query,
  );

  Future<EngineResult<List<TrialFormulaModel>>> searchApprovedFormulas(
    String query,
  );

  Future<EngineResult<List<ShadeModel>>> searchApprovedShades(String query);
}

/// Searches approved knowledge, formulas, and shades using the
/// Repository Layer only.
class KnowledgeEngine extends EngineBase implements IKnowledgeEngine {
  KnowledgeEngine({
    required KnowledgeRepository knowledgeRepository,
    required TrialRepository trialRepository,
    required ShadeRepository shadeRepository,
  })  : _knowledgeRepository = knowledgeRepository,
        _trialRepository = trialRepository,
        _shadeRepository = shadeRepository;

  final KnowledgeRepository _knowledgeRepository;
  final TrialRepository _trialRepository;
  final ShadeRepository _shadeRepository;

  @override
  String get engineName => 'KnowledgeEngine';

  @override
  Future<EngineResult<List<KnowledgeBaseModel>>> searchKnowledge(
    String query,
  ) async {
    try {
      final List<KnowledgeBaseModel> entries =
          await _knowledgeRepository.searchEntries(query);

      if (entries.isEmpty) {
        return EngineResult<List<KnowledgeBaseModel>>.success(
          data: const <KnowledgeBaseModel>[],
          confidenceScore: 0.0,
          messages: const <String>['No knowledge base entries matched.'],
        );
      }

      final List<int> ids = <int>[
        for (final KnowledgeBaseModel entry in entries)
          if (entry.id != null) entry.id!,
      ];

      return EngineResult<List<KnowledgeBaseModel>>.success(
        data: entries,
        recommendedIds: ids,
      );
    } on RepositoryException catch (error) {
      logDebug('searchKnowledge failed: $error');
      return EngineResult<List<KnowledgeBaseModel>>.failure(
        message: 'Unable to search the knowledge base.',
      );
    }
  }

  @override
  Future<EngineResult<List<TrialFormulaModel>>> searchApprovedFormulas(
    String query,
  ) async {
    try {
      final List<TrialFormulaModel> approvedTrials =
          await _trialRepository.filter(<String, Object?>{
        'status': 'approved',
      });

      final List<MatchResult<TrialFormulaModel>> matches =
          SearchMatcher.matchAll<TrialFormulaModel>(
        query: query,
        candidates: approvedTrials,
        textOf: (TrialFormulaModel trial) =>
            '${trial.name} ${trial.trialCode}',
      );

      if (matches.isEmpty) {
        return EngineResult<List<TrialFormulaModel>>.success(
          data: const <TrialFormulaModel>[],
          confidenceScore: 0.0,
          warnings: const <String>[
            'No exact or similar match found among approved formulas.',
          ],
          messages: const <String>['No approved formulas matched.'],
        );
      }

      final List<TrialFormulaModel> ranked = <TrialFormulaModel>[
        for (final MatchResult<TrialFormulaModel> match in matches)
          match.item,
      ];
      final List<int> ids = <int>[
        for (final TrialFormulaModel trial in ranked)
          if (trial.id != null) trial.id!,
      ];

      return EngineResult<List<TrialFormulaModel>>.success(
        data: ranked,
        confidenceScore: matches.first.score,
        recommendedIds: ids,
      );
    } on RepositoryException catch (error) {
      logDebug('searchApprovedFormulas failed: $error');
      return EngineResult<List<TrialFormulaModel>>.failure(
        message: 'Unable to search approved formulas.',
      );
    }
  }

  @override
  Future<EngineResult<List<ShadeModel>>> searchApprovedShades(
    String query,
  ) async {
    try {
      final List<ShadeModel> approvedShades =
          await _shadeRepository.filter(<String, Object?>{
        'status': 'approved',
      });

      final List<MatchResult<ShadeModel>> matches =
          SearchMatcher.matchAll<ShadeModel>(
        query: query,
        candidates: approvedShades,
        textOf: (ShadeModel shade) =>
            '${shade.name} ${shade.shadeCode} ${shade.shadeFamily ?? ''}',
      );

      if (matches.isEmpty) {
        return EngineResult<List<ShadeModel>>.success(
          data: const <ShadeModel>[],
          confidenceScore: 0.0,
          messages: const <String>['No approved shades matched.'],
        );
      }

      final List<ShadeModel> ranked = <ShadeModel>[
        for (final MatchResult<ShadeModel> match in matches) match.item,
      ];
      final List<int> ids = <int>[
        for (final ShadeModel shade in ranked)
          if (shade.id != null) shade.id!,
      ];

      return EngineResult<List<ShadeModel>>.success(
        data: ranked,
        confidenceScore: matches.first.score,
        recommendedIds: ids,
      );
    } on RepositoryException catch (error) {
      logDebug('searchApprovedShades failed: $error');
      return EngineResult<List<ShadeModel>>.failure(
        message: 'Unable to search approved shades.',
      );
    }
  }
}
