/// Purpose      : Shade Management screen — create, list, edit,
///                soft-delete, and restore Shade_Master records.
/// Author       : HMEOS Engineering
/// Version      : 1.0.1
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/shade_repository.dart,
///                repositories/product_repository.dart,
///                repositories/repository_exception.dart,
///                models/shade_model.dart, models/product_model.dart,
///                widgets/*
/// Description  : Pushed route (see AppRoutes.shadeManagement), not a
///                bottom tab — same rationale as every other R1-R4
///                management screen: the frozen 5-tab shell
///                (SPR-DEP-002) is untouched. Reached from Home's
///                "Manage Shades" quick action (shows every shade) or
///                from a product row in ProductManagementScreen's
///                "View Shades" action (opens with that product
///                pre-selected). Talks to ShadeRepository/
///                ProductRepository only, through ServiceLocator —
///                never SQLite directly. Fills the R4-001 gap: R4
///                found ShadeRepository.create() was never called
///                anywhere in the app.
///
///                Field mapping (brief vs. actual Shade_Master
///                schema, confirmed by reading database_helper.dart
///                directly, not assumed):
///                - Product, Shade Name, Shade Code, Finish, Status,
///                  Created Date, Modified Date: all real columns,
///                  shown/edited as-is.
///                - "Pantone": no such column exists. The closest
///                  real field is `hex_color` ("Colour (Hex)"), shown
///                  honestly under its real name — not relabeled
///                  "Pantone", which would misrepresent what's
///                  actually stored.
///                - "Coverage" and "Description": no such columns
///                  exist anywhere in Shade_Master, and no other
///                  column is a plausible stand-in (unlike hex_color
///                  for Pantone). Both are omitted rather than
///                  invented — see the R5 report's Known Issues.
///                - `shade_family` (a real column, already surfaced
///                  elsewhere in the app — Formula Details, Search)
///                  is included even though the brief's field list
///                  didn't name it, since hiding a real, already-used
///                  field would be an arbitrary omission.
///                - Restore: BaseSqliteRepository has no dedicated
///                  restore() method, and none was added — update()
///                  already writes every field including `is_active`
///                  (confirmed by reading its implementation), so
///                  Restore is exactly update(shade.copyWith(
///                  isActive: true)). No repository change needed.
/// Change History:
///   1.0.0 - Repair Sprint R5 (Missing Business Modules) - Initial
///           creation.
///   1.0.1 - CI Compatibility Repair - `DropdownButtonFormField`'s
///           `value:` renamed to `initialValue:` (Flutter 3.34+
///           deprecated `value:` in favor of it) — first real
///           `flutter analyze` run (GitHub Actions) surfaced this;
///           no behavior change, same widget, same reactivity. All
///           4 dropdowns in this file affected (Product filter,
///           form Product, Finish, Status).
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../models/product_model.dart';
import '../models/shade_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/search_box.dart';

/// Arguments for [AppRoutes.shadeManagement]. Omit entirely to show
/// every shade; set `productId` to pre-select that product's filter
/// (still changeable afterward), matching the pattern already
/// established for AppRoutes.formulaList.
class ShadeManagementScreenArgs {
  const ShadeManagementScreenArgs({this.productId});
  final int? productId;
}

const List<String> kShadeStatusOptions = <String>[
  'draft',
  'in_review',
  'approved',
];

enum _ActiveFilter { active, inactive, all }

/// Shade Management screen: list, add, edit, soft-delete, restore.
class ShadeManagementScreen extends StatefulWidget {
  const ShadeManagementScreen({
    this.args = const ShadeManagementScreenArgs(),
    super.key,
  });

  final ShadeManagementScreenArgs args;

  @override
  State<ShadeManagementScreen> createState() => _ShadeManagementScreenState();
}

class _ShadeManagementScreenState extends State<ShadeManagementScreen> {
  late final ShadeRepository _shadeRepository;
  late final ProductRepository _productRepository;
  late final Future<List<ProductModel>> _productsFuture;
  late Future<List<ShadeModel>> _shadesFuture;

