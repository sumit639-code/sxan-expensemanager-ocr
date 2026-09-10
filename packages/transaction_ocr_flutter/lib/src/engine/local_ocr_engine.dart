import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../core/configuration/ocr_config.dart';
import '../core/exceptions/ocr_exceptions.dart';
import '../core/models/ocr_item.dart';
import '../core/models/ocr_result.dart';
import '../parsing/amount_classifier.dart';
import '../parsing/transaction_grouper.dart';
import '../postprocessing/candidate_consolidator.dart';
import '../postprocessing/ctc_decoder.dart';
import '../postprocessing/db_postprocessor.dart';
import '../preprocessing/image_preprocessor.dart';
import 'ocr_engine.dart';

/// On-device offline OCR Engine running ONNX Runtime inference locally on mobile (Android/iOS).
/// Uses bundled DBNet detection model and SVTR-LCNet recognition model.
class LocalOcrEngine implements OcrEngine {
  final OcrConfig config;

  OrtSession? _detSession;
  OrtSession? _recSession;
  CtcDecoder? _ctcDecoder;
  late DbPostProcessor _dbPostProcessor;

  bool _isInitialized = false;

  LocalOcrEngine({OcrConfig? config}) : config = config ?? const OcrConfig();

  @override
  String get engineName => 'RapidOCR-ONNX-Mobile';

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize({
    String? customKeysContent,
  }) async {
    if (_isInitialized) return;

    try {
      final onnx = OnnxRuntime();
      final sessionOptions = OrtSessionOptions();

      Future<OrtSession> createSessionWithFallback(String path) async {
        try {
          return await onnx.createSessionFromAsset(path, options: sessionOptions);
        } catch (e) {
          if (!path.startsWith('packages/')) {
            final pkgPath = 'packages/transaction_ocr_flutter/$path';
            return await onnx.createSessionFromAsset(pkgPath, options: sessionOptions);
          }
          rethrow;
        }
      }

      Future<String> loadStringWithFallback(String path) async {
        try {
          return await rootBundle.loadString(path);
        } catch (e) {
          if (!path.startsWith('packages/')) {
            final pkgPath = 'packages/transaction_ocr_flutter/$path';
            return await rootBundle.loadString(pkgPath);
          }
          rethrow;
        }
      }

      // 1. Initialize Detection Session
      _detSession = await createSessionWithFallback(config.detModelPath);

      // 2. Initialize Recognition Session
      _recSession = await createSessionWithFallback(config.recModelPath);

      // 3. Load Character Dictionary
      String keysContent = customKeysContent ?? '';
      if (keysContent.isEmpty) {
        keysContent = await loadStringWithFallback(config.keysPath);
      }
      _ctcDecoder = CtcDecoder.fromKeysText(keysContent);

      // 4. Initialize DB Post-processor
      _dbPostProcessor = DbPostProcessor(
        thresh: config.detThresh,
        boxThresh: config.boxThresh,
        unclipRatio: config.unclipRatio,
      );

      _isInitialized = true;
    } catch (e, st) {
      throw ModelLoadException(
        'Failed to initialize LocalOcrEngine models: $e',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<OcrResult> extractImage(
    Uint8List imageBytes, {
    String filename = 'screenshot.png',
    OcrProgressCallback? onProgress,
    int currentImage = 1,
    int totalImages = 1,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      onProgress?.call(currentImage, totalImages, 'Decoding image', 0.10);
      final image = ImagePreprocessor.decodeImage(imageBytes);
      final origW = image.width;
      final origH = image.height;

      // ── 1. Text Detection ─────────────────────────────────────────
      onProgress?.call(currentImage, totalImages, 'Preprocessing image for detection', 0.20);
      final detPrep = ImagePreprocessor.preprocessForDetection(
        image,
        limitSideLen: config.limitSideLen,
      );

      onProgress?.call(currentImage, totalImages, 'Running text detection model', 0.35);
      final detInputVal = await OrtValue.fromList(
        detPrep.chwTensor,
        [1, 3, detPrep.tensorHeight, detPrep.tensorWidth],
      );

      final detOutputs = await _detSession!.run({'x': detInputVal});
      final detProbOrtVal = detOutputs.values.first;
      final detFlat = await detProbOrtVal.asFlattenedList();

      await detInputVal.dispose();
      for (final v in detOutputs.values) {
        await v.dispose();
      }

      onProgress?.call(currentImage, totalImages, 'Extracting bounding boxes', 0.50);
      final rawDoubleList = detFlat.map((e) => (e as num).toDouble()).toList();
      final boxes = _dbPostProcessor.getBoxes(
        rawDoubleList,
        detPrep.tensorWidth,
        detPrep.tensorHeight,
        origW,
        origH,
      );

      // ── 2. Text Line Recognition ──────────────────────────────────
      final List<Map<String, dynamic>> rawDetections = [];
      final int totalBoxes = boxes.length;

      for (int i = 0; i < totalBoxes; i++) {
        final box = boxes[i];
        final progressFrac = 0.50 + (0.30 * (i / max(1, totalBoxes)));
        onProgress?.call(
          currentImage,
          totalImages,
          'Recognizing text region ${i + 1}/$totalBoxes',
          progressFrac,
        );

        final crop = ImagePreprocessor.cropTextRegion(image, box);
        if (crop.width <= 2 || crop.height <= 2) continue;

        final recPrep = ImagePreprocessor.preprocessForRecognition(crop);
        final recInputVal = await OrtValue.fromList(
          recPrep.chwTensor,
          [1, 3, recPrep.tensorHeight, recPrep.tensorWidth],
        );

        final recOutputs = await _recSession!.run({'x': recInputVal});
        final recOrtVal = recOutputs.values.first;
        final recFlat = await recOrtVal.asFlattenedList();

        await recInputVal.dispose();
        for (final v in recOutputs.values) {
          await v.dispose();
        }

        // Decode CTC Output: Shape [1, T, 6625]
        const int numClasses = 6625;
        final int timeSteps = recFlat.length ~/ numClasses;
        final List<int> predIndices = [];
        final List<double> predProbs = [];

        for (int t = 0; t < timeSteps; t++) {
          int maxIdx = 0;
          double maxVal = -1e9;
          final offset = t * numClasses;

          for (int c = 0; c < numClasses; c++) {
            final val = (recFlat[offset + c] as num).toDouble();
            if (val > maxVal) {
              maxVal = val;
              maxIdx = c;
            }
          }
          predIndices.add(maxIdx);
          predProbs.add(maxVal);
        }

        final decoded = _ctcDecoder!.decode(predIndices, predProbs);
        final text = decoded['text'] as String;
        final conf = decoded['confidence'] as double;

        if (conf >= config.textScoreThresh && text.trim().isNotEmpty) {
          rawDetections.add({
            'text': text,
            'confidence': conf,
            'bbox': box,
          });
        }
      }

      // ── 3. Candidate Consolidation & V2 Parsing ─────────────────────
      onProgress?.call(currentImage, totalImages, 'Consolidating candidates', 0.85);
      final consolidated = OcrCandidateConsolidator.consolidate(rawDetections);

      // Sort top-to-bottom reading order
      consolidated.sort((a, b) {
        final yCmp = a.bbox.center.y.compareTo(b.bbox.center.y);
        if (yCmp != 0) return yCmp;
        return a.bbox.minX.compareTo(b.bbox.minX);
      });

      onProgress?.call(currentImage, totalImages, 'Classifying amounts and grouping transactions (V2)', 0.95);
      final List<OcrItem> items = [];
      final List<Map<String, dynamic>> grouperInputDets = [];

      for (int idx = 0; idx < consolidated.length; idx++) {
        final det = consolidated[idx];
        final rawText = det.text;
        final normText = det.textNormalized;
        final score = det.compositeScore;
        final conf = det.confidence;
        final bbox = det.bbox;

        // V2 Amount Classification
        var amtCls = AmountClassifier.classify(
          normText.isNotEmpty ? normText : rawText,
          bbox: bbox,
          imgWidth: origW,
          imgHeight: origH,
        );
        if (!amtCls.isAmount) {
          final amtClsRaw = AmountClassifier.classify(
            rawText,
            bbox: bbox,
            imgWidth: origW,
            imgHeight: origH,
          );
          if (amtClsRaw.isAmount) {
            amtCls = amtClsRaw;
          }
        }

        final candidateModels = det.candidates.map((c) => OcrCandidate(
              text: c.text,
              textNormalized: c.textNormalized,
              confidence: c.confidence,
              compositeScore: c.compositeScore,
              bbox: c.bbox,
            )).toList();

        items.add(OcrItem(
          readingIndex: idx + 1,
          text: rawText,
          textNormalized: normText,
          compositeScore: score,
          confidence: conf,
          bbox: bbox,
          amountClassification: amtCls,
          isNumericAmount: amtCls.isAmount && amtCls.parsedValue != null,
          parsedIntegerAmount: amtCls.parsedValue,
          currency: amtCls.isAmount ? 'INR' : null,
          candidates: candidateModels,
        ));

        grouperInputDets.add({
          'text': rawText,
          'text_normalized': normText,
          'confidence': conf,
          'composite_score': score,
          'bbox': bbox,
        });
      }

      // ── 4. Spatial Transaction Row Grouping ─────────────────────────
      final grouperResult = TransactionGrouper.group(
        detections: grouperInputDets,
        imgWidth: origW,
        imgHeight: origH,
      );

      final Map<String, int> tokenSummary = {};
      for (final tok in grouperResult.tokenClassifications) {
        tokenSummary[tok.tokenType] = (tokenSummary[tok.tokenType] ?? 0) + 1;
      }

      onProgress?.call(currentImage, totalImages, 'Complete', 1.0);

      return OcrResult(
        success: true,
        filename: filename,
        width: origW,
        height: origH,
        engine: engineName,
        itemsCount: items.length,
        items: items,
        pipelineVersion: 'V2',
        tokenSummary: tokenSummary,
        transactionCandidates: grouperResult.transactionCandidates,
        transactionCandidatesCount: grouperResult.transactionCandidates.length,
      );
    } catch (e, st) {
      if (e is OcrException) rethrow;
      throw ModelInferenceException(
        'Failed to execute local OCR inference: $e',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _detSession?.close();
    await _recSession?.close();
    _detSession = null;
    _recSession = null;
    _isInitialized = false;
  }
}
