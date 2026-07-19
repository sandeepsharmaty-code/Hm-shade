/// Purpose      : Application entry point for Hue Muse Shade AI.
/// Author       : HMEOS Engineering
/// Version      : 1.8.0
/// Dependencies : flutter/material.dart, app.dart,
///                core/di/service_locator.dart,
///                core/database/database_helper.dart,
///                repositories/*.dart, engines/*.dart
/// Description  : Pure bootstrap file. Registers core singletons —
///                DatabaseHelper, every Repository Layer class, and
///                every engine — with the ServiceLocator, initializes
///                Flutter bindings, and runs the root
///                HueMuseShadeAiApp widget (see app.dart). No
///                internet, cloud, login, or API dependencies, per
///                approved project information.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation.
///   1.1.0 - SPR-DEP-001 - Root widget split out into app.dart.
///   1.2.0 - SPR-DEP-002 - Registered DatabaseHelper with
///           ServiceLocator ahead of runApp (dependency injection).
///   1.3.0 - SPR-DEP-003 - Registered all 11 Data Layer repositories
///           with ServiceLocator.
///   1.4.0 - SPR-DEP-004 - Registered KnowledgeEngine, ShadeEngine,
///           and RecommendationEngine (by interface type) with
///           ServiceLocator.
///   1.5.0 - SPR-DEP-005 - Registered RuleRepository, RuleEngine,
///           ShadeMatchingEngine, and MaterialMatchingEngine.
///           RecommendationEngine's dependencies changed (now takes
///           IRuleEngine + IMaterialMatchingEngine instead of the six
///           raw-material repositories directly).
///   1.6.0 - SPR-DEP-006 - Registered RecommendationHistoryRepository
///           and the six new Formula Recommendation Engine classes
///           (RecommendationConflictDetector, RecommendationReasonBuilder,
///           RecommendationFilter, RecommendationRanker,
///           RecommendationHistory, FormulaRecommendationEngine).
///   1.7.0 - SPR-DEP-007 - Registered TrialAuditRepository and the
///           five new Trial Recommendation Workflow classes
///           (TrialGeneratorEngine, TrialValidationEngine,
///           TrialComparisonEngine, TrialExplanationEngine,
///           TrialWorkflowManager).
///   1.8.0 - SPR-DEP-008 - Registered the seven new Image Intelligence
///           classes (ImageProcessor, ColorConversionEngine,
///           ColorSamplingEngine, DominantColorEngine,
///           ColorExtractionEngine, ColorProfileBuilder,
///           ImageAnalysisEngine).
library;

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/di/service_locator.dart';
import 'engines/color_conversion_engine.dart';
import 'engines/color_extraction_engine.dart';
import 'engines/color_profile_builder.dart';
import 'engines/color_sampling_engine.dart';
import 'engines/dominant_color_engine.dart';
import 'engines/formula_recommendation_engine.dart';
import 'engines/image_analysis_engine.dart';
import 'engines/image_processor.dart';
import 'engines/knowledge_engine.dart';
import 'engines/material_matching_engine.dart';
import 'engines/recommendation_conflict_detector.dart';
import 'engines/recommendation_engine.dart';
import 'engines/recommendation_filter.dart';
import 'engines/recommendation_history.dart';
import 'engines/recommendation_ranker.dart';
import 'engines/recommendation_reason_builder.dart';
import 'engines/rule_engine.dart';
import 'engines/shade_engine.dart';
import 'engines/shade_matching_engine.dart';
import 'engines/trial_comparison_engine.dart';
import 'engines/trial_explanation_engine.dart';
import 'engines/trial_generator_engine.dart';
import 'engines/trial_validation_engine.dart';
import 'engines/trial_workflow_manager.dart';
import 'repositories/binder_repository.dart';
import 'repositories/blend_repository.dart';
import 'repositories/dye_repository.dart';
import 'repositories/filler_repository.dart';
import 'repositories/knowledge_repository.dart';
import 'repositories/mica_repository.dart';
import 'repositories/pearl_repository.dart';
import 'repositories/pigment_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/recommendation_history_repository.dart';
import 'repositories/rule_repository.dart';
import 'repositories/shade_repository.dart';
import 'repositories/trial_audit_repository.dart';
import 'repositories/trial_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final DatabaseHelper databaseHelper = DatabaseHelper.instance;

  final ProductRepository productRepository = ProductRepository(
    databaseHelper: databaseHelper,
  );
  final ShadeRepository shadeRepository = ShadeRepository(
    databaseHelper: databaseHelper,
  );
  final PigmentRepository pigmentRepository = PigmentRepository(
    databaseHelper: databaseHelper,
  );
  final DyeRepository dyeRepository = DyeRepository(
    databaseHelper: databaseHelper,
  );
  final MicaRepository micaRepository = MicaRepository(
    databaseHelper: databaseHelper,
  );
  final PearlRepository pearlRepository = PearlRepository(
    databaseHelper: databaseHelper,
  );
  final FillerRepository fillerRepository = FillerRepository(
    databaseHelper: databaseHelper,
  );
  final BinderRepository binderRepository = BinderRepository(
    databaseHelper: databaseHelper,
  );
  final BlendRepository blendRepository = BlendRepository(
    databaseHelper: databaseHelper,
  );
  final TrialRepository trialRepository = TrialRepository(
    databaseHelper: databaseHelper,
  );
  final KnowledgeRepository knowledgeRepository = KnowledgeRepository(
    databaseHelper: databaseHelper,
  );
  final RuleRepository ruleRepository = RuleRepository(
    databaseHelper: databaseHelper,
  );
  final RecommendationHistoryRepository historyRepository =
      RecommendationHistoryRepository(databaseHelper: databaseHelper);
  final TrialAuditRepository trialAuditRepository = TrialAuditRepository(
    databaseHelper: databaseHelper,
  );

  final RuleEngine ruleEngine = RuleEngine(ruleRepository: ruleRepository);
  final MaterialMatchingEngine materialMatchingEngine = MaterialMatchingEngine(
    ruleEngine: ruleEngine,
    pigmentRepository: pigmentRepository,
    dyeRepository: dyeRepository,
    micaRepository: micaRepository,
    pearlRepository: pearlRepository,
    fillerRepository: fillerRepository,
    binderRepository: binderRepository,
  );
  final KnowledgeEngine knowledgeEngine = KnowledgeEngine(
    knowledgeRepository: knowledgeRepository,
    trialRepository: trialRepository,
    shadeRepository: shadeRepository,
  );
  final RecommendationEngine recommendationEngine = RecommendationEngine(
    trialRepository: trialRepository,
    shadeRepository: shadeRepository,
    ruleEngine: ruleEngine,
    materialMatchingEngine: materialMatchingEngine,
  );
  final RecommendationConflictDetector conflictDetector =
      RecommendationConflictDetector(
    shadeRepository: shadeRepository,
    ruleRepository: ruleRepository,
  );
  const RecommendationReasonBuilder reasonBuilder =
      RecommendationReasonBuilder();
  const RecommendationFilter recommendationFilter = RecommendationFilter();
  const RecommendationRanker recommendationRanker = RecommendationRanker();
  final RecommendationHistory recommendationHistory = RecommendationHistory(
    historyRepository: historyRepository,
  );
  final FormulaRecommendationEngine formulaRecommendationEngine =
      FormulaRecommendationEngine(
    recommendationEngine: recommendationEngine,
    knowledgeEngine: knowledgeEngine,
    materialMatchingEngine: materialMatchingEngine,
    trialRepository: trialRepository,
    conflictDetector: conflictDetector,
    reasonBuilder: reasonBuilder,
    filter: recommendationFilter,
    ranker: recommendationRanker,
    history: recommendationHistory,
  );
  final TrialValidationEngine trialValidationEngine = TrialValidationEngine(
    trialRepository: trialRepository,
  );
  const TrialComparisonEngine trialComparisonEngine = TrialComparisonEngine();
  final TrialExplanationEngine trialExplanationEngine = TrialExplanationEngine(
    ruleEngine: ruleEngine,
    materialMatchingEngine: materialMatchingEngine,
    trialRepository: trialRepository,
    shadeRepository: shadeRepository,
  );
  final TrialWorkflowManager trialWorkflowManager = TrialWorkflowManager(
    trialRepository: trialRepository,
    auditRepository: trialAuditRepository,
  );
  final TrialGeneratorEngine trialGeneratorEngine = TrialGeneratorEngine(
    formulaRecommendationEngine: formulaRecommendationEngine,
    validationEngine: trialValidationEngine,
  );
  final ShadeEngine shadeEngine = ShadeEngine(
    shadeRepository: shadeRepository,
    productRepository: productRepository,
  );

  const ImageProcessor imageProcessor = ImageProcessor();
  const ColorConversionEngine colorConversionEngine = ColorConversionEngine();
  const ColorSamplingEngine colorSamplingEngine = ColorSamplingEngine();
  const DominantColorEngine dominantColorEngine = DominantColorEngine();
  const ColorExtractionEngine colorExtractionEngine = ColorExtractionEngine(
    samplingEngine: colorSamplingEngine,
    dominantColorEngine: dominantColorEngine,
    conversionEngine: colorConversionEngine,
  );
  const ColorProfileBuilder colorProfileBuilder = ColorProfileBuilder(
    conversionEngine: colorConversionEngine,
  );
  final ImageAnalysisEngine imageAnalysisEngine = ImageAnalysisEngine(
    imageProcessor: imageProcessor,
    extractionEngine: colorExtractionEngine,
    profileBuilder: colorProfileBuilder,
    shadeEngine: shadeEngine,
    trialGeneratorEngine: trialGeneratorEngine,
  );

  ServiceLocator.instance
    ..registerSingleton<DatabaseHelper>(databaseHelper)
    ..registerSingleton<ProductRepository>(productRepository)
    ..registerSingleton<ShadeRepository>(shadeRepository)
    ..registerSingleton<PigmentRepository>(pigmentRepository)
    ..registerSingleton<DyeRepository>(dyeRepository)
    ..registerSingleton<MicaRepository>(micaRepository)
    ..registerSingleton<PearlRepository>(pearlRepository)
    ..registerSingleton<FillerRepository>(fillerRepository)
    ..registerSingleton<BinderRepository>(binderRepository)
    ..registerSingleton<BlendRepository>(blendRepository)
    ..registerSingleton<TrialRepository>(trialRepository)
    ..registerSingleton<KnowledgeRepository>(knowledgeRepository)
    ..registerSingleton<RuleRepository>(ruleRepository)
    ..registerSingleton<RecommendationHistoryRepository>(historyRepository)
    ..registerSingleton<TrialAuditRepository>(trialAuditRepository)
    ..registerSingleton<IKnowledgeEngine>(knowledgeEngine)
    ..registerSingleton<IShadeEngine>(shadeEngine)
    ..registerSingleton<IRuleEngine>(ruleEngine)
    ..registerSingleton<IShadeMatchingEngine>(
      ShadeMatchingEngine(
        shadeRepository: shadeRepository,
        ruleEngine: ruleEngine,
      ),
    )
    ..registerSingleton<IMaterialMatchingEngine>(materialMatchingEngine)
    ..registerSingleton<IRecommendationEngine>(recommendationEngine)
    ..registerSingleton<IRecommendationConflictDetector>(conflictDetector)
    ..registerSingleton<IRecommendationReasonBuilder>(reasonBuilder)
    ..registerSingleton<IRecommendationFilter>(recommendationFilter)
    ..registerSingleton<IRecommendationRanker>(recommendationRanker)
    ..registerSingleton<IRecommendationHistory>(recommendationHistory)
    ..registerSingleton<IFormulaRecommendationEngine>(
      formulaRecommendationEngine,
    )
    ..registerSingleton<ITrialValidationEngine>(trialValidationEngine)
    ..registerSingleton<ITrialComparisonEngine>(trialComparisonEngine)
    ..registerSingleton<ITrialExplanationEngine>(trialExplanationEngine)
    ..registerSingleton<ITrialWorkflowManager>(trialWorkflowManager)
    ..registerSingleton<ITrialGeneratorEngine>(trialGeneratorEngine)
    ..registerSingleton<IImageProcessor>(imageProcessor)
    ..registerSingleton<IColorConversionEngine>(colorConversionEngine)
    ..registerSingleton<IColorSamplingEngine>(colorSamplingEngine)
    ..registerSingleton<IDominantColorEngine>(dominantColorEngine)
    ..registerSingleton<IColorExtractionEngine>(colorExtractionEngine)
    ..registerSingleton<IColorProfileBuilder>(colorProfileBuilder)
    ..registerSingleton<IImageAnalysisEngine>(imageAnalysisEngine);

  runApp(const HueMuseShadeAiApp());
}
