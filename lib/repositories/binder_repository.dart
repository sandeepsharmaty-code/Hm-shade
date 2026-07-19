/// Purpose      : Repository for Binder_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/binder_model.dart
/// Description  : Only entry point for Binder_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/binder_model.dart';
import 'base_repository.dart';

/// Repository for [BinderModel] records.
class BinderRepository extends BaseSqliteRepository<BinderModel> {
  BinderRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Binder_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(BinderModel entity) => entity.toMap();

  @override
  BinderModel fromMap(Map<String, Object?> map) =>
      BinderModel.fromMap(map);

  @override
  int? idOf(BinderModel entity) => entity.id;

  /// Finds active materials whose [materialCode] exactly matches —
  /// useful for duplicate-code checks before create().
  Future<List<BinderModel>> findByMaterialCode(String materialCode) {
    return filter(<String, Object?>{'material_code': materialCode});
  }
}
