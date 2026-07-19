/// Purpose      : Widget tests for SearchScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/search_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. Covers the Products category end-to-end
///                and confirms category switching works; the other
///                four categories (Shades, Materials, Formulas,
///                Knowledge) share the exact same code path per
///                search_screen.dart's own _search() switch, so this
///                is not re-tested five times over.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/screens/search_screen.dart';

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

  testWidgets('shows the "search this category" prompt before typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const SearchScreen()));
    await settle(tester);

    expect(find.text('Search Shades'), findsOneWidget);
  });

  testWidgets('finds a product by name after switching to Products', (
    WidgetTester tester,
  ) async {
    await ServiceLocator.instance.get<ProductRepository>().create(
          const ProductModel(
            name: 'Classic Nail Polish',
            productCode: 'NP-001',
            category: 'Nail Polish',
          ),
        );

    await tester.pumpWidget(_wrap(const SearchScreen()));
    await settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Products'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Classic');
    await settle(tester);

    expect(find.text('Classic Nail Polish'), findsOneWidget);
  });

  testWidgets('shows "no results" for a query that matches nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const SearchScreen()));
    await settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Products'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'NoSuchThing');
    await settle(tester);

    expect(find.textContaining('No results for'), findsOneWidget);
  });
}
