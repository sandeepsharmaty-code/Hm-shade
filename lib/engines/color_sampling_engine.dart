/// Purpose      : Samples pixels from a decoded image using
///                deterministic strategies.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : dart:math, package:image, color_models.dart
/// Description  : Implements every strategy this sprint's "COLOR
///                EXTRACTION" requirement lists: Single Pixel
///                Sampling, Grid Sampling, Multi-point Sampling,
///                Noise Reduction (3x3 neighbourhood averaging around
///                each sample point — a standard deterministic mean
///                filter, not ML), and Transparent Pixel Handling
///                (pixels below an alpha threshold are excluded
///                entirely rather than corrupting the average with a
///                meaningless colour). Grid points are evenly spaced;
///                multi-point uses a fixed centre-plus-ring layout —
///                both are fully deterministic (same image, same
///                points, every time), never random.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'color_models.dart';

/// The three sampling strategies this sprint requires.
enum SamplingStrategy { singlePixel, grid, multiPoint }

/// A single (x, y) pixel coordinate.
class _Point {
  const _Point(this.x, this.y);
  final int x;
  final int y;
}

/// Contract for [ColorSamplingEngine].
abstract class IColorSamplingEngine {
  List<RgbColor> sample(
    img.Image image, {
    required SamplingStrategy strategy,
    int gridDivisions,
    int multiPointCount,
    bool reduceNoise,
    int transparencyThreshold,
  });
}

/// Samples pixel colours from a decoded image.
class ColorSamplingEngine implements IColorSamplingEngine {
  const ColorSamplingEngine();

  @override
  List<RgbColor> sample(
    img.Image image, {
    required SamplingStrategy strategy,
    int gridDivisions = 8,
    int multiPointCount = 9,
    bool reduceNoise = true,
    int transparencyThreshold = 10,
  }) {
    if (image.width == 0 || image.height == 0) {
      return const <RgbColor>[];
    }

    final List<_Point> points = switch (strategy) {
      SamplingStrategy.singlePixel => <_Point>[
          _Point(image.width ~/ 2, image.height ~/ 2),
        ],
      SamplingStrategy.grid => _gridPoints(image, gridDivisions),
      SamplingStrategy.multiPoint => _multiPoints(image, multiPointCount),
    };

    final List<RgbColor> samples = <RgbColor>[];
    for (final _Point point in points) {
      final RgbColor color = reduceNoise
          ? _averagedPixel(image, point.x, point.y)
          : _rawPixel(image, point.x, point.y);
      // Transparent Pixel Handling: exclude near-fully-transparent
      // samples rather than let them skew the average toward
      // whatever arbitrary colour a transparent pixel happens to
      // store.
      if (color.a < transparencyThreshold) {
        continue;
      }
      samples.add(color);
    }
    return samples;
  }

  RgbColor _rawPixel(img.Image image, int x, int y) {
    final img.Pixel pixel = image.getPixel(x, y);
    return RgbColor(
      r: pixel.r.toInt(),
      g: pixel.g.toInt(),
      b: pixel.b.toInt(),
      a: pixel.a.toInt(),
    );
  }

  /// Averages the 3x3 neighbourhood around ([x], [y]) — a standard
  /// deterministic mean filter for Noise Reduction.
  RgbColor _averagedPixel(img.Image image, int x, int y) {
    int rSum = 0, gSum = 0, bSum = 0, aSum = 0, count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final int nx = x + dx;
        final int ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
          continue;
        }
        final img.Pixel pixel = image.getPixel(nx, ny);
        rSum += pixel.r.toInt();
        gSum += pixel.g.toInt();
        bSum += pixel.b.toInt();
        aSum += pixel.a.toInt();
        count++;
      }
    }
    if (count == 0) {
      return _rawPixel(image, x, y);
    }
    return RgbColor(
      r: rSum ~/ count,
      g: gSum ~/ count,
      b: bSum ~/ count,
      a: aSum ~/ count,
    );
  }

  /// Evenly spaced grid of [divisions] x [divisions] sample points.
  List<_Point> _gridPoints(img.Image image, int divisions) {
    final List<_Point> points = <_Point>[];
    for (int row = 0; row < divisions; row++) {
      for (int col = 0; col < divisions; col++) {
        final int x = ((col + 0.5) * image.width / divisions)
            .floor()
            .clamp(0, image.width - 1);
        final int y = ((row + 0.5) * image.height / divisions)
            .floor()
            .clamp(0, image.height - 1);
        points.add(_Point(x, y));
      }
    }
    return points;
  }

  /// A fixed centre-plus-ring layout: the image centre, then [count]
  /// - 1 points evenly spaced around a ring at 35% of the image's
  /// half-dimensions. Deterministic — the same image always produces
  /// the same points.
  List<_Point> _multiPoints(img.Image image, int count) {
    final List<_Point> points = <_Point>[
      _Point(image.width ~/ 2, image.height ~/ 2),
    ];
    final int ringCount = count - 1;
    if (ringCount <= 0) {
      return points;
    }
    final double centerX = image.width / 2;
    final double centerY = image.height / 2;
    final double radiusX = image.width * 0.35;
    final double radiusY = image.height * 0.35;

    for (int i = 0; i < ringCount; i++) {
      final double angle = (2 * math.pi * i) / ringCount;
      final int x = (centerX + radiusX * math.cos(angle))
          .round()
          .clamp(0, image.width - 1);
      final int y = (centerY + radiusY * math.sin(angle))
          .round()
          .clamp(0, image.height - 1);
      points.add(_Point(x, y));
    }
    return points;
  }
}
