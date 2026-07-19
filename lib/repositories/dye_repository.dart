/// Purpose      : Repository for Dye_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/dye_model.dart
/// Description  : Only entry point for Dye_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/dye_model.dart';
import 'base_repository.dart';

/// Repository for [DyeModel] records.
class DyeRepository extends BaseSqliteRepository<DyeModel> {
  DyeRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Dye_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(DyeModel entity) => entity.toMap();

  @override
  DyeModel fromMap(Map<String, Object?> map) =>
      DyeModel.fromMap(map);

  @override
  int? idOf(DyeModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<DyeModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
