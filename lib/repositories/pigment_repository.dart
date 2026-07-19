/// Purpose      : Repository for Pigment_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/pigment_model.dart
/// Description  : Only entry point for Pigment_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/pigment_model.dart';
import 'base_repository.dart';

/// Repository for [PigmentModel] records.
class PigmentRepository extends BaseSqliteRepository<PigmentModel> {
  PigmentRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Pigment_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(PigmentModel entity) => entity.toMap();

  @override
  PigmentModel fromMap(Map<String, Object?> map) =>
      PigmentModel.fromMap(map);

  @override
  int? idOf(PigmentModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<PigmentModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
