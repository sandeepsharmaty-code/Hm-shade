/// Purpose      : Domain model for Product_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents a cosmetic product line (e.g. Nail
///                Polish, Lipstick — see the approved Supported
///                Products list) that shades and formulas are built
///                against.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// A cosmetic product line, e.g. "Nail Polish" or "Lipstick".
@immutable
class ProductModel {
  const ProductModel({
    required this.name,
    required this.productCode,
    required this.category,
    this.id,
    this.baseType,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Row primary key. Null until persisted.
  final int? id;

  /// Display name, e.g. "Classic Nail Polish".
  final String name;

  /// Unique short code, e.g. "NP-001".
  final String productCode;

  /// One of the approved product categories (Nail Polish, Lipstick,
  /// Lip Balm, Kajal, Mascara, Foundation, Concealer, Highlighter,
  /// Blush, Eyeshadow, Lip Liner, Eyeliner, BB Cream, CC Cream,
  /// Color Corrector, Glitter & Metallic Cosmetics).
  final String category;

  /// Optional formulation base, e.g. "Water-Based", "Solvent-Based".
  final String? baseType;

  /// Optional free-text description.
  final String? description;

  /// Soft-delete flag. False means the record is hidden from normal
  /// reads but not physically removed.
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Builds a [ProductModel] from a SQLite row map.
  factory ProductModel.fromMap(Map<String, Object?> map) {
    return ProductModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      productCode: map['product_code'] as String? ?? '',
      category: map['category'] as String? ?? '',
      baseType: map['base_type'] as String?,
      description: map['description'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  /// Converts this model into a SQLite row map. Omits `id` when null
  /// so inserts let SQLite assign the primary key.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'product_code': productCode,
      'category': category,
      'base_type': baseType,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? productCode,
    String? category,
    String? baseType,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      productCode: productCode ?? this.productCode,
      category: category ?? this.category,
      baseType: baseType ?? this.baseType,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ProductModel &&
        other.id == id &&
        other.name == name &&
        other.productCode == productCode &&
        other.category == category &&
        other.baseType == baseType &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        productCode,
        category,
        baseType,
        description,
        isActive,
      );

  @override
  String toString() =>
      'ProductModel(id: $id, name: $name, productCode: $productCode, '
      'category: $category, isActive: $isActive)';
}
