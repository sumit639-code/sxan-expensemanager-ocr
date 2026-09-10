import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/ocr_document.dart';
import '../../domain/services/ocr_engine.dart';

/// Concrete implementation of [OcrEngine] powered by Google ML Kit Text Recognition.
///
/// Runs 100% on-device (offline) using ML Kit's Latin script model.
/// Normalizes vendor types (RecognizedText, TextBlock, TextLine, TextElement)
/// into domain [OcrDocument], [OcrBlock], [OcrLine], and [OcrElement].
class MlKitOcrEngine implements OcrEngine {
  TextRecognizer? _recognizer;

  TextRecognizer get _safeRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.devanagiri);

  @override
  Future<OcrDocument> recognizeText(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('[IMPORT] Image: $imagePath');
      debugPrint('[OCR] Started');
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _safeRecognizer.processImage(inputImage);

      // Read actual image dimensions for accurate spatial segmentation
      int? imgWidth;
      int? imgHeight;
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          imgWidth = frame.image.width;
          imgHeight = frame.image.height;
          frame.image.dispose();
          codec.dispose();
          if (kDebugMode) {
            debugPrint('[OCR] Image dimensions: ${imgWidth}x$imgHeight');
          }
        }
      } catch (dimErr) {
        if (kDebugMode) {
          debugPrint('[OCR] Could not read image dimensions: $dimErr');
        }
      }

      final domainBlocks = <OcrBlock>[];
      final allLines = <OcrLine>[];
      int totalElements = 0;

      for (final block in recognizedText.blocks) {
        final domainLines = <OcrLine>[];

        for (final line in block.lines) {
          final domainElements = <OcrElement>[];
          for (final el in line.elements) {
            totalElements++;
            domainElements.add(
              OcrElement(
                text: el.text,
                boundingBox: el.boundingBox,
                confidence: el.confidence,
              ),
            );
          }

          final domainLine = OcrLine(
            text: line.text,
            boundingBox: line.boundingBox,
            elements: domainElements,
            confidence: line.confidence,
          );

          domainLines.add(domainLine);
          allLines.add(domainLine);
        }

        domainBlocks.add(
          OcrBlock(
            text: block.text,
            boundingBox: block.boundingBox,
            lines: domainLines,
          ),
        );
      }

      // Sort lines top-to-bottom, left-to-right if bounding boxes are present
      allLines.sort((a, b) {
        if (a.boundingBox != null && b.boundingBox != null) {
          final diffY = a.boundingBox!.top - b.boundingBox!.top;
          if (diffY.abs() > 12) {
            return diffY.compareTo(0);
          }
          return a.boundingBox!.left.compareTo(b.boundingBox!.left);
        }
        return 0;
      });

      if (kDebugMode) {
        debugPrint('[OCR] Completed in ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('[OCR] Blocks: ${domainBlocks.length}');
        debugPrint('[OCR] Lines: ${allLines.length}');
        debugPrint('[OCR] Elements: $totalElements');
        debugPrint('[OCR] TEXT:\n${recognizedText.text}');
      }

      return OcrDocument(
        fullText: recognizedText.text,
        blocks: domainBlocks,
        lines: allLines,
        imagePath: imagePath,
        imageWidth: imgWidth,
        imageHeight: imgHeight,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          '[OCR ERROR] Failed to process image $imagePath: $e\n$stack',
        );
      }
      return OcrDocument.empty(imagePath: imagePath);
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
