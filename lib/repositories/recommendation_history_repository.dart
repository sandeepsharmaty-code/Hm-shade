/// Purpose      : Repository for recommendation history entries.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/recommendation_history_model.dart
/// Description  : Only entry point for recommendation-history SQLite
///                access. Backed by `Settings` (see
///                database_helper.dart header), every row tagged
///                `record_type = 'recommendation_history'`. Base CRUD
///                from BaseSqliteRepository applies unchanged; adds
///                `recent()`, the one history-specific query
///                RecommendationHistory (the engine-layer service)
///                needs.
///
///                CONSTRAINT: shares the same cross-repository id
///                caveat as RuleRepository (see that file's header)
///                — an id from this repository must never be passed
///                to RuleRepository or vice versa.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/recommendation_history_model.dart';
import 'base_repository.dart';

/// Repository for [RecommendationHistoryModel] records.
class RecommendationHistoryRepository
    extends BaseSqliteRepository<RecommendationHistoryModel> {
  RecommendationHistoryRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Settings',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(RecommendationHistoryModel entity) =>
      entity.toMap();

  @override
  RecommendationHistoryModel fromMap(Map<String, Object?> map) =>
      RecommendationHistoryModel.fromMap(map);

  @override
  int? idOf(RecommendationHistoryModel entity) => entity.id;

  /// Returns the most recent [limit] history entries, newest first.
  Future<List<RecommendationHistoryModel>> recent({int limit = 20}) async {
    final List<RecommendationHistoryModel> all = await filter(
      <String, Object?>{'record_type': 'recommendation_history'},
    );
    return all.take(limit).toList();
  }
}
