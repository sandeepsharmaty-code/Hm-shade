/// Purpose      : Standard result shape returned by RuleEngine's
///                evaluation.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : models/rule_model.dart
/// Description  : Distinct from the generic EngineResult<T>
///                (SPR-DEP-004) because rule evaluation always has
///                this specific, richer shape — matched/failed rule
///                lists, alternative suggestions, recommended
///                material ids, reason messages — rather than a
///                single generic payload.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import '../models/rule_model.dart';

/// The outcome of evaluating one rule type's active rules against a
/// facts map.
@immutable
class RuleResult {
  const RuleResult({
    required this.success,
    required this.confidenceScore,
    this.matchedRules = const <RuleModel>[],
    this.failedRules = const <RuleModel>[],
    this.alternativeSuggestions = const <String>[],
    this.recommendedMaterialIds = const <int>[],
    this.reasonMessages = const <String>[],
  });

  /// True if at least one rule matched.
  final bool success;

  /// Weighted-average confidence across all evaluated rules of this
  /// type, 0.0–1.0.
  final double confidenceScore;

  /// Rules whose condition matched the supplied facts.
  final List<RuleModel> matchedRules;

  /// Rules whose condition did not match.
  final List<RuleModel> failedRules;

  /// Free-text alternative suggestions (e.g. "consider an alternative
  /// pigment") generated when a rule signals a substitution is
  /// needed.
  final List<String> alternativeSuggestions;

  /// IDs of raw-material rows this evaluation recommends, when
  /// applicable (populated by MaterialMatchingEngine's rule-driven
  /// calls, not by every rule type).
  final List<int> recommendedMaterialIds;

  /// Human-readable explanations, one per matched rule by default —
  /// the basis for Reason Generation.
  final List<String> reasonMessages;

  @override
  String toString() =>
      'RuleResult(success: $success, confidence: $confidenceScore, '
      'matched: ${matchedRules.length}, failed: ${failedRules.length})';
}
