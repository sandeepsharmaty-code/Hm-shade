/// Purpose      : Unit tests for ShadeEngine's pure detection
///                methods (detectShadeFamily, detectUndertone,
///                detectFinish).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, engines/shade_engine.dart,
///                models/shade_model.dart
/// Description  : Exercises the deterministic colour-math and
///                keyword rules directly — these three methods take
///                an already-loaded ShadeModel and touch no
///                repository, so no database setup is needed. The
///                repository-backed validateProductCompatibility()
///                is exercised separately (see Known Issues in the
///                SPR-DEP-004 report — full repository-backed engine
///                tests are a follow-up).
/// Change History:
///   1.0.0 - SPR-DEP-004 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/engines/engine_result.dart';
import 'package:hue_muse_shade_ai/engines/shade_engine.dart';
import 'package:hue_muse_shade_ai/models/shade_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/repositories/shade_repository.dart';

void main() {
  // detect* methods don't touch the database, but ShadeEngine's
  // constructor requires repositories — DatabaseHelper.instance is
  // never actually opened by these tests since detect* never calls
  // it.
  final ShadeEngine engine = ShadeEngine(
    shadeRepository: ShadeRepository(databaseHelper: DatabaseHelper.instance),
    productRepository: ProductRepository(
      databaseHelper: DatabaseHelper.instance,
    ),
  );

  group('detectShadeFamily', () {
    test('trusts an already-recorded shadeFamily', () {
      final EngineResult<String> result = engine.detectShadeFamily(
        const ShadeModel(
          name: 'Test',
          shadeCode: 'SH-1',
          shadeFamily: 'Nude',
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'Nude');
    });

    test('classifies a red hex colour as Red', () {
      final EngineResult<String> result = engine.detectShadeFamily(
        const ShadeModel(
          name: 'Test',
          shadeCode: 'SH-2',
          hexColor: '#D42B2B',
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'Red');
    });

    test('classifies a low-saturation colour as Neutral', () {
      final EngineResult<String> result = engine.detectShadeFamily(
        const ShadeModel(
          name: 'Test',
          shadeCode: 'SH-3',
          hexColor: '#888888',
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'Neutral');
    });

    test('fails when neither shadeFamily nor a valid hexColor exist', () {
      final EngineResult<String> result = engine.detectShadeFamily(
        const ShadeModel(name: 'Test', shadeCode: 'SH-4'),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('detectUndertone', () {
    test('classifies a warm red as Warm', () {
      final EngineResult<String> result = engine.detectUndertone(
        const ShadeModel(
          name: 'Test',
          shadeCode: 'SH-5',
          hexColor: '#D42B2B',
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'Warm');
    });

    test('classifies a blue as Cool', () {
      final EngineResult<String> result = engine.detectUndertone(
        const ShadeModel(
          name: 'Test',
          shadeCode: 'SH-6',
          hexColor: '#2B4FD4',
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'Cool');
    });
  });

  group('detectFinish', () {
    test('trusts an already-recorded finish', () {
      final EngineResult<String> result = engine.detectFinish(
        const ShadeModel(name: 'Test', shadeCode: 'SH-7', finish: 'Satin'),
      );
      expect(result.data, 'Satin');
    });

    test('detects Matte from the shade name', () {
      final EngineResult<String> result = engine.detectFinish(
        const ShadeModel(name: 'Ruby Matte Red', shadeCode: 'SH-8'),
      );
      expect(result.data, 'Matte');
    });

    test('defaults to Glossy with a warning when no keyword matches', () {
      final EngineResult<String> result = engine.detectFinish(
        const ShadeModel(name: 'Ruby Red', shadeCode: 'SH-9'),
      );
      expect(result.data, 'Glossy');
      expect(result.warnings, isNotEmpty);
    });
  });
}
