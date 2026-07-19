/// Purpose      : Unit tests for DominantColorEngine's quantization
///                and frequency counting.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/dominant_color_engine.dart,
///                engines/color_models.dart
/// Description  : Pure logic, no image decoding involved.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/engines/color_models.dart';
import 'package:hue_muse_shade_ai/engines/dominant_color_engine.dart';

void main() {
  const DominantColorEngine engine = DominantColorEngine();

  test('empty input returns no results', () {
    expect(engine.detect(const <RgbColor>[]), isEmpty);
  });

  test('groups similar colours into one dominant bucket', () {
    final List<RgbColor> samples = <RgbColor>[
      const RgbColor(r: 200, g: 10, b: 10),
      const RgbColor(r: 205, g: 12, b: 8),
      const RgbColor(r: 198, g: 9, b: 11),
      const RgbColor(r: 10, g: 10, b: 200),
    ];

    final List<DominantColorResult> results = engine.detect(samples);

    expect(results, isNotEmpty);
    // The three near-red samples should dominate the top bucket.
    expect(results.first.count, 3);
    expect(results.first.percentage, closeTo(0.75, 0.0001));
  });

  test('percentages across all buckets sum to 1.0', () {
    final List<RgbColor> samples = <RgbColor>[
      const RgbColor(r: 255, g: 0, b: 0),
      const RgbColor(r: 0, g: 255, b: 0),
      const RgbColor(r: 0, g: 0, b: 255),
      const RgbColor(r: 255, g: 255, b: 255),
    ];

    final List<DominantColorResult> results = engine.detect(
      samples,
      maxResults: 10,
    );
    final double total = results.fold(
      0.0,
      (double sum, DominantColorResult r) => sum + r.percentage,
    );
    expect(total, closeTo(1.0, 0.0001));
  });

  test('respects maxResults', () {
    final List<RgbColor> samples = <RgbColor>[
      const RgbColor(r: 255, g: 0, b: 0),
      const RgbColor(r: 0, g: 255, b: 0),
      const RgbColor(r: 0, g: 0, b: 255),
      const RgbColor(r: 255, g: 255, b: 0),
    ];

    final List<DominantColorResult> results = engine.detect(
      samples,
      maxResults: 2,
    );
    expect(results.length, lessThanOrEqualTo(2));
  });
}
