/// Purpose      : Detects dominant colours and their distribution
///                from a set of sampled pixels.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : color_models.dart
/// Description  : Deterministic colour quantization (round each
///                channel down to the nearest [quantizationStep]) and
///                frequency counting — explicitly NOT k-means or any
///                learned clustering, per "NO IMAGE AI". Same sample
///                set always produces the same buckets in the same
///                order.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'package:flutter/foundation.dart';

import 'color_models.dart';

/// One dominant colour bucket: its representative colour, sample
/// count, and share of the total — the basis for "Color
/// Distribution".
@immutable
class DominantColorResult {
  const DominantColorResult({
    required this.color,
    required this.count,
    required this.percentage,
  });

  final RgbColor color;
  final int count;

  /// 0.0-1.0 share of all samples this bucket represents.
  final double percentage;
}

/// Contract for [DominantColorEngine].
abstract class IDominantColorEngine {
  List<DominantColorResult> detect(
    List<RgbColor> samples, {
    int quantizationStep,
    int maxResults,
  });
}

/// Quantization-and-frequency dominant colour detector.
class DominantColorEngine implements IDominantColorEngine {
  const DominantColorEngine();

  @override
  List<DominantColorResult> detect(
    List<RgbColor> samples, {
    int quantizationStep = 32,
    int maxResults = 5,
  }) {
    if (samples.isEmpty) {
      return const <DominantColorResult>[];
    }

    final Map<String, List<RgbColor>> buckets = <String, List<RgbColor>>{};
    for (final RgbColor sample in samples) {
      final String key = _bucketKey(sample, quantizationStep);
      buckets.putIfAbsent(key, () => <RgbColor>[]).add(sample);
    }

    final int total = samples.length;
    final List<DominantColorResult> results = <DominantColorResult>[
      for (final List<RgbColor> bucket in buckets.values)
        DominantColorResult(
          color: _averageOf(bucket),
          count: bucket.length,
          percentage: bucket.length / total,
        ),
    ];

    results.sort(
      (DominantColorResult a, DominantColorResult b) =>
          b.count.compareTo(a.count),
    );

    return results.take(maxResults).toList();
  }

  String _bucketKey(RgbColor color, int step) {
    int bucket(int channel) => (channel ~/ step) * step;
    return '${bucket(color.r)}-${bucket(color.g)}-${bucket(color.b)}';
  }

  RgbColor _averageOf(List<RgbColor> colors) {
    int rSum = 0, gSum = 0, bSum = 0;
    for (final RgbColor c in colors) {
      rSum += c.r;
      gSum += c.g;
      bSum += c.b;
    }
    final int n = colors.length;
    return RgbColor(r: rSum ~/ n, g: gSum ~/ n, b: bSum ~/ n);
  }
}
