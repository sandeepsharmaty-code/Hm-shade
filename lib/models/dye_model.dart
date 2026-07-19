/// Purpose      : Domain model for Dye_Master.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents a raw dye material used in formula
///                composition (Formula_Material lines reference this
///                table via material_table + material_id).
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';
import 'raw_material_model.dart';

/// A raw dye material in inventory.
@immutable
class DyeModel implements RawMaterialModel {
  const DyeModel({
    required this.name,
    required this.materialCode,
    this.id,
    this.casNumber,
    this.supplier,
    this.unit = 'g',
    this.costPerUnit = 0,
    this.stockQuantity = 0,
    this.solubility,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  @override
  final int? id;

  /// Display name, e.g. "Iron Oxide Red".
  @override
  final String name;

  /// Unique short code, e.g. "PIG-0001".
  @override
  final String materialCode;

  /// CAS registry number, where applicable.
  @override
  final String? casNumber;

  /// Supplier name.
  @override
  final String? supplier;

  /// Unit of measure for stock/cost, e.g. "g", "kg".
  @override
  final String unit;

  /// Cost per [unit] in the local currency.
  @override
  final double costPerUnit;

  /// Current stock quantity in [unit].
  @override
  final double stockQuantity;

  /// Solubility characteristic, e.g. "Water-Soluble", "Oil-Soluble".
  final String? solubility;

  @override
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DyeModel.fromMap(Map<String, Object?> map) {
    return DyeModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      materialCode: map['material_code'] as String? ?? '',
      casNumber: map['cas_number'] as String?,
      supplier: map['supplier'] as String?,
      unit: map['unit'] as String? ?? 'g',
      costPerUnit: parseReal(map['cost_per_unit']),
      stockQuantity: parseReal(map['stock_quantity']),
      solubility: map['solubility'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'material_code': materialCode,
      'cas_number': casNumber,
      'supplier': supplier,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'stock_quantity': stockQuantity,
      'solubility': solubility,
      'is_active': isActive ? 1 : 0,
    };
  }

  DyeModel copyWith({
    int? id,
    String? name,
    String? materialCode,
    String? casNumber,
    String? supplier,
    String? unit,
    double? costPerUnit,
    double? stockQuantity,
    String? solubility,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DyeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      materialCode: materialCode ?? this.materialCode,
      casNumber: casNumber ?? this.casNumber,
      supplier: supplier ?? this.supplier,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      solubility: solubility ?? this.solubility,
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
    return other is DyeModel &&
        other.id == id &&
        other.name == name &&
        other.materialCode == materialCode &&
        other.casNumber == casNumber &&
        other.supplier == supplier &&
        other.unit == unit &&
        other.costPerUnit == costPerUnit &&
        other.stockQuantity == stockQuantity &&
        other.solubility == solubility &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        materialCode,
        casNumber,
        supplier,
        unit,
        costPerUnit,
        stockQuantity,
        solubility,
        isActive,
      );

  @override
  String toString() =>
      'DyeModel(id: $id, name: $name, materialCode: $materialCode, '
      'stockQuantity: $stockQuantity, isActive: $isActive)';
}
