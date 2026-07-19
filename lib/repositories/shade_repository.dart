/// Purpose      : Repository for Shade_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/shade_model.dart
/// Description  : Only entry point for Shade_Master SQLite access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/shade_model.dart';
import 'base_repository.dart';

/// Repository for [ShadeModel] records.
class ShadeRepository extends BaseSqliteRepository<ShadeModel> {
  ShadeRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Shade_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(ShadeModel entity) => entity.toMap();

  @override
  ShadeModel fromMap(Map<String, Object?> map) => ShadeModel.fromMap(map);

  @override
  int? idOf(ShadeModel entity) => entity.id;

  /// Finds active shades belonging to [productId].
  Future<List<ShadeModel>> findByProduct(int productId) {
    return filter(<String, Object?>{'product_id': productId});
  }
}
