/// Purpose      : Conflict types and result shape for
///                RecommendationConflictDetector.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : The six conflict categories this sprint's brief
///                requires: Inactive Material, Missing Material,
///                Disabled Rule, Low Confidence, Product Mismatch,
///                Shade Mismatch.
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// The six conflict categories RecommendationConflictDetector checks.
enum ConflictType {
  inactiveMaterial,
  missingMaterial,
  disabledRule,
  lowConfidence,
  productMismatch,
  shadeMismatch,
}

/// One detected conflict for a candidate recommendation.
@immutable
class RecommendationConflict {
  const RecommendationConflict({
    required this.type,
    required this.message,
  });

  final ConflictType type;
  final String message;

  @override
  String toString() => 'RecommendationConflict(${type.name}: $message)';
}
