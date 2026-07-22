/// Purpose      : Widget tests for FormulaDetailsScreen, including
///                the R3 Approved Formula workflow (R6-003).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widget_test_support.dart,
///                screens/formula_details_screen.dart
/// Description  : See widget_test_support.dart for the shared
///                harness. Covers R2's base details view and R3's
///                Approve action end-to-end against a real (in-
///                memory) TrialRepository.approveTrial() call.
/// Change History:
///   1.0.0 - Repair Sprint R6 (Production Readiness & QA) - Initial
///           creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/core/di/service_locator.dart';
import 'package:hue_muse_shade_ai/models/trial_formula_model.dart';
import 'package:hue_muse_shade_ai/models/trial_status.dart';
import 'package:hue_muse_shade_ai/repositories/trial_repository.dart';
import 'package:hue_muse_shade_ai/screens/formula_details_screen.dart';

import 'widget_test_support.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late WidgetTestHarness harness;
  late TrialRepository trialRepository;

  setUp(() async {
    harness = await WidgetTestHarness.open();
    trialRepository = ServiceLocator.instance.get<TrialRepository>();
  });

  tearDown(() async {
    await harness.close();
  });

  testWidgets('shows a not-found message for a missing trial', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FormulaDetailsScreen(
          args: FormulaDetailsScreenArgs(trialFormulaId: 999),
        ),
      ),
    );
    await settle(tester);

    expect(find.textContaining('could not be found'), findsOneWidget);
  });

  testWidgets('displays name, trial code, and status for an existing trial', (
    WidgetTester tester,
  ) async {
    final TrialFormulaModel trial = await trialRepository.create(
      const TrialFormulaModel(name: 'Ruby Trial 1', trialCode: 'TRL-0001'),
    );

    await tester.pumpWidget(
      _wrap(
        FormulaDetailsScreen(
          args: FormulaDetailsScreenArgs(trialFormulaId: trial.id!),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Ruby Trial 1'), findsOneWidget);
    expect(find.text('TRL-0001'), findsOneWidget);
    expect(find.text(TrialStatus.draft.label), findsOneWidget);
  });

  testWidgets(
    'Approve creates an approval record and locks the formula (R3-004/007)',
    (WidgetTester tester) async {
      final TrialFormulaModel trial = await trialRepository.create(
        const TrialFormulaModel(
          name: 'Ruby Trial 1',
          trialCode: 'TRL-0001',
          status: 'lab_testing',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FormulaDetailsScreen(
            args: FormulaDetailsScreenArgs(trialFormulaId: trial.id!),
          ),
        ),
      );
      await settle(tester);

      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Approve'),
        200,
      );
      await settle(tester);

      expect(find.widgetWithText(ElevatedButton, 'Approve'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await settle(tester);

      // The Approve sheet requires "Approved By".
      await tester.enterText(find.byType(TextFormField).first, 'QA Lead');
      await tester.tap(find.text('Approve').last);
      await settle(tester);

      // Locked: Edit is replaced by Create Revision, Delete disappears.
      expect(find.text('Create Revision'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
      expect(find.textContaining('Approved and read-only'), findsOneWidget);

      final TrialFormulaModel? reloaded = await trialRepository.readById(
        trial.id!,
      );
      expect(reloaded?.status, TrialStatus.approved.storageKey);
    },
  );
}
