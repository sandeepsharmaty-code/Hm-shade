/// Purpose      : Top-level orchestrator for image colour analysis,
///                and the bridge into the existing recommendation
///                pipeline.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : dart:io, image_processor.dart,
///                color_extraction_engine.dart, color_profile_builder.dart,
///                engines/shade_engine.dart (SPR-DEP-004),
///                engines/trial_generator_engine.dart (SPR-DEP-007),
///                engines/formula_recommendation_engine.dart,
///                models/shade_model.dart
/// Description  : Implements the "ENGINE INTEGRATION" pipeline:
///                ImageAnalysisEngine -> ShadeEngine -> RuleEngine ->
///                RecommendationEngine -> TrialGeneratorEngine.
///                Decodes a Gallery Image (Local Device Storage file
///                path — the same path shape ImagePickerCard,
///                SPR-DEP-002, already produces) into a ColorProfile,
///                classifies it against the "IMAGE RULES" categories
///                by delegating to ShadeEngine's existing hex-based
///                classification (an ephemeral, unpersisted
///                ShadeModel carries the analyzed colour — no new
///                shade-family logic is duplicated here), then
///                optionally feeds the result into
///                TrialGeneratorEngine (which itself already chains
///                through RuleEngine and RecommendationEngine,
///                SPR-DEP-005/006/007 — not re-wired here). Image ID
///                is a deterministic FNV-1a hash of the file's bytes,
///                not a random UUID — identical images always get the
///                identical id.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/shade_model.dart';
import 'color_extraction_engine.dart';
import 'color_profile_builder.dart';
import 'color_sampling_engine.dart';
import 'engine_base.dart';
import 'engine_result.dart';
import 'formula_recommendation_engine.dart';
import 'image_processor.dart';
import 'shade_engine.dart';
import 'trial_generator_engine.dart';

/// Classification of an image's colour content against this sprint's
/// "IMAGE RULES" categories.
@immutable
class ImageColorClassification {
  const ImageColorClassification({
    required this.hasSingleDominantColor,
    required this.isDark,
    required this.isLight,
    required this.shadeFamily,
    required this.undertone,
  });

  /// True if one dominant-colour bucket accounts for >= 50% of
  /// samples (Single dominant colour); false means Multiple dominant
  /// colours.
  final bool hasSingleDominantColor;

  /// Dark shades: brightness < 0.35.
  final bool isDark;

  /// Light shades: brightness > 0.65.
  final bool isLight;

  /// From ShadeEngine.detectShadeFamily — Red/Nude/Yellow/etc., or
  /// Neutral.
  final String shadeFamily;

  /// From ShadeEngine.detectUndertone — Warm/Cool/Neutral tones.
  final String undertone;
}

/// Combined output of one full image analysis pass.
@immutable
class ImageAnalysisResult {
  const ImageAnalysisResult({
    required this.profile,
    required this.classification,
  });

  final ColorProfile profile;
  final ImageColorClassification classification;
}

/// Contract for [ImageAnalysisEngine].
abstract class IImageAnalysisEngine {
  Future<EngineResult<ImageAnalysisResult>> analyzeImage(String imagePath);

  Future<EngineResult<List<FormulaRecommendation>>> analyzeAndRecommend({
    required String imagePath,
    required int productId,
    int maxResults,
  });
}

/// Top-level Image Intelligence orchestrator.
class ImageAnalysisEngine extends EngineBase implements IImageAnalysisEngine {
  ImageAnalysisEngine({
    required IImageProcessor imageProcessor,
    required IColorExtractionEngine extractionEngine,
    required IColorProfileBuilder profileBuilder,
    required IShadeEngine shadeEngine,
    required ITrialGeneratorEngine trialGeneratorEngine,
  })  : _imageProcessor = imageProcessor,
        _extractionEngine = extractionEngine,
        _profileBuilder = profileBuilder,
        _shadeEngine = shadeEngine,
        _trialGeneratorEngine = trialGeneratorEngine;

  final IImageProcessor _imageProcessor;
  final IColorExtractionEngine _extractionEngine;
  final IColorProfileBuilder _profileBuilder;
  final IShadeEngine _shadeEngine;
  final ITrialGeneratorEngine _trialGeneratorEngine;

  @override
  String get engineName => 'ImageAnalysisEngine';

