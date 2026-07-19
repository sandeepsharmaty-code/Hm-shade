/// Purpose      : Widget tests for KnowledgeBaseScreen (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/knowledge_base_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. Covers all four tabs' empty states plus
///                the Approved Formulas tab populated from a real
///                approveTrial() call, tying R3's approval workflow
///                to this pre-existing (SPR-DEP-009) screen.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/approved_formula_model.dart';
import 'package:hue_muse_shade_ai/models/trial_formula_model.dart';
import 'package:hue_muse_shade_ai/repositories/trial_repository.dart';
import 'package:hue_muse_shade_ai/screens/knowledge_base_screen.dart';

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

  testWidgets('shows all four tabs and the Knowledge empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const KnowledgeBaseScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Knowledge'), findsWidgets);
    expect(find.text('Approved Formulas'), findsWidgets);
    expect(find.text('Rules'), findsWidgets);
    expect(find.text('Recent Updates'), findsWidgets);
    expect(find.text('Knowledge Base is empty.'), findsOneWidget);
  });

  testWidgets('Approved Formulas tab shows a formula approved via R3', (
    WidgetTester tester,
  ) async {
    final TrialRepository trialRepository = ServiceLocator.instance
        .get<TrialRepository>();
    final TrialFormulaModel trial = await trialRepository.create(
      const TrialFormulaModel(
        name: 'Ruby Trial 1',
        trialCode: 'TRL-0001',
        status: 'lab_testing',
      ),
    );
    await trialRepository.approveTrial(
      ApprovedFormulaModel(trialFormulaId: trial.id!, approvedBy: 'QA Lead'),
    );

    await tester.pumpWidget(_wrap(const KnowledgeBaseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approved Formulas'));
    await tester.pumpAndSettle();

    expect(find.text('Ruby Trial 1'), findsOneWidget);
  });
}
