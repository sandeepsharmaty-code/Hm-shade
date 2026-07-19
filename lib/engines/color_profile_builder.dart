/// Purpose      : Assembles the final ColorProfile from extraction
///                results.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : color_conversion_engine.dart, color_extraction_engine.dart,
///                color_models.dart, dominant_color_engine.dart
/// Description  : Produces every field this sprint's "COLOR PROFILE"
///                requirement lists: Image ID, Analysis Timestamp,
///                Dominant Color List, Color Distribution (via each
///                DominantColorResult.percentage), Average Color,
///                Brightness, Saturation, Lightness, Contrast
///                Estimate. Brightness uses the standard ITU-R BT.601
///                luma formula (deterministic, not perceptual ML);
///                Contrast Estimate is the spread between the
///                brightest and darkest dominant colour's luminance —
///                simple, transparent, deterministic.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'color_conversion_engine.dart';
import 'color_extraction_engine.dart';
import 'color_models.dart';
import 'dominant_color_engine.dart';

/// The full per-image colour profile this sprint requires.
@immutable
class ColorProfile {
  const ColorProfile({
    required this.imageId,
    required this.analyzedAt,
    required this.dominantColors,
    required this.averageColor,
    required this.averageHsv,
    required this.averageHsl,
    required this.averageLab,
    required this.brightness,
    required this.saturation,
    required this.lightness,
    required this.contrastEstimate,
  });

  final String imageId;
  final DateTime analyzedAt;

  /// Dominant Color List; each entry's `percentage` is the Color
  /// Distribution for that colour.
  final List<DominantColorResult> dominantColors;

  final RgbColor averageColor;
  final HsvColor averageHsv;
  final HslColor averageHsl;
  final LabColor averageLab;

  /// 0.0-1.0, ITU-R BT.601 luma of the average colour.
  final double brightness;

  /// 0.0-1.0, HSV saturation of the average colour.
  final double saturation;

  /// 0.0-1.0, HSL lightness of the average colour.
  final double lightness;

  /// 0.0-1.0, spread between the brightest and darkest dominant
  /// colour's luminance.
  final double contrastEstimate;
}

/// Contract for [ColorProfileBuilder].
abstract class IColorProfileBuilder {
  ColorProfile build({
    required String imageId,
    required ColorExtractionResult extraction,
  });
}

/// Builds a [ColorProfile] from a [ColorExtractionResult].
class ColorProfileBuilder implements IColorProfileBuilder {
  const ColorProfileBuilder({
    required IColorConversionEngine conversionEngine,
  }) : _conversionEngine = conversionEngine;

  final IColorConversionEngine _conversionEngine;

  @override
  ColorProfile build({
    required String imageId,
    required ColorExtractionResult extraction,
  }) {
    final RgbColor average = extraction.averageColor;
    final HsvColor hsv = _conversionEngine.rgbToHsv(average);
    final HslColor hsl = _conversionEngine.rgbToHsl(average);
    final LabColor lab = _conversionEngine.rgbToLab(average);
    final double brightness = _luma(average).clamp(0.0, 1.0);
    final double contrastEstimate = _contrastEstimate(
      extraction.dominantColors,
    );

    return ColorProfile(
      imageId: imageId,
      analyzedAt: DateTime.now(),
      dominantColors: extraction.dominantColors,
      averageColor: average,
      averageHsv: hsv,
      averageHsl: hsl,
      averageLab: lab,
      brightness: brightness,
      saturation: hsv.s.clamp(0.0, 1.0),
      lightness: hsl.l.clamp(0.0, 1.0),
      contrastEstimate: contrastEstimate,
    );
  }

  double _luma(RgbColor color) {
    return (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) / 255.0;
  }

  double _contrastEstimate(List<DominantColorResult> dominantColors) {
    if (dominantColors.isEmpty) {
      return 0.0;
    }
    double maxLuma = 0.0;
    double minLuma = 1.0;
    for (final DominantColorResult result in dominantColors) {
      final double luma = _luma(result.color);
      if (luma > maxLuma) {
        maxLuma = luma;
      }
      if (luma < minLuma) {
        minLuma = luma;
      }
    }
    return (maxLuma - minLuma).clamp(0.0, 1.0);
  }
}
