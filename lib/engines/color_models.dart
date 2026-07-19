/// Purpose      : Immutable colour value types shared across the
///                Image Intelligence engines.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : dart:math
/// Description  : Plain data holders for each colour space this
///                sprint's "COLOR CONVERSION" requirement lists
///                (RGB, HEX as a getter, HSV, HSL, XYZ, CIELAB). No
///                colour math beyond LabColor.distanceTo (a standard
///                Delta-E CIE76 formula) lives here — the actual
///                conversions are ColorConversionEngine's job; these
///                are typed containers so engine signatures aren't a
///                soup of raw doubles.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 8-bit-per-channel RGB colour, optionally with alpha.
@immutable
class RgbColor {
  const RgbColor({
    required this.r,
    required this.g,
    required this.b,
    this.a = 255,
  });

  /// 0-255.
  final int r;
  final int g;
  final int b;

  /// 0-255, 0 = fully transparent.
  final int a;

  String get hex =>
      ('#${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}')
          .toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is RgbColor &&
      other.r == r &&
      other.g == g &&
      other.b == b &&
      other.a == a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'RgbColor($hex, a: $a)';
}

/// Hue in degrees (0-360); saturation/value in 0.0-1.0.
@immutable
class HsvColor {
  const HsvColor({required this.h, required this.s, required this.v});
  final double h;
  final double s;
  final double v;

  @override
  String toString() =>
      'HsvColor(h: ${h.toStringAsFixed(1)}, s: ${s.toStringAsFixed(2)}, '
      'v: ${v.toStringAsFixed(2)})';
}

/// Hue in degrees (0-360); saturation/lightness in 0.0-1.0.
@immutable
class HslColor {
  const HslColor({required this.h, required this.s, required this.l});
  final double h;
  final double s;
  final double l;

  @override
  String toString() =>
      'HslColor(h: ${h.toStringAsFixed(1)}, s: ${s.toStringAsFixed(2)}, '
      'l: ${l.toStringAsFixed(2)})';
}

/// CIE 1931 XYZ tristimulus values (D65 white point).
@immutable
class XyzColor {
  const XyzColor({required this.x, required this.y, required this.z});
  final double x;
  final double y;
  final double z;

  @override
  String toString() =>
      'XyzColor(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      '${z.toStringAsFixed(2)})';
}

/// CIELAB (L*a*b*) colour, D65 white point.
@immutable
class LabColor {
  const LabColor({required this.l, required this.a, required this.b});

  /// Lightness, 0-100.
  final double l;

  /// Green-red axis, roughly -128..127.
  final double a;

  /// Blue-yellow axis, roughly -128..127.
  final double b;

  /// Euclidean distance to [other] in Lab space — the standard,
  /// deterministic Delta-E CIE76 perceptual colour-difference
  /// formula, used for "Color Distance Data".
  double distanceTo(LabColor other) {
    final double dl = l - other.l;
    final double da = a - other.a;
    final double db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  @override
  String toString() =>
      'LabColor(L: ${l.toStringAsFixed(1)}, a: ${a.toStringAsFixed(1)}, '
      'b: ${b.toStringAsFixed(1)})';
}
