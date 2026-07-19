/// Purpose      : Raw Material Management screen — ONE reusable
///                screen covering Pigment/Dye/Mica/Pearl/Filler/
///                Binder_Master, not six separate screens.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/{pigment,dye,mica,pearl,filler,binder}
///                _repository.dart, repositories/repository_exception.dart,
///                models/{pigment,dye,mica,pearl,filler,binder}
///                _model.dart, models/raw_material_model.dart, widgets/*
/// Description  : Pushed route (see AppRoutes.materialManagement).
///                Fills the second R4-001 gap: none of the six raw-
///                material repositories' create() was ever called
///                anywhere in the app.
///
///                "ONE reusable screen... generic configuration" is
///                implemented via six small `_MaterialTypeAdapter`
///                instances (one per table), each just a thin set of
///                closures over that table's own typed repository —
///                not six screens, not six forms, not six copies of
///                list/search/CRUD logic. This is the same shape R2's
///                formula_form_screen.dart already used for its
///                ingredient-table dropdown (`_kMaterialTableLabels` +
///                a Future.wait fan-out across all six repositories),
///                extended here to full CRUD. All UI/state code below
///                is written once and operates on one adapter-
///                agnostic `_MaterialRecord`, converted to/from each
///                table's real concrete model only inside that
///                table's adapter.
///
///                Field mapping (brief's generic field list vs. what
///                actually exists — confirmed by reading
///                database_helper.dart and all six model files
///                directly, not assumed): every one of the six
///                tables shares an *identical* 7-column core (name,
///                material_code, cas_number, supplier, unit,
///                cost_per_unit, stock_quantity) plus audit columns —
///                confirmed byte-for-byte identical across all six
///                schema definitions. Each table also has exactly one
///                extra column unique to it (Pigment: color_index,
///                Dye: solubility, Mica: particle_size, Pearl:
///                pearl_type, Filler: filler_type, Binder: binder_
///                type) — deliberately NOT surfaced here, because a
///                truly generic single screen can't sensibly label or
///                edit six different, differently-named fields as one
///                UI element. Mapping the brief's requested fields:
///                - Material Name, Material Code, Supplier, CAS
///                  Number: real, shared columns, shown as-is.
///                - "Type": not a per-record column on any table —
///                  it's *which table* a record belongs to. Shown as
///                  a selector when adding (fixed thereafter, since a
///                  row's table can't change without deleting and
///                  recreating it, which this screen does not do
///                  silently).
///                - "Colour": no shared column. Only Pigment has a
///                  colour-adjacent field (`color_index`, a Colour
///                  Index reference code, not a colour value), and
///                  it's Pigment-only — surfacing it as a generic
///                  "Colour" for all six tables would misrepresent
///                  the other five. Omitted.
///                - "Notes": no such column on any of the six tables.
///                  Omitted rather than invented.
///                - "Status": these tables have no `status` text
///                  column (unlike Shade_Master/Trial_Formula) — only
///                  the standard `is_active` audit flag. Mapped to
///                  Active/Inactive, not a fabricated workflow status.
///                - Unit, Cost Per Unit, Stock Quantity: real, shared
///                  columns not named in the brief's list, but
///                  genuinely important, already-existing data for a
///                  material record — included rather than hidden.
///                Full detail in the R5 report's Known Issues.
/// Change History:
///   1.0.0 - Repair Sprint R5 (Missing Business Modules) - Initial
///           creation.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../models/binder_model.dart';
import '../models/dye_model.dart';
import '../models/filler_model.dart';
import '../models/mica_model.dart';
import '../models/pearl_model.dart';
import '../models/pigment_model.dart';
import '../repositories/binder_repository.dart';
import '../repositories/dye_repository.dart';
import '../repositories/filler_repository.dart';
import '../repositories/mica_repository.dart';
import '../repositories/pearl_repository.dart';
import '../repositories/pigment_repository.dart';
import '../repositories/repository_exception.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/search_box.dart';

enum _ActiveFilter { active, inactive, all }

