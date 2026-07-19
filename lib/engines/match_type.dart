/// Purpose      : Shared match-classification types and a pure
///                string-similarity matcher used by every engine's
///                search methods.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Implements the "Exact Match / Similar Match /
///                Nearest Match / Alternative Match" search
///                capability using only deterministic string/token
///                comparison — no machine learning, no image
///                processing, no external APIs, per this sprint's
///                explicit "Only business-rule implementation"
///                constraint.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// Classifies how closely a candidate matched a search query.
enum MatchType {
  /// Candidate text equals the query exactly (case-insensitive).
  exact,

  /// Candidate contains the query, or the query contains the
  /// candidate, as a substring.
  similar,

  /// Candidate shares a majority of whitespace-separated tokens with
  /// the query, but isn't a substring match.
  nearest,

  /// Candidate shares at least one token with the query — the
  /// weakest positive match, offered when nothing closer exists.
  alternative,
}

/// A single scored match produced by [SearchMatcher].
@immutable
class MatchResult<T> {
  const MatchResult({
    required this.item,
    required this.matchType,
    required this.score,
  });

  final T item;
  final MatchType matchType;

  /// Confidence score for this match, 0.0–1.0, derived from
  /// [matchType] (see [SearchMatcher.scoreFor]).
  final double score;
}

/// Pure, deterministic text matcher. No ML, no external calls.
class SearchMatcher {
  const SearchMatcher._();

  /// Classifies [candidate] against [query], or returns null if they
  /// share nothing in common.
  static MatchType? classify(String candidate, String query) {
    final String c = candidate.toLowerCase().trim();
    final String q = query.toLowerCase().trim();
    if (q.isEmpty || c.isEmpty) {
      return null;
    }
    if (c == q) {
      return MatchType.exact;
    }
    if (c.contains(q) || q.contains(c)) {
      return MatchType.similar;
    }

    final double overlap = _tokenOverlapScore(c, q);
    if (overlap >= 0.5) {
      return MatchType.nearest;
    }
    if (overlap > 0) {
      return MatchType.alternative;
    }
    return null;
  }

  /// The confidence score associated with a [MatchType].
  static double scoreFor(MatchType matchType) {
    switch (matchType) {
      case MatchType.exact:
        return 1.0;
      case MatchType.similar:
        return 0.75;
      case MatchType.nearest:
        return 0.5;
      case MatchType.alternative:
        return 0.25;
    }
  }

  /// Jaccard-style overlap between the whitespace-separated token
  /// sets of [a] and [b], from 0.0 (nothing shared) to 1.0 (identical
  /// token sets).
  static double _tokenOverlapScore(String a, String b) {
    final Set<String> tokensA = a.split(RegExp(r'\s+')).toSet();
    final Set<String> tokensB = b.split(RegExp(r'\s+')).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) {
      return 0.0;
    }
    final int intersection = tokensA.intersection(tokensB).length;
    final int union = tokensA.union(tokensB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  /// Matches [query] against every item in [candidates], using
  /// [textOf] to extract the comparable text from each item. Returns
  /// results sorted by score descending; items with no match at all
  /// are excluded.
  static List<MatchResult<T>> matchAll<T>({
    required String query,
    required List<T> candidates,
    required String Function(T item) textOf,
  }) {
    final List<MatchResult<T>> results = <MatchResult<T>>[];
    for (final T candidate in candidates) {
      final MatchType? matchType = classify(textOf(candidate), query);
      if (matchType != null) {
        results.add(
          MatchResult<T>(
            item: candidate,
            matchType: matchType,
            score: scoreFor(matchType),
          ),
        );
      }
    }
    results.sort((MatchResult<T> a, MatchResult<T> b) {
      return b.score.compareTo(a.score);
    });
    return results;
  }
}
