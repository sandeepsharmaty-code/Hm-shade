/// Purpose      : New Shade tab content — the full Select Image ->
///                Image Analysis -> Color Profile -> Shade Detection
///                workflow, handing off to TrialScreen for Top 5
///                Recommendations onward.
/// Author       : HMEOS Engineering
/// Version      : 2.0.0
/// Dependencies : flutter/material.dart, core/di/service_locator.dart,
///                engines/image_analysis_engine.dart,
///                repositories/product_repository.dart,
///                screens/trial_screen.dart, widgets/*
/// Description  : Implements the first half of this sprint's "NEW
///                SHADE SCREEN" workflow directly; the second half
///                (Top 5 Recommendations -> Recommendation Details ->
///                Trial Selection -> Ready for Lab) is TrialScreen
///                (SPR-DEP-009, new this sprint) — reused via
///                Navigator.pushNamed rather than duplicated here, so
///                there is exactly one place that renders a Top 5
///                list and one place that handles trial selection.
///                Calls ImageAnalysisEngine and ProductRepository
///                through ServiceLocator only; no SQLite or scoring
///                logic lives in this file.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation. Image capture/selection
///           only; workflow stopped there pending later sprints.
///   2.0.0 - SPR-DEP-009 - Full workflow: product selection, real
///           ImageAnalysisEngine call, ColorProfile + shade detection
///           display, handoff to TrialScreen.
library;

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../core/routing/app_routes.dart';
import '../engines/engine_result.dart';
import '../engines/image_analysis_engine.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../repositories/repository_exception.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/error_dialog.dart';
import '../widgets/image_picker_card.dart';
import '../widgets/loading_view.dart';
import 'trial_screen.dart';

/// New Shade tab: Select Image -> Image Analysis -> Color Profile ->
/// Shade Detection, then hand off to [TrialScreen].
class NewShadeScreen extends StatefulWidget {
  const NewShadeScreen({super.key});

  @override
  State<NewShadeScreen> createState() => _NewShadeScreenState();
}

class _NewShadeScreenState extends State<NewShadeScreen> {
  late final IImageAnalysisEngine _imageAnalysisEngine;
  late final ProductRepository _productRepository;
  late Future<List<ProductModel>> _productsFuture;

  ProductModel? _selectedProduct;
  String? _selectedImagePath;
  bool _isAnalyzing = false;
  ImageAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _imageAnalysisEngine = ServiceLocator.instance
        .get<IImageAnalysisEngine>();
    _productRepository = ServiceLocator.instance.get<ProductRepository>();
    _productsFuture = _loadProducts();
  }

  Future<List<ProductModel>> _loadProducts() async {
    try {
      return await _productRepository.readAll();
    } on RepositoryException {
      return const <ProductModel>[];
    }
  }

  void _handleImageSelected(String path) {
    setState(() {
      _selectedImagePath = path;
      _analysisResult = null;
    });
  }

  void _handleImageError(String message) {
    ErrorDialog.show(context, message: message);
  }

  Future<void> _analyzeImage() async {
    final String? path = _selectedImagePath;
    if (path == null) {
      return;
    }
    setState(() => _isAnalyzing = true);

    final EngineResult<ImageAnalysisResult> result = await _imageAnalysisEngine
        .analyzeImage(path);

    if (!mounted) {
      return;
    }
    setState(() => _isAnalyzing = false);

    if (result.isSuccess && result.data != null) {
      setState(() => _analysisResult = result.data);
    } else {
      await ErrorDialog.show(
        context,
        message: result.messages.isNotEmpty
            ? result.messages.first
            : 'Unable to analyze this image.',
      );
    }
  }

  void _viewRecommendations() {
    final ProductModel? product = _selectedProduct;
    final ImageAnalysisResult? analysis = _analysisResult;
    if (product?.id == null || analysis == null) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.trial,
      arguments: TrialScreenArgs(
        productId: product!.id!,
        shadeFamily: analysis.classification.shadeFamily,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Product', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<ProductModel>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            final List<ProductModel> products = snapshot.data ?? const [];
            if (products.isEmpty) {
              return const AppCard(
                child: Text(
                  'No products exist yet. Add a product before starting '
                  'a shade workflow.',
                ),
              );
            }
            _selectedProduct ??= products.first;
            return AppCard(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProductModel>(
                  isExpanded: true,
                  value: _selectedProduct,
                  items: <DropdownMenuItem<ProductModel>>[
                    for (final ProductModel p in products)
                      DropdownMenuItem<ProductModel>(
                        value: p,
                        child: Text('${p.name} (${p.category})'),
                      ),
                  ],
                  onChanged: (ProductModel? value) {
                    setState(() => _selectedProduct = value);
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Shade Image', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Capture a photo or select one from your gallery.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        ImagePickerCard(
          onImageSelected: _handleImageSelected,
          onError: _handleImageError,
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Analyze Image',
          icon: Icons.auto_awesome,
          expand: true,
          isLoading: _isAnalyzing,
          onPressed: _selectedImagePath == null ? null : _analyzeImage,
        ),
        if (_analysisResult != null) ...<Widget>[
          const SizedBox(height: 24),
          _ColorProfileSection(result: _analysisResult!),
          const SizedBox(height: 24),
          AppButton(
            label: 'View Top 5 Recommendations',
            icon: Icons.arrow_forward,
            expand: true,
            onPressed: _selectedProduct?.id == null
                ? null
                : _viewRecommendations,
          ),
        ],
      ],
    );
  }
}

/// Displays the Color Profile and Shade Detection results.
class _ColorProfileSection extends StatelessWidget {
  const _ColorProfileSection({required this.result});

  final ImageAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final profile = result.profile;
    final classification = result.classification;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    Color swatchColor(int r, int g, int b) => Color.fromARGB(255, r, g, b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Color Profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: swatchColor(
                    profile.averageColor.r,
                    profile.averageColor.g,
                    profile.averageColor.b,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Average: ${profile.averageColor.hex}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Brightness ${(profile.brightness * 100).toStringAsFixed(0)}% · '
                      'Saturation ${(profile.saturation * 100).toStringAsFixed(0)}% · '
                      'Lightness ${(profile.lightness * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.dominantColors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Dominant Colors', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final d in profile.dominantColors)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: swatchColor(d.color.r, d.color.g, d.color.b),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const Divider(height: 32),
          Text('Shade Detection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('Family: ${classification.shadeFamily}')),
              Chip(label: Text('Undertone: ${classification.undertone}')),
              Chip(
                label: Text(
                  classification.isDark
                      ? 'Dark'
                      : classification.isLight
                          ? 'Light'
                          : 'Mid-tone',
                ),
              ),
              Chip(
                label: Text(
                  classification.hasSingleDominantColor
                      ? 'Single dominant colour'
                      : 'Multiple dominant colours',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
