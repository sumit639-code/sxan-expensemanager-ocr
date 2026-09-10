import 'package:flutter/foundation.dart';

import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/extraction_result.dart';
import '../../domain/services/ocr_engine.dart';
import '../../domain/services/transaction_extractor.dart';
import '../../domain/services/transaction_parser.dart';
import 'image_preprocessor.dart';

/// Production on-device implementation of [TransactionExtractor].
///
/// Orchestrates:
/// 1. Image preprocessing / validation
/// 2. Local on-device OCR via [OcrEngine]
/// 3. Rule-based parsing via [TransactionParser]
/// 4. Aggregation and honest progress reporting across screenshots
class RealTransactionExtractor implements TransactionExtractor {
  final OcrEngine _ocrEngine;
  final TransactionParser _parser;
  final ImagePreprocessor _preprocessor;

  RealTransactionExtractor({
    required OcrEngine ocrEngine,
    required TransactionParser parser,
    ImagePreprocessor? preprocessor,
  }) : _ocrEngine = ocrEngine,
       _parser = parser,
       _preprocessor = preprocessor ?? const ImagePreprocessor();

  @override
  Future<ExtractionResult> extractTransactions(
    List<String> imagePaths, {
    void Function(String step, double progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      return const ExtractionResult(
        transactions: [],
        successfulImages: [],
        errors: ['No screenshot images selected.'],
      );
    }

    onProgress?.call('Preparing screenshots...', 0.05);

    // 1. Validate images
    final validated = _preprocessor.validateImages(imagePaths);
    final validImages = validated
        .where((v) => v.isValid)
        .map((v) => v.path)
        .toList();
    final invalidImages = validated.where((v) => !v.isValid).toList();

    final successfulImages = <String>[];
    final failedImages = <String>[];
    final errors = <String>[];
    final debugOcrBuffer = StringBuffer();

    for (final inv in invalidImages) {
      failedImages.add(inv.path);
      errors.add('${inv.name}: ${inv.error ?? "Invalid image file."}');
    }

    if (validImages.isEmpty) {
      return ExtractionResult(
        transactions: const [],
        successfulImages: const [],
        failedImages: failedImages,
        errors: errors,
      );
    }

    // 2. Sequential OCR & Parsing per screenshot
    final allExtracted = <ExtractedTransaction>[];

    final totalCount = validImages.length;
    for (int i = 0; i < totalCount; i++) {
      final path = validImages[i];
      final currentNum = i + 1;
      final stepProgress = 0.10 + ((i / totalCount) * 0.70);

      onProgress?.call(
        'Reading screenshot $currentNum of $totalCount...',
        stepProgress,
      );

      try {
        final ocrDoc = await _ocrEngine.recognizeText(path);

        debugOcrBuffer.writeln('=== SCREENSHOT $currentNum ($path) ===');
        debugOcrBuffer.writeln('Dimensions: ${ocrDoc.estimatedWidth.toInt()}x${ocrDoc.estimatedHeight.toInt()}');
        for (final line in ocrDoc.lines) {
          final box = line.boundingBox;
          final coords = box != null
              ? '[L:${box.left.toInt()}, T:${box.top.toInt()}, W:${box.width.toInt()}, H:${box.height.toInt()}]'
              : '[no box]';
          debugOcrBuffer.writeln('$coords ${line.text}');
        }
        debugOcrBuffer.writeln();

        if (ocrDoc.isEmpty) {
          failedImages.add(path);
          errors.add(
            'Screenshot $currentNum: Couldn\'t read text from this screenshot. Please ensure the image is clear and try again.',
          );
          continue;
        }

        onProgress?.call(
          'Parsing screenshot $currentNum of $totalCount...',
          stepProgress + (0.35 / totalCount),
        );

        final parsed = _parser.parse(ocrDoc);
        if (parsed.isEmpty) {
          // OCR succeeded, but no transaction patterns were detected
          failedImages.add(path);
          errors.add(
            'Screenshot $currentNum: No recognizable transactions were found. You can try another screenshot.',
          );
        } else {
          successfulImages.add(path);
          allExtracted.addAll(parsed);
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[IMPORT ERROR] Failed to analyze screenshot $currentNum: $e\n$stackTrace',
          );
        }
        failedImages.add(path);
        errors.add('Screenshot $currentNum: Error during processing: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('[IMPORT] Final transactions: ${allExtracted.length}');
    }

    onProgress?.call('Checking duplicates...', 0.90);

    return ExtractionResult(
      transactions: allExtracted,
      successfulImages: successfulImages,
      failedImages: failedImages,
      errors: errors,
      debugOcrText: debugOcrBuffer.toString(),
    );
  }
}
