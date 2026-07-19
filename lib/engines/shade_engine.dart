/// Purpose      : Business-rule engine for shade classification and
///                product-compatibility validation.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : engine_base.dart, engine_result.dart,
///                models/shade_model.dart, models/product_model.dart
/// Description  : Detects Shade Family / Undertone / Finish from a
///                shade's already-stored attributes (hex colour,
///                name, finish) using deterministic colour-theory
///                math (hex -> HSL -> hue bucket) and keyword rules —
///                explicitly NOT image processing, camera input, or
///                machine learning, per this sprint's scope. Also
///                validates that a shade is compatible with a given
///                product. Reads only through ShadeRepository /
///                ProductRepository when given ids; the pure
///                classification functions take already-loaded models
///                and touch no repository at all.
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'dart:math' as math;

import '../models/product_model.dart';
import '../models/shade_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import 'engine_base.dart';
import 'engine_result.dart';

/// Contract for [ShadeEngine].
abstract class IShadeEngine {
  EngineResult<String> detectShadeFamily(ShadeModel shade);
  EngineResult<String> detectUndertone(ShadeModel shade);
  EngineResult<String> detectFinish(ShadeModel shade);

  Future<EngineResult<bool>> validateProductCompatibility({
    required int shadeId,
    required int productId,
  });
}

/// Classifies shade attributes and validates shade/product pairing.
class ShadeEngine extends EngineBase implements IShadeEngine {
  ShadeEngine({
    required ShadeRepository shadeRepository,
    required ProductRepository productRepository,
  })  : _shadeRepository = shadeRepository,
        _productRepository = productRepository;

  final ShadeRepository _shadeRepository;
  final ProductRepository _productRepository;

  @override
  String get engineName => 'ShadeEngine';

  /// Named hue buckets, in degrees on the 0-360 HSL colour wheel.
  /// Deliberately simple, named ranges — a business rule, not a
  /// colour-science model.
  static const List<(double, double, String)> _hueFamilies = <(
    double,
    double,
    String
  )>[
    (345, 360, 'Red'),
    (0, 15, 'Red'),
    (15, 45, 'Nude'),
    (45, 70, 'Yellow'),
    (70, 160, 'Green'),
    (160, 200, 'Teal'),
    (200, 260, 'Blue'),
    (260, 300, 'Purple'),
    (300, 345, 'Pink'),
  ];

  @override
  EngineResult<String> detectShadeFamily(ShadeModel shade) {
    // If a family was already recorded (e.g. entered during Trial
    // approval), trust it — this is a confirmation, not an override.
    if (shade.shadeFamily != null && shade.shadeFamily!.trim().isNotEmpty) {
      return EngineResult<String>.success(data: shade.shadeFamily);
    }

    final _Hsl? hsl = _hexToHsl(shade.hexColor);
    if (hsl == null) {
      return EngineResult<String>.failure(
        message:
            'Cannot detect shade family: no shadeFamily on record and '
            'hexColor is missing or invalid.',
      );
    }

    if (hsl.saturation < 0.12) {
      return EngineResult<String>.success(
        data: hsl.lightness > 0.85 ? 'White/Sheer' : 'Neutral',
        confidenceScore: 0.7,
      );
    }

    for (final (double start, double end, String family) in _hueFamilies) {
      if (hsl.hue >= start && hsl.hue < end) {
        return EngineResult<String>.success(
          data: family,
          confidenceScore: 0.8,
        );
      }
    }

    return EngineResult<String>.success(
      data: 'Neutral',
      confidenceScore: 0.4,
      warnings: const <String>[
        'Hue did not fall into a known family bucket.',
      ],
    );
  }

  @override
  EngineResult<String> detectUndertone(ShadeModel shade) {
    final _Hsl? hsl = _hexToHsl(shade.hexColor);
    if (hsl == null) {
      return EngineResult<String>.failure(
        message: 'Cannot detect undertone: hexColor is missing or invalid.',
      );
    }

    // Warm hues cluster around red/orange/yellow; cool hues cluster
    // around blue/green/purple. This is a simplified, documented
    // business rule, not a colourimetry model.
    final bool isWarm = (hsl.hue >= 0 && hsl.hue < 70) || hsl.hue >= 300;
    final bool isCool = hsl.hue >= 160 && hsl.hue < 300;

    if (hsl.saturation < 0.12) {
      return EngineResult<String>.success(
        data: 'Neutral',
        confidenceScore: 0.6,
      );
    }
    if (isWarm) {
      return EngineResult<String>.success(data: 'Warm', confidenceScore: 0.75);
    }
    if (isCool) {
      return EngineResult<String>.success(data: 'Cool', confidenceScore: 0.75);
    }
    return EngineResult<String>.success(data: 'Neutral', confidenceScore: 0.5);
  }

