import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/models/bounding_box.dart';
import '../core/exceptions/ocr_exceptions.dart';

/// Preprocessed detection input tensor details.
class DetPreprocessResult {
  final Float32List chwTensor;
  final int tensorWidth;
  final int tensorHeight;
  final int origWidth;
  final int origHeight;
  final double ratioW;
  final double ratioH;

  DetPreprocessResult({
    required this.chwTensor,
    required this.tensorWidth,
    required this.tensorHeight,
    required this.origWidth,
    required this.origHeight,
    required this.ratioW,
    required this.ratioH,
  });
}

/// Preprocessed recognition input tensor details.
class RecPreprocessResult {
  final Float32List chwTensor;
  final int tensorWidth;
  final int tensorHeight;

  RecPreprocessResult({
    required this.chwTensor,
    required this.tensorWidth,
    required this.tensorHeight,
  });
}

/// Image Preprocessor for on-device OCR inference.
/// Handles image decoding, detection resizing/normalization, text line cropping,
/// and recognition normalization matching RapidOCR Python specifications.
class ImagePreprocessor {
  // Detection Normalization constants (BGR order matching OpenCV / RapidOCR)
  static const List<double> detMeanBgr = [0.406, 0.456, 0.485];
  static const List<double> detStdBgr = [0.225, 0.224, 0.229];

  /// Decodes raw image bytes (PNG, JPEG, WebP, BMP) into an `img.Image`.
  static img.Image decodeImage(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw const ImageProcessingException('Failed to decode image bytes into image.');
    }
    // Handle orientation if EXIF metadata exists
    return img.bakeOrientation(image);
  }

  /// Resizes and normalizes an image for the DBNet detection model (`det_v1.onnx`).
  ///
  /// - Min side is scaled to [limitSideLen] (default 736), rounded to multiples of 32.
  /// - Normalization: `(pixel * (1/255) - mean) / std` in BGR planar CHW order.
  static DetPreprocessResult preprocessForDetection(
    img.Image image, {
    int limitSideLen = 736,
  }) {
    final origW = image.width;
    final origH = image.height;

    // Calculate resize ratio based on min side >= limitSideLen
    double ratio = 1.0;
    if (min(origH, origW) < limitSideLen) {
      if (origH < origW) {
        ratio = limitSideLen / origH.toDouble();
      } else {
        ratio = limitSideLen / origW.toDouble();
      }
    }

    int resizeH = (origH * ratio).toInt();
    int resizeW = (origW * ratio).toInt();

    // Round to nearest multiple of 32
    resizeH = ((resizeH / 32.0).round() * 32).toInt();
    resizeW = ((resizeW / 32.0).round() * 32).toInt();

    resizeH = max(32, resizeH);
    resizeW = max(32, resizeW);

    final ratioH = resizeH / origH.toDouble();
    final ratioW = resizeW / origW.toDouble();

    // Resize image
    final resized = img.copyResize(
      image,
      width: resizeW,
      height: resizeH,
      interpolation: img.Interpolation.cubic,
    );

    // Build planar CHW Float32 tensor [1, 3, resizeH, resizeW]
    final int planeSize = resizeH * resizeW;
    final Float32List tensor = Float32List(3 * planeSize);

    for (int y = 0; y < resizeH; y++) {
      for (int x = 0; x < resizeW; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final offset = y * resizeW + x;

        // BGR order
        tensor[0 * planeSize + offset] = ((b - detMeanBgr[0]) / detStdBgr[0]).toDouble();
        tensor[1 * planeSize + offset] = ((g - detMeanBgr[1]) / detStdBgr[1]).toDouble();
        tensor[2 * planeSize + offset] = ((r - detMeanBgr[2]) / detStdBgr[2]).toDouble();
      }
    }

    return DetPreprocessResult(
      chwTensor: tensor,
      tensorWidth: resizeW,
      tensorHeight: resizeH,
      origWidth: origW,
      origHeight: origH,
      ratioW: ratioW,
      ratioH: ratioH,
    );
  }

  /// Crops a text line region from the source image given a bounding box with slight margin padding.
  static img.Image cropTextRegion(img.Image image, BoundingBox bbox) {
    const padX = 3;
    const padY = 2;
    final minX = (bbox.minX - padX).floor().clamp(0, image.width - 1);
    final minY = (bbox.minY - padY).floor().clamp(0, image.height - 1);
    final maxX = (bbox.maxX + padX).ceil().clamp(0, image.width);
    final maxY = (bbox.maxY + padY).ceil().clamp(0, image.height);
    final w = max(1, maxX - minX);
    final h = max(1, maxY - minY);

    return img.copyCrop(image, x: minX, y: minY, width: w, height: h);
  }

  /// Preprocesses a cropped text line image for the SVTR-LCNet recognition model (`rec_v1.onnx`).
  ///
  /// - Height is fixed at 48.
  /// - Width is scaled proportionally: `ceil(48 * (w / h))`.
  /// - Normalization: `(pixel / 255.0 - 0.5) / 0.5` in RGB planar CHW order.
  static RecPreprocessResult preprocessForRecognition(
    img.Image crop, {
    int targetHeight = 48,
    int? maxTargetWidth,
  }) {
    final h = crop.height;
    final w = crop.width;
    final ratio = w / max(1.0, h.toDouble());

    int targetW = (targetHeight * ratio).ceil();
    if (maxTargetWidth != null && targetW > maxTargetWidth) {
      targetW = maxTargetWidth;
    }
    targetW = max(16, targetW);

    final resized = img.copyResize(
      crop,
      width: targetW,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final int planeSize = targetHeight * targetW;
    final Float32List tensor = Float32List(3 * planeSize);

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetW; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final offset = y * targetW + x;

        // RGB planar CHW order matching SVTR-LCNet / PP-OCR recognition specifications
        tensor[0 * planeSize + offset] = ((r - 0.5) / 0.5).toDouble();
        tensor[1 * planeSize + offset] = ((g - 0.5) / 0.5).toDouble();
        tensor[2 * planeSize + offset] = ((b - 0.5) / 0.5).toDouble();
      }
    }

    return RecPreprocessResult(
      chwTensor: tensor,
      tensorWidth: targetW,
      tensorHeight: targetHeight,
    );
  }
}
