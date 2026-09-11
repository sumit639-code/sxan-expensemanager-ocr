import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart' as pkg;

import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/extraction_result.dart';
import '../../domain/entities/ocr_document.dart';
import '../../domain/services/transaction_extractor.dart';
import '../../domain/services/transaction_parser.dart';
import '../parser/date_extractor.dart';
import 'image_preprocessor.dart';

/// Production on-device implementation of [TransactionExtractor] powered by
/// [pkg.TransactionOcr.local()] from `transaction_ocr_flutter` V2.
///
/// Features:
/// - 100% offline local on-device inference using ONNX Runtime (Mobile).
/// - Fast and memory-efficient pipeline with bundled DBNet detection, SVTR-LCNet recognition, and CTC decoding.
/// - Multi-layer candidate consolidation, ₹ symbol normalizer, and spatial transaction row grouping.
/// - Exact integer minor units (paise/cents) amount preservation.
/// - Rejection of noise (time labels e.g. 16:48, dates, status bar artifacts, alpha tokens).
class LocalTransactionOcrExtractor implements TransactionExtractor {
  final pkg.TransactionOcr _ocrService;
  final TransactionParser? _fallbackParser;
  final ImagePreprocessor _preprocessor;

  LocalTransactionOcrExtractor({
    pkg.TransactionOcr? ocrService,
    TransactionParser? fallbackParser,
    ImagePreprocessor? preprocessor,
  })  : _ocrService = ocrService ??
            pkg.TransactionOcr.local(
              config: const pkg.OcrConfig(
                detModelPath:
                    'packages/transaction_ocr_flutter/assets/models/v1.0.0/det_v1.onnx',
                recModelPath:
                    'packages/transaction_ocr_flutter/assets/models/v1.0.0/rec_v1.onnx',
                clsModelPath:
                    'packages/transaction_ocr_flutter/assets/models/v1.0.0/cls_v1.onnx',
                keysPath:
                    'packages/transaction_ocr_flutter/assets/models/v1.0.0/keys_v1.txt',
              ),
            ),
        _fallbackParser = fallbackParser,
        _preprocessor = preprocessor ?? const ImagePreprocessor();

  /// Ensures OCR engine models are initialized and ready for inference.
  Future<void> initialize() => _ocrService.initialize();

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

    onProgress?.call('Validating screenshots...', 0.05);

    // 1. Validate images
    final validated = _preprocessor.validateImages(imagePaths);
    final validImages =
        validated.where((v) => v.isValid).map((v) => v.path).toList();
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

