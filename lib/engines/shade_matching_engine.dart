/// Purpose      : Matches shades against a search query and optional
///                family/finish criteria, combining text-similarity
///                matching with configurable rules.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart, match_type.dart,
///                rule_engine.dart, models/shade_model.dart,
///                models/rule_model.dart,
///                repositories/shade_repository.dart,
///                repositories/repository_exception.dart
/// Description  : Implements Exact/Similar/Nearest/Alternative Match
///                (via the existing SearchMatcher from SPR-DEP-004 —
///                not reimplemented), Confidence Calculation, Reason
///                Generation, and Matched Rule List, per this
///                sprint's Shade Matching requirements. Confidence
///                blends the text-match score with RuleEngine's
///                shade_family/finish rule evaluation rather than
///                hardcoding shade-scoring weights here.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/rule_model.dart';
import '../models/shade_model.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'match_type.dart';
import 'rule_engine.dart';

/// One shade's match outcome: text-match classification, blended
/// confidence, the rules that contributed, and human-readable reasons.
@immutable
class ShadeMatchResult {
  const ShadeMatchResult({
    required this.shade,
    required this.matchType,
    required this.confidence,
    this.matchedRules = const <RuleModel>[],
    this.reasons = const <String>[],
  });

  final ShadeModel shade;
  final MatchType matchType;
  final double confidence;
  final List<RuleModel> matchedRules;
  final List<String> reasons;
}

/// Contract for [ShadeMatchingEngine].
abstract class IShadeMatchingEngine {
  Future<EngineResult<List<ShadeMatchResult>>> matchShades({
    required String query,
    String? shadeFamily,
    String? finish,
  });
}

/// Matches active shades against a query and optional criteria.
class ShadeMatchingEngine extends EngineBase implements IShadeMatchingEngine {
  ShadeMatchingEngine({
    required ShadeRepository shadeRepository,
    required IRuleEngine ruleEngine,
  })  : _shadeRepository = shadeRepository,
        _ruleEngine = ruleEngine;

  final ShadeRepository _shadeRepository;
  final IRuleEngine _ruleEngine;

  @override
  String get engineName => 'ShadeMatchingEngine';

  @override
  Future<EngineResult<List<ShadeMatchResult>>> matchShades({
    required String query,
    String? shadeFamily,
    String? finish,
  }) async {
    try {
      final List<ShadeModel> candidates = await _shadeRepository.readAll();

      final List<MatchResult<ShadeModel>> textMatches =
          SearchMatcher.matchAll<ShadeModel>(
        query: query,
        candidates: candidates,
        textOf: (ShadeModel shade) =>
            '${shade.name} ${shade.shadeCode} ${shade.shadeFamily ?? ''}',
      );

      if (textMatches.isEmpty) {
        return EngineResult<List<ShadeMatchResult>>.success(
          data: const <ShadeMatchResult>[],
          confidenceScore: 0.0,
          messages: const <String>['No shades matched the query.'],
        );
      }

      final List<ShadeMatchResult> results = <ShadeMatchResult>[];
      for (final MatchResult<ShadeModel> textMatch in textMatches) {
        results.add(
          await _buildShadeMatchResult(textMatch, shadeFamily, finish),
        );
      }

      results.sort(
        (ShadeMatchResult a, ShadeMatchResult b) =>
            b.confidence.compareTo(a.confidence),
      );

      return EngineResult<List<ShadeMatchResult>>.success(
        data: results,
        confidenceScore: results.first.confidence,
        recommendedIds: <int>[
          for (final ShadeMatchResult r in results)
            if (r.shade.id != null) r.shade.id!,
        ],
      );
    } on RepositoryException catch (error) {
      logDebug('matchShades failed: $error');
      return EngineResult<List<ShadeMatchResult>>.failure(
        message: 'Unable to match shades.',
      );
    }
  }

  Future<ShadeMatchResult> _buildShadeMatchResult(
    MatchResult<ShadeModel> textMatch,
    String? shadeFamily,
    String? finish,
  ) async {
    final ShadeModel shade = textMatch.item;
    final List<String> reasons = <String>[
      '${_matchTypeLabel(textMatch.matchType)} on name/code/family '
          '(score ${textMatch.score.toStringAsFixed(2)}).',
    ];
    final List<RuleModel> matchedRules = <RuleModel>[];
    final List<double> ruleConfidences = <double>[];

    if (shadeFamily != null) {
      final result = await _ruleEngine.evaluate(
        ruleType: RuleType.shadeFamily,
        facts: <String, Object?>{
          'shadeFamily': shade.shadeFamily,
          'shadeFamily_target': shadeFamily,
        },
      );
      matchedRules.addAll(result.matchedRules);
      reasons.addAll(result.reasonMessages);
      ruleConfidences.add(result.confidenceScore);
    }

    if (finish != null) {
      final result = await _ruleEngine.evaluate(
        ruleType: RuleType.finish,
        facts: <String, Object?>{
          'finish': shade.finish,
          'finish_target': finish,
        },
      );
      matchedRules.addAll(result.matchedRules);
      reasons.addAll(result.reasonMessages);
      ruleConfidences.add(result.confidenceScore);
    }

    final double ruleAverage = ruleConfidences.isEmpty
        ? textMatch.score
        : ruleConfidences.reduce((double a, double b) => a + b) /
            ruleConfidences.length;
    final double blended =
        ((textMatch.score + ruleAverage) / 2).clamp(0.0, 1.0);

    return ShadeMatchResult(
      shade: shade,
      matchType: textMatch.matchType,
      confidence: blended,
      matchedRules: matchedRules,
      reasons: reasons,
    );
  }

  String _matchTypeLabel(MatchType matchType) => switch (matchType) {
        MatchType.exact => 'Exact match',
        MatchType.similar => 'Similar match',
        MatchType.nearest => 'Nearest match',
        MatchType.alternative => 'Alternative match',
      };
}
