/// Purpose      : Formula Details screen — full read view of one
///                Trial_Formula, its ingredients, its workflow state,
///                and (R3) its approval record and lock behavior.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/product_repository.dart,
///                repositories/shade_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/trial_audit_repository.dart,
///                repositories/repository_exception.dart,
///                engines/trial_workflow_manager.dart,
///                engines/material_matching_engine.dart,
///                models/*, widgets/*
/// Description  : Pushed route (see AppRoutes.formulaDetails),
///                requires a `trialFormulaId` argument. Displays
///                Product, Shade, Formula Name, Ingredients +
///                Percentages, Notes, Status, a Version/Revision
///                History section (see the note on that section below
///                for why it isn't a bare version number), and — R3 —
///                an Approval section (Approval Date, Approved By,
///                Approval Notes) whenever an ApprovedFormulaModel
///                exists for this trial. Per-ingredient Rule
///                Compliance is shown by calling the existing
///                IMaterialMatchingEngine.matchMaterial() for each
///                line (R2-009). Status changes go through the
///                existing ITrialWorkflowManager.transition() — the
///                Formula workflow never writes `status` directly.
///
///                R3 approval workflow — where each brief item lives:
///                - Approve (R3-004): calls the existing
///                  TrialRepository.approveTrial() directly, which
///                  already inserts the Approved_Formula row AND
///                  moves Trial_Formula.status to 'approved' in one
///                  transaction. Because approveTrial() already does
///                  the status change itself, this screen's generic
///                  "Change Status" picker no longer offers `approved`
///                  as a destination — offering both would be two
///                  divergent paths to the same state, one of which
///                  (the generic picker) would silently skip creating
///                  the approval record. Same reasoning for `rejected`
///                  (see next point) — genericNext() below is the
///                  single place this exclusion is applied.
///                - Reject (R3-005): fully supported by the existing
///                  TrialStatus graph (labTesting -> rejected) and
///                  ITrialWorkflowManager.transition() already — no
///                  engine change needed. Given its own dedicated
///                  button (rather than the generic picker) purely so
///                  a reason can be required and captured every time.
///                - Revision Request (R3-006): also fully supported
///                  by the existing graph (rejected -> draft, "for
///                  rework" per TrialStatus's own doc comment).
///                  Reviewer remarks are stored via transition()'s
///                  existing `reason` parameter, which
///                  ITrialWorkflowManager already writes into
///                  TrialAuditRepository — no new data structure.
///                - Lock (R3-007): when an active approval exists,
///                  "Edit" is replaced with "Create Revision" and
///                  "Delete" is hidden. Archive remains available
///                  (approved -> archived is an existing, legitimate
///                  lifecycle end state, not an edit).
///                - Revision Workflow (R3-008): "Create Revision"
///                  pushes FormulaFormScreen in duplicate-from mode
///                  (see that file's R3 notes) — a brand new
///                  Trial_Formula row via the existing create(), never
///                  touching the approved row's data. Revision lineage
///                  ("Revision of <code>") is stored as a plain
///                  sentence in the new row's `notes` field, the only
///                  free-text field available without a schema change,
///                  and is parsed back out for display here. This is
///                  a best-effort convention, not a real foreign key —
///                  see the "Revision Of" row's note below and the R3
///                  report's Known Issues for the honest limitation
///                  (no reverse "Superseded By" lookup is attempted;
///                  that would need either a schema column or an
///                  extra full-table search per row, and is left as a
///                  documented option for R4 rather than implemented
///                  here).
/// Change History:
///   1.0.0 - Repair Sprint R2 (Formula Workflow) - Initial creation.
///   2.0.0 - Repair Sprint R3 (Approved Formula Workflow) - Added the
///           Approval section, Approve/Reject/Request Revision/Create
///           Revision actions, and the approved-formula lock
///           (Edit -> Create Revision, Delete hidden). See the
///           R3 notes above for how each maps onto existing,
///           unmodified TrialRepository/ITrialWorkflowManager APIs.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../engines/engine_result.dart';
import '../engines/material_matching_engine.dart';
import '../engines/trial_workflow_manager.dart';
import '../models/approved_formula_model.dart';
import '../models/formula_material_model.dart';
import '../models/product_model.dart';
import '../models/shade_model.dart';
import '../models/trial_audit_entry_model.dart';
import '../models/trial_formula_model.dart';
import '../models/trial_status.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_audit_repository.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/trial_status_chip.dart';
import 'formula_form_screen.dart';

