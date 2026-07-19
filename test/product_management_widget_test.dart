/// Purpose      : Widget tests for ProductManagementScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/product_management_screen.dart
/// Description  : Uses WidgetTestHarness (see widget_test_support.dart
///                for why a real in-memory database + real
///                repositories, not mocks) to exercise the screen
///                exactly as ServiceLocator wires it in production.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/screens/product_management_screen.dart';

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

  testWidgets('shows the empty state when no products exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No products exist yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('lists a product created through the repository', (
    WidgetTester tester,
  ) async {
    final ProductRepository repository = ServiceLocator.instance
        .get<ProductRepository>();
    await repository.create(
      const ProductModel(
        name: 'Classic Nail Polish',
        productCode: 'NP-001',
        category: 'Nail Polish',
      ),
    );

    await tester.pumpWidget(_wrap(const ProductManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Classic Nail Polish'), findsOneWidget);
    expect(find.textContaining('NP-001'), findsOneWidget);
  });

  testWidgets('Add Product form validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductManagementScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Submitting with empty required fields should surface validation
    // errors rather than close the sheet or crash. 'Add Product' text
    // appears twice (the sheet's title and its submit button) — the
    // submit button is the later one in the tree.
    await tester.tap(find.text('Add Product').last);
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);
  });
}
