/// Purpose      : Home tab content for the application shell.
/// Author       : HMEOS Engineering
/// Version      : 5.0.0
/// Dependencies : flutter/material.dart, provider,
///                core/services/navigation_provider.dart,
///                core/routing/app_routes.dart,
///                core/di/service_locator.dart,
///                repositories/product_repository.dart,
///                repositories/shade_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/recommendation_history_repository.dart,
///                repositories/{pigment,dye,mica,pearl,filler,binder}
///                _repository.dart,
///                screens/formula_list_screen.dart, widgets/*
/// Description  : Landing tab shown inside RootShellScreen's
///                IndexedStack. Displays this sprint's required
///                "HOME SCREEN" content — Application Summary, Recent
///                Recommendations, Pending Lab Trials, Quick Actions
///                — all read through repositories via ServiceLocator,
///                never SQLite directly. "Recent Analysis" is not
///                separately tracked (ColorProfile has no repository,
///                per SPR-DEP-008's Known Issues — image analysis
///                results are transient), so this screen surfaces
///                Recent Recommendations as the closest honest proxy
///                rather than fabricating a separate analysis feed —
///                flagged in the SPR-DEP-009 report.
/// Change History:
///   1.0.0 - SPR-DEP-001 - Initial creation. Standalone placeholder
///           screen with its own Scaffold/AppBar.
///   2.0.0 - SPR-DEP-002 - Converted to shell tab content (body-only).
///           Added quick-start card wired to real tab navigation.
///   3.0.0 - SPR-DEP-009 - Full Home Screen: Application Summary,
///           Recent Recommendations, Pending Lab Trials, Quick
///           Actions, all repository-backed.
///   3.1.0 - Repair Sprint R1 - Added "Manage Products" quick action,
///           pushing AppRoutes.productManagement and refreshing the
///           summary (Products count) on return.
///   3.2.0 - Repair Sprint R2 (Formula Workflow) - Added "Formulas"
///           quick action, pushing AppRoutes.formulaList (no
///           arguments -> every formula grouped by product) and
///           refreshing the summary on return.
///   4.0.0 - Repair Sprint R3 (Approved Formula Workflow) - Added an
///           "Approval Workflow" stat section (Approved, Awaiting
///           Approval, Rejected, Revisions Pending — R3-009) as its
///           own Wrap below the existing Products/Shades/Pending row,
///           which is unchanged. Added an "Approved Formulas" quick
///           action. All four new counts reuse the existing
///           TrialRepository.filter()/search() — no new repository
///           code (see that file's own R3 notes for the "Revisions
///           Pending" interpretation, since there is no dedicated
///           revision field).
///   5.0.0 - Repair Sprint R5 (Missing Business Modules) - Added
///           "Manage Shades" and "Manage Materials" quick actions.
///           Converted the top summary Row (Products/Shades/Pending)
///           to a Wrap and added a "Materials" card (sum of all six
///           raw-material repositories' count() — R5-F) so it fits
///           alongside the existing three without a fixed-width Row
///           needing hand-tuned flex values for a 4th card.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../core/services/navigation_provider.dart';
import '../models/recommendation_history_model.dart';
import '../models/trial_formula_model.dart';
import '../models/trial_status.dart';
import '../repositories/binder_repository.dart';
import '../repositories/dye_repository.dart';
import '../repositories/filler_repository.dart';
import '../repositories/mica_repository.dart';
import '../repositories/pearl_repository.dart';
import '../repositories/pigment_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/recommendation_history_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';
import '../widgets/trial_status_chip.dart';
import 'formula_list_screen.dart';

class _HomeSummary {
  const _HomeSummary({
    required this.productCount,
    required this.shadeCount,
    required this.pendingTrials,
    required this.recentRecommendations,
    required this.approvedCount,
    required this.awaitingApprovalCount,
    required this.rejectedCount,
    required this.revisionPendingCount,
    required this.materialsCount,
  });

  final int productCount;
  final int shadeCount;
  final List<TrialFormulaModel> pendingTrials;
  final List<RecommendationHistoryModel> recentRecommendations;

  // R3-009 (Approved Formula Workflow dashboard integration).
  final int approvedCount;
  final int awaitingApprovalCount;
  final int rejectedCount;
  final int revisionPendingCount;

