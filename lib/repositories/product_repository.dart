/// Purpose      : Repository for Product_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/product_model.dart
/// Description  : Only entry point for Product_Master SQLite access.
///                CRUD/search/filter/exists/count come from
///                BaseSqliteRepository; this class only supplies the
///                table name and the ProductModel<->row mapping.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/product_model.dart';
import 'base_repository.dart';

/// Repository for [ProductModel] records.
class ProductRepository extends BaseSqliteRepository<ProductModel> {
  ProductRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Product_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(ProductModel entity) => entity.toMap();

  @override
  ProductModel fromMap(Map<String, Object?> map) =>
      ProductModel.fromMap(map);

  @override
  int? idOf(ProductModel entity) => entity.id;

  /// Finds active products in [category], e.g. "Nail Polish".
  Future<List<ProductModel>> findByCategory(String category) {
    return filter(<String, Object?>{'category': category});
  }
}
