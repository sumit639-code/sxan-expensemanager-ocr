/// Base class for all OCR exceptions in transaction_ocr_flutter.
abstract class OcrException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;

  const OcrException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    if (cause != null) {
      return '$runtimeType: $message (Caused by: $cause)';
    }
    return '$runtimeType: $message';
  }
}

/// Thrown when an OCR model asset (ONNX, dictionary, config) cannot be found or loaded.
class ModelLoadException extends OcrException {
  final String? modelPath;

  const ModelLoadException(super.message, {this.modelPath, super.cause, super.stackTrace});
}

/// Thrown when ONNX runtime inference fails (e.g. tensor shape mismatch, unsupported op, out of memory).
class ModelInferenceException extends OcrException {
  final String? stage; // 'detection', 'classification', 'recognition'

  const ModelInferenceException(super.message, {this.stage, super.cause, super.stackTrace});
}

/// Thrown when image decoding, resizing, normalization, or cropping fails.
class ImageProcessingException extends OcrException {
  const ImageProcessingException(super.message, {super.cause, super.stackTrace});
}

/// Thrown when OCR output or server response is corrupted or malformed.
class InvalidOcrResultException extends OcrException {
  const InvalidOcrResultException(super.message, {super.cause, super.stackTrace});
}

/// Thrown when remote API request fails in RemoteOcrEngine.
class RemoteOcrException extends OcrException {
  final int? statusCode;

  const RemoteOcrException(super.message, {this.statusCode, super.cause, super.stackTrace});
}
