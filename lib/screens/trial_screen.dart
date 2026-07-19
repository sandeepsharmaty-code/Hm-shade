/// Purpose      : Trial screen — Top 5 recommendations, comparison,
///                validation, explanation, workflow status, and audit
///                history for one product/shade-family request.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                engines/trial_generator_engine.dart,
///                engines/trial_comparison_engine.dart,
///                engines/trial_validation_engine.dart,
///                engines/trial_explanation_engine.dart,
///                engines/trial_workflow_manager.dart,
///                engines/recommendation_engine.dart,
///                engines/formula_recommendation_engine.dart,
///                models/trial_status.dart,
///                models/trial_audit_entry_model.dart, widgets/*
/// Description  : Pushed route (see AppRoutes.trial), not a bottom
///                tab — the approved 5-tab shell (SPR-DEP-002) stays
///                exactly as frozen. Reached from NewShadeScreen's
///                workflow and HomeScreen's "Pending Lab Trials"
///                quick action. Calls engines directly through
///                ServiceLocator (Repository Layer only underneath —
///                this screen never touches SQLite or a repository
///                itself); all scoring/ranking/validation logic lives
///                in the engines, this file only renders their
///                output.
/// Change History:
///   1.0.0 - SPR-DEP-009 - Initial creation.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../engines/engine_result.dart';
import '../engines/formula_recommendation_engine.dart';
import '../engines/recommendation_engine.dart';
import '../engines/trial_comparison_engine.dart';
import '../engines/trial_explanation_engine.dart';
import '../engines/trial_generator_engine.dart';
import '../engines/trial_validation_engine.dart';
import '../engines/trial_workflow_manager.dart';
import '../models/trial_audit_entry_model.dart';
import '../models/trial_status.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/recommendation_summary_card.dart';

/// Arguments for [AppRoutes.trial].
class TrialScreenArgs {
  const TrialScreenArgs({required this.productId, this.shadeFamily});
  final int productId;
  final String? shadeFamily;
}

/// Trial screen: Top 5 recommendations with comparison, validation,
/// explanation, and workflow/audit history.
class TrialScreen extends StatefulWidget {
  const TrialScreen({required this.args, super.key});

  final TrialScreenArgs args;

  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  late final ITrialGeneratorEngine _generatorEngine;
  late final ITrialComparisonEngine _comparisonEngine;
  late final ITrialValidationEngine _validationEngine;
  late final ITrialExplanationEngine _explanationEngine;
  late final ITrialWorkflowManager _workflowManager;

