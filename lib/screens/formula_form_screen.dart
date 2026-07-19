/// Purpose      : Formula create/edit screen — Trial_Formula fields
///                plus a dynamic Formula_Material ingredients editor.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                repositories/product_repository.dart,
///                repositories/shade_repository.dart,
///                repositories/trial_repository.dart,
///                repositories/{pigment,dye,mica,pearl,filler,binder}
///                _repository.dart, repositories/repository_exception.dart,
///                models/*, widgets/*
/// Description  : Pushed route (see AppRoutes.formulaEdit). Handles
///                Create (R2-004), Edit (R2-005), and — R3 — Create
///                Revision (R3-008) — `args.existingTrialFormulaId`
///                null means create. `args.productId` optionally
///                pre-selects a product (R2-008). `args.
///                duplicateFromTrialFormulaId` (R3-008) pre-fills a
///                brand-new record from an existing (typically
///                approved) formula's name/product/shade/notes/
///                ingredients — it is still a create(), never an
///                update() of the source, so "Do NOT overwrite
///                approved production data" holds by construction:
///                the source Trial_Formula/Formula_Material rows are
///                only ever read here, never written. Product
///                selection drives the Shade dropdown via the
///                existing ShadeRepository.findByProduct() (no
///                repository change needed there). Ingredient lines
///                are backed by TrialRepository's existing
///                addMaterialLine/removeMaterialLine plus
///                updateMaterialLine (see trial_repository.dart's
///                v1.1.0 change note — unchanged in R3). `status` is
///                never edited here — status only moves via
///                ITrialWorkflowManager.transition() or
///                TrialRepository.approveTrial(), from
///                FormulaDetailsScreen, so every status change stays
///                audited. Saves through TrialRepository only — no
///                SQLite, no schema changes.
/// Change History:
///   1.0.0 - Repair Sprint R2 (Formula Workflow) - Initial creation.
///   2.0.0 - Repair Sprint R3 (Approved Formula Workflow) - Added
///           `duplicateFromTrialFormulaId` / Create Revision mode
///           (R3-008). No change to Create/Edit behavior otherwise.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../models/formula_material_model.dart';
import '../models/product_model.dart';
import '../models/raw_material_model.dart';
import '../models/shade_model.dart';
import '../models/trial_formula_model.dart';
import '../models/trial_status.dart';
import '../repositories/binder_repository.dart';
import '../repositories/dye_repository.dart';
import '../repositories/filler_repository.dart';
import '../repositories/mica_repository.dart';
import '../repositories/pearl_repository.dart';
import '../repositories/pigment_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/shade_repository.dart';
import '../repositories/trial_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';

/// Arguments for [AppRoutes.formulaEdit]. All fields are optional:
/// - `existingTrialFormulaId` set -> Edit mode.
/// - `existingTrialFormulaId` null, `productId` set -> Create mode
///   with the product pre-selected (R2-008).
/// - `existingTrialFormulaId` null, `duplicateFromTrialFormulaId` set
///   -> Create Revision mode (R3-008): a new record pre-filled from
///   the referenced formula. Ignored if `existingTrialFormulaId` is
///   also set (Edit takes precedence).
/// - All null -> plain Create mode.
class FormulaFormScreenArgs {
  const FormulaFormScreenArgs({
    this.existingTrialFormulaId,
    this.productId,
    this.duplicateFromTrialFormulaId,
  });
  final int? existingTrialFormulaId;
  final int? productId;
  final int? duplicateFromTrialFormulaId;
}

const Map<String, String> _kMaterialTableLabels = <String, String>{
  'Pigment_Master': 'Pigment',
  'Dye_Master': 'Dye',
  'Mica_Master': 'Mica',
  'Pearl_Master': 'Pearl',
  'Filler_Master': 'Filler',
  'Binder_Master': 'Binder',
};

/// Mutable draft of one ingredient line while the form is open. Wraps
/// [FormulaMaterialModel] fields with the TextEditingControllers the
/// UI needs; converted back to a model on save.
class _MaterialLineDraft {
  _MaterialLineDraft({
    required this.materialTable,
    required this.materialId,
    required this.materialName,
    this.id,
    double percentage = 0,
    String? notes,
  })  : percentageController = TextEditingController(
          text: percentage == 0 ? '' : _trimTrailingZeros(percentage),
        ),
        notesController = TextEditingController(text: notes ?? '');

