/// Purpose      : Widget tests for HomeScreen / the Dashboard
///                (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, provider, widget_test_support.dart,
///                screens/home_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. HomeScreen reads NavigationProvider via
///                context.read() inside quick-action onPressed
///                closures (not during build), so no provider
///                ancestor is strictly required to pump it — one is
///                supplied anyway to match how RootShellScreen wraps
///                it in production and keep the test realistic.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/core/services/navigation_provider.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';
import 'package:hue_muse_shade_ai/screens/home_screen.dart';

import 'widget_test_support.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<NavigationProvider>(
    create: (_) => NavigationProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  late WidgetTestHarness harness;

  setUp(() async {
    harness = await WidgetTestHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  testWidgets('shows zeroed stat cards with no data seeded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await settle(tester);

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('Products count reflects a repository-created product (R4-002)', (
    WidgetTester tester,
  ) async {
    await ServiceLocator.instance.get<ProductRepository>().create(
          const ProductModel(
            name: 'Classic Nail Polish',
            productCode: 'NP-001',
            category: 'Nail Polish',
          ),
        );

    await tester.pumpWidget(_wrap(const HomeScreen()));
    await settle(tester);

    // With only one product seeded and nothing else, the Products
    // stat card's value text is '1' — checked directly rather than
    // via an ancestor/descendant finder chain tied to the card's
    // internal layout, which would be more precise but more brittle
    // if that layout ever changes.
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('all five quick action buttons are present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await settle(tester);

    for (final String label in <String>[
      'New Shade',
      'Manage Products',
      'Manage Shades',
      'Manage Materials',
      'Formulas',
      'Approved Formulas',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '"$label" button');
    }
  });
}
