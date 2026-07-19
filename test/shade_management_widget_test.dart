/// Purpose      : Widget tests for ShadeManagementScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/shade_management_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                real-database-plus-real-repositories harness this
///                relies on.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/models/shade_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/repositories/shade_repository.dart';
import 'package:hue_muse_shade_ai/screens/shade_management_screen.dart';

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

  testWidgets('shows the empty state when no shades exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ShadeManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No shades found. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('lists a shade created through the repository', (
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
    await ServiceLocator.instance.get<ShadeRepository>().create(
          ShadeModel(
            name: 'Ruby Red',
            shadeCode: 'SH-001',
            productId: product.id,
          ),
        );

    await tester.pumpWidget(_wrap(const ShadeManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ruby Red'), findsOneWidget);
    expect(find.textContaining('SH-001'), findsOneWidget);
  });

  testWidgets('Active/Inactive filter chips render for all three states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ShadeManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Active'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Inactive'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
  });
}
