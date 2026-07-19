/// Purpose      : Records and retrieves recommendation events.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart,
///                repositories/recommendation_history_repository.dart,
///                models/recommendation_history_model.dart
/// Description  : "Store: Recommendation ID, Timestamp, Input
///                Parameters, Selected Recommendation, Confidence,
///                Reason" — this class is that store, via
///                RecommendationHistoryRepository (never SQLite
///                directly). FormulaRecommendationEngine calls
///                `record()` after producing results, logging the
///                top-ranked pick as the "Selected Recommendation" —
///                see the SPR-DEP-006 report for why that
///                interpretation was chosen over only recording an
///                explicit user selection (no selection UI exists
///                yet to call this from).
/// Change History:
///   1.0.0 - SPR-DEP-006 - Initial creation.
library;

import 'dart:convert';

import '../models/recommendation_history_model.dart';
import '../repositories/recommendation_history_repository.dart';
import 'engine_base.dart';

/// Contract for [RecommendationHistory].
abstract class IRecommendationHistory {
  Future<RecommendationHistoryModel> record({
    required Map<String, Object?> inputParameters,
    int? selectedTrialFormulaId,
    double? confidenceScore,
    String? reasonText,
  });

  Future<List<RecommendationHistoryModel>> recent({int limit});
}

/// Records recommendation events for later review/audit.
class RecommendationHistory extends EngineBase
    implements IRecommendationHistory {
  RecommendationHistory({
    required RecommendationHistoryRepository historyRepository,
  }) : _historyRepository = historyRepository;

  final RecommendationHistoryRepository _historyRepository;

  @override
  String get engineName => 'RecommendationHistory';

  @override
  Future<RecommendationHistoryModel> record({
    required Map<String, Object?> inputParameters,
    int? selectedTrialFormulaId,
    double? confidenceScore,
    String? reasonText,
  }) async {
    final RecommendationHistoryModel entry = RecommendationHistoryModel(
      inputParameters: jsonEncode(inputParameters),
      selectedTrialFormulaId: selectedTrialFormulaId,
      confidenceScore: confidenceScore,
      reasonText: reasonText,
    );
    final RecommendationHistoryModel saved = await _historyRepository.create(
      entry,
    );
    logDebug('Recorded history entry #${saved.id}');
    return saved;
  }

  @override
  Future<List<RecommendationHistoryModel>> recent({int limit = 20}) {
    return _historyRepository.recent(limit: limit);
  }
}
