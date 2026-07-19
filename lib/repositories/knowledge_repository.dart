/// Purpose      : Repository for Knowledge_Base.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/knowledge_base_model.dart
/// Description  : Only entry point for Knowledge_Base SQLite access.
///                Backs the app's "Search Knowledge Base" workflow
///                step (search() is inherited from
///                BaseSqliteRepository, matching against `name`,
///                `tags`, and `content`).
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/knowledge_base_model.dart';
import 'base_repository.dart';

/// Repository for [KnowledgeBaseModel] records.
class KnowledgeRepository extends BaseSqliteRepository<KnowledgeBaseModel> {
  KnowledgeRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Knowledge_Base',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(KnowledgeBaseModel entity) => entity.toMap();

  @override
  KnowledgeBaseModel fromMap(Map<String, Object?> map) =>
      KnowledgeBaseModel.fromMap(map);

  @override
  int? idOf(KnowledgeBaseModel entity) => entity.id;

  /// Searches title, tags, and content — the three text columns a
  /// knowledge-base lookup would reasonably match against.
  Future<List<KnowledgeBaseModel>> searchEntries(String query) {
    return search(query, columns: const <String>['name', 'tags', 'content']);
  }
}