  final int? id;
  final String materialTable;
  final int materialId;
  final String materialName;
  final TextEditingController percentageController;
  final TextEditingController notesController;

  static String _trimTrailingZeros(double value) {
    String text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  void dispose() {
    percentageController.dispose();
    notesController.dispose();
  }
}

/// Formula create/edit screen.
class FormulaFormScreen extends StatefulWidget {
  const FormulaFormScreen({required this.args, super.key});

  final FormulaFormScreenArgs args;

  @override
  State<FormulaFormScreen> createState() => _FormulaFormScreenState();
}

class _FormulaFormScreenState extends State<FormulaFormScreen> {
  late final TrialRepository _trialRepository;
  late final ProductRepository _productRepository;
  late final ShadeRepository _shadeRepository;
  late final PigmentRepository _pigmentRepository;
  late final DyeRepository _dyeRepository;
  late final MicaRepository _micaRepository;
  late final PearlRepository _pearlRepository;
  late final FillerRepository _fillerRepository;
  late final BinderRepository _binderRepository;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _trialCodeController;
  late final TextEditingController _notesController;
  late final Future<void> _bootstrapFuture;

  bool _isSaving = false;

  TrialFormulaModel? _existingTrial;
  List<ProductModel> _products = const <ProductModel>[];
  List<ShadeModel> _shades = const <ShadeModel>[];
  Map<String, List<RawMaterialModel>> _materialCatalog =
      const <String, List<RawMaterialModel>>{};
  final List<_MaterialLineDraft> _lines = <_MaterialLineDraft>[];
  final List<int> _removedLineIds = <int>[];

  int? _selectedProductId;
  int? _selectedShadeId;