  @override
  EngineResult<String> detectFinish(ShadeModel shade) {
    if (shade.finish != null && shade.finish!.trim().isNotEmpty) {
      return EngineResult<String>.success(data: shade.finish);
    }

    final String name = shade.name.toLowerCase();
    const Map<String, List<String>> keywordsByFinish = <String, List<String>>{
      'Matte': <String>['matte', 'mat '],
      'Shimmer': <String>['shimmer', 'glitter', 'sparkle', 'metallic'],
      'Glossy': <String>['glossy', 'gloss', 'shine'],
      'Satin': <String>['satin', 'silk'],
    };

    for (final MapEntry<String, List<String>> entry
        in keywordsByFinish.entries) {
      for (final String keyword in entry.value) {
        if (name.contains(keyword)) {
          return EngineResult<String>.success(
            data: entry.key,
            confidenceScore: 0.6,
          );
        }
      }
    }

    return EngineResult<String>.success(
      data: 'Glossy',
      confidenceScore: 0.3,
      warnings: const <String>[
        'No finish keyword found in shade name; defaulted to Glossy.',
      ],
    );
  }

  @override
  Future<EngineResult<bool>> validateProductCompatibility({
    required int shadeId,
    required int productId,
  }) async {
    try {
      final ShadeModel? shade = await _shadeRepository.readById(shadeId);
      final ProductModel? product =
          await _productRepository.readById(productId);

      if (shade == null) {
        return EngineResult<bool>.failure(
          message: 'Shade $shadeId not found or inactive.',
        );
      }
      if (product == null) {
        return EngineResult<bool>.failure(
          message: 'Product $productId not found or inactive.',
        );
      }

      if (shade.productId == null) {
        return EngineResult<bool>.success(
          data: true,
          confidenceScore: 0.6,
          warnings: const <String>[
            'Shade is not yet assigned to any product; treating as '
            'compatible pending assignment.',
          ],
        );
      }

      if (shade.productId == product.id) {
        return EngineResult<bool>.success(data: true);
      }

      return EngineResult<bool>.success(
        data: false,
        confidenceScore: 1.0,
        warnings: <String>[
          'Shade "${shade.name}" is assigned to a different product.',
        ],
      );
    } on RepositoryException catch (error) {
      logDebug('validateProductCompatibility failed: $error');
      return EngineResult<bool>.failure(
        message: 'Unable to validate shade/product compatibility.',
      );
    }
  }

  /// Converts a `#RRGGBB` hex string to HSL, or null if [hex] is
  /// missing/malformed.
  _Hsl? _hexToHsl(String? hex) {
    if (hex == null) {
      return null;
    }
    final String cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) {
      return null;
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return null;
    }

    final double r = ((value >> 16) & 0xFF) / 255.0;
    final double g = ((value >> 8) & 0xFF) / 255.0;
    final double b = (value & 0xFF) / 255.0;

    final double maxC = math.max(r, math.max(g, b));
    final double minC = math.min(r, math.min(g, b));
    final double lightness = (maxC + minC) / 2;
    final double delta = maxC - minC;

    if (delta == 0) {
      return _Hsl(hue: 0, saturation: 0, lightness: lightness);
    }

    final double saturation = lightness > 0.5
        ? delta / (2 - maxC - minC)
        : delta / (maxC + minC);

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

    return _Hsl(hue: hue, saturation: saturation, lightness: lightness);
  }
}

/// Internal HSL representation used only by [ShadeEngine]'s colour
/// math. Hue in degrees (0-360); saturation/lightness in 0.0-1.0.
class _Hsl {
  const _Hsl({
    required this.hue,
    required this.saturation,
    required this.lightness,
  });

  final double hue;
  final double saturation;
  final double lightness;
}
