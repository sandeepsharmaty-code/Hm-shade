/// Purpose      : Widget tests for MaterialManagementScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/material_management_screen.dart
/// Description  : See widget_test_support.dart for the shared harness.
///                Exercises the generic screen's per-table adapter
///                switching (R5-B), not just the default Pigment tab.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/pigment_model.dart';
import 'package:hue_muse_shade_ai/repositories/pigment_repository.dart';
import 'package:hue_muse_shade_ai/screens/material_management_screen.dart';

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

  testWidgets('shows the empty state for the default (Pigment) tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const MaterialManagementScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('No pigment records found. Tap + to add one.'),
      findsOneWidget,
    );
  });

  testWidgets('lists a pigment created through the repository', (
    WidgetTester tester,
  ) async {
    await ServiceLocator.instance.get<PigmentRepository>().create(
          const PigmentModel(name: 'Iron Oxide Red', materialCode: 'PIG-0001'),
        );

    await tester.pumpWidget(_wrap(const MaterialManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Iron Oxide Red'), findsOneWidget);
  });

  testWidgets('switching the Type chip changes which table is shown', (
    WidgetTester tester,
  ) async {
    await ServiceLocator.instance.get<PigmentRepository>().create(
          const PigmentModel(name: 'Iron Oxide Red', materialCode: 'PIG-0001'),
        );

    await tester.pumpWidget(_wrap(const MaterialManagementScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Iron Oxide Red'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Dye'));
    await tester.pumpAndSettle();

    expect(find.text('Iron Oxide Red'), findsNothing);
    expect(
      find.text('No dye records found. Tap + to add one.'),
      findsOneWidget,
    );
  });
}