  @override
  void initState() {
    super.initState();
    _trialRepository = ServiceLocator.instance.get<TrialRepository>();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _shadeRepository = ServiceLocator.instance.get<ShadeRepository>();
    _pigmentRepository = ServiceLocator.instance.get<PigmentRepository>();
    _dyeRepository = ServiceLocator.instance.get<DyeRepository>();
    _micaRepository = ServiceLocator.instance.get<MicaRepository>();
    _pearlRepository = ServiceLocator.instance.get<PearlRepository>();
    _fillerRepository = ServiceLocator.instance.get<FillerRepository>();
    _binderRepository = ServiceLocator.instance.get<BinderRepository>();

    _nameController = TextEditingController();
    _trialCodeController = TextEditingController();
    _notesController = TextEditingController();
    _selectedProductId = widget.args.productId;

    _bootstrapFuture = _bootstrap();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _trialCodeController.dispose();
    _notesController.dispose();
    for (final _MaterialLineDraft line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final List<Object> baseResults = await Future.wait<Object>(<
        Future<Object>>[
      _productRepository.readAll(),
      _pigmentRepository.readAll(),
      _dyeRepository.readAll(),
      _micaRepository.readAll(),
      _pearlRepository.readAll(),
      _fillerRepository.readAll(),
      _binderRepository.readAll(),
    ]);

    _products = baseResults[0] as List<ProductModel>;
    _materialCatalog = <String, List<RawMaterialModel>>{
      'Pigment_Master': baseResults[1] as List<RawMaterialModel>,
      'Dye_Master': baseResults[2] as List<RawMaterialModel>,
      'Mica_Master': baseResults[3] as List<RawMaterialModel>,
      'Pearl_Master': baseResults[4] as List<RawMaterialModel>,
      'Filler_Master': baseResults[5] as List<RawMaterialModel>,
      'Binder_Master': baseResults[6] as List<RawMaterialModel>,
    };

    final int? existingId = widget.args.existingTrialFormulaId;
    final int? duplicateFromId = widget.args.duplicateFromTrialFormulaId;
    if (existingId != null) {
      final TrialFormulaModel? trial = await _trialRepository.readById(
        existingId,
        includeInactive: true,
      );
      if (trial == null) {
        throw RepositoryException(
          message: 'Formula $existingId was not found.',
          operation: 'readById',
        );
      }
      _existingTrial = trial;
      _nameController.text = trial.name;
      _trialCodeController.text = trial.trialCode;
      _notesController.text = trial.notes ?? '';
      _selectedProductId = trial.productId;
      _selectedShadeId = trial.shadeId;

      final List<FormulaMaterialModel> existingLines =
          await _trialRepository.materialsForTrial(existingId);
      for (final FormulaMaterialModel line in existingLines) {
        _lines.add(
          _MaterialLineDraft(
            id: line.id,
            materialTable: line.materialTable,
            materialId: line.materialId,
            materialName: (line.name?.trim().isNotEmpty ?? false)
                ? line.name!
                : '${_kMaterialTableLabels[line.materialTable] ?? line.materialTable} #${line.materialId}',
            percentage: line.percentage,
            notes: line.notes,
          ),
        );
      }
    } else if (duplicateFromId != null) {
      // R3-008: Create Revision. This is still a create() below
      // (_existingTrial stays null) — the source row and its
      // Formula_Material lines are only ever read here, never
      // written, so the approved production data this was opened
      // from cannot be overwritten by this screen.
      final TrialFormulaModel? source = await _trialRepository.readById(
        duplicateFromId,
        includeInactive: true,
      );
      if (source == null) {
        throw RepositoryException(
          message: 'Formula $duplicateFromId was not found.',
          operation: 'readById',
        );
      }
      _nameController.text = '${source.name} (Revision)';
      // Trial Code is deliberately left blank: this project enforces
      // no uniqueness constraint on trial_code at the database level
      // (see database_helper.dart's Trial_Formula columns), so rather
      // than guess a numbering scheme that might collide, the user
      // supplies a new one.
      _notesController.text = <String>[
        'Revision of ${source.trialCode}.',
        if ((source.notes ?? '').trim().isNotEmpty) source.notes!.trim(),
      ].join('\n\n');
      _selectedProductId = source.productId;
      _selectedShadeId = source.shadeId;

      final List<FormulaMaterialModel> sourceLines = await _trialRepository
          .materialsForTrial(duplicateFromId);
      for (final FormulaMaterialModel line in sourceLines) {
        _lines.add(
          _MaterialLineDraft(
            // id intentionally omitted (null): every line becomes a
            // brand-new Formula_Material row via addMaterialLine() on
            // save, never updateMaterialLine() against the source's
            // rows.
            materialTable: line.materialTable,
            materialId: line.materialId,
            materialName: (line.name?.trim().isNotEmpty ?? false)
                ? line.name!
                : '${_kMaterialTableLabels[line.materialTable] ?? line.materialTable} #${line.materialId}',
            percentage: line.percentage,
            notes: line.notes,
          ),
        );
      }
    }

    if (_selectedProductId != null) {
      _shades = await _shadeRepository.findByProduct(_selectedProductId!);
    }

    // Defensive: if the formula's linked product or shade was
    // soft-deleted after this formula was created, it won't appear
    // in the active-only lists above, but _selectedProductId/
    // _selectedShadeId still point at it — DropdownButtonFormField
    // asserts that a non-null `value` must match an item in `items`,
    // so append the missing record (read with includeInactive) if
    // needed, exactly the same defense applied to ingredient lines
    // above and in _IngredientEditorSheetState._materialsForSelectedTable.
    final int? productId = _selectedProductId;
    if (productId != null &&
        !_products.any((ProductModel p) => p.id == productId)) {
      final ProductModel? missing = await _productRepository.readById(
        productId,
        includeInactive: true,
      );
      if (missing != null) {
        _products = <ProductModel>[..._products, missing];
      }
    }
    final int? shadeId = _selectedShadeId;
    if (shadeId != null && !_shades.any((ShadeModel s) => s.id == shadeId)) {
      final ShadeModel? missing = await _shadeRepository.readById(
        shadeId,
        includeInactive: true,
      );
      if (missing != null) {
        _shades = <ShadeModel>[..._shades, missing];
      }
    }
  }

  Future<void> _handleProductChanged(int? productId) async {
    setState(() {
      _selectedProductId = productId;
      _selectedShadeId = null;
      _shades = const <ShadeModel>[];
    });
    if (productId == null) {
      return;
    }
    try {
      final List<ShadeModel> shades = await _shadeRepository.findByProduct(
        productId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _shades = shades);
    } on RepositoryException {
      // Leave the shade list empty; the product itself was already
      // read successfully during bootstrap, so this is a transient
      // read failure, not a reason to block the form.
    }
  }

  Future<void> _addIngredient() async {
    final _MaterialLineDraft? draft = await showModalBottomSheet<
        _MaterialLineDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IngredientEditorSheet(catalog: _materialCatalog),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() => _lines.add(draft));
  }

