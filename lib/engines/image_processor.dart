/// Purpose      : Decodes image bytes/files into raw pixel data and
///                performs deterministic pre-processing.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : dart:io, dart:typed_data, package:image
/// Description  : The one place in this sprint that touches the
///                filesystem/codec layer — reads bytes from Local
///                Device Storage (a Gallery Image's file path, as
///                already supplied by ImagePickerCard's image_picker
///                integration, SPR-DEP-002) and decodes them via
///                `package:image` (pure Dart, offline, deterministic
///                — no AI/ML, no camera/TensorFlow/OpenCV/cloud APIs,
///                satisfying "NO IMAGE AI"). Downscaling before
///                sampling is a fixed, deterministic resize (same
///                input image always yields the same output
///                dimensions), not a learned or randomized operation.
/// Change History:
///   1.0.0 - SPR-DEP-008 - Initial creation.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Contract for [ImageProcessor].
abstract class IImageProcessor {
  Future<img.Image?> decodeBytes(Uint8List bytes);
  Future<img.Image?> decodeFile(String path);
  img.Image downscale(img.Image image, {int maxDimension});
}

/// Decodes and pre-processes images for colour analysis.
class ImageProcessor implements IImageProcessor {
  const ImageProcessor();

  @override
  Future<img.Image?> decodeBytes(Uint8List bytes) async {
    return img.decodeImage(bytes);
  }

  @override
  Future<img.Image?> decodeFile(String path) async {
    final File file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    return decodeBytes(bytes);
  }

  /// Deterministically downscales [image] so its longer side is at
  /// most [maxDimension] pixels, preserving aspect ratio. Sampling a
  /// smaller, fixed-size image keeps analysis time bounded and
  /// consistent regardless of the original photo's resolution.
  /// Images already at or below the limit are returned unchanged.
  @override
  img.Image downscale(img.Image image, {int maxDimension = 200}) {
    final int longerSide = image.width > image.height
        ? image.width
        : image.height;
    if (longerSide <= maxDimension) {
      return image;
    }

    final double scale = maxDimension / longerSide;
    final int newWidth = (image.width * scale).round();
    final int newHeight = (image.height * scale).round();

    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );
  }
}
