/// Purpose      : Repository for Pearl_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/pearl_model.dart
/// Description  : Only entry point for Pearl_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/pearl_model.dart';
import 'base_repository.dart';

/// Repository for [PearlModel] records.
class PearlRepository extends BaseSqliteRepository<PearlModel> {
  PearlRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Pearl_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(PearlModel entity) => entity.toMap();

  @override
  PearlModel fromMap(Map<String, Object?> map) =>
      PearlModel.fromMap(map);

  @override
  int? idOf(PearlModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<PearlModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
