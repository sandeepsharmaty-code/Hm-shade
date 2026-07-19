/// Purpose      : Domain model for Knowledge_Base.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : model_parsing_utils.dart
/// Description  : Represents a saved knowledge-base entry, typically
///                created from an ApprovedFormulaModel, that the
///                app's Knowledge Base Search step queries against
///                for future shade development.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'model_parsing_utils.dart';

/// A searchable knowledge-base entry.
@immutable
class KnowledgeBaseModel {
  const KnowledgeBaseModel({
    required this.name,
    this.id,
    this.approvedFormulaId,
    this.tags,
    this.content,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Entry title, e.g. "Ruby Red Nail Polish - Approved Formula".
  final String name;

  /// Optional foreign key to Approved_Formula.id.
  final int? approvedFormulaId;

  /// Comma-separated free-text tags, e.g. "red,glossy,10-free".
  final String? tags;

  /// Free-text notes/body content for this entry.
  final String? content;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory KnowledgeBaseModel.fromMap(Map<String, Object?> map) {
    return KnowledgeBaseModel(
      id: parseId(map['id']),
      name: map['name'] as String? ?? '',
      approvedFormulaId: parseId(map['approved_formula_id']),
      tags: map['tags'] as String?,
      content: map['content'] as String?,
      isActive: parseActiveFlag(map['is_active']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'approved_formula_id': approvedFormulaId,
      'tags': tags,
      'content': content,
      'is_active': isActive ? 1 : 0,
    };
  }

  KnowledgeBaseModel copyWith({
    int? id,
    String? name,
    int? approvedFormulaId,
    String? tags,
    String? content,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnowledgeBaseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      approvedFormulaId: approvedFormulaId ?? this.approvedFormulaId,
      tags: tags ?? this.tags,
      content: content ?? this.content,
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
    return other is KnowledgeBaseModel &&
        other.id == id &&
        other.name == name &&
        other.approvedFormulaId == approvedFormulaId &&
        other.tags == tags &&
        other.content == content &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        approvedFormulaId,
        tags,
        content,
        isActive,
      );

  @override
  String toString() =>
      'KnowledgeBaseModel(id: $id, name: $name, '
      'approvedFormulaId: $approvedFormulaId, isActive: $isActive)';
}
