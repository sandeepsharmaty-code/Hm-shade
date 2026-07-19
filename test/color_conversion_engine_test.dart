/// Purpose      : Unit tests for ColorConversionEngine's deterministic
///                RGB/HEX/HSV/HSL/XYZ/CIELAB conversions.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/color_conversion_engine.dart,
///                engines/color_models.dart
/// Description  : Pure logic, no image decoding or repository
///                involved. Known reference colours (pure red, white,
///                black) have well-established conversion values used
///                to sanity-check every formula.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/engines/color_conversion_engine.dart';
import 'package:hue_muse_shade_ai/engines/color_models.dart';

void main() {
  const ColorConversionEngine engine = ColorConversionEngine();

  group('rgbToHex / hexToRgb', () {
    test('round-trips pure red', () {
      const RgbColor red = RgbColor(r: 255, g: 0, b: 0);
      expect(engine.rgbToHex(red), '#FF0000');
      expect(engine.hexToRgb('#FF0000'), red);
    });

    test('hexToRgb returns null for malformed input', () {
      expect(engine.hexToRgb('not-a-color'), isNull);
      expect(engine.hexToRgb('#FFF'), isNull);
    });
  });

  group('rgbToHsv', () {
    test('pure red is hue 0, full saturation and value', () {
      final HsvColor hsv = engine.rgbToHsv(
        const RgbColor(r: 255, g: 0, b: 0),
      );
      expect(hsv.h, closeTo(0, 0.01));
      expect(hsv.s, closeTo(1.0, 0.01));
      expect(hsv.v, closeTo(1.0, 0.01));
    });

    test('white has zero saturation', () {
      final HsvColor hsv = engine.rgbToHsv(
        const RgbColor(r: 255, g: 255, b: 255),
      );
      expect(hsv.s, closeTo(0.0, 0.01));
      expect(hsv.v, closeTo(1.0, 0.01));
    });

    test('black has zero value', () {
      final HsvColor hsv = engine.rgbToHsv(const RgbColor(r: 0, g: 0, b: 0));
      expect(hsv.v, closeTo(0.0, 0.01));
    });
  });

  group('rgbToHsl', () {
    test('pure red is hue 0, full saturation, 50% lightness', () {
      final HslColor hsl = engine.rgbToHsl(
        const RgbColor(r: 255, g: 0, b: 0),
      );
      expect(hsl.h, closeTo(0, 0.01));
      expect(hsl.s, closeTo(1.0, 0.01));
      expect(hsl.l, closeTo(0.5, 0.01));
    });

    test('white is 100% lightness', () {
      final HslColor hsl = engine.rgbToHsl(
        const RgbColor(r: 255, g: 255, b: 255),
      );
      expect(hsl.l, closeTo(1.0, 0.01));
    });
  });

  group('rgbToLab', () {
    test('white is approximately L*=100, a*=0, b*=0', () {
      final LabColor lab = engine.rgbToLab(
        const RgbColor(r: 255, g: 255, b: 255),
      );
      expect(lab.l, closeTo(100.0, 0.5));
      expect(lab.a, closeTo(0.0, 0.5));
      expect(lab.b, closeTo(0.0, 0.5));
    });

    test('black is approximately L*=0', () {
      final LabColor lab = engine.rgbToLab(const RgbColor(r: 0, g: 0, b: 0));
      expect(lab.l, closeTo(0.0, 0.5));
    });

    test('is deterministic — same input always gives same output', () {
      const RgbColor color = RgbColor(r: 120, g: 60, b: 200);
      final LabColor first = engine.rgbToLab(color);
      final LabColor second = engine.rgbToLab(color);
      expect(first.l, second.l);
      expect(first.a, second.a);
      expect(first.b, second.b);
    });
  });

  group('LabColor.distanceTo', () {
    test('identical colours have zero distance', () {
      final LabColor lab = engine.rgbToLab(
        const RgbColor(r: 10, g: 20, b: 30),
      );
      expect(lab.distanceTo(lab), closeTo(0.0, 0.0001));
    });

    test('white and black have a large distance', () {
      final LabColor white = engine.rgbToLab(
        const RgbColor(r: 255, g: 255, b: 255),
      );
      final LabColor black = engine.rgbToLab(
        const RgbColor(r: 0, g: 0, b: 0),
      );
      expect(white.distanceTo(black), greaterThan(50));
    });
  });
}
