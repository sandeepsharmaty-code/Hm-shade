/// Purpose      : Product Management screen — create, list, edit, and
///                soft-delete Product_Master records.
/// Author       : HMEOS Engineering
/// Version      : 1.2.1
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                core/routing/app_routes.dart,
///                repositories/product_repository.dart,
///                repositories/repository_exception.dart,
///                models/product_model.dart,
///                screens/formula_list_screen.dart,
///                screens/shade_management_screen.dart, widgets/*
/// Description  : Pushed route (see AppRoutes.productManagement), not
///                a bottom tab — the approved 5-tab shell
///                (SPR-DEP-002) stays exactly as frozen. Reached from
///                HomeScreen's "Manage Products" quick action. Talks
///                to ProductRepository only (create/readAll/update/
///                softDelete/search), through ServiceLocator — this
///                screen never touches SQLite or writes raw SQL.
///                Fills the gap identified in the repair brief: the
///                Repository/Model/Database layers for Product_Master
///                were already complete, but no screen existed to
///                create records, so Dashboard showed "Products = 0"
///                and New Shade showed "No products exist yet."
/// Change History:
///   1.0.0 - Repair Sprint R1 - Initial creation. List (with search),
///           Add, Edit, and Soft Delete, all through the existing
///           ProductRepository and existing shared widgets.
///   1.0.1 - Repair Sprint R1 Verification - Fixed a widget-lifecycle
///           bug caught in manual code review: _openForm() and
///           _handleDelete() called setState() (via _refresh()) after
///           an await without rechecking `mounted` first, risking
///           "setState() called after dispose()" if the screen were
///           popped while the create/update/softDelete call was in
///           flight. Both now recheck `mounted` immediately after
///           that await, matching the pattern already established in
///           trial_screen.dart.
///   1.1.0 - Repair Sprint R2 (Formula Workflow) - Added a "View
///           Formulas" icon button per product row, pushing
///           AppRoutes.formulaList with that product's id (R2-008:
///           "Selecting a Product should show only its formulas").
///           The existing card tap (-> Edit Product) is unchanged.
///   1.2.0 - Repair Sprint R5 (Missing Business Modules) - Added a
///           "View Shades" icon button per product row, pushing
///           AppRoutes.shadeManagement with that product's id — same
///           pattern as "View Formulas" above.
///   1.2.1 - CI Compatibility Repair - `DropdownButtonFormField`'s
///           `value:` renamed to `initialValue:` (Flutter 3.34+
///           deprecated `value:` in favor of it) — first real
///           `flutter analyze` run (GitHub Actions) surfaced this;
///           no behavior change, same widget, same reactivity.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/search_box.dart';
import 'formula_list_screen.dart';
import 'shade_management_screen.dart';

/// The approved product categories, as documented on
/// [ProductModel.category] — the fixed list this screen's category
/// dropdown offers so every record stays within the approved set.
const List<String> kApprovedProductCategories = <String>[
  'Nail Polish',
  'Lipstick',
  'Lip Balm',
  'Kajal',
  'Mascara',
  'Foundation',
  'Concealer',
  'Highlighter',
  'Blush',
  'Eyeshadow',
  'Lip Liner',
  'Eyeliner',
  'BB Cream',
  'CC Cream',
  'Color Corrector',
  'Glitter & Metallic Cosmetics',
];

/// Product Management screen: list, add, edit, and soft-delete
/// Product_Master records.
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  late final ProductRepository _productRepository;
  late Future<List<ProductModel>> _productsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _productsFuture = _loadProducts();
  }

 Future<List<ProductModel>> _loadProducts() async {
    final String query = _query.trim();

    final List<ProductModel> result = query.isEmpty
        ? await _productRepository.readAll()
        : await _productRepository.search(
            query,
            columns: const <String>[
              'name',
              'product_code',
              'category',
            ],
          );

    return result;
  }
  void _refresh() {
    setState(() => _productsFuture = _loadProducts());
  }

  void _handleQueryChanged(String value) {
    setState(() {
      _recordsFuture = _loadRecords();
    });

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({ProductModel? existing}) async {
    final ProductModel? result = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductFormSheet(existing: existing),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      if (existing == null) {
        await _productRepository.create(result);
      } else {
        await _productRepository.update(result);
      }
      if (!mounted) {
        return;
      }
      _showMessage(existing == null ? 'Product created.' : 'Product updated.');
      _refresh();
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(context, message: error.message);
    }
  }

  Future<void> _openShades(ProductModel product) async {
    final int? id = product.id;
    if (id == null) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.shadeManagement,
      arguments: ShadeManagementScreenArgs(productId: id),
    );
  }

  Future<void> _openFormulas(ProductModel product) async {
    final int? id = product.id;
    if (id == null) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.formulaList,
      arguments: FormulaListScreenArgs(productId: id),
    );
  }

  Future<void> _handleDelete(ProductModel product) async {
    final int? id = product.id;
    if (id == null) {
      return;
    }
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Product?',
      message:
          'This removes "${product.name}" from active product lists. '
          'Existing shades and formulas that already reference it are '
          'unaffected.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _productRepository.softDelete(id);
      if (!mounted) {
        return;
      }
      _showMessage('Product deleted.');
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SearchBox(
              hint: 'Search products',
              onChanged: _handleQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<ProductModel>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load products.'),
                    );
                  }
                  final List<ProductModel> products =
                      snapshot.data ?? const <ProductModel>[];
                  if (products.isEmpty) {
                    return Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'No products exist yet. Tap + to add one.'
                            : 'No products match "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ProductModel product = products[index];
                      return AppCard(
                        onTap: () => _openForm(existing: product),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    product.name,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${product.productCode} · ${product.category}',
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
                            IconButton(
                              icon: const Icon(Icons.palette_outlined),
                              tooltip: 'View Shades',
                              onPressed: () => _openShades(product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.science_outlined),
                              tooltip: 'View Formulas',
                              onPressed: () => _openFormulas(product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _handleDelete(product),
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
      ),
    );
  }
}

/// Add/Edit form for a single [ProductModel], shown as a modal bottom
/// sheet. Returns the built [ProductModel] via [Navigator.pop] on
/// save, or null if dismissed — [_ProductManagementScreenState] owns
/// the actual create()/update() repository call.
class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({this.existing});

  final ProductModel? existing;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _productCodeController;
  late final TextEditingController _baseTypeController;
  late final TextEditingController _descriptionController;
  String? _category;

  @override
  void initState() {
    super.initState();
    final ProductModel? existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _productCodeController = TextEditingController(
      text: existing?.productCode ?? '',
    );
    _baseTypeController = TextEditingController(
      text: existing?.baseType ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _category = existing?.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productCodeController.dispose();
    _baseTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final ProductModel? existing = widget.existing;
    final String baseType = _baseTypeController.text.trim();
    final String description = _descriptionController.text.trim();

    final ProductModel result = ProductModel(
      id: existing?.id,
      name: _nameController.text.trim(),
      productCode: _productCodeController.text.trim(),
      category: _category!,
      baseType: baseType.isEmpty ? null : baseType,
      description: description.isEmpty ? null : description,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;

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
                  isEditing ? 'Edit Product' : 'Add Product',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Name',
                  controller: _nameController,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Product Code',
                  controller: _productCodeController,
                  hint: 'e.g. NP-001',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Product code is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: <DropdownMenuItem<String>>[
                    for (final String category in kApprovedProductCategories)
                      DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Category is required.' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Base Type (optional)',
                  controller: _baseTypeController,
                  hint: 'e.g. Water-Based, Solvent-Based',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Description (optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: isEditing ? 'Save Changes' : 'Add Product',
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