  Future<void> _editIngredient(int index) async {
    final _MaterialLineDraft current = _lines[index];
    final _MaterialLineDraft? draft = await showModalBottomSheet<
        _MaterialLineDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IngredientEditorSheet(
        catalog: _materialCatalog,
        existing: current,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _lines[index] = draft;
    });
    current.dispose();
  }

  void _removeIngredient(int index) {
    final _MaterialLineDraft removed = _lines.removeAt(index);
    if (removed.id != null) {
      _removedLineIds.add(removed.id!);
    }
    setState(() {});
    removed.dispose();
  }

  double get _totalPercentage => _lines.fold<double>(
        0,
        (double sum, _MaterialLineDraft line) =>
            sum + (double.tryParse(line.percentageController.text.trim()) ?? 0),
      );

  Future<void> _handleSave() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final TrialFormulaModel trial = TrialFormulaModel(
        id: _existingTrial?.id,
        name: _nameController.text.trim(),
        trialCode: _trialCodeController.text.trim(),
        shadeId: _selectedShadeId,
        productId: _selectedProductId,
        status: _existingTrial?.status ?? TrialStatus.draft.storageKey,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isActive: _existingTrial?.isActive ?? true,
        createdAt: _existingTrial?.createdAt,
        updatedAt: _existingTrial?.updatedAt,
      );

      final TrialFormulaModel saved = _existingTrial == null
          ? await _trialRepository.create(trial)
          : await _trialRepository.update(trial);
      final int? trialId = saved.id;
      if (trialId == null) {
        throw const RepositoryException(
          message: 'Formula was saved but has no id.',
          operation: 'create',
        );
      }

