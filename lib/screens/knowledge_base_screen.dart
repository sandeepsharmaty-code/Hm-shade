/// Purpose      : Knowledge tab content — Knowledge Records, Approved
///                Formulas, Rules, and Recent Updates.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/knowledge_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/rule_repository.dart, widgets/*
/// Description  : Four tabs, each backed by exactly the repository
///                that already owns that data — KnowledgeRepository,
///                TrialRepository (filtered to approved), and
///                RuleRepository (SPR-DEP-005) — never SQLite
///                directly and no scoring/business logic in this
///                file. Recent Updates is the 5 most-recently-updated
///                Knowledge_Base entries by `updatedAt`, computed
///                in-memory from the same read this screen already
///                needs (no new repository method required).
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation. Honest empty state only
///           (Repository Layer didn't exist yet).
///   2.0.0 - SPR-DEP-009 - Full 4-tab screen: Knowledge Records,
///           Approved Formulas, Rules, Recent Updates.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../models/knowledge_base_model.dart';
import '../models/rule_model.dart';
import '../models/trial_formula_model.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/rule_repository.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';

/// Knowledge tab: Records / Approved Formulas / Rules / Recent
/// Updates.
class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  late Future<List<KnowledgeBaseModel>> _knowledgeFuture;
  late Future<List<TrialFormulaModel>> _approvedFuture;
  late Future<List<RuleModel>> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _knowledgeFuture = ServiceLocator.instance
        .get<KnowledgeRepository>()
        .readAll()
        .catchError((_) => const <KnowledgeBaseModel>[]);
    _approvedFuture = ServiceLocator.instance
        .get<TrialRepository>()
        .filter(<String, Object?>{'status': 'approved'})
        .catchError((_) => const <TrialFormulaModel>[]);
    _rulesFuture = ServiceLocator.instance
        .get<RuleRepository>()
        .findAllRules(includeInactive: true)
        .catchError((_) => const <RuleModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: <Widget>[
          const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Knowledge'),
              Tab(text: 'Approved Formulas'),
              Tab(text: 'Rules'),
              Tab(text: 'Recent Updates'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _KnowledgeRecordsTab(future: _knowledgeFuture),
                _ApprovedFormulasTab(future: _approvedFuture),
                _RulesTab(future: _rulesFuture),
                _RecentUpdatesTab(future: _knowledgeFuture),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeRecordsTab extends StatelessWidget {
  const _KnowledgeRecordsTab({required this.future});
  final Future<List<KnowledgeBaseModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KnowledgeBaseModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final entries = snapshot.data ?? const <KnowledgeBaseModel>[];
        if (entries.isEmpty) {
          return const _EmptyState(
            icon: Icons.menu_book_outlined,
            message: 'Knowledge Base is empty.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry.name, style: Theme.of(context).textTheme.titleSmall),
                  if (entry.tags != null) Text(entry.tags!),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ApprovedFormulasTab extends StatelessWidget {
  const _ApprovedFormulasTab({required this.future});
  final Future<List<TrialFormulaModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrialFormulaModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final entries = snapshot.data ?? const <TrialFormulaModel>[];
        if (entries.isEmpty) {
          return const _EmptyState(
            icon: Icons.verified_outlined,
            message: 'No approved formulas yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final trial = entries[index];
            return AppCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(trial.name),
                        Text(
                          trial.trialCode,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.future});
  final Future<List<RuleModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RuleModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final rules = snapshot.data ?? const <RuleModel>[];
        if (rules.isEmpty) {
          return const _EmptyState(
            icon: Icons.rule_outlined,
            message: 'No rules configured.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rule = rules[index];
            return AppCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    rule.isActive ? Icons.toggle_on : Icons.toggle_off,
                    color: rule.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(rule.name),
                        Text(
                          '${rule.ruleType.storageKey} · priority '
                          '${rule.priority} · weight ${rule.weight}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RecentUpdatesTab extends StatelessWidget {
  const _RecentUpdatesTab({required this.future});
  final Future<List<KnowledgeBaseModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KnowledgeBaseModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final List<KnowledgeBaseModel> all = List<KnowledgeBaseModel>.of(
          snapshot.data ?? const <KnowledgeBaseModel>[],
        );
        all.sort((a, b) {
          final DateTime aTime = a.updatedAt ?? DateTime(1970);
          final DateTime bTime = b.updatedAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        final List<KnowledgeBaseModel> recent = all.take(5).toList();

        if (recent.isEmpty) {
          return const _EmptyState(
            icon: Icons.update,
            message: 'No recent updates.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = recent[index];
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.name),
                subtitle: Text(
                  entry.updatedAt?.toString().split('.').first ?? '',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