  // R5-F (Dashboard) — sum of all six raw-material repositories'
  // count(), each already active-only by default.
  final int materialsCount;
}

/// Home tab: application summary, recent activity, and quick actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<_HomeSummary> _loadSummary() async {
    final ProductRepository productRepository = ServiceLocator.instance
        .get<ProductRepository>();
    final ShadeRepository shadeRepository = ServiceLocator.instance
        .get<ShadeRepository>();
    final TrialRepository trialRepository = ServiceLocator.instance
        .get<TrialRepository>();
    final RecommendationHistoryRepository historyRepository =
        ServiceLocator.instance.get<RecommendationHistoryRepository>();
    final PigmentRepository pigmentRepository = ServiceLocator.instance
        .get<PigmentRepository>();
    final DyeRepository dyeRepository = ServiceLocator.instance
        .get<DyeRepository>();
    final MicaRepository micaRepository = ServiceLocator.instance
        .get<MicaRepository>();
    final PearlRepository pearlRepository = ServiceLocator.instance
        .get<PearlRepository>();
    final FillerRepository fillerRepository = ServiceLocator.instance
        .get<FillerRepository>();
    final BinderRepository binderRepository = ServiceLocator.instance
        .get<BinderRepository>();

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        productRepository.count(),
        shadeRepository.count(),
        trialRepository.filter(<String, Object?>{
          'status': TrialStatus.readyForLab.storageKey,
        }),
        trialRepository.filter(<String, Object?>{
          'status': TrialStatus.labTesting.storageKey,
        }),
        historyRepository.recent(limit: 5),
        // R3-009: reuses the same public filter()/search() methods
        // already used above — no new repository code.
        trialRepository.filter(<String, Object?>{
          'status': TrialStatus.approved.storageKey,
        }),
        trialRepository.filter(<String, Object?>{
          'status': TrialStatus.rejected.storageKey,
        }),
        // "Revision Pending": drafts created by Create Revision that
        // haven't been resubmitted yet. There is no dedicated
        // revision/lineage column (see formula_details_screen.dart's
        // R3 notes), so this is the same "Revision of " notes-marker
        // convention, narrowed to drafts, via the existing search().
        trialRepository.search(
          'Revision of',
          columns: const <String>['notes'],
        ),
        // R5-F: sum of all six raw-material repositories' existing
        // count() — no new repository code.
        pigmentRepository.count(),
        dyeRepository.count(),
        micaRepository.count(),
        pearlRepository.count(),
        fillerRepository.count(),
        binderRepository.count(),
      ]);

      final List<TrialFormulaModel> readyForLab =
          results[2] as List<TrialFormulaModel>;
      final List<TrialFormulaModel> labTesting =
          results[3] as List<TrialFormulaModel>;
      final List<TrialFormulaModel> approved =
          results[5] as List<TrialFormulaModel>;
      final List<TrialFormulaModel> rejected =
          results[6] as List<TrialFormulaModel>;
      final List<TrialFormulaModel> revisionMatches =
          results[7] as List<TrialFormulaModel>;
      final int revisionPendingCount = revisionMatches
          .where(
            (TrialFormulaModel t) =>
                t.status == TrialStatus.draft.storageKey,
          )
          .length;
      final int materialsCount = (results[8] as int) +
          (results[9] as int) +
          (results[10] as int) +
          (results[11] as int) +
          (results[12] as int) +
          (results[13] as int);

      return _HomeSummary(
        productCount: results[0] as int,
        shadeCount: results[1] as int,
        pendingTrials: <TrialFormulaModel>[...readyForLab, ...labTesting],
        recentRecommendations:
            results[4] as List<RecommendationHistoryModel>,
        approvedCount: approved.length,
        awaitingApprovalCount: labTesting.length,
        rejectedCount: rejected.length,
        revisionPendingCount: revisionPendingCount,
        materialsCount: materialsCount,
      );
    } on RepositoryException {
      return const _HomeSummary(
        productCount: 0,
        shadeCount: 0,
        pendingTrials: <TrialFormulaModel>[],
        recentRecommendations: <RecommendationHistoryModel>[],
        approvedCount: 0,
        awaitingApprovalCount: 0,
        rejectedCount: 0,
        revisionPendingCount: 0,
        materialsCount: 0,
      );
    }
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  Future<void> _openProductManagement() async {
    await Navigator.of(context).pushNamed(AppRoutes.productManagement);
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openShadeManagement() async {
    await Navigator.of(context).pushNamed(AppRoutes.shadeManagement);
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openMaterialManagement() async {
    await Navigator.of(context).pushNamed(AppRoutes.materialManagement);
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openFormulaList() async {
    await Navigator.of(context).pushNamed(AppRoutes.formulaList);
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openApprovedFormulas() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaList,
      arguments: const FormulaListScreenArgs(
        statusFilter: TrialStatus.approved,
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<_HomeSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          final _HomeSummary summary =
              snapshot.data ??
              const _HomeSummary(
                productCount: 0,
                shadeCount: 0,
                pendingTrials: <TrialFormulaModel>[],
                recentRecommendations: <RecommendationHistoryModel>[],
                approvedCount: 0,
                awaitingApprovalCount: 0,
                rejectedCount: 0,
                revisionPendingCount: 0,
                materialsCount: 0,
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Application Summary
              Text(
                'Hue Muse Shade AI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Offline cosmetic colour shade development.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Products',
                      value: '${summary.productCount}',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Shades',
                      value: '${summary.shadeCount}',
                      icon: Icons.palette_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Materials',
                      value: '${summary.materialsCount}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Pending',
                      value: '${summary.pendingTrials.length}',
                      icon: Icons.science_outlined,
                    ),
                  ),
                ],
              ),

              // Approval Workflow (R3-009) — its own section below
              // the Products/Shades/Materials/Pending summary above,
              // rather than merged into one long Wrap, to keep the
              // two groups of stats visually and semantically
              // distinct.
              const SizedBox(height: 16),
              Text(
                'Approval Workflow',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Approved',
                      value: '${summary.approvedCount}',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Awaiting Approval',
                      value: '${summary.awaitingApprovalCount}',
                      icon: Icons.hourglass_empty,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Rejected',
                      value: '${summary.rejectedCount}',
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _StatCard(
                      label: 'Revisions Pending',
                      value: '${summary.revisionPendingCount}',
                      icon: Icons.content_copy,
                    ),
                  ),
                ],
              ),

              // Quick Actions
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  AppButton(
                    label: 'New Shade',
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed: () => context.read<NavigationProvider>()
                        .selectTab(AppTab.newShade),
                  ),
                  AppButton(
                    label: 'Manage Products',
                    icon: Icons.category_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openProductManagement,
                  ),
                  AppButton(
                    label: 'Manage Shades',
                    icon: Icons.palette_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openShadeManagement,
                  ),
                  AppButton(
                    label: 'Manage Materials',
                    icon: Icons.inventory_2_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openMaterialManagement,
                  ),
                  AppButton(
                    label: 'Formulas',
                    icon: Icons.science_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openFormulaList,
                  ),
                  AppButton(
                    label: 'Approved Formulas',
                    icon: Icons.verified_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openApprovedFormulas,
                  ),
                  AppButton(
                    label: 'Search',
                    icon: Icons.search,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.read<NavigationProvider>()
                        .selectTab(AppTab.search),
                  ),
                  AppButton(
                    label: 'Knowledge',
                    icon: Icons.menu_book_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.read<NavigationProvider>()
                        .selectTab(AppTab.knowledgeBase),
                  ),
                ],
              ),

              // Pending Lab Trials
              const SizedBox(height: 24),
              Text(
                'Pending Lab Trials',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (summary.pendingTrials.isEmpty)
                const AppCard(child: Text('No trials pending lab work.'))
              else
                for (final trial in summary.pendingTrials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(trial.name)),
                          TrialStatusChip(
                            status:
                                TrialStatus.fromStorageKey(trial.status) ??
                                TrialStatus.draft,
                          ),
                        ],
                      ),
                    ),
                  ),

              // Recent Recommendations
              const SizedBox(height: 24),
              Text(
                'Recent Recommendations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (summary.recentRecommendations.isEmpty)
                const AppCard(child: Text('No recommendations generated yet.'))
              else
                for (final entry in summary.recentRecommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.insights,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.reasonText ??
                                      'Trial #${entry.selectedTrialFormulaId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (entry.confidenceScore != null)
                                  Text(
                                    '${(entry.confidenceScore! * 100).toStringAsFixed(0)}% confidence',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: <Widget>[
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