      for (final int removedId in _removedLineIds) {
        await _trialRepository.removeMaterialLine(removedId);
      }
      for (final _MaterialLineDraft line in _lines) {
        final double percentage =
            double.tryParse(line.percentageController.text.trim()) ?? 0;
        final String noteText = line.notesController.text.trim();
        final FormulaMaterialModel material = FormulaMaterialModel(
          id: line.id,
          trialFormulaId: trialId,
          materialTable: line.materialTable,
          materialId: line.materialId,
          name: line.materialName,
          percentage: percentage,
          notes: noteText.isEmpty ? null : noteText,
        );
        if (line.id == null) {
          await _trialRepository.addMaterialLine(material);
        } else {
          await _trialRepository.updateMaterialLine(material);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
    } on RepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      await ErrorDialog.show(context, message: error.message);
    }
  }

  Future<void> _handleCancel() async {
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Discard Changes?',
      message: 'Any unsaved changes to this formula will be lost.',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.args.existingTrialFormulaId != null;
    final bool isRevision = !isEditing &&
        widget.args.duplicateFromTrialFormulaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Formula'
              : isRevision
                  ? 'Create Revision'
                  : 'Add Formula',
        ),
      ),
      body: FutureBuilder<void>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Unable to load formula data.'),
              ),
            );
          }
          return _buildForm(context, isEditing, isRevision);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isEditing, bool isRevision) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppTextField(
            label: 'Formula Name',
            controller: _nameController,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Name is required.'
                : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Trial Code',
            controller: _trialCodeController,
            hint: 'e.g. TRL-0001',
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Trial code is required.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedProductId,
            decoration: const InputDecoration(labelText: 'Product'),
            items: <DropdownMenuItem<int>>[
              for (final ProductModel product in _products)
                if (product.id != null)
                  DropdownMenuItem<int>(
                    value: product.id,
                    child: Text(product.name),
                  ),
            ],
            onChanged: _handleProductChanged,
            validator: (value) => value == null ? 'Product is required.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _selectedShadeId,
            decoration: const InputDecoration(labelText: 'Shade (optional)'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(value: null, child: Text('No shade')),
              for (final ShadeModel shade in _shades)
                if (shade.id != null)
                  DropdownMenuItem<int?>(
                    value: shade.id,
                    child: Text(shade.name),
                  ),
            ],
            onChanged: (int? value) => setState(() => _selectedShadeId = value),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Notes (optional)',
            controller: _notesController,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_totalPercentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lines.isEmpty)
            const AppCard(child: Text('No ingredients added yet.'))
          else
            for (int i = 0; i < _lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IngredientLineCard(
                  line: _lines[i],
                  onTap: () => _editIngredient(i),
                  onRemove: () => _removeIngredient(i),
                ),
              ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Add Ingredient',
            icon: Icons.add,
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: _addIngredient,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: isEditing
                ? 'Save Changes'
                : isRevision
                    ? 'Create Revision'
                    : 'Create Formula',
            expand: true,
            isLoading: _isSaving,
            onPressed: _handleSave,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: _handleCancel,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _IngredientLineCard extends StatelessWidget {
  const _IngredientLineCard({
    required this.line,
    required this.onTap,
    required this.onRemove,
  });

  final _MaterialLineDraft line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String tableLabel =
        _kMaterialTableLabels[line.materialTable] ?? line.materialTable;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.materialName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: line.percentageController,
                  builder: (context, value, _) => Text(
                    '$tableLabel · ${value.text.isEmpty ? '0' : value.text}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for adding or editing one ingredient line.
class _IngredientEditorSheet extends StatefulWidget {
  const _IngredientEditorSheet({required this.catalog, this.existing});

  final Map<String, List<RawMaterialModel>> catalog;
  final _MaterialLineDraft? existing;

  @override
  State<_IngredientEditorSheet> createState() =>
      _IngredientEditorSheetState();
}

class _IngredientEditorSheetState extends State<_IngredientEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _percentageController;
  late final TextEditingController _notesController;
  String? _selectedTable;
  int? _selectedMaterialId;

  @override
  void initState() {
    super.initState();
    final _MaterialLineDraft? existing = widget.existing;
    _selectedTable = existing?.materialTable ??
        (widget.catalog.keys.isEmpty ? null : widget.catalog.keys.first);
    _selectedMaterialId = existing?.materialId;
    _percentageController = TextEditingController(
      text: existing?.percentageController.text ?? '',
    );
    _notesController = TextEditingController(
      text: existing?.notesController.text ?? '',
    );
  }

  @override
  void dispose() {
    _percentageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Active materials in the selected table, plus the currently
  /// selected material even if it has since gone inactive — without
  /// this, editing an existing line whose material was deactivated
  /// after the fact would leave `_selectedMaterialId` pointing at an
  /// id absent from `items`, which DropdownButtonFormField asserts
  /// against (crashes in debug/test builds).
  List<RawMaterialModel> get _materialsForSelectedTable {
    final String? table = _selectedTable;
    if (table == null) {
      return const <RawMaterialModel>[];
    }
    final int? selectedId = _selectedMaterialId;
    return (widget.catalog[table] ?? const <RawMaterialModel>[])
        .where((RawMaterialModel m) => m.isActive || m.id == selectedId)
        .toList();
  }

  void _handleSave() {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final String? table = _selectedTable;
    final int? materialId = _selectedMaterialId;
    if (table == null || materialId == null) {
      return;
    }
    RawMaterialModel? material;
    for (final RawMaterialModel candidate in _materialsForSelectedTable) {
      if (candidate.id == materialId) {
        material = candidate;
        break;
      }
    }

    final _MaterialLineDraft draft = _MaterialLineDraft(
      id: widget.existing?.id,
      materialTable: table,
      materialId: materialId,
      materialName: material?.name ?? widget.existing?.materialName ?? '',
      percentage: double.tryParse(_percentageController.text.trim()) ?? 0,
      notes: _notesController.text.trim(),
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    final List<RawMaterialModel> materials = _materialsForSelectedTable;

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
                  isEditing ? 'Edit Ingredient' : 'Add Ingredient',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTable,
                  decoration: const InputDecoration(
                    labelText: 'Material Type',
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final MapEntry<String, String> entry
                        in _kMaterialTableLabels.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (String? value) => setState(() {
                    _selectedTable = value;
                    _selectedMaterialId = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Material type is required.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedMaterialId,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: <DropdownMenuItem<int>>[
                    for (final RawMaterialModel material in materials)
                      if (material.id != null)
                        DropdownMenuItem<int>(
                          value: material.id,
                          child: Text(material.name),
                        ),
                  ],
                  onChanged: (int? value) =>
                      setState(() => _selectedMaterialId = value),
                  validator: (value) =>
                      value == null ? 'Material is required.' : null,
                ),
                if (materials.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'No active materials in this category.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Percentage',
                  controller: _percentageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final double? parsed = double.tryParse(
                      (value ?? '').trim(),
                    );
                    if (parsed == null) {
                      return 'Enter a valid percentage.';
                    }
                    if (parsed < 0 || parsed > 100) {
                      return 'Percentage must be between 0 and 100.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Notes (optional)',
                  controller: _notesController,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: isEditing ? 'Save Ingredient' : 'Add Ingredient',
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
