/// Purpose      : Standard result envelope returned by every engine.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Every engine method returns an EngineResult<T>
///                rather than throwing or returning raw data, so
///                callers (future use-case/UI code) always get a
///                consistent success/failure/warnings/confidence/
///                messages/recommendedIds shape regardless of which
///                engine produced it.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'package:flutter/foundation.dart';

/// Whether an engine operation succeeded or failed.
enum EngineResultStatus { success, failure }

/// Standard result type returned by every engine method.
@immutable
class EngineResult<T> {
  const EngineResult._({
    required this.status,
    required this.confidenceScore,
    this.data,
    this.warnings = const <String>[],
    this.messages = const <String>[],
    this.recommendedIds = const <int>[],
  });

  /// Builds a success result. [confidenceScore] must be within
  /// 0.0–1.0 and defaults to 1.0 (fully confident).
  factory EngineResult.success({
    T? data,
    double confidenceScore = 1.0,
    List<String> warnings = const <String>[],
    List<String> messages = const <String>[],
    List<int> recommendedIds = const <int>[],
  }) {
    assert(
      confidenceScore >= 0.0 && confidenceScore <= 1.0,
      'confidenceScore must be between 0.0 and 1.0',
    );
    return EngineResult<T>._(
      status: EngineResultStatus.success,
      data: data,
      confidenceScore: confidenceScore,
      warnings: warnings,
      messages: messages,
      recommendedIds: recommendedIds,
    );
  }

  /// Builds a failure result. Confidence is always 0 for failures.
  factory EngineResult.failure({
    required String message,
    List<String> warnings = const <String>[],
  }) {
    return EngineResult<T>._(
      status: EngineResultStatus.failure,
      confidenceScore: 0.0,
      messages: <String>[message],
      warnings: warnings,
    );
  }

  final EngineResultStatus status;

  /// The engine's output payload. Null on failure, and may be null on
  /// success for engines that only report messages/recommendedIds.
  final T? data;

  /// Non-fatal notices (e.g. "no exact match, showing nearest").
  final List<String> warnings;

  /// Human-readable messages, always includes the failure reason (if
  /// any) as the first entry.
  final List<String> messages;

  /// How confident the engine is in [data], from 0.0 to 1.0.
  final double confidenceScore;

  /// IDs of records the engine recommends the caller look at next
  /// (e.g. matching Knowledge_Base or Trial_Formula row ids).
  final List<int> recommendedIds;

  bool get isSuccess => status == EngineResultStatus.success;
  bool get isFailure => status == EngineResultStatus.failure;

  @override
  String toString() =>
      'EngineResult<$T>(status: $status, confidence: $confidenceScore, '
      'messages: $messages, warnings: $warnings, '
      'recommendedIds: $recommendedIds)';
}
