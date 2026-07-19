/// Purpose      : Repository for Blend_Template_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : base_repository.dart, core/database/database_helper.dart,
///                models/blend_template_model.dart
/// Description  : Only entry point for Blend_Template_Master SQLite
///                access.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import '../core/database/database_helper.dart';
import '../models/blend_template_model.dart';
import 'base_repository.dart';

/// Repository for [BlendTemplateModel] records.
class BlendRepository extends BaseSqliteRepository<BlendTemplateModel> {
  BlendRepository({DatabaseHelper? databaseHelper})
      : super(
          tableName: 'Blend_Template_Master',
          databaseHelper: databaseHelper ?? DatabaseHelper.instance,
        );

  @override
  Map<String, Object?> toMap(BlendTemplateModel entity) => entity.toMap();

  @override
  BlendTemplateModel fromMap(Map<String, Object?> map) =>
      BlendTemplateModel.fromMap(map);

  @override
  int? idOf(BlendTemplateModel entity) => entity.id;

  /// Finds active blend templates for [productId].
  Future<List<BlendTemplateModel>> findByProduct(int productId) {
    return filter(<String, Object?>{'product_id': productId});
  }
}
