/// Purpose      : Orchestrates pixel sampling and dominant-colour
///                detection into a full colour extraction result.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : color_sampling_engine.dart, dominant_color_engine.dart,
///                color_conversion_engine.dart, color_models.dart,
///                package:image
/// Description  : Produces Average Color, dominant colours/palette,
///                and Color Distance Data (pairwise CIELAB Delta-E
///                between palette colours) — the extraction-layer
///                outputs this sprint's OUTPUT list requires. Does
///                not sample or bucket pixels itself; delegates to
///                ColorSamplingEngine/DominantColorEngine so that
///                logic exists in exactly one place each.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'color_conversion_engine.dart';
import 'color_models.dart';
import 'color_sampling_engine.dart';
import 'dominant_color_engine.dart';

/// The full colour-extraction result for one image.
@immutable
class ColorExtractionResult {
  const ColorExtractionResult({
    required this.averageColor,
    required this.dominantColors,
    required this.palette,
    required this.colorDistances,
  });

  final RgbColor averageColor;
  final List<DominantColorResult> dominantColors;

  /// Just the colours from [dominantColors], in the same order.
  final List<RgbColor> palette;

  /// Pairwise CIELAB Delta-E distance between palette colours, keyed
  /// `"HEX1-HEX2"` — the "Color Distance Data" output.
  final Map<String, double> colorDistances;
}

/// Contract for [ColorExtractionEngine].
abstract class IColorExtractionEngine {
  ColorExtractionResult extract(
    img.Image image, {
    SamplingStrategy strategy,
    int gridDivisions,
    int maxDominantColors,
  });
}

/// Extracts average/dominant colours and colour-distance data from an
/// image.
class ColorExtractionEngine implements IColorExtractionEngine {
  const ColorExtractionEngine({
    required IColorSamplingEngine samplingEngine,
    required IDominantColorEngine dominantColorEngine,
    required IColorConversionEngine conversionEngine,
  })  : _samplingEngine = samplingEngine,
        _dominantColorEngine = dominantColorEngine,
        _conversionEngine = conversionEngine;

  final IColorSamplingEngine _samplingEngine;
  final IDominantColorEngine _dominantColorEngine;
  final IColorConversionEngine _conversionEngine;

  @override
  ColorExtractionResult extract(
    img.Image image, {
    SamplingStrategy strategy = SamplingStrategy.grid,
    int gridDivisions = 8,
    int maxDominantColors = 5,
  }) {
    final List<RgbColor> samples = _samplingEngine.sample(
      image,
      strategy: strategy,
      gridDivisions: gridDivisions,
    );

    if (samples.isEmpty) {
      const RgbColor black = RgbColor(r: 0, g: 0, b: 0);
      return const ColorExtractionResult(
        averageColor: black,
        dominantColors: <DominantColorResult>[],
        palette: <RgbColor>[],
        colorDistances: <String, double>{},
      );
    }

    final RgbColor average = _averageOf(samples);
    final List<DominantColorResult> dominant = _dominantColorEngine.detect(
      samples,
      maxResults: maxDominantColors,
    );
    final List<RgbColor> palette = <RgbColor>[
      for (final DominantColorResult d in dominant) d.color,
    ];

    final Map<String, double> distances = <String, double>{};
    for (int i = 0; i < palette.length; i++) {
      for (int j = i + 1; j < palette.length; j++) {
        final LabColor labA = _conversionEngine.rgbToLab(palette[i]);
        final LabColor labB = _conversionEngine.rgbToLab(palette[j]);
        distances['${palette[i].hex}-${palette[j].hex}'] = labA.distanceTo(
          labB,
        );
      }
    }

    return ColorExtractionResult(
      averageColor: average,
      dominantColors: dominant,
      palette: palette,
      colorDistances: distances,
    );
  }

  RgbColor _averageOf(List<RgbColor> samples) {
    int rSum = 0, gSum = 0, bSum = 0;
    for (final RgbColor c in samples) {
      rSum += c.r;
      gSum += c.g;
      bSum += c.b;
    }
    final int n = samples.length;
    return RgbColor(r: rSum ~/ n, g: gSum ~/ n, b: bSum ~/ n);
  }
}
