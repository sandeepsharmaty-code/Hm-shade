/// Purpose      : Search tab content — supports Search Shades,
///                Search Products, Search Materials, Search Formulas,
///                and Search Knowledge Base.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/*
/// Description  : One SearchBox plus a category selector; each
///                category delegates to the matching repository's
///                existing `search()` (Repository Layer only, no SQL
///                or scoring logic in this file). Search Materials
///                fans out across all six raw-material repositories
///                and merges results, tagged with which table each
///                came from.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation. Honest empty state only
///           (Repository Layer didn't exist yet).
///   2.0.0 - SPR-DEP-009 - Full search across 5 categories, all
///           repository-backed.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../repositories/binder_repository.dart';
import '../repositories/dye_repository.dart';
import '../repositories/filler_repository.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/mica_repository.dart';
import '../repositories/pearl_repository.dart';
import '../repositories/pigment_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';
import '../widgets/search_box.dart';

enum _SearchCategory { shades, products, materials, formulas, knowledge }

extension on _SearchCategory {
  String get label => switch (this) {
        _SearchCategory.shades => 'Shades',
        _SearchCategory.products => 'Products',
        _SearchCategory.materials => 'Materials',
        _SearchCategory.formulas => 'Formulas',
        _SearchCategory.knowledge => 'Knowledge',
      };
}

/// One search result row, category-agnostic for uniform rendering.
class _SearchResultRow {
  const _SearchResultRow({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
}

/// Search tab: query input plus a category selector.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  _SearchCategory _category = _SearchCategory.shades;
  String _query = '';
  Future<List<_SearchResultRow>>? _resultsFuture;

  void _handleQueryChanged(String value) {
    setState(() {
      _query = value;
      _resultsFuture = value.trim().isEmpty ? null : _search(value);
    });
  }

  void _handleCategoryChanged(_SearchCategory category) {
    setState(() {
      _category = category;
      _resultsFuture = _query.trim().isEmpty ? null : _search(_query);
    });
  }

  Future<List<_SearchResultRow>> _search(String query) async {
    try {
      switch (_category) {
        case _SearchCategory.shades:
          final results = await ServiceLocator.instance
              .get<ShadeRepository>()
              .search(query);
          return <_SearchResultRow>[
            for (final s in results)
              _SearchResultRow(
                title: s.name,
                subtitle: '${s.shadeCode} · ${s.status}',
              ),
          ];

        case _SearchCategory.products:
          final results = await ServiceLocator.instance
              .get<ProductRepository>()
              .search(query);
          return <_SearchResultRow>[
            for (final p in results)
              _SearchResultRow(title: p.name, subtitle: p.category),
          ];

        case _SearchCategory.materials:
          return _searchMaterials(query);

        case _SearchCategory.formulas:
          final results = await ServiceLocator.instance
              .get<TrialRepository>()
              .search(query);
          return <_SearchResultRow>[
            for (final t in results)
              _SearchResultRow(
                title: t.name,
                subtitle: '${t.trialCode} · ${t.status}',
              ),
          ];

        case _SearchCategory.knowledge:
          final results = await ServiceLocator.instance
              .get<KnowledgeRepository>()
              .searchEntries(query);
          return <_SearchResultRow>[
            for (final k in results)
              _SearchResultRow(title: k.name, subtitle: k.tags),
          ];
      }
    } on RepositoryException {
      return const <_SearchResultRow>[];
    }
  }

  Future<List<_SearchResultRow>> _searchMaterials(String query) async {
    final locator = ServiceLocator.instance;
    final results = await Future.wait<List<_SearchResultRow>>(<
        Future<List<_SearchResultRow>>>[
      locator.get<PigmentRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Pigment'),
            ],
          ),
      locator.get<DyeRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Dye'),
            ],
          ),
      locator.get<MicaRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Mica'),
            ],
          ),
      locator.get<PearlRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Pearl'),
            ],
          ),
      locator.get<FillerRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Filler'),
            ],
          ),
      locator.get<BinderRepository>().search(query).then(
            (list) => <_SearchResultRow>[
              for (final m in list)
                _SearchResultRow(title: m.name, subtitle: 'Binder'),
            ],
          ),
    ]);
    return results.expand((List<_SearchResultRow> r) => r).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final category in _SearchCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => _handleCategoryChanged(category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SearchBox(
            hint: 'Search ${_category.label.toLowerCase()}',
            onChanged: _handleQueryChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _resultsFuture == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.search,
                          size: 56,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search ${_category.label}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<List<_SearchResultRow>>(
                    future: _resultsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState !=
                          ConnectionState.done) {
                        return const LoadingView();
                      }
                      final List<_SearchResultRow> results =
                          snapshot.data ?? const <_SearchResultRow>[];
                      if (results.isEmpty) {
                        return Center(
                          child: Text('No results for "$_query".'),
                        );
                      }
                      return ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  result.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall,
                                ),
                                if (result.subtitle != null)
                                  Text(
                                    result.subtitle!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