/// Arguments for [AppRoutes.formulaDetails].
class FormulaDetailsScreenArgs {
  const FormulaDetailsScreenArgs({required this.trialFormulaId});
  final int trialFormulaId;
}

/// Statuses the generic "Change Status" picker offers — everything
/// [current] allows next, minus `approved`/`rejected` (which now have
/// dedicated, reason-collecting actions — Approve/Reject) and
/// `archived` (which has its own always-available Archive button).
/// Centralized here so _changeStatus() and the button's visibility
/// check can never disagree about what's "generic".
List<TrialStatus> _genericNextStatuses(TrialStatus current) {
  return current.allowedNextStatuses
      .where(
        (TrialStatus s) =>
            s != TrialStatus.approved &&
            s != TrialStatus.rejected &&
            s != TrialStatus.archived,
      )
      .toList();
}

/// Best-effort parse of a "Revision of <CODE>" marker that
/// FormulaFormScreen's duplicate-from mode writes into a new
/// revision's `notes`. Not a foreign key — just a documented text
/// convention, since Trial_Formula has no lineage column and the
/// schema is frozen.
String? _extractRevisionOfCode(String? notes) {
  if (notes == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'Revision of ([A-Za-z0-9\-]+)',
  ).firstMatch(notes);
  return match?.group(1);
}

/// One ingredient line paired with its rule-compliance outcome
/// (R2-009: consumes IMaterialMatchingEngine's existing result, never
/// recomputed here).
class _IngredientRow {
  const _IngredientRow({required this.line, this.match});
  final FormulaMaterialModel line;
  final MaterialMatchResult? match;
}

/// Everything the screen needs, loaded once per open/refresh.
class _FormulaDetails {
  const _FormulaDetails({
    required this.trial,
    required this.ingredients,
    required this.history,
    this.product,
    this.shade,
    this.approval,
    this.revisionOfCode,
  });

  final TrialFormulaModel trial;
  final ProductModel? product;
  final ShadeModel? shade;
  final List<_IngredientRow> ingredients;
  final List<TrialAuditEntryModel> history;

  /// Non-null exactly when this trial has an active Approved_Formula
  /// record (R3-004/R3-007: presence of this drives the read-only
  /// lock).
  final ApprovedFormulaModel? approval;

  /// Parsed from `trial.notes` — see [_extractRevisionOfCode].
  final String? revisionOfCode;
}

const Map<String, String> _kMaterialTableLabels = <String, String>{
  'Pigment_Master': 'Pigment',
  'Dye_Master': 'Dye',
  'Mica_Master': 'Mica',
  'Pearl_Master': 'Pearl',
  'Filler_Master': 'Filler',
  'Binder_Master': 'Binder',
};

/// Formula Details screen: full read view plus workflow actions.
class FormulaDetailsScreen extends StatefulWidget {
  const FormulaDetailsScreen({required this.args, super.key});

  final FormulaDetailsScreenArgs args;

  @override
  State<FormulaDetailsScreen> createState() => _FormulaDetailsScreenState();
}

class _FormulaDetailsScreenState extends State<FormulaDetailsScreen> {
  late final TrialRepository _trialRepository;
  late final ProductRepository _productRepository;
  late final ShadeRepository _shadeRepository;
  late final TrialAuditRepository _auditRepository;
  late final IMaterialMatchingEngine _materialMatchingEngine;
  late final ITrialWorkflowManager _workflowManager;

