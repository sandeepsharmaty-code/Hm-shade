/// Purpose      : Repository for Mica_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/mica_model.dart
/// Description  : Only entry point for Mica_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/mica_model.dart';
import 'base_repository.dart';

/// Repository for [MicaModel] records.
class MicaRepository extends BaseSqliteRepository<MicaModel> {
  MicaRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Mica_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(MicaModel entity) => entity.toMap();

  @override
  MicaModel fromMap(Map<String, Object?> map) =>
      MicaModel.fromMap(map);

  @override
  int? idOf(MicaModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<MicaModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
