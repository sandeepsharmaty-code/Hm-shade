/// Purpose      : Widget test for TrialStatusChip — the first widget
///                test in this project (flagged as a gap since
///                SPR-DEP-009; addressed here as part of this
///                sprint's QA focus).
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, widgets/trial_status_chip.dart,
///                models/trial_status.dart
/// Description  : TrialStatusChip needs no ServiceLocator/repository
///                wiring (it's a pure presentation widget taking a
///                TrialStatus), so it's the safest starting point for
///                widget-test coverage — pumping a full screen would
///                require registering test doubles for the entire DI
///                graph, a larger undertaking flagged as a follow-up
///                in the SPR-DEP-010 report rather than attempted
///                here.
/// Change History:
///   1.0.0 - SPR-DEP-010 - Initial creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/models/trial_status.dart';
import 'package:hue_muse_shade_ai/widgets/trial_status_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  for (final TrialStatus status in TrialStatus.values) {
    testWidgets('renders the correct label for ${status.name}', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(TrialStatusChip(status: status)));

      expect(find.text(status.label), findsOneWidget);
    });
  }

  testWidgets('renders inside a Container with rounded corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const TrialStatusChip(status: TrialStatus.readyForLab)),
    );

    final Container container = tester.widget<Container>(
      find.byType(Container),
    );
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, isNotNull);
  });
}
