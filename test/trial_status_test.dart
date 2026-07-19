/// Purpose      : Unit tests for TrialStatus's allowed-transition
///                graph.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, models/trial_status.dart
/// Description  : Pure logic — no repository or database involved.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hue_muse_shade_ai/models/trial_status.dart';

void main() {
  group('TrialStatus.canTransitionTo', () {
    test('draft can move to ready_for_lab', () {
      expect(
        TrialStatus.draft.canTransitionTo(TrialStatus.readyForLab),
        isTrue,
      );
    });

    test('draft cannot jump straight to approved', () {
      expect(
        TrialStatus.draft.canTransitionTo(TrialStatus.approved),
        isFalse,
      );
    });

    test('lab_testing can move to approved or rejected', () {
      expect(
        TrialStatus.labTesting.canTransitionTo(TrialStatus.approved),
        isTrue,
      );
      expect(
        TrialStatus.labTesting.canTransitionTo(TrialStatus.rejected),
        isTrue,
      );
    });

    test('rejected can return to draft for rework', () {
      expect(
        TrialStatus.rejected.canTransitionTo(TrialStatus.draft),
        isTrue,
      );
    });

    test('archived is terminal', () {
      expect(TrialStatus.archived.allowedNextStatuses, isEmpty);
    });

    test('any non-archived status can be archived', () {
      for (final status in TrialStatus.values) {
        if (status == TrialStatus.archived) {
          continue;
        }
        expect(status.canTransitionTo(TrialStatus.archived), isTrue);
      }
    });
  });

  group('TrialStatus.fromStorageKey', () {
    test('round-trips every status through storageKey', () {
      for (final status in TrialStatus.values) {
        expect(TrialStatus.fromStorageKey(status.storageKey), status);
      }
    });

    test('returns null for an unrecognized key', () {
      expect(TrialStatus.fromStorageKey('not_a_real_status'), isNull);
    });
  });
}