  late Future<_FormulaDetails?> _detailsFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _trialRepository = ServiceLocator.instance.get<TrialRepository>();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _shadeRepository = ServiceLocator.instance.get<ShadeRepository>();
    _auditRepository = ServiceLocator.instance.get<TrialAuditRepository>();
    _materialMatchingEngine =
        ServiceLocator.instance.get<IMaterialMatchingEngine>();
    _workflowManager = ServiceLocator.instance.get<ITrialWorkflowManager>();
    _detailsFuture = _loadDetails();
  }

  Future<_FormulaDetails?> _loadDetails() async {
    try {
      final TrialFormulaModel? trial = await _trialRepository.readById(
        widget.args.trialFormulaId,
        includeInactive: true,
      );
      if (trial == null) {
        return null;
      }

      final List<Object?> results = await Future.wait<Object?>(<
          Future<Object?>>[
        trial.productId == null
            ? Future<ProductModel?>.value()
            : _productRepository.readById(trial.productId!),
        trial.shadeId == null
            ? Future<ShadeModel?>.value()
            : _shadeRepository.readById(trial.shadeId!),
        _trialRepository.materialsForTrial(widget.args.trialFormulaId),
        _auditRepository.historyForTrial(widget.args.trialFormulaId),
        _trialRepository.approvalForTrial(widget.args.trialFormulaId),
      ]);

      final ProductModel? product = results[0] as ProductModel?;
      final ShadeModel? shade = results[1] as ShadeModel?;
      final List<FormulaMaterialModel> lines =
          results[2]! as List<FormulaMaterialModel>;
      final List<TrialAuditEntryModel> history =
          results[3]! as List<TrialAuditEntryModel>;
      final ApprovedFormulaModel? approval =
          results[4] as ApprovedFormulaModel?;

      final List<_IngredientRow> ingredients = await Future.wait<
          _IngredientRow>(
        <Future<_IngredientRow>>[
          for (final FormulaMaterialModel line in lines)
            _materialMatchingEngine
                .matchMaterial(
                  materialTable: line.materialTable,
                  materialId: line.materialId,
                )
                .then(
                  (EngineResult<MaterialMatchResult> result) =>
                      _IngredientRow(line: line, match: result.data),
                ),
        ],
      );

      return _FormulaDetails(
        trial: trial,
        product: product,
        shade: shade,
        ingredients: ingredients,
        history: history,
        approval: approval,
        revisionOfCode: _extractRevisionOfCode(trial.notes),
      );
    } on RepositoryException {
      return null;
    }
  }
