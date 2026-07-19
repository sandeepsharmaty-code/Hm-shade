/// Purpose      : Repository for configurable business rules.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/rule_model.dart
/// Description  : Only entry point for rule SQLite access. Backed by
///                the `Settings` table (see database_helper.dart
///                header for why — no dedicated Rules table exists in
///                the frozen schema) with every row tagged
///                `record_type = 'rule'`. All base CRUD from
///                BaseSqliteRepository applies unchanged; this class
///                adds `findByRuleType`/`findAllRules`, the
///                rule-specific queries the Rule Engine and conflict
///                detection actually need.
///
///                CONSTRAINT: because Settings is shared across three
///                record types (plain settings, rules, recommendation
///                history — see database_helper.dart), an `id` this
///                repository returns must never be passed to
///                RecommendationHistoryRepository or vice versa.
///                `readById`/`update`/`softDelete`/`exists` are
///                id-only and do not check `record_type`, so passing
///                the wrong repository's id would silently
///                misinterpret a row. In practice this is safe as
///                long as ids only ever flow from the repository that
///                created them back to that same repository, which is
///                how every caller in this codebase uses them.
/// Change History:
///   1.0.0 - SPR-DEP-005 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/rule_model.dart';
import 'base_repository.dart';

/// Repository for [RuleModel] records.
class RuleRepository extends BaseSqliteRepository<RuleModel> {
  RuleRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Settings',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(RuleModel entity) => entity.toMap();

  @override
  RuleModel fromMap(Map<String, Object?> map) => RuleModel.fromMap(map);

  @override
  int? idOf(RuleModel entity) => entity.id;

  /// Returns active rules of [ruleType], highest priority first — the
  /// exact set RuleEngine evaluates for one rule-type lookup.
  ///
  /// Filters on `record_type = 'rule'` as well as `rule_type`, so a
  /// plain (non-rule) Settings row can never be misread as a rule.
  Future<List<RuleModel>> findByRuleType(RuleType ruleType) {
    return filter(
      <String, Object?>{
        'record_type': 'rule',
        'rule_type': ruleType.storageKey,
      },
      orderBy: 'priority DESC',
    );
  }

  /// Returns every rule (all types), including disabled ones when
  /// [includeInactive] is true — used by
  /// RecommendationConflictDetector to report disabled rules.
  ///
  /// Deliberately does NOT delegate to the inherited `readAll()`:
  /// that method has no way to know this table is shared with plain
  /// Settings and recommendation-history rows, so calling it directly
  /// here would return every Settings row, not just rules. This
  /// method scopes to `record_type = 'rule'` via `readAll`'s
  /// `extraWhere` parameter instead.
  Future<List<RuleModel>> findAllRules({bool includeInactive = false}) {
    return readAll(
      includeInactive: includeInactive,
      extraWhere: "record_type = 'rule'",
    );
  }
}
