/// Purpose      : Repository for Filler_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/filler_model.dart
/// Description  : Only entry point for Filler_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/filler_model.dart';
import 'base_repository.dart';

/// Repository for [FillerModel] records.
class FillerRepository extends BaseSqliteRepository<FillerModel> {
  FillerRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Filler_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(FillerModel entity) => entity.toMap();

  @override
  FillerModel fromMap(Map<String, Object?> map) =>
      FillerModel.fromMap(map);

  @override
  int? idOf(FillerModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<FillerModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