  String _query = '';
  late int? _productFilterId;
  _ActiveFilter _activeFilter = _ActiveFilter.active;

  @override
  void initState() {
    super.initState();
    _shadeRepository = ServiceLocator.instance.get<ShadeRepository>();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _productFilterId = widget.args.productId;
    _productsFuture = _productRepository.readAll();
    _shadesFuture = _loadShades();
  }

  Future<List<ShadeModel>> _loadShades() async {
    try {
      final String query = _query.trim();
      final bool includeInactive = _activeFilter != _ActiveFilter.active;
      List<ShadeModel> shades = query.isEmpty
          ? await _shadeRepository.readAll(includeInactive: includeInactive)
          : await _shadeRepository.search(
              query,
              columns: const <String>['name', 'shade_code', 'shade_family'],
            );
      // search() has no includeInactive parameter (always active-only —
      // confirmed by reading base_repository.dart), so an Inactive/All
      // view combined with a search term can only honestly show active
      // matches; that's a real limitation of the existing search(), not
      // one this screen tries to paper over. See the R5 report.

      if (_activeFilter == _ActiveFilter.inactive) {
        shades = shades.where((ShadeModel s) => !s.isActive).toList();
      }

      final int? filterId = _productFilterId;
      if (filterId != null) {
        shades = shades.where((ShadeModel s) => s.productId == filterId).toList();
      }
      return shades;
    } on RepositoryException {
      return const <ShadeModel>[];
    }
  }

  void _refresh() {
    setState(() {
      _shadesFuture = _loadShades();
    });
  }

  void _handleQueryChanged(String value) {
    setState(() {
      _query = value;
      _shadesFuture = _loadShades();
    });
  }

  void _handleProductFilterChanged(int? productId) {
    setState(() {
      _productFilterId = productId;
      _shadesFuture = _loadShades();
    });
  }