    // 2. Initialize local on-device OCR engine
    if (!_ocrService.isInitialized) {
      onProgress?.call('Initializing local OCR engine...', 0.10);
      try {
        await _ocrService.initialize();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[LOCAL OCR INIT ERROR]: $e\n$st');
        }
        return ExtractionResult(
          transactions: const [],
          successfulImages: const [],
          failedImages: validImages,
          errors: ['Failed to load on-device OCR models: $e'],
        );
      }
    }

    final allExtracted = <ExtractedTransaction>[];
    final totalCount = validImages.length;
    final files = validImages.map((p) => File(p)).toList();

    // 3. Process each screenshot on-device via TransactionOcr.local()
    for (int i = 0; i < totalCount; i++) {
      final file = files[i];
      final path = validImages[i];
      final currentNum = i + 1;
      final stepProgress = 0.15 + ((i / totalCount) * 0.70);

      onProgress?.call(
        'Processing screenshot $currentNum of $totalCount...',
        stepProgress,
      );

      // Yield between screenshots so the loading animation stays smooth
      if (i > 0) {
        await Future<void>.delayed(Duration.zero);
      }

      try {
        final ocrResult = await _ocrService.extractImage(
          file,
          onProgress: (current, total, step, frac) {
            final overallProgress = stepProgress + (frac * (0.70 / totalCount));
            onProgress?.call(
              'Screenshot $currentNum of $totalCount: $step',
              overallProgress.clamp(0.0, 0.95),
            );
          },
        );

        // Record structured debug output for Debug Extraction Inspector
        debugOcrBuffer.writeln('========================================');
        debugOcrBuffer.writeln('SCREENSHOT $currentNum: ${ocrResult.filename}');
        debugOcrBuffer.writeln('Path: $path');
        debugOcrBuffer.writeln('Dimensions: ${ocrResult.width}x${ocrResult.height}');
        debugOcrBuffer.writeln('Engine: ${ocrResult.engine} | Pipeline: ${ocrResult.pipelineVersion}');
        debugOcrBuffer.writeln('----------------------------------------');
        debugOcrBuffer.writeln('1. RAW OCR ITEMS (${ocrResult.items.length}):');
        if (ocrResult.items.isEmpty) {
          debugOcrBuffer.writeln('  (No raw OCR items in payload)');
        } else {
          for (final item in ocrResult.items) {
            final amtTag = item.isNumericAmount ? ' [AMOUNT CANDIDATE: ₹${item.parsedIntegerAmount}]' : '';
            final bboxStr = '[${item.bbox.minX.round()}, ${item.bbox.minY.round()}, ${item.bbox.maxX.round()}, ${item.bbox.maxY.round()}]';
            debugOcrBuffer.writeln('  #${item.readingIndex} "${item.text}" -> norm: "${item.textNormalized}" | bbox: $bboxStr | conf: ${(item.confidence * 100).toStringAsFixed(1)}% | score: ${item.compositeScore.toStringAsFixed(2)}$amtTag');
          }
        }
        debugOcrBuffer.writeln('----------------------------------------');
        debugOcrBuffer.writeln('2. CANDIDATE TRANSACTIONS (${ocrResult.transactions.length}):');
        if (ocrResult.transactions.isEmpty) {
          debugOcrBuffer.writeln('  (No candidates grouped)');
        } else {
          for (int cIdx = 0; cIdx < ocrResult.transactions.length; cIdx++) {
            final cand = ocrResult.transactions[cIdx];
            final mBbox = cand.merchantBbox != null
                ? '[${cand.merchantBbox!.minX.round()}, ${cand.merchantBbox!.minY.round()}, ${cand.merchantBbox!.maxX.round()}, ${cand.merchantBbox!.maxY.round()}]'
                : 'none';
            final aBbox = cand.amountBbox != null
                ? '[${cand.amountBbox!.minX.round()}, ${cand.amountBbox!.minY.round()}, ${cand.amountBbox!.maxX.round()}, ${cand.amountBbox!.maxY.round()}]'
                : 'none';
            debugOcrBuffer.writeln('  Row #${cIdx + 1}:');
            debugOcrBuffer.writeln('    • Merchant: "${cand.merchantText ?? "(none)"}" (bbox: $mBbox)');
            debugOcrBuffer.writeln('    • Amount: ${cand.amountTextNormalized} (raw: "${cand.amountTextRaw}", minorUnits: ${cand.amountMinorUnits ?? (cand.amountValue != null ? (cand.amountValue! * 100).round() : 0)}, bbox: $aBbox)');
            debugOcrBuffer.writeln('    • Date: "${cand.dateText ?? "(none)"}"');
            debugOcrBuffer.writeln('    • Type: ${cand.transactionType}');
            debugOcrBuffer.writeln('    • Confidence: ${(cand.groupingConfidence * 100).toStringAsFixed(1)}% (amt conf: ${(cand.amountConfidence * 100).toStringAsFixed(1)}%)');
            if (cand.warnings.isNotEmpty) {
              debugOcrBuffer.writeln('    • Warnings: ${cand.warnings.join(", ")}');
            }
          }
        }
        debugOcrBuffer.writeln('========================================');
        debugOcrBuffer.writeln();

        final candidateTxs = <ExtractedTransaction>[];

        // 3a. First consume structured V2 transaction candidates from TransactionGrouper
        if (ocrResult.transactions.isNotEmpty) {
          // Pre-resolve dates for all candidates in this screenshot
          final parsedDates = <int, DateTime>{};
          for (int idx = 0; idx < ocrResult.transactions.length; idx++) {
            final rawDate = ocrResult.transactions[idx].dateText;
            if (rawDate != null && rawDate.trim().isNotEmpty) {
              final res = DateExtractor.parseDate(rawDate);
              if (res != null) {
                parsedDates[idx] = res.date;
              } else {
                final tryDt = DateTime.tryParse(rawDate);
                if (tryDt != null) parsedDates[idx] = tryDt;
              }
            }
          }

          // Contextual date propagation: if a candidate has no explicit date (e.g. cut off at screen edge),
          // inherit from nearest preceding row, or nearest succeeding row in the same screenshot.
          final DateTime? screenshotFallbackDate =
              parsedDates.isNotEmpty ? parsedDates.values.first : null;

          for (int idx = 0; idx < ocrResult.transactions.length; idx++) {
            final cand = ocrResult.transactions[idx];
            final amtValue = cand.amountValue;
            if (amtValue == null || amtValue <= 0) continue;

            final minorUnits = cand.amountMinorUnits ?? MoneyUtils.doubleToMinorUnits(amtValue.toDouble());

            DateTime? resolvedDate = parsedDates[idx];
            bool dateInferred = false;
            if (resolvedDate == null) {
              // Search backwards for nearest preceding date in screenshot
              for (int back = idx - 1; back >= 0; back--) {
                if (parsedDates.containsKey(back)) {
                  resolvedDate = parsedDates[back];
                  dateInferred = true;
                  break;
                }
              }
              // If none preceding, search forward
              if (resolvedDate == null) {
                for (int fwd = idx + 1; fwd < ocrResult.transactions.length; fwd++) {
                  if (parsedDates.containsKey(fwd)) {
                    resolvedDate = parsedDates[fwd];
                    dateInferred = true;
                    break;
                  }
                }
              }
              resolvedDate ??= screenshotFallbackDate ?? DateTime.now();
            }

            final merchant = cand.merchantText?.trim();
            final title = (merchant != null && merchant.isNotEmpty)
                ? merchant
                : 'Payment ${MoneyUtils.formatMinorUnits(minorUnits)}';

            final confidence = (cand.groupingConfidence > 0)
                ? cand.groupingConfidence
                : cand.amountConfidence;

            final txType = (cand.transactionType.toLowerCase() == 'income')
                ? TransactionType.income
                : TransactionType.expense;

            final activeWarnings = List<String>.from(cand.warnings);
            if (dateInferred) {
              activeWarnings.remove('Date not detected');
            }

            candidateTxs.add(
              ExtractedTransaction(
                id: 'tx_local_${DateTime.now().microsecondsSinceEpoch}_${i}_$idx',
                amount: minorUnits,
                currency: 'INR',
                title: title,
                merchant: merchant,
                date: resolvedDate,
                type: txType,
                confidence: double.parse(confidence.clamp(0.1, 1.0).toStringAsFixed(2)),
                sourceReference: ocrResult.filename,
                note: activeWarnings.isNotEmpty ? activeWarnings.join('; ') : null,
                rawText: cand.amountTextRaw.isNotEmpty
                    ? cand.amountTextRaw
                    : (cand.amountTextNormalized.isNotEmpty
                        ? cand.amountTextNormalized
                        : title),
              ),
            );
          }
        }

        // 3b. Fallback: if grouper produced 0 candidates but OCR detected text items, run fallback parser
        if (candidateTxs.isEmpty && ocrResult.items.isNotEmpty && _fallbackParser != null) {
          final ocrDoc = convertToOcrDocument(
            ocrResult.items,
            imagePath: path,
            imageWidth: ocrResult.width,
            imageHeight: ocrResult.height,
          );
          final fallbackParsed = _fallbackParser.parse(ocrDoc);
          candidateTxs.addAll(fallbackParsed);
        }


        if (candidateTxs.isEmpty) {
          failedImages.add(path);
          errors.add(
            'Screenshot $currentNum: No recognizable transactions found in this receipt.',
          );
        } else {
          successfulImages.add(path);
          allExtracted.addAll(candidateTxs);
        }
      } on pkg.ModelLoadException catch (e) {
        if (kDebugMode) {
          debugPrint('[LOCAL OCR MODEL ERROR] $path: $e');
        }
        failedImages.add(path);
        errors.add('Screenshot $currentNum: OCR model failed to load. Please restart the app and try again.');
      } on pkg.ModelInferenceException catch (e) {
        if (kDebugMode) {
          debugPrint('[LOCAL OCR INFERENCE ERROR] $path: $e');
        }
        failedImages.add(path);
        errors.add('Screenshot $currentNum: OCR inference failed. The image may be too large or corrupted.');
      } on pkg.ImageProcessingException catch (e) {
        if (kDebugMode) {
          debugPrint('[LOCAL OCR IMAGE ERROR] $path: $e');
        }
        failedImages.add(path);
        errors.add('Screenshot $currentNum: Could not process this image. Please try a different screenshot.');
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('[LOCAL OCR ERROR] Failed on $path: $e\n$stackTrace');
        }
        failedImages.add(path);
        errors.add('Screenshot $currentNum: OCR error: $e');
      }
    }

    onProgress?.call('Finalizing extraction...', 0.95);

    return ExtractionResult(
      transactions: allExtracted,
      successfulImages: successfulImages,
      failedImages: failedImages,
      errors: errors,
      debugOcrText: debugOcrBuffer.toString(),
    );
  }

  static OcrDocument convertToOcrDocument(
    List<pkg.OcrItem> items, {
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
  }) {
    final ocrLines = <OcrLine>[];
    final fullTextLines = <String>[];

    for (final item in items) {
      final text = item.textNormalized.isNotEmpty ? item.textNormalized : item.text;
      if (text.trim().isEmpty) continue;
      fullTextLines.add(text);

      ui.Rect? rect;
      final bbox = item.bbox;
      if (bbox.width > 0 && bbox.height > 0) {
        rect = ui.Rect.fromLTRB(bbox.minX, bbox.minY, bbox.maxX, bbox.maxY);
      }

      ocrLines.add(
        OcrLine(
          text: text,
          boundingBox: rect,
          confidence: item.compositeScore,
          elements: [
            OcrElement(
              text: text,
              boundingBox: rect,
              confidence: item.compositeScore,
            ),
          ],
        ),
      );
    }

    final docWidth = imageWidth ?? 720;
    final docHeight = imageHeight ?? 1600;

    return OcrDocument(
      fullText: fullTextLines.join('\n'),
      blocks: [
        OcrBlock(
          text: fullTextLines.join('\n'),
          boundingBox: ui.Rect.fromLTWH(0, 0, docWidth.toDouble(), docHeight.toDouble()),
          lines: ocrLines,
        ),
      ],
      lines: ocrLines,
      imageWidth: docWidth,
      imageHeight: docHeight,
      imagePath: imagePath,
    );
  }
}
