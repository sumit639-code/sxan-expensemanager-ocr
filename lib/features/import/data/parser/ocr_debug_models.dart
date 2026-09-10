import 'dart:ui';

/// Debug model representing an inspected OCR line with bounding box and decision tracking.
class OcrDebugLine {
  final String rawText;
  final Rect? boundingBox;
  final String normalizedText;
  final String? rejectionReason;
  final bool isAmount;
  final bool isDate;
  final bool isMerchant;

  const OcrDebugLine({
    required this.rawText,
    this.boundingBox,
    required this.normalizedText,
    this.rejectionReason,
    this.isAmount = false,
    this.isDate = false,
    this.isMerchant = false,
  });

  @override
  String toString() {
    final boxStr = boundingBox != null
        ? '[L:${boundingBox!.left.toInt()}, T:${boundingBox!.top.toInt()}, R:${boundingBox!.right.toInt()}, B:${boundingBox!.bottom.toInt()}]'
        : '[No BBox]';
    final rejStr = rejectionReason != null
        ? ' -> REJECTED ($rejectionReason)'
        : '';
    return '$boxStr "$rawText"$rejStr';
  }
}

/// Debug report generated during parsing for developer inspection in debug builds.
class OcrDebugReport {
  final String layoutDetected;
  final List<OcrDebugLine> lines;
  final List<String> detectedRows;
  final List<String> rejections;

  const OcrDebugReport({
    required this.layoutDetected,
    this.lines = const [],
    this.detectedRows = const [],
    this.rejections = const [],
  });

  /// Generates human-readable debug report summary.
  String toFormattedText() {
    final buffer = StringBuffer();
    buffer.writeln('=== OCR LAYOUT PARSER DEBUG REPORT ===');
    buffer.writeln('Layout: $layoutDetected');
    buffer.writeln('');
    buffer.writeln('--- OCR LINES (${lines.length}) ---');
    for (final line in lines) {
      buffer.writeln(line.toString());
    }
    if (rejections.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('--- REJECTIONS (${rejections.length}) ---');
      for (final rej in rejections) {
        buffer.writeln('• $rej');
      }
    }
    if (detectedRows.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
        '--- DETECTED TRANSACTION ROWS (${detectedRows.length}) ---',
      );
      for (final row in detectedRows) {
        buffer.writeln(row);
      }
    }
    return buffer.toString();
  }
}
