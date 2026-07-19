/// Purpose      : Formula List screen — Trial_Formula records grouped
///                by Product, with search, refresh, and (R3) in-
///                screen Product and Status filters.
/// Author       : HMEOS Engineering
/// Version      : 2.0.1
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                core/routing/app_routes.dart,
///                repositories/product_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/repository_exception.dart,
///                models/product_model.dart,
///                models/trial_formula_model.dart,
///                models/trial_status.dart, widgets/*
/// Description  : Pushed route (see AppRoutes.formulaList), not a
///                bottom tab — same rationale as AppRoutes.trial and
///                AppRoutes.productManagement: the approved 5-tab
///                shell (SPR-DEP-002) stays frozen. Reached from
///                Home's "Formulas" quick action (shows every
///                formula, grouped by product), from a product row in
///                ProductManagementScreen's "View Formulas" action
///                (opens with that product pre-selected — R2-008), or
///                from Home's "Approved Formulas" quick action (R3,
///                opens with the Approved status pre-selected).
///                "Formula" in this brief maps onto the existing
///                TrialFormulaModel/TrialRepository — see
///                formula_form_screen.dart's header for the full
///                R2-001 findings on why no separate FormulaModel/
///                FormulaRepository was created.
///
///                R3-002 note: rather than build a separate "Approved
///                Formula List Screen" that would duplicate this
///                screen's grouping/search/refresh/empty-state code
///                almost entirely, this screen gained an in-screen
///                Status filter (chips) alongside the existing
///                Product filter — both `args.productId` and the new
///                `args.statusFilter` are just the *initial* filter
///                values; the person can change either afterward.
///                "Approved Formulas" is this same screen opened with
///                statusFilter: TrialStatus.approved. This is
///                documented in full in the R3 report's R3-001
///                review section.
///
///                Reads only through ProductRepository/TrialRepository,
///                through ServiceLocator — never SQLite directly.
/// Change History:
///   1.0.0 - Repair Sprint R2 (Formula Workflow) - Initial creation.
///   2.0.0 - Repair Sprint R3 (Approved Formula Workflow) - Added
///           `statusFilter` to args and an in-screen Status filter
///           (chips) plus a Product filter dropdown, satisfying
///           R3-002 by extending this screen instead of duplicating
///           it — see the note above.
///   2.0.1 - CI Compatibility Repair - `DropdownButtonFormField`'s
///           `value:` renamed to `initialValue:` (Flutter 3.34+
///           deprecated `value:` in favor of it) — first real
///           `flutter analyze` run (GitHub Actions) surfaced this;
///           no behavior change, same widget, same reactivity.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../models/product_model.dart';
import '../models/trial_formula_model.dart';
import '../models/trial_status.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';
import '../widgets/search_box.dart';
import '../widgets/trial_status_chip.dart';
import 'formula_details_screen.dart';
import 'formula_form_screen.dart';

/// Arguments for [AppRoutes.formulaList]. Omit entirely (push with no
/// arguments) to show every formula grouped by product. Both fields
/// are only the *initial* filter state — the screen lets the person
/// change either afterward.
class FormulaListScreenArgs {
  const FormulaListScreenArgs({this.productId, this.statusFilter});

  /// When set, only this product's formulas are shown initially
  /// (R2-008) and grouping is skipped since there is only one group.
  final int? productId;

  /// When set (R3-002), only formulas in this status are shown
  /// initially — e.g. TrialStatus.approved for "Approved Formulas".
  final TrialStatus? statusFilter;
}

/// One product's formulas, or the "Unassigned" bucket for formulas
/// with no `productId`.
class _FormulaGroup {
  _FormulaGroup({required this.product, required this.trials});

  /// Null for the "Unassigned" bucket.
  final ProductModel? product;
  final List<TrialFormulaModel> trials;
}

/// Formula List screen: formulas grouped by product, with search.
class FormulaListScreen extends StatefulWidget {
  const FormulaListScreen({this.args = const FormulaListScreenArgs(), super.key});

  final FormulaListScreenArgs args;

  @override
  State<FormulaListScreen> createState() => _FormulaListScreenState();
}

class _FormulaListScreenState extends State<FormulaListScreen> {
  late final TrialRepository _trialRepository;
  late final ProductRepository _productRepository;
  late Future<List<_FormulaGroup>> _groupsFuture;
  late final Future<List<ProductModel>> _productsFuture;
  String _query = '';

