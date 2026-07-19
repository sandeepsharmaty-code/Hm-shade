/// Purpose      : The six lab-workflow statuses a Trial_Formula can
///                be in, and which transitions between them are
///                allowed.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : none (pure Dart)
/// Description  : Trial_Formula.status has always been a plain TEXT
///                column with no CHECK constraint (see
///                database_helper.dart), so introducing this richer
///                vocabulary needs no schema change — only this
///                sprint's code now writes these six specific values
///                instead of the informal draft/in_review/approved/
///                rejected set used loosely since SPR-DEP-003.
/// Change History:
///   1.0.0 - SPR-DEP-007 - Initial creation.
library;

/// The six statuses this sprint's Lab Workflow requires.
enum TrialStatus {
  draft,
  readyForLab,
  labTesting,
  approved,
  rejected,
  archived;

  /// The value stored in `Trial_Formula.status`.
  String get storageKey => switch (this) {
        TrialStatus.draft => 'draft',
        TrialStatus.readyForLab => 'ready_for_lab',
        TrialStatus.labTesting => 'lab_testing',
        TrialStatus.approved => 'approved',
        TrialStatus.rejected => 'rejected',
        TrialStatus.archived => 'archived',
      };

  /// Human-readable label, e.g. "Ready for Lab".
  String get label => switch (this) {
        TrialStatus.draft => 'Draft',
        TrialStatus.readyForLab => 'Ready for Lab',
        TrialStatus.labTesting => 'Lab Testing',
        TrialStatus.approved => 'Approved',
        TrialStatus.rejected => 'Rejected',
        TrialStatus.archived => 'Archived',
      };

  static TrialStatus? fromStorageKey(String? value) {
    for (final TrialStatus status in TrialStatus.values) {
      if (status.storageKey == value) {
        return status;
      }
    }
    return null;
  }

  /// Allowed forward/lateral transitions from each status. Rejected
  /// and Archived are terminal except that a Rejected trial can be
  /// sent back to Draft for rework, and any non-Archived status can
  /// be Archived directly (a simple "shelve this" escape hatch).
  static const Map<TrialStatus, List<TrialStatus>> _allowedTransitions =
      <TrialStatus, List<TrialStatus>>{
    TrialStatus.draft: <TrialStatus>[
      TrialStatus.readyForLab,
      TrialStatus.archived,
    ],
    TrialStatus.readyForLab: <TrialStatus>[
      TrialStatus.labTesting,
      TrialStatus.draft,
      TrialStatus.archived,
    ],
    TrialStatus.labTesting: <TrialStatus>[
      TrialStatus.approved,
      TrialStatus.rejected,
      TrialStatus.archived,
    ],
    TrialStatus.approved: <TrialStatus>[
      TrialStatus.archived,
    ],
    TrialStatus.rejected: <TrialStatus>[
      TrialStatus.draft,
      TrialStatus.archived,
    ],
    TrialStatus.archived: <TrialStatus>[],
  };

  /// Returns true if moving from this status to [next] is allowed.
  bool canTransitionTo(TrialStatus next) {
    return _allowedTransitions[this]?.contains(next) ?? false;
  }

  List<TrialStatus> get allowedNextStatuses =>
      List<TrialStatus>.unmodifiable(_allowedTransitions[this] ?? const []);
}
