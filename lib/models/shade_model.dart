/// Purpose      : Domain model for Shade_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents a specific colour shade under a Product,
///                e.g. "Ruby Red" nail polish. Detected/created
///                through the app's shade-development workflow.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// A named colour shade, optionally linked to a [ProductModel].
@immutable
class ShadeModel {
  const ShadeModel({
    required this.name,
    required this.shadeCode,
    this.id,
    this.productId,
    this.hexColor,
    this.shadeFamily,
    this.finish,
    this.status = 'draft',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Display name, e.g. "Ruby Red".
  final String name;

  /// Unique short code, e.g. "SH-0001".
  final String shadeCode;

  /// Foreign key to Product_Master.id.
  final int? productId;

  /// Approximate hex colour, e.g. "#B5384D".
  final String? hexColor;

  /// Colour family, e.g. "Red", "Nude", "Glitter".
  final String? shadeFamily;

  /// Finish type, e.g. "Glossy", "Matte", "Shimmer".
  final String? finish;

  /// Workflow status: 'draft', 'in_review', or 'approved'.
  final String status;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ShadeModel.fromMap(Map<String, Object?> map) {
    return ShadeModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      shadeCode: map['shade_code'] as String? ?? '',
      productId: parseId(map['product_id']),
      hexColor: map['hex_color'] as String?,
      shadeFamily: map['shade_family'] as String?,
      finish: map['finish'] as String?,
      status: map['status'] as String? ?? 'draft',
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'shade_code': shadeCode,
      'product_id': productId,
      'hex_color': hexColor,
      'shade_family': shadeFamily,
      'finish': finish,
      'status': status,
      'is_active': isActive ? 1 : 0,
    };
  }

  ShadeModel copyWith({
    int? id,
    String? name,
    String? shadeCode,
    int? productId,
    String? hexColor,
    String? shadeFamily,
    String? finish,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShadeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shadeCode: shadeCode ?? this.shadeCode,
      productId: productId ?? this.productId,
      hexColor: hexColor ?? this.hexColor,
      shadeFamily: shadeFamily ?? this.shadeFamily,
      finish: finish ?? this.finish,
      status: status ?? this.status,
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
    return other is ShadeModel &&
        other.id == id &&
        other.name == name &&
        other.shadeCode == shadeCode &&
        other.productId == productId &&
        other.hexColor == hexColor &&
        other.shadeFamily == shadeFamily &&
        other.finish == finish &&
        other.status == status &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        shadeCode,
        productId,
        hexColor,
        shadeFamily,
        finish,
        status,
        isActive,
      );

  @override
  String toString() =>
      'ShadeModel(id: $id, name: $name, shadeCode: $shadeCode, '
      'status: $status, isActive: $isActive)';
}
