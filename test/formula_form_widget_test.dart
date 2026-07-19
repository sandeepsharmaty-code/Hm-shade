/// Purpose      : Widget tests for FormulaFormScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/formula_form_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. Covers Create (R2-004) with a real
///                Product/Shade/Material set already seeded, so the
///                dropdowns this screen depends on (R5-D) are
///                genuinely populated rather than asserted empty.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/screens/formula_form_screen.dart';

import 'widget_test_support.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late WidgetTestHarness harness;

  setUp(() async {
    harness = await WidgetTestHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  testWidgets('shows "Add Formula" title in plain create mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FormulaFormScreen(args: FormulaFormScreenArgs()),
      ),
    );
    await settle(tester);

    expect(find.text('Add Formula'), findsWidgets);
  });

  testWidgets('Product dropdown lists a product created beforehand (R5-D)', (
    WidgetTester tester,
  ) async {
    await ServiceLocator.instance.get<ProductRepository>().create(
          const ProductModel(
            name: 'Classic Nail Polish',
            productCode: 'NP-001',
            category: 'Nail Polish',
          ),
        );

    await tester.pumpWidget(
      _wrap(
        const FormulaFormScreen(args: FormulaFormScreenArgs()),
      ),
    );
    await settle(tester);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Product'));
    await settle(tester);

    expect(find.text('Classic Nail Polish'), findsOneWidget);
  });

  testWidgets('validates required fields before saving', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FormulaFormScreen(args: FormulaFormScreenArgs()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Create Formula').last);
    await settle(tester);

    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Trial code is required.'), findsOneWidget);
  });
}