  @override
  Future<EngineResult<ImageAnalysisResult>> analyzeImage(
    String imagePath,
  ) async {
    try {
      final File file = File(imagePath);
      if (!file.existsSync()) {
        return EngineResult<ImageAnalysisResult>.failure(
          message: 'Image file not found: $imagePath',
        );
      }
      final Uint8List bytes = await file.readAsBytes();

      final decoded = await _imageProcessor.decodeBytes(bytes);
      if (decoded == null) {
        return EngineResult<ImageAnalysisResult>.failure(
          message: 'Unable to decode image at $imagePath.',
        );
      }

      final downscaled = _imageProcessor.downscale(decoded);
      final ColorExtractionResult extraction = _extractionEngine.extract(
        downscaled,
        strategy: SamplingStrategy.grid,
      );

      final String imageId = _generateImageId(bytes);
      final ColorProfile profile = _profileBuilder.build(
        imageId: imageId,
        extraction: extraction,
      );

      final ImageColorClassification classification = _classify(profile);

      logDebug(
        'Analyzed $imagePath -> $imageId, ${profile.dominantColors.length} '
        'dominant colors, brightness '
        '${profile.brightness.toStringAsFixed(2)}',
      );

      return EngineResult<ImageAnalysisResult>.success(
        data: ImageAnalysisResult(
          profile: profile,
          classification: classification,
        ),
      );
    } catch (error) {
      logDebug('analyzeImage failed: $error');
      return EngineResult<ImageAnalysisResult>.failure(
        message: 'Unable to analyze image at $imagePath.',
      );
    }
  }

  @override
  Future<EngineResult<List<FormulaRecommendation>>> analyzeAndRecommend({
    required String imagePath,
    required int productId,
    int maxResults = 5,
  }) async {
    final EngineResult<ImageAnalysisResult> analysis = await analyzeImage(
      imagePath,
    );
    if (!analysis.isSuccess || analysis.data == null) {
      return EngineResult<List<FormulaRecommendation>>.failure(
        message: analysis.messages.isNotEmpty
            ? analysis.messages.first
            : 'Image analysis failed.',
      );
    }

    final ImageColorClassification classification =
        analysis.data!.classification;

    final FormulaRecommendationRequest request = FormulaRecommendationRequest(
      productId: productId,
      shadeFamily: classification.shadeFamily,
      maxResults: maxResults,
    );

    final EngineResult<List<FormulaRecommendation>> result =
        await _trialGeneratorEngine.generateTopFive(request);

    return EngineResult<List<FormulaRecommendation>>.success(
      data: result.data ?? const <FormulaRecommendation>[],
      confidenceScore: result.confidenceScore,
      recommendedIds: result.recommendedIds,
      warnings: result.warnings,
      messages: <String>[
        'Detected ${classification.shadeFamily} family, '
            '${classification.undertone} undertone from image '
            '(id: ${analysis.data!.profile.imageId}).',
        ...result.messages,
      ],
    );
  }

  ImageColorClassification _classify(ColorProfile profile) {
    final bool hasSingleDominant = profile.dominantColors.isNotEmpty &&
        profile.dominantColors.first.percentage >= 0.5;

    // Ephemeral, unpersisted ShadeModel — carries the analyzed colour
    // through ShadeEngine's existing hex-based classification without
    // duplicating that logic here.
    final ShadeModel probe = ShadeModel(
      name: 'Image Analysis Probe',
      shadeCode: 'IMG-${profile.imageId}',
      hexColor: profile.averageColor.hex,
    );

    final String shadeFamily =
        _shadeEngine.detectShadeFamily(probe).data ?? 'Neutral';
    final String undertone =
        _shadeEngine.detectUndertone(probe).data ?? 'Neutral';

    return ImageColorClassification(
      hasSingleDominantColor: hasSingleDominant,
      isDark: profile.brightness < 0.35,
      isLight: profile.brightness > 0.65,
      shadeFamily: shadeFamily,
      undertone: undertone,
    );
  }

  /// Deterministic FNV-1a hash of [bytes] — the same image file
  /// always produces the same Image ID.
  String _generateImageId(Uint8List bytes) {
    int hash = 0x811C9DC5;
    const int prime = 0x01000193;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return 'IMG-${hash.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
