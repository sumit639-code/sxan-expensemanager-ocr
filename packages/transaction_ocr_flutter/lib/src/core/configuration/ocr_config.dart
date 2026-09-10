/// Configuration parameters for OCR engines and pipelines.
class OcrConfig {
  /// Path to detection ONNX model asset.
  final String detModelPath;

  /// Path to recognition ONNX model asset.
  final String recModelPath;

  /// Path to angle classifier ONNX model asset.
  final String clsModelPath;

  /// Path to character keys dictionary file asset.
  final String keysPath;

  /// Threshold for DBNet probability map binarization.
  final double detThresh;

  /// Minimum average score inside bounding box to keep detection.
  final double boxThresh;

  /// Unclip polygon expansion ratio.
  final double unclipRatio;

  /// Minimum recognition score to keep detection.
  final double textScoreThresh;

  /// Minimum side length for detection image resizing.
  final int limitSideLen;

  /// Whether to run angle classifier on cropped text bars.
  final bool useAngleCls;

  /// Number of CPU threads for ONNX runtime inference sessions.
  final int numThreads;

  /// Base URL for RemoteOcrEngine (FastAPI development bridge).
  final String remoteBaseUrl;

  const OcrConfig({
    this.detModelPath = 'assets/models/v1.0.0/det_v1.onnx',
    this.recModelPath = 'assets/models/v1.0.0/rec_v1.onnx',
    this.clsModelPath = 'assets/models/v1.0.0/cls_v1.onnx',
    this.keysPath = 'assets/models/v1.0.0/keys_v1.txt',
    this.detThresh = 0.3,
    this.boxThresh = 0.5,
    this.unclipRatio = 1.6,
    this.textScoreThresh = 0.5,
    this.limitSideLen = 736,
    this.useAngleCls = false,
    this.numThreads = 2,
    this.remoteBaseUrl = 'http://localhost:8000',
  });
}
