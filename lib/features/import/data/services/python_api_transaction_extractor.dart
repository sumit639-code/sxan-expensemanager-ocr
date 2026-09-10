import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/extraction_result.dart';
import '../../domain/services/transaction_extractor.dart';
import '../datasources/python_ocr_api.dart';
import '../parser/python_ocr_transaction_parser.dart';
import 'image_preprocessor.dart';

import 'real_transaction_extractor.dart';

/// Production API-backed implementation of [TransactionExtractor].
///
/// Sends screenshots to the local Python FastAPI RapidOCR server,
/// receives structured OCR items, and parses them into [ExtractedTransaction]s.
/// Automatically falls back to on-device OCR if the Python server is offline.
class PythonApiTransactionExtractor implements TransactionExtractor {
  final PythonOcrApi _api;
  final PythonOcrTransactionParser _parser;
  final ImagePreprocessor _preprocessor;
  final RealTransactionExtractor? _fallbackExtractor;

  PythonApiTransactionExtractor({
    required PythonOcrApi api,
    PythonOcrTransactionParser? parser,
    ImagePreprocessor? preprocessor,
    RealTransactionExtractor? fallbackExtractor,
  }) : _api = api,
       _parser = parser ?? PythonOcrTransactionParser(),
       _preprocessor = preprocessor ?? const ImagePreprocessor(),
       _fallbackExtractor = fallbackExtractor;

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

    // 2. Sequential OCR & Parsing per screenshot via Python API
    final allExtracted = <ExtractedTransaction>[];
    final totalCount = validImages.length;

    for (int i = 0; i < totalCount; i++) {
      final path = validImages[i];
      final currentNum = i + 1;
      final stepProgress = 0.10 + ((i / totalCount) * 0.70);

      onProgress?.call(
        'Analyzing screenshot $currentNum of $totalCount...',
        stepProgress,
      );

      try {
        final ocrResponse = await _api.extractFromImage(path);

        debugOcrBuffer.writeln('=== SCREENSHOT $currentNum ($path) ===');
        debugOcrBuffer.writeln(
          'Python OCR items: ${ocrResponse.items.length}, success: ${ocrResponse.success}',
        );
        for (final item in ocrResponse.items) {
          final box = item.boundingBox;
          final coords = box != null
              ? '[L:${box.left.toInt()}, T:${box.top.toInt()}, W:${box.width.toInt()}, H:${box.height.toInt()}]'
              : '[no box]';
          debugOcrBuffer.writeln(
            '$coords (#${item.readingIndex}) "${item.text}" (score: ${item.compositeScore.toStringAsFixed(2)})',
          );
        }
        debugOcrBuffer.writeln();

        if (!ocrResponse.success || ocrResponse.items.isEmpty) {
          failedImages.add(path);
          errors.add(
            'Screenshot $currentNum: Couldn\'t read text from this screenshot. Please ensure the image is clear and try again.',
          );
          continue;
        }

        onProgress?.call(
          'Processing transactions from screenshot $currentNum of $totalCount...',
          stepProgress + (0.35 / totalCount),
        );

        final parsed = _parser.parseResponse(
          ocrResponse,
          sourceReference: path,
        );

        if (parsed.isEmpty) {
          failedImages.add(path);
          errors.add(
            'Screenshot $currentNum: No recognizable transactions were found. You can try another screenshot.',
          );
        } else {
          successfulImages.add(path);
          allExtracted.addAll(parsed);
        }
      } on PythonOcrConnectionException catch (e) {
        final fallback = _fallbackExtractor;
        if (fallback != null) {
          debugOcrBuffer.writeln(
            '[FALLBACK] Python OCR API offline ($e). Running on-device ML Kit OCR fallback.',
          );

          try {
            final fallbackResult =
                await fallback.extractTransactions([path]);

            if (fallbackResult.transactions.isNotEmpty) {
              successfulImages.add(path);
              allExtracted.addAll(fallbackResult.transactions);
              if (fallbackResult.debugOcrText != null) {
                debugOcrBuffer.writeln(fallbackResult.debugOcrText);
              }
              continue;
            }
          } catch (fbErr) {
            debugOcrBuffer.writeln('[FALLBACK ERROR] $fbErr');
          }
        }
        failedImages.add(path);
        errors.add(
          'Screenshot $currentNum: Couldn\'t connect to the OCR service. Please ensure the Python server is running.',
        );
        debugOcrBuffer.writeln('[CONNECTION ERROR] $e');
      } on PythonOcrTimeoutException catch (e) {
        failedImages.add(path);
        errors.add(
          'Screenshot $currentNum: OCR processing timed out. Please try again.',
        );
        debugOcrBuffer.writeln('[TIMEOUT ERROR] $e');
      } on PythonOcrApiException catch (e) {
        failedImages.add(path);
        errors.add('Screenshot $currentNum: ${e.message}');
        debugOcrBuffer.writeln('[API ERROR] $e');
      } catch (e) {
        failedImages.add(path);
        errors.add('Screenshot $currentNum: Error during processing: $e');
        debugOcrBuffer.writeln('[UNKNOWN ERROR] $e');
      }
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