  void _handleActiveFilterChanged(_ActiveFilter filter) {
    setState(() {
      _activeFilter = filter;
      _shadesFuture = _loadShades();
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

  Future<void> _openForm({ShadeModel? existing}) async {
    final List<ProductModel> products = await _productsFuture;
    if (!mounted) {
      return;
    }
    final ShadeModel? result = await showModalBottomSheet<ShadeModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShadeFormSheet(
        existing: existing,
        products: products,
        initialProductId: existing?.productId ?? _productFilterId,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      if (existing == null) {
        await _shadeRepository.create(result);
        _showMessage('Shade created.');
      } else {
        await _shadeRepository.update(result);
        _showMessage('Shade updated.');
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

  Future<void> _handleDelete(ShadeModel shade) async {
    final int? id = shade.id;
    if (id == null) {
      return;
    }
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Shade?',
      message: 'This hides "${shade.name}" from active shade lists. It '
          'can be restored later from the Inactive view.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _shadeRepository.softDelete(id);
      if (!mounted) {
        return;
      }
      _showMessage('Shade deleted.');
      _refresh();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(context, message: error.message);
    }
  }

  Future<void> _handleRestore(ShadeModel shade) async {
    try {
      await _shadeRepository.update(shade.copyWith(isActive: true));
      if (!mounted) {
        return;
      }
      _showMessage('Shade restored.');
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
      appBar: AppBar(title: const Text('Manage Shades')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add Shade',
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
            const SizedBox(height: 8),
            FutureBuilder<List<ProductModel>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                final List<ProductModel> products =
                    snapshot.data ?? const <ProductModel>[];
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
            SearchBox(hint: 'Search shades', onChanged: _handleQueryChanged),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<ShadeModel>>(
                future: _shadesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  final List<ShadeModel> shades =
                      snapshot.data ?? const <ShadeModel>[];
                  if (shades.isEmpty) {
                    return Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'No shades found. Tap + to add one.'
                            : 'No shades match "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: shades.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ShadeModel shade = shades[index];
                      return _ShadeCard(
                        shade: shade,
                        onTap: () => _openForm(existing: shade),
                        onDelete: () => _handleDelete(shade),
                        onRestore: () => _handleRestore(shade),
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

class _ShadeCard extends StatelessWidget {
  const _ShadeCard({
    required this.shade,
    required this.onTap,
    required this.onDelete,
    required this.onRestore,
  });

  final ShadeModel shade;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: shade.isActive ? onTap : null,
      child: Row(
        children: <Widget>[
          if (shade.hexColor != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ColorSwatch(hex: shade.hexColor!),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(shade.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${shade.shadeCode} · ${shade.status}'
                  '${shade.isActive ? '' : ' · inactive'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (shade.isActive)
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

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});
  final String hex;

  @override
  Widget build(BuildContext context) {
    final Color? color = _parseHexColor(hex);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }

  static Color? _parseHexColor(String hex) {
    String cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8) {
      return null;
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(value);
  }
}

class _ShadeFormSheet extends StatefulWidget {
  const _ShadeFormSheet({
    required this.products,
    this.existing,
    this.initialProductId,
  });

  final ShadeModel? existing;
  final List<ProductModel> products;
  final int? initialProductId;

  @override
  State<_ShadeFormSheet> createState() => _ShadeFormSheetState();
}

class _ShadeFormSheetState extends State<_ShadeFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shadeCodeController;
  late final TextEditingController _hexColorController;
  late final TextEditingController _shadeFamilyController;
  int? _selectedProductId;
  String? _finish;
  late String _status;

  @override
  void initState() {
    super.initState();
    final ShadeModel? existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _shadeCodeController = TextEditingController(
      text: existing?.shadeCode ?? '',
    );
    _hexColorController = TextEditingController(
      text: existing?.hexColor ?? '',
    );
    _shadeFamilyController = TextEditingController(
      text: existing?.shadeFamily ?? '',
    );
    _selectedProductId = existing?.productId ?? widget.initialProductId;
    _finish = existing?.finish;
    _status = existing?.status ?? kShadeStatusOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shadeCodeController.dispose();
    _hexColorController.dispose();
    _shadeFamilyController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final ShadeModel? existing = widget.existing;
    final String hexColor = _hexColorController.text.trim();
    final String shadeFamily = _shadeFamilyController.text.trim();

    final ShadeModel result = ShadeModel(
      id: existing?.id,
      name: _nameController.text.trim(),
      shadeCode: _shadeCodeController.text.trim(),
      productId: _selectedProductId,
      hexColor: hexColor.isEmpty ? null : hexColor,
      shadeFamily: shadeFamily.isEmpty ? null : shadeFamily,
      finish: _finish,
      status: _status,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    final ShadeModel? existing = widget.existing;

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
                  isEditing ? 'Edit Shade' : 'Add Shade',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Shade Name',
                  controller: _nameController,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Shade name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Shade Code',
                  controller: _shadeCodeController,
                  hint: 'e.g. SH-0001',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Shade code is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Product (optional)',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No product linked'),
                    ),
                    for (final ProductModel product in widget.products)
                      if (product.id != null)
                        DropdownMenuItem<int?>(
                          value: product.id,
                          child: Text(product.name),
                        ),
                  ],
                  onChanged: (int? value) =>
                      setState(() => _selectedProductId = value),
                ),
                const SizedBox(height: 12),
                // "Pantone" per the brief has no column in Shade_Master
                // — hex_color is the closest real field, shown under
                // its actual name rather than relabeled.
                AppTextField(
                  label: 'Colour (Hex)',
                  controller: _hexColorController,
                  hint: 'e.g. #B5384D',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Shade Family (optional)',
                  controller: _shadeFamilyController,
                  hint: 'e.g. Red, Nude, Glitter',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _finish,
                  decoration: const InputDecoration(
                    labelText: 'Finish (optional)',
                  ),
                  items: const <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(value: null, child: Text('—')),
                    DropdownMenuItem<String?>(
                      value: 'Glossy',
                      child: Text('Glossy'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Matte',
                      child: Text('Matte'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Shimmer',
                      child: Text('Shimmer'),
                    ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _finish = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: <DropdownMenuItem<String>>[
                    for (final String status in kShadeStatusOptions)
                      DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
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
                  label: isEditing ? 'Save Changes' : 'Add Shade',
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
