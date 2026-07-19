/// Purpose      : Reusable card for capturing or selecting an image.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter/material.dart, image_picker, dart:io,
///                app_card.dart
/// Description  : Implements the "Capture or Select Shade Image"
///                step of the approved workflow at the shell level —
///                a real, working camera/gallery picker with preview
///                and error handling. Shade colour analysis itself is
///                out of scope for this sprint (Knowledge Engine, not
///                yet built); this widget only captures the image
///                and reports it back via [onImageSelected].
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'app_card.dart';

/// Card that lets the user pick an image from the camera or gallery
/// and shows a preview once selected.
class ImagePickerCard extends StatefulWidget {
  const ImagePickerCard({
    required this.onImageSelected,
    super.key,
    this.onError,
  });

  /// Called with the picked file's path when selection succeeds.
  final ValueChanged<String> onImageSelected;

  /// Called with a human-readable message if picking fails. Optional
  /// — if omitted, failures are silently absorbed after logging,
  /// per the "never crash application" rule.
  final ValueChanged<String>? onError;

  @override
  State<ImagePickerCard> createState() => _ImagePickerCardState();
}

class _ImagePickerCardState extends State<ImagePickerCard> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isPicking = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file == null) {
        // User cancelled picking; not an error.
        return;
      }
      setState(() => _selectedImagePath = file.path);
      widget.onImageSelected(file.path);
    } catch (error) {
      // Caught and reported rather than left to crash the app.
      if (kDebugMode) {
        debugPrint('ImagePickerCard: pickImage($source) failed: $error');
      }
      widget.onError?.call(
        'Unable to access $source. Please check app permissions.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _selectedImagePath == null
                  ? Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isPicking ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPicking
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
