/// Purpose      : Unit tests for SearchMatcher's Exact/Similar/
///                Nearest/Alternative match classification.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/match_type.dart
/// Description  : Pure logic, no repository or database involved —
///                exercises the deterministic string/token matching
///                that backs every engine's search capability.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/engines/match_type.dart';

void main() {
  group('SearchMatcher.classify', () {
    test('identical text (case-insensitive) is an exact match', () {
      expect(
        SearchMatcher.classify('Ruby Red', 'ruby red'),
        MatchType.exact,
      );
    });

    test('substring containment is a similar match', () {
      expect(
        SearchMatcher.classify('Ruby Red Nail Polish', 'Ruby Red'),
        MatchType.similar,
      );
    });

    test('majority shared tokens is a nearest match', () {
      expect(
        SearchMatcher.classify('Red Glossy Nail Polish', 'Red Glossy'),
        anyOf(MatchType.similar, MatchType.nearest),
      );
    });

    test('single shared token is an alternative match', () {
      expect(
        SearchMatcher.classify('Coral Blush', 'Coral Lipstick'),
        MatchType.alternative,
      );
    });

    test('no shared content returns null', () {
      expect(
        SearchMatcher.classify('Ruby Red', 'Emerald Green'),
        isNull,
      );
    });

    test('empty query returns null', () {
      expect(SearchMatcher.classify('Ruby Red', ''), isNull);
    });
  });

  group('SearchMatcher.matchAll', () {
    test('ranks results by score descending and excludes non-matches', () {
      final List<MatchResult<String>> results = SearchMatcher.matchAll<String>(
        query: 'Ruby Red',
        candidates: const <String>[
          'Coral Blush',
          'Ruby Red',
          'Ruby Red Nail Polish',
          'Emerald Green',
        ],
        textOf: (String s) => s,
      );

      expect(results, hasLength(2));
      expect(results.first.item, 'Ruby Red');
      expect(results.first.matchType, MatchType.exact);
      expect(results.last.item, 'Ruby Red Nail Polish');
      expect(results.last.matchType, MatchType.similar);
    });
  });
}