void _refresh() {
    setState(() {
      _detailsFuture = _loadDetails();
    });
  }

  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit(TrialFormulaModel trial) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaEdit,
      arguments: FormulaFormScreenArgs(existingTrialFormulaId: trial.id),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _changeStatus(TrialFormulaModel trial) async {
    final TrialStatus current =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    final List<TrialStatus> next = _genericNextStatuses(current);
    if (next.isEmpty) {
      _showMessage('No other status changes are available right now.');
      return;
    }

    final TrialStatus? chosen = await showModalBottomSheet<TrialStatus>(
      context: context,
      builder: (_) => _StatusPickerSheet(options: next),
    );
    if (chosen == null || !mounted) {
      return;
    }

    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Move to ${chosen.label}?',
      message: 'This records a status change from ${current.label} to '
          '${chosen.label} in the formula\'s audit history.',
      confirmLabel: 'Confirm',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runTransition(trial, chosen);
  }

  Future<void> _archive(TrialFormulaModel trial) async {
    final TrialStatus current =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    if (!current.canTransitionTo(TrialStatus.archived)) {
      _showMessage('${current.label} formulas cannot be archived directly.');
      return;
    }
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Archive Formula?',
      message: 'Archiving records a final status change and cannot be '
          'undone through the app — the formula stays on record but '
          'moves out of the active workflow. To hide it entirely '
          'instead, use Delete.',
      confirmLabel: 'Archive',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runTransition(
      trial,
      TrialStatus.archived,
      reason: 'Archived from Formula Details.',
    );
  }

  /// R3-004: Approve. Calls the existing TrialRepository.approveTrial()
  /// directly — that single call both inserts the Approved_Formula
  /// row and moves Trial_Formula.status to 'approved' in one
  /// transaction (see approveTrial()'s own doc comment). Never
  /// insert into Approved_Formula manually, and never additionally
  /// call ITrialWorkflowManager.transition(to: approved) for this —
  /// that would either no-op or duplicate the status write that
  /// approveTrial() already did atomically.
  Future<void> _approve(TrialFormulaModel trial) async {
    final int? id = trial.id;
    final TrialStatus current =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    if (id == null || !current.canTransitionTo(TrialStatus.approved)) {
      _showMessage('${current.label} formulas cannot be approved directly.');
      return;
    }

    final List<String>? input = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TextInputSheet(
        title: 'Approve Formula',
        confirmLabel: 'Approve',
        fields: <_TextInputFieldSpec>[
          _TextInputFieldSpec(label: 'Approved By', required: true),
          _TextInputFieldSpec(
            label: 'Approval Notes (optional)',
            maxLines: 3,
          ),
        ],
      ),
    );
    if (input == null || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _trialRepository.approveTrial(
        ApprovedFormulaModel(
          trialFormulaId: id,
          approvedBy: input[0],
          approvalNotes: input[1].isEmpty ? null : input[1],
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _showMessage('Formula approved.');
      _refresh();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      await ErrorDialog.show(context, message: error.message);
    }
  }

  /// R3-005: Reject. Fully supported by the existing TrialStatus
  /// graph (labTesting -> rejected) — reuses
  /// ITrialWorkflowManager.transition() exactly like Archive already
  /// does, just with a required reason collected up front so it's
  /// never optional for a rejection.
  Future<void> _reject(TrialFormulaModel trial) async {
    final TrialStatus current =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    if (!current.canTransitionTo(TrialStatus.rejected)) {
      _showMessage('${current.label} formulas cannot be rejected directly.');
      return;
    }
    final List<String>? input = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TextInputSheet(
        title: 'Reject Formula',
        confirmLabel: 'Reject',
        fields: <_TextInputFieldSpec>[
          _TextInputFieldSpec(label: 'Reason', required: true, maxLines: 3),
        ],
      ),
    );
    if (input == null || !mounted) {
      return;
    }
    await _runTransition(trial, TrialStatus.rejected, reason: input[0]);
  }

  /// R3-006: Revision Request. A rejected formula being "returned"
  /// for rework is the existing rejected -> draft transition (see
  /// TrialStatus's own doc comment: "Rejected trial can be sent back
  /// to Draft for rework"). The reviewer's remarks are stored via
  /// transition()'s existing `reason` parameter — already written
  /// into TrialAuditRepository, no new field or table.
  Future<void> _requestRevision(TrialFormulaModel trial) async {
    final TrialStatus current =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    if (current != TrialStatus.rejected) {
      return;
    }
    final List<String>? input = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TextInputSheet(
        title: 'Request Revision',
        confirmLabel: 'Send Back for Revision',
        fields: <_TextInputFieldSpec>[
          _TextInputFieldSpec(
            label: 'Revision Notes',
            required: true,
            maxLines: 3,
          ),
        ],
      ),
    );
    if (input == null || !mounted) {
      return;
    }
    await _runTransition(trial, TrialStatus.draft, reason: input[0]);
  }

  /// R3-007/R3-008: Create Revision. Approved formulas are locked —
  /// this pushes FormulaFormScreen in "duplicate from" mode, which
  /// builds a brand-new Trial_Formula (and fresh Formula_Material
  /// rows) via the existing create()/addMaterialLine(). The approved
  /// row this was opened from is never read-modified here.
  Future<void> _createRevision(TrialFormulaModel trial) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaEdit,
      arguments: FormulaFormScreenArgs(duplicateFromTrialFormulaId: trial.id),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _runTransition(
    TrialFormulaModel trial,
    TrialStatus to, {
    String? reason,
  }) async {
    setState(() => _isBusy = true);
    final EngineResult<TrialFormulaModel> result =
        await _workflowManager.transition(
      trialFormulaId: widget.args.trialFormulaId,
      to: to,
      reason: reason,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      _showMessage(
        result.messages.isNotEmpty ? result.messages.first : 'Updated.',
      );
      _refresh();
    } else {
      await ErrorDialog.show(
        context,
        message: result.messages.isNotEmpty
            ? result.messages.first
            : 'Unable to update this formula\'s status.',
      );
    }
  }

  Future<void> _delete(TrialFormulaModel trial) async {
    final int? id = trial.id;
    if (id == null) {
      return;
    }
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Formula?',
      message: 'This hides "${trial.name}" from formula lists. Its '
          'ingredient lines and audit history are kept, matching how '
          'Delete works for Products.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _trialRepository.softDelete(id);
      if (!mounted) {
        return;
      }
      _showMessage('Formula deleted.');
      Navigator.of(context).pop();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(context, message: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formula Details')),
      body: FutureBuilder<_FormulaDetails?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          final _FormulaDetails? details = snapshot.data;
          if (details == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This formula could not be found. It may have been '
                  'deleted.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_isBusy) {
            return const LoadingView(message: 'Updating…');
          }
          return _FormulaDetailsBody(
            details: details,
            onEdit: () => _openEdit(details.trial),
            onChangeStatus: () => _changeStatus(details.trial),
            onArchive: () => _archive(details.trial),
            onDelete: () => _delete(details.trial),
            onApprove: () => _approve(details.trial),
            onReject: () => _reject(details.trial),
            onRequestRevision: () => _requestRevision(details.trial),
            onCreateRevision: () => _createRevision(details.trial),
          );
        },
      ),
    );
  }
}

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({required this.options});
  final List<TrialStatus> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Move to…'),
          ),
          for (final TrialStatus status in options)
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: Text(status.label),
              onTap: () => Navigator.of(context).pop(status),
            ),
        ],
      ),
    );
  }
}