  late Future<EngineResult<List<FormulaRecommendation>>> _future;
  List<FormulaRecommendation> _recommendations = <FormulaRecommendation>[];
  FormulaRecommendation? _selected;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _generatorEngine = ServiceLocator.instance.get<ITrialGeneratorEngine>();
    _comparisonEngine = ServiceLocator.instance.get<ITrialComparisonEngine>();
    _validationEngine = ServiceLocator.instance.get<ITrialValidationEngine>();
    _explanationEngine = ServiceLocator.instance
        .get<ITrialExplanationEngine>();
    _workflowManager = ServiceLocator.instance.get<ITrialWorkflowManager>();
    _future = _generate();
  }

  Future<EngineResult<List<FormulaRecommendation>>> _generate() async {
    final result = await _generatorEngine.generateTopFive(
      FormulaRecommendationRequest(
        productId: widget.args.productId,
        shadeFamily: widget.args.shadeFamily,
      ),
    );
    if (result.data != null) {
      _recommendations = result.data!;
    }
    return result;
  }

  RecommendationRequest get _baseRequest => RecommendationRequest(
        productId: widget.args.productId,
        shadeFamily: widget.args.shadeFamily,
      );

  Future<void> _showComparison() async {
    final ComparisonReport report = _comparisonEngine.compare(
      _recommendations,
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComparisonSheet(report: report),
    );
  }

  Future<void> _showValidation(FormulaRecommendation rec) async {
    final ValidationReport report = _validationEngine.validate(
      recommendation: rec,
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ValidationSheet(report: report),
    );
  }

  Future<void> _showExplanation(FormulaRecommendation rec) async {
    final explanation = await _explanationEngine.explain(
      recommendation: rec,
      request: _baseRequest,
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExplanationSheet(explanation: explanation),
    );
  }

  Future<void> _showHistory(FormulaRecommendation rec) async {
    final trialId = rec.trialFormula.id;
    if (trialId == null) {
      return;
    }
    final List<TrialAuditEntryModel> history = await _workflowManager
        .history(trialId);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(history: history),
    );
  }

  Future<void> _markReadyForLab(FormulaRecommendation rec) async {
    final trialId = rec.trialFormula.id;
    if (trialId == null) {
      return;
    }
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Mark Ready for Lab?',
      message: 'This moves "${rec.trialFormula.name}" into the lab '
          'workflow and records the transition in its audit history.',
      confirmLabel: 'Mark Ready',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isTransitioning = true);
    final result = await _workflowManager.transition(
      trialFormulaId: trialId,
      to: TrialStatus.readyForLab,
      reason: 'Selected from Top 5 recommendations.',
    );
    if (!mounted) {
      return;
    }
    setState(() => _isTransitioning = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.messages.isNotEmpty
                ? result.messages.first
                : 'Moved to Ready for Lab.',
          ),
        ),
      );
      setState(() {
        _future = _generate();
        _selected = null;
      });
    } else {
      await ErrorDialog.show(
        context,
        message: result.messages.isNotEmpty
            ? result.messages.first
            : 'Unable to update trial status.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trial Recommendations'),
        actions: <Widget>[
          if (_recommendations.length > 1)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              tooltip: 'Compare all',
              onPressed: _showComparison,
            ),
        ],
      ),
      body: FutureBuilder<EngineResult<List<FormulaRecommendation>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Generating recommendations…');
          }
          final result = snapshot.data;
          if (result == null || !result.isSuccess) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  result?.messages.isNotEmpty == true
                      ? result!.messages.first
                      : 'Unable to generate recommendations.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_recommendations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No trial formulas exist yet for this product/shade.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              for (final rec in _recommendations) ...<Widget>[
                RecommendationSummaryCard(
                  recommendation: rec,
                  selected: _selected == rec,
                  onTap: () => setState(
                    () => _selected = _selected == rec ? null : rec,
                  ),
                ),
                if (_selected == rec) _buildDetailActions(rec),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailActions(FormulaRecommendation rec) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          AppButton(
            label: 'Explanation',
            variant: AppButtonVariant.secondary,
            onPressed: () => _showExplanation(rec),
          ),
          AppButton(
            label: 'Validation',
            variant: AppButtonVariant.secondary,
            onPressed: () => _showValidation(rec),
          ),
          AppButton(
            label: 'History',
            variant: AppButtonVariant.secondary,
            onPressed: () => _showHistory(rec),
          ),
          AppButton(
            label: 'Mark Ready for Lab',
            isLoading: _isTransitioning,
            onPressed: () => _markReadyForLab(rec),
          ),
        ],
      ),
    );
  }
}

class _ComparisonSheet extends StatelessWidget {
  const _ComparisonSheet({required this.report});
  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Comparison Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final row in report.rows)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                row.field,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall,
                              ),
                              if (row.hasDifference) ...<Widget>[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.flag,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (final entry in row.valuesByTrialId.entries)
                            Text('Trial #${entry.key}: ${entry.value}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationSheet extends StatelessWidget {
  const _ValidationSheet({required this.report});
  final ValidationReport report;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Validation Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final check in report.checks)
                    ListTile(
                      leading: Icon(
                        check.passed ? Icons.check_circle : Icons.cancel,
                        color: check.passed
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                      title: Text(check.name),
                      subtitle: Text(check.message),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationSheet extends StatelessWidget {
  const _ExplanationSheet({required this.explanation});
  final TrialExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Explanation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Text(
                    'Why selected',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(explanation.whySelected),
                  const SizedBox(height: 12),
                  Text(
                    'Why this confidence',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(explanation.whyConfidence),
                  const SizedBox(height: 12),
                  Text(
                    'Rules matched (${explanation.rulesMatched.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final rule in explanation.rulesMatched)
                    Text('• ${rule.name}'),
                  const SizedBox(height: 12),
                  Text(
                    'Rules failed (${explanation.rulesFailed.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final rule in explanation.rulesFailed)
                    Text('• ${rule.name}'),
                  if (explanation.alternatives.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Alternatives',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final alt in explanation.alternatives)
                      Text('• $alt'),
                  ],
                  if (explanation.conflictsFound.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Conflicts found',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final c in explanation.conflictsFound)
                      Text('• ${c.message}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.history});
  final List<TrialAuditEntryModel> history;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Audit History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('No status changes recorded yet.')
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final entry in history)
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          '${entry.statusFrom} -> ${entry.statusTo}',
                        ),
                        subtitle: Text(
                          '${entry.changedBy}'
                          '${entry.reason != null ? ' — ${entry.reason}' : ''}',
                        ),
                        trailing: Text(
                          entry.createdAt?.toString().split('.').first ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
