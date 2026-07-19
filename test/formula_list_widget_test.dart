/// Purpose      : Widget tests for FormulaListScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/formula_list_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. Covers grouping-by-product (R2-002) and
///                the status filter added in R3-002.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/models/trial_formula_model.dart';
import 'package:hue_muse_shade_ai/models/trial_status.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/repositories/trial_repository.dart';
import 'package:hue_muse_shade_ai/screens/formula_list_screen.dart';

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

  testWidgets('shows the empty state when no formulas exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const FormulaListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No formulas exist yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('lists a formula grouped under its product', (
    WidgetTester tester,
  ) async {
    final ProductModel product = await ServiceLocator.instance
        .get<ProductRepository>()
        .create(
          const ProductModel(
            name: 'Classic Nail Polish',
            productCode: 'NP-001',
            category: 'Nail Polish',
          ),
        );
    await ServiceLocator.instance.get<TrialRepository>().create(
          TrialFormulaModel(
            name: 'Ruby Trial 1',
            trialCode: 'TRL-0001',
            productId: product.id,
          ),
        );

    await tester.pumpWidget(_wrap(const FormulaListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Classic Nail Polish'), findsOneWidget);
    expect(find.text('Ruby Trial 1'), findsOneWidget);
  });

  testWidgets('status filter narrows results to the selected status', (
    WidgetTester tester,
  ) async {
    final TrialRepository trialRepository = ServiceLocator.instance
        .get<TrialRepository>();
    await trialRepository.create(
      const TrialFormulaModel(name: 'Draft Trial', trialCode: 'TRL-0001'),
    );

    await tester.pumpWidget(_wrap(const FormulaListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Draft Trial'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, TrialStatus.approved.label));
    await tester.pumpAndSettle();

    expect(find.text('Draft Trial'), findsNothing);
  });
}
