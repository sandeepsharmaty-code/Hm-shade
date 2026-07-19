/// Purpose      : Domain model for Blend_Template_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents a reusable base-blend template that
///                trial formulas can start from (e.g. a standard
///                nail polish base before pigment is added).
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// A reusable formulation blend template.
@immutable
class BlendTemplateModel {
  const BlendTemplateModel({
    required this.name,
    required this.templateCode,
    this.id,
    this.productId,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Display name, e.g. "Standard Glossy Base".
  final String name;

  /// Unique short code, e.g. "BLT-0001".
  final String templateCode;

  /// Optional foreign key to Product_Master.id.
  final int? productId;

  final String? description;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BlendTemplateModel.fromMap(Map<String, Object?> map) {
    return BlendTemplateModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      templateCode: map['template_code'] as String? ?? '',
      productId: parseId(map['product_id']),
      description: map['description'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'template_code': templateCode,
      'product_id': productId,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }

  BlendTemplateModel copyWith({
    int? id,
    String? name,
    String? templateCode,
    int? productId,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlendTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      templateCode: templateCode ?? this.templateCode,
      productId: productId ?? this.productId,
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
    return other is BlendTemplateModel &&
        other.id == id &&
        other.name == name &&
        other.templateCode == templateCode &&
        other.productId == productId &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        templateCode,
        productId,
        description,
        isActive,
      );

  @override
  String toString() =>
      'BlendTemplateModel(id: $id, name: $name, '
      'templateCode: $templateCode, isActive: $isActive)';
}