  late int? _productFilterId;
  late TrialStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _trialRepository = ServiceLocator.instance.get<TrialRepository>();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _productFilterId = widget.args.productId;
    _statusFilter = widget.args.statusFilter;
    // Fetched once and reused (both by _loadGroups()'s grouping logic
    // and by the Product filter dropdown below) — awaiting the same
    // Future multiple times is safe in Dart and avoids re-querying
    // products on every search keystroke/refresh.
    _productsFuture = _productRepository.readAll();
    _groupsFuture = _loadGroups();
  }

  Future<List<_FormulaGroup>> _loadGroups() async {
    try {
      final String query = _query.trim();
      final List<TrialFormulaModel> trials = query.isEmpty
          ? await _trialRepository.readAll()
          : await _trialRepository.search(
              query,
              columns: const <String>['name', 'trial_code', 'notes'],
            );

      final int? filterId = _productFilterId;
      final TrialStatus? statusFilter = _statusFilter;
      final List<TrialFormulaModel> scoped = trials.where((
        TrialFormulaModel t,
      ) {
        if (filterId != null && t.productId != filterId) {
          return false;
        }
        if (statusFilter != null && t.status != statusFilter.storageKey) {
          return false;
        }
        return true;
      }).toList();

      final List<ProductModel> products = await _productsFuture;
      final Map<int, ProductModel> productById = <int, ProductModel>{
        for (final ProductModel p in products)
          if (p.id != null) p.id!: p,
      };

      final Map<int?, List<TrialFormulaModel>> byProduct =
          <int?, List<TrialFormulaModel>>{};
      for (final TrialFormulaModel trial in scoped) {
        byProduct
            .putIfAbsent(trial.productId, () => <TrialFormulaModel>[])
            .add(trial);
      }

      final List<_FormulaGroup> groups = <_FormulaGroup>[
        for (final MapEntry<int?, List<TrialFormulaModel>> entry
            in byProduct.entries)
          _FormulaGroup(
            product: entry.key == null ? null : productById[entry.key],
            trials: entry.value,
          ),
      ]..sort((_FormulaGroup a, _FormulaGroup b) {
          if (a.product == null) {
            return 1;
          }
          if (b.product == null) {
            return -1;
          }
          return a.product!.name.compareTo(b.product!.name);
        });

      return groups;
    } on RepositoryException {
      return const <_FormulaGroup>[];
    }
  }

  void _refresh() {
    setState(() => _groupsFuture = _loadGroups());
  }

  void _handleQueryChanged(String value) {
    setState(() {
      _query = value;
      _groupsFuture = _loadGroups();
    });
  }

  void _handleProductFilterChanged(int? productId) {
    setState(() {
      _productFilterId = productId;
      _groupsFuture = _loadGroups();
    });
  }

  void _handleStatusFilterChanged(TrialStatus? status) {
    setState(() {
      _statusFilter = status;
      _groupsFuture = _loadGroups();
    });
  }

  Future<void> _openDetails(TrialFormulaModel trial) async {
    final int? id = trial.id;
    if (id == null) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaDetails,
      arguments: FormulaDetailsScreenArgs(trialFormulaId: id),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaEdit,
      arguments: FormulaFormScreenArgs(productId: _productFilterId),
    );
    if (mounted) {
      _refresh();
    }
  }

  String get _title {
    if (_statusFilter == TrialStatus.approved && _productFilterId == null) {
      return 'Approved Formulas';
    }
    return _productFilterId == null ? 'Formulas' : 'Product Formulas';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: 'Add Formula',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  _StatusFilterChip(
                    label: 'All',
                    selected: _statusFilter == null,
                    onSelected: () => _handleStatusFilterChanged(null),
                  ),
                  for (final TrialStatus status in TrialStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _StatusFilterChip(
                        label: status.label,
                        selected: _statusFilter == status,
                        onSelected: () => _handleStatusFilterChanged(status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<ProductModel>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                final List<ProductModel> products =
                    snapshot.data ?? const <ProductModel>[];
                // Defensive: if the product currently filtered on was
                // soft-deleted since, it won't be in `products` (an
                // active-only list), but _productFilterId still
                // points at it — DropdownButtonFormField asserts a
                // non-null `value` must match an item in `items`.
                // Same defense as formula_form_screen.dart's dropdowns.
                final bool filterStillPresent = _productFilterId == null ||
                    products.any((ProductModel p) => p.id == _productFilterId);
                return DropdownButtonFormField<int?>(
                  initialValue: filterStillPresent ? _productFilterId : null,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Products'),
                    ),
                    for (final ProductModel product in products)
                      if (product.id != null)
                        DropdownMenuItem<int?>(
                          value: product.id,
                          child: Text(product.name),
                        ),
                  ],
                  onChanged: _handleProductFilterChanged,
                );
              },
            ),
            const SizedBox(height: 16),
            SearchBox(
              hint: 'Search formulas',
              onChanged: _handleQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: FutureBuilder<List<_FormulaGroup>>(
                  future: _groupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView();
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: const <Widget>[
                          SizedBox(height: 80),
                          Center(child: Text('Unable to load formulas.')),
                        ],
                      );
                    }
                    final List<_FormulaGroup> groups =
                        snapshot.data ?? const <_FormulaGroup>[];
                    final bool isEmpty =
                        groups.every((_FormulaGroup g) => g.trials.isEmpty);
                    if (isEmpty) {
                      return ListView(
                        children: <Widget>[
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              _query.trim().isEmpty
                                  ? 'No formulas exist yet. Tap + to add one.'
                                  : 'No formulas match "$_query".',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      children: <Widget>[
                        for (final _FormulaGroup group in groups)
                          if (group.trials.isNotEmpty)
                            _FormulaGroupSection(
                              group: group,
                              showHeader: _productFilterId == null,
                              onTap: _openDetails,
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable status filter chip, using Flutter's own Material 3
/// ChoiceChip — not a new shared widget, the same standard-library
/// building block (Row/Column/Icon/DropdownButtonFormField) already
/// used throughout this codebase for anything AppCard/AppButton/etc.
/// don't cover.
class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _FormulaGroupSection extends StatelessWidget {
  const _FormulaGroupSection({
    required this.group,
    required this.showHeader,
    required this.onTap,
  });

  final _FormulaGroup group;
  final bool showHeader;
  final ValueChanged<TrialFormulaModel> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            Text(
              group.product?.name ?? 'Unassigned',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
          for (final TrialFormulaModel trial in group.trials)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => onTap(trial),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            trial.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trial.trialCode,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    TrialStatusChip(
                      status: TrialStatus.fromStorageKey(trial.status) ??
                          TrialStatus.draft,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
