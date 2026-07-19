/// Purpose      : Deterministic colour-space conversions.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : dart:math, color_models.dart
/// Description  : Implements every conversion this sprint's "COLOR
///                CONVERSION" requirement lists: RGB, HEX, HSV, HSL,
///                CIELAB, XYZ. Every function is a pure, stateless
///                mathematical transform (standard sRGB/D65 formulas)
///                — same input always produces the same output, no
///                randomness, no external calls, no ML. Deliberately
///                NOT reusing ShadeEngine's private _hexToHsl
///                (SPR-DEP-004, frozen/approved) — see Known Issues
///                in the SPR-DEP-008 report for why that's flagged as
///                a minor, acceptable duplication rather than a
///                modification to already-approved code.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'dart:math' as math;

import 'color_models.dart';

/// Contract for [ColorConversionEngine].
abstract class IColorConversionEngine {
  String rgbToHex(RgbColor rgb);
  RgbColor? hexToRgb(String hex);
  HsvColor rgbToHsv(RgbColor rgb);
  HslColor rgbToHsl(RgbColor rgb);
  XyzColor rgbToXyz(RgbColor rgb);
  LabColor xyzToLab(XyzColor xyz);
  LabColor rgbToLab(RgbColor rgb);
}

/// Deterministic colour-space conversion implementations.
class ColorConversionEngine implements IColorConversionEngine {
  const ColorConversionEngine();

  // D65 reference white, CIE 1931 2-degree observer.
  static const double _refX = 95.047;
  static const double _refY = 100.000;
  static const double _refZ = 108.883;

  @override
  String rgbToHex(RgbColor rgb) => rgb.hex;

  @override
  RgbColor? hexToRgb(String hex) {
    final String cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) {
      return null;
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return null;
    }
    return RgbColor(
      r: (value >> 16) & 0xFF,
      g: (value >> 8) & 0xFF,
      b: value & 0xFF,
    );
  }

  @override
  HsvColor rgbToHsv(RgbColor rgb) {
    final double r = rgb.r / 255.0;
    final double g = rgb.g / 255.0;
    final double b = rgb.b / 255.0;

    final double maxC = math.max(r, math.max(g, b));
    final double minC = math.min(r, math.min(g, b));
    final double delta = maxC - minC;

    final double v = maxC;
    final double s = maxC == 0 ? 0 : delta / maxC;
    final double h = _hueFrom(r, g, b, maxC, delta);

    return HsvColor(h: h, s: s, v: v);
  }

  @override
  HslColor rgbToHsl(RgbColor rgb) {
    final double r = rgb.r / 255.0;
    final double g = rgb.g / 255.0;
    final double b = rgb.b / 255.0;

    final double maxC = math.max(r, math.max(g, b));
    final double minC = math.min(r, math.min(g, b));
    final double delta = maxC - minC;

    final double l = (maxC + minC) / 2;
    double s = 0;
    if (delta != 0) {
      s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC);
    }
    final double h = _hueFrom(r, g, b, maxC, delta);

    return HslColor(h: h, s: s, l: l);
  }

  double _hueFrom(
    double r,
    double g,
    double b,
    double maxC,
    double delta,
  ) {
    if (delta == 0) {
      return 0;
    }
    double hue;
    if (maxC == r) {
      hue = ((g - b) / delta) % 6;
    } else if (maxC == g) {
      hue = ((b - r) / delta) + 2;
    } else {
      hue = ((r - g) / delta) + 4;
    }
    hue *= 60;
    if (hue < 0) {
      hue += 360;
    }
    return hue;
  }

  @override
  XyzColor rgbToXyz(RgbColor rgb) {
    double linearize(int channel) {
      final double c = channel / 255.0;
      return c > 0.04045
          ? math.pow((c + 0.055) / 1.055, 2.4).toDouble()
          : c / 12.92;
    }

    final double r = linearize(rgb.r) * 100;
    final double g = linearize(rgb.g) * 100;
    final double b = linearize(rgb.b) * 100;

    // Standard sRGB -> XYZ (D65) matrix.
    final double x = r * 0.4124 + g * 0.3576 + b * 0.1805;
    final double y = r * 0.2126 + g * 0.7152 + b * 0.0722;
    final double z = r * 0.0193 + g * 0.1192 + b * 0.9505;

    return XyzColor(x: x, y: y, z: z);
  }

  @override
  LabColor xyzToLab(XyzColor xyz) {
    double f(double t) {
      const double epsilon = 216.0 / 24389.0;
      const double kappa = 24389.0 / 27.0;
      return t > epsilon
          ? math.pow(t, 1.0 / 3.0).toDouble()
          : (kappa * t + 16.0) / 116.0;
    }

    final double fx = f(xyz.x / _refX);
    final double fy = f(xyz.y / _refY);
    final double fz = f(xyz.z / _refZ);

    final double l = (116.0 * fy) - 16.0;
    final double a = 500.0 * (fx - fy);
    final double b = 200.0 * (fy - fz);

    return LabColor(l: l, a: a, b: b);
  }

  @override
  LabColor rgbToLab(RgbColor rgb) => xyzToLab(rgbToXyz(rgb));
}