/// Adapter-agnostic shape every one of the six concrete material
/// models is converted to/from. `materialTable` is the same
/// convention already used by Formula_Material's `material_table`
/// column (R2/R3) — 'Pigment_Master', 'Dye_Master', etc.
@immutable
class _MaterialRecord {
  const _MaterialRecord({
    required this.materialTable,
    required this.name,
    required this.materialCode,
    this.id,
    this.casNumber,
    this.supplier,
    this.unit = 'g',
    this.costPerUnit = 0,
    this.stockQuantity = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String materialTable;
  final String name;
  final String materialCode;
  final String? casNumber;
  final String? supplier;
  final String unit;
  final double costPerUnit;
  final double stockQuantity;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _MaterialRecord copyWith({
    int? id,
    String? name,
    String? materialCode,
    String? casNumber,
    String? supplier,
    String? unit,
    double? costPerUnit,
    double? stockQuantity,
    bool? isActive,
  }) {
    return _MaterialRecord(
      materialTable: materialTable,
      id: id ?? this.id,
      name: name ?? this.name,
      materialCode: materialCode ?? this.materialCode,
      casNumber: casNumber ?? this.casNumber,
      supplier: supplier ?? this.supplier,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

typedef _FetchAll = Future<List<_MaterialRecord>> Function({
  bool includeInactive,
});
typedef _Search = Future<List<_MaterialRecord>> Function(String query);
typedef _Create = Future<_MaterialRecord> Function(_MaterialRecord draft);
typedef _Update = Future<_MaterialRecord> Function(_MaterialRecord draft);
typedef _SoftDelete = Future<bool> Function(int id);

/// One table's thin dispatch layer — the only per-table code in this
/// file. Six instances of this, built once in initState, are all
/// that stands between "one generic screen" and "six near-identical
/// repositories" (RawMaterialModel doesn't declare create/update/
/// copyWith, so a truly type-erased generic path isn't possible
/// without this).
class _MaterialTypeAdapter {
  const _MaterialTypeAdapter({
    required this.tableKey,
    required this.label,
    required this.fetchAll,
    required this.search,
    required this.create,
    required this.update,
    required this.softDelete,
  });

  final String tableKey;
  final String label;
  final _FetchAll fetchAll;
  final _Search search;
  final _Create create;
  final _Update update;
  final _SoftDelete softDelete;
}

const List<String> kMaterialSearchColumns = <String>[
  'name',
  'material_code',
  'cas_number',
  'supplier',
];

/// Raw Material Management screen: one list/search/CRUD screen for
/// all six raw-material tables.
class MaterialManagementScreen extends StatefulWidget {
  const MaterialManagementScreen({super.key});

  @override
  State<MaterialManagementScreen> createState() =>
      _MaterialManagementScreenState();
}

class _MaterialManagementScreenState extends State<MaterialManagementScreen> {
  late final List<_MaterialTypeAdapter> _adapters;
  late Future<List<_MaterialRecord>> _recordsFuture;

  String _query = '';
  late String _selectedTable;
  _ActiveFilter _activeFilter = _ActiveFilter.active;

  @override
  void initState() {
    super.initState();
    _adapters = _buildAdapters();
    _selectedTable = _adapters.first.tableKey;
    _recordsFuture = _loadRecords();
  }

  _MaterialTypeAdapter get _currentAdapter =>
      _adapters.firstWhere((_MaterialTypeAdapter a) => a.tableKey == _selectedTable);

  List<_MaterialTypeAdapter> _buildAdapters() {
    final PigmentRepository pigmentRepository =
        ServiceLocator.instance.get<PigmentRepository>();
    final DyeRepository dyeRepository =
        ServiceLocator.instance.get<DyeRepository>();
    final MicaRepository micaRepository =
        ServiceLocator.instance.get<MicaRepository>();
    final PearlRepository pearlRepository =
        ServiceLocator.instance.get<PearlRepository>();
    final FillerRepository fillerRepository =
        ServiceLocator.instance.get<FillerRepository>();
    final BinderRepository binderRepository =
        ServiceLocator.instance.get<BinderRepository>();

    return <_MaterialTypeAdapter>[
      _MaterialTypeAdapter(
        tableKey: 'Pigment_Master',
        label: 'Pigment',
        fetchAll: ({bool includeInactive = false}) async => (await pigmentRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromPigment)
            .toList(),
        search: (String q) async => (await pigmentRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromPigment).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromPigment(await pigmentRepository.create(_pigmentFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromPigment(await pigmentRepository.update(_pigmentFromRecord(d))),
        softDelete: pigmentRepository.softDelete,
      ),
      _MaterialTypeAdapter(
        tableKey: 'Dye_Master',
        label: 'Dye',
        fetchAll: ({bool includeInactive = false}) async => (await dyeRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromDye)
            .toList(),
        search: (String q) async => (await dyeRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromDye).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromDye(await dyeRepository.create(_dyeFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromDye(await dyeRepository.update(_dyeFromRecord(d))),
        softDelete: dyeRepository.softDelete,
      ),
      _MaterialTypeAdapter(
        tableKey: 'Mica_Master',
        label: 'Mica',
        fetchAll: ({bool includeInactive = false}) async => (await micaRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromMica)
            .toList(),
        search: (String q) async => (await micaRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromMica).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromMica(await micaRepository.create(_micaFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromMica(await micaRepository.update(_micaFromRecord(d))),
        softDelete: micaRepository.softDelete,
      ),
      _MaterialTypeAdapter(
        tableKey: 'Pearl_Master',
        label: 'Pearl',
        fetchAll: ({bool includeInactive = false}) async => (await pearlRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromPearl)
            .toList(),
        search: (String q) async => (await pearlRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromPearl).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromPearl(await pearlRepository.create(_pearlFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromPearl(await pearlRepository.update(_pearlFromRecord(d))),
        softDelete: pearlRepository.softDelete,
      ),
      _MaterialTypeAdapter(
        tableKey: 'Filler_Master',
        label: 'Filler',
        fetchAll: ({bool includeInactive = false}) async => (await fillerRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromFiller)
            .toList(),
        search: (String q) async => (await fillerRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromFiller).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromFiller(await fillerRepository.create(_fillerFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromFiller(await fillerRepository.update(_fillerFromRecord(d))),
        softDelete: fillerRepository.softDelete,
      ),
      _MaterialTypeAdapter(
        tableKey: 'Binder_Master',
        label: 'Binder',
        fetchAll: ({bool includeInactive = false}) async => (await binderRepository
                .readAll(includeInactive: includeInactive))
            .map(_recordFromBinder)
            .toList(),
        search: (String q) async => (await binderRepository.search(
          q,
          columns: kMaterialSearchColumns,
        )).map(_recordFromBinder).toList(),
        create: (_MaterialRecord d) async =>
            _recordFromBinder(await binderRepository.create(_binderFromRecord(d))),
        update: (_MaterialRecord d) async =>
            _recordFromBinder(await binderRepository.update(_binderFromRecord(d))),
        softDelete: binderRepository.softDelete,
      ),
    ];
  }

  // --- Adapter conversion functions (the only per-table code) ---

  static _MaterialRecord _recordFromPigment(PigmentModel m) => _MaterialRecord(
        materialTable: 'Pigment_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static PigmentModel _pigmentFromRecord(_MaterialRecord r) => PigmentModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static _MaterialRecord _recordFromDye(DyeModel m) => _MaterialRecord(
        materialTable: 'Dye_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static DyeModel _dyeFromRecord(_MaterialRecord r) => DyeModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static _MaterialRecord _recordFromMica(MicaModel m) => _MaterialRecord(
        materialTable: 'Mica_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static MicaModel _micaFromRecord(_MaterialRecord r) => MicaModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static _MaterialRecord _recordFromPearl(PearlModel m) => _MaterialRecord(
        materialTable: 'Pearl_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static PearlModel _pearlFromRecord(_MaterialRecord r) => PearlModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static _MaterialRecord _recordFromFiller(FillerModel m) => _MaterialRecord(
        materialTable: 'Filler_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static FillerModel _fillerFromRecord(_MaterialRecord r) => FillerModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static _MaterialRecord _recordFromBinder(BinderModel m) => _MaterialRecord(
        materialTable: 'Binder_Master',
        id: m.id,
        name: m.name,
        materialCode: m.materialCode,
        casNumber: m.casNumber,
        supplier: m.supplier,
        unit: m.unit,
        costPerUnit: m.costPerUnit,
        stockQuantity: m.stockQuantity,
        isActive: m.isActive,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static BinderModel _binderFromRecord(_MaterialRecord r) => BinderModel(
        id: r.id,
        name: r.name,
        materialCode: r.materialCode,
        casNumber: r.casNumber,
        supplier: r.supplier,
        unit: r.unit,
        costPerUnit: r.costPerUnit,
        stockQuantity: r.stockQuantity,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  // --- Generic screen logic (written once, table-agnostic) ---

  Future<List<_MaterialRecord>> _loadRecords() async {
    try {
      final String query = _query.trim();
      final bool includeInactive = _activeFilter != _ActiveFilter.active;
      List<_MaterialRecord> records = query.isEmpty
          ? await _currentAdapter.fetchAll(includeInactive: includeInactive)
          : await _currentAdapter.search(query);
      if (_activeFilter == _ActiveFilter.inactive) {
        records = records.where((_MaterialRecord r) => !r.isActive).toList();
      }
      return records;
    } on RepositoryException {
      return const <_MaterialRecord>[];
    }
  }

  void _refresh() {
    setState(() => _recordsFuture = _loadRecords());
  }

  void _handleQueryChanged(String value) {
    setState(() {
      _query = value;
      _recordsFuture = _loadRecords();
    });
  }

  void _handleTableChanged(String tableKey) {
    setState(() {
      _selectedTable = tableKey;
      _recordsFuture = _loadRecords();
    });
  }

  void _handleActiveFilterChanged(_ActiveFilter filter) {
    setState(() {
      _activeFilter = filter;
      _recordsFuture = _loadRecords();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({_MaterialRecord? existing}) async {
    final _MaterialTypeAdapter adapter = existing == null
        ? _currentAdapter
        : _adapters.firstWhere(
            (_MaterialTypeAdapter a) => a.tableKey == existing.materialTable,
          );
    final _MaterialRecord? result = await showModalBottomSheet<_MaterialRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MaterialFormSheet(
        existing: existing,
        adapters: _adapters,
        initialTableKey: adapter.tableKey,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      if (existing == null) {
        await adapter.create(result);
        _showMessage('Material created.');
      } else {
        await adapter.update(result);
        _showMessage('Material updated.');
      }
      if (!mounted) {
        return;
      }
      _refresh();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(context, message: error.message);
    }
  }

  Future<void> _handleDelete(_MaterialRecord record) async {
    final int? id = record.id;
    if (id == null) {
      return;
    }
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Material?',
      message: 'This hides "${record.name}" from active material lists. '
          'It can be restored later from the Inactive view.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      final _MaterialTypeAdapter adapter = _adapters.firstWhere(
        (_MaterialTypeAdapter a) => a.tableKey == record.materialTable,
      );
      await adapter.softDelete(id);
      if (!mounted) {
        return;
      }
      _showMessage('Material deleted.');
      _refresh();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(context, message: error.message);
    }
  }

  Future<void> _handleRestore(_MaterialRecord record) async {
    try {
      final _MaterialTypeAdapter adapter = _adapters.firstWhere(
        (_MaterialTypeAdapter a) => a.tableKey == record.materialTable,
      );
      await adapter.update(record.copyWith(isActive: true));
      if (!mounted) {
        return;
      }
      _showMessage('Material restored.');
      _refresh();
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
      appBar: AppBar(title: const Text('Manage Materials')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add Material',
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
                  for (final _MaterialTypeAdapter adapter in _adapters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(adapter.label),
                        selected: _selectedTable == adapter.tableKey,
                        onSelected: (_) => _handleTableChanged(adapter.tableKey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final _ActiveFilter filter in _ActiveFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (filter) {
                          _ActiveFilter.active => 'Active',
                          _ActiveFilter.inactive => 'Inactive',
                          _ActiveFilter.all => 'All',
                        }),
                        selected: _activeFilter == filter,
                        onSelected: (_) => _handleActiveFilterChanged(filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SearchBox(
              hint: 'Search ${_currentAdapter.label.toLowerCase()}s',
              onChanged: _handleQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<_MaterialRecord>>(
                future: _recordsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  final List<_MaterialRecord> records =
                      snapshot.data ?? const <_MaterialRecord>[];
                  if (records.isEmpty) {
                    return Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'No ${_currentAdapter.label.toLowerCase()} '
                                'records found. Tap + to add one.'
                            : 'No results for "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final _MaterialRecord record = records[index];
                      return _MaterialCard(
                        record: record,
                        onTap: () => _openForm(existing: record),
                        onDelete: () => _handleDelete(record),
                        onRestore: () => _handleRestore(record),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
    required this.onRestore,
  });

  final _MaterialRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: record.isActive ? onTap : null,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${record.materialCode} · ${record.stockQuantity} '
                  '${record.unit}${record.isActive ? '' : ' · inactive'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (record.isActive)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            )
          else
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore',
              onPressed: onRestore,
            ),
        ],
      ),
    );
  }
}

class _MaterialFormSheet extends StatefulWidget {
  const _MaterialFormSheet({
    required this.adapters,
    required this.initialTableKey,
    this.existing,
  });

  final _MaterialRecord? existing;
  final List<_MaterialTypeAdapter> adapters;
  final String initialTableKey;

  @override
  State<_MaterialFormSheet> createState() => _MaterialFormSheetState();
}

class _MaterialFormSheetState extends State<_MaterialFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _casController;
  late final TextEditingController _supplierController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late String _tableKey;

  @override
  void initState() {
    super.initState();
    final _MaterialRecord? existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(
      text: existing?.materialCode ?? '',
    );
    _casController = TextEditingController(text: existing?.casNumber ?? '');
    _supplierController = TextEditingController(
      text: existing?.supplier ?? '',
    );
    _unitController = TextEditingController(text: existing?.unit ?? 'g');
    _costController = TextEditingController(
      text: existing == null ? '' : existing.costPerUnit.toString(),
    );
    _stockController = TextEditingController(
      text: existing == null ? '' : existing.stockQuantity.toString(),
    );
    _tableKey = existing?.materialTable ?? widget.initialTableKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _casController.dispose();
    _supplierController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final _MaterialRecord? existing = widget.existing;
    final String cas = _casController.text.trim();
    final String supplier = _supplierController.text.trim();
    final String unit = _unitController.text.trim();

    final _MaterialRecord result = _MaterialRecord(
      materialTable: _tableKey,
      id: existing?.id,
      name: _nameController.text.trim(),
      materialCode: _codeController.text.trim(),
      casNumber: cas.isEmpty ? null : cas,
      supplier: supplier.isEmpty ? null : supplier,
      unit: unit.isEmpty ? 'g' : unit,
      costPerUnit: double.tryParse(_costController.text.trim()) ?? 0,
      stockQuantity: double.tryParse(_stockController.text.trim()) ?? 0,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    final _MaterialRecord? existing = widget.existing;
    final _MaterialTypeAdapter currentAdapter = widget.adapters.firstWhere(
      (_MaterialTypeAdapter a) => a.tableKey == _tableKey,
    );

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
                Text(
                  isEditing
                      ? 'Edit ${currentAdapter.label}'
                      : 'Add Material',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Type: ${currentAdapter.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _tableKey,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: <DropdownMenuItem<String>>[
                        for (final _MaterialTypeAdapter adapter
                            in widget.adapters)
                          DropdownMenuItem<String>(
                            value: adapter.tableKey,
                            child: Text(adapter.label),
                          ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _tableKey = value);
                        }
                      },
                    ),
                  ),
                AppTextField(
                  label: 'Material Name',
                  controller: _nameController,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Material name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Material Code',
                  controller: _codeController,
                  hint: 'e.g. PIG-0001',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Material code is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'CAS Number (optional)',
                  controller: _casController,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Supplier (optional)',
                  controller: _supplierController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Unit',
                        controller: _unitController,
                        hint: 'g',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Cost / Unit',
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Stock Quantity',
                  controller: _stockController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (isEditing) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Created: ${existing?.createdAt?.toString().split('.').first ?? 'Unknown'}\n'
                    'Modified: ${existing?.updatedAt?.toString().split('.').first ?? 'Unknown'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: isEditing ? 'Save Changes' : 'Add Material',
                  expand: true,
                  onPressed: _handleSave,
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