/// One field definition for [_TextInputSheet].
class _TextInputFieldSpec {
  const _TextInputFieldSpec({
    required this.label,
    this.required = false,
    this.maxLines = 1,
  });

  final String label;
  final bool required;
  final int maxLines;
}

/// Reusable small form sheet collecting 1+ text fields and returning
/// their trimmed values (in order) via Navigator.pop, or null if
/// dismissed. Shared by Approve/Reject/Request Revision (R3-004/005/
/// 006) instead of three near-identical dialogs.
class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.fields,
    required this.confirmLabel,
  });

  final String title;
  final List<_TextInputFieldSpec> fields;
  final String confirmLabel;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <TextEditingController>[
      for (int i = 0; i < widget.fields.length; i++) TextEditingController(),
    ];
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmit() {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    Navigator.of(context).pop(<String>[
      for (final TextEditingController c in _controllers) c.text.trim(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                for (int i = 0; i < widget.fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppTextField(
                      label: widget.fields[i].label,
                      controller: _controllers[i],
                      maxLines: widget.fields[i].maxLines,
                      validator: widget.fields[i].required
                          ? (value) => (value == null || value.trim().isEmpty)
                              ? '${widget.fields[i].label} is required.'
                              : null
                          : null,
                    ),
                  ),
                const SizedBox(height: 8),
                AppButton(
                  label: widget.confirmLabel,
                  expand: true,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormulaDetailsBody extends StatelessWidget {
  const _FormulaDetailsBody({
    required this.details,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onArchive,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
    required this.onRequestRevision,
    required this.onCreateRevision,
  });

  final _FormulaDetails details;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestRevision;
  final VoidCallback onCreateRevision;

  @override
  Widget build(BuildContext context) {
    final TrialFormulaModel trial = details.trial;
    final TrialStatus status =
        TrialStatus.fromStorageKey(trial.status) ?? TrialStatus.draft;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // R3-007: an active approval record locks the formula read-only.
    // Editing/Delete are replaced by Create Revision.
    final bool isLocked = details.approval != null;
    final bool canApprove = status.canTransitionTo(TrialStatus.approved);
    final bool canReject = status.canTransitionTo(TrialStatus.rejected);
    final bool canRequestRevision = status == TrialStatus.rejected;
    final bool canArchive = status.canTransitionTo(TrialStatus.archived);
    final bool showGenericChangeStatus =
        _genericNextStatuses(status).isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      trial.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TrialStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                trial.trialCode,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const Divider(height: 24),
              _DetailRow(
                label: 'Product',
                value: details.product?.name ?? 'No product linked',
              ),
              _DetailRow(
                label: 'Shade',
                value: details.shade?.name ?? 'No shade selected',
              ),
              if (details.revisionOfCode != null)
                _DetailRow(
                  label: 'Revision',
                  value: 'Revision of ${details.revisionOfCode}',
                ),
              if (isLocked)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Approved and read-only. Use Create Revision to '
                          'make changes.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (details.approval != null) ...<Widget>[
          const SizedBox(height: 16),
          Text('Approval', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DetailRow(
                  label: 'Approved On',
                  value: details.approval!.createdAt?.toString().split(
                        '.',
                      ).first ??
                      'Unknown',
                ),
                _DetailRow(
                  label: 'Approved By',
                  value: details.approval!.approvedBy ?? 'Not recorded',
                ),
                _DetailRow(
                  label: 'Approval Notes',
                  value: (details.approval!.approvalNotes?.trim().isEmpty ??
                          true)
                      ? 'None'
                      : details.approval!.approvalNotes!,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (details.ingredients.isEmpty)
          const AppCard(child: Text('No ingredients added yet.'))
        else
          for (final _IngredientRow row in details.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IngredientCard(row: row),
            ),
        const SizedBox(height: 16),
        Text('Notes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AppCard(
          child: Text(
            (trial.notes?.trim().isEmpty ?? true)
                ? 'No notes.'
                : trial.notes!,
          ),
        ),
        const SizedBox(height: 16),
        // "Version" (per the brief) has no dedicated integer column
        // anywhere in the frozen schema — not on Trial_Formula, not
        // on Approved_Formula. Rather than inventing one (which would
        // need a schema change), this surfaces the existing, real
        // audit trail (TrialAuditRepository.historyForTrial) as the
        // closest honest equivalent — same "closest honest proxy"
        // approach HomeScreen already uses for "Recent Analysis".
        Text(
          'Version / Revision History',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'No dedicated version number exists in the schema; this is '
          'the formula\'s recorded status-change history instead.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        if (details.history.isEmpty)
          const AppCard(child: Text('No status changes recorded yet.'))
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final TrialAuditEntryModel entry in details.history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${entry.statusFrom} → ${entry.statusTo}'
                      '${entry.reason != null ? ' — ${entry.reason}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (isLocked)
              AppButton(
                label: 'Create Revision',
                icon: Icons.content_copy,
                onPressed: onCreateRevision,
              )
            else
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            if (canApprove)
              AppButton(
                label: 'Approve',
                icon: Icons.check_circle_outline,
                onPressed: onApprove,
              ),
            if (canReject)
              AppButton(
                label: 'Reject',
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: onReject,
              ),
            if (canRequestRevision)
              AppButton(
                label: 'Request Revision',
                icon: Icons.undo,
                variant: AppButtonVariant.secondary,
                onPressed: onRequestRevision,
              ),
            if (showGenericChangeStatus)
              AppButton(
                label: 'Change Status',
                icon: Icons.swap_horiz,
                variant: AppButtonVariant.secondary,
                onPressed: onChangeStatus,
              ),
            if (canArchive)
              AppButton(
                label: 'Archive',
                icon: Icons.archive_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: onArchive,
              ),
            if (!isLocked)
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.secondary,
                onPressed: onDelete,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.row});
  final _IngredientRow row;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final FormulaMaterialModel line = row.line;
    final MaterialMatchResult? match = row.match;
    final String tableLabel =
        _kMaterialTableLabels[line.materialTable] ?? line.materialTable;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            match == null
                ? Icons.help_outline
                : match.isApproved
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
            color: match == null
                ? colorScheme.onSurfaceVariant
                : match.isApproved
                    ? colorScheme.primary
                    : colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.name?.trim().isNotEmpty == true
                      ? line.name!
                      : '$tableLabel #${line.materialId}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '$tableLabel · ${line.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (line.notes?.trim().isNotEmpty ?? false)
                  Text(
                    line.notes!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (match != null && match.reasons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      match.reasons.first,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
