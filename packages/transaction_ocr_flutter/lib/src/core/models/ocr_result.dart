import 'ocr_item.dart';
import 'extracted_transaction.dart';

/// Top-level result returned from OCR and transaction extraction.
/// Compatible with Python V2 pipeline /extract/v2 format.
class OcrResult {
  final bool success;
  final String filename;
  final int width;
  final int height;
  final String engine;
  final int itemsCount;
  final List<OcrItem> items;
  final String pipelineVersion;
  final Map<String, int> tokenSummary;
  final List<ExtractedTransaction> transactionCandidates;
  final int transactionCandidatesCount;
  final String? errorMessage;

  const OcrResult({
    required this.success,
    required this.filename,
    required this.width,
    required this.height,
    required this.engine,
    required this.itemsCount,
    required this.items,
    this.pipelineVersion = 'V2',
    this.tokenSummary = const {},
    this.transactionCandidates = const [],
    this.transactionCandidatesCount = 0,
    this.errorMessage,
  });

  /// Shortcut getter to access extracted transaction candidates
  List<ExtractedTransaction> get transactions => transactionCandidates;

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((i) => OcrItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final txList = (json['transaction_candidates'] as List<dynamic>? ?? [])
        .map((t) => ExtractedTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    final summaryRaw = json['token_summary'] as Map<String, dynamic>? ?? {};
    final tokenSummary = summaryRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    return OcrResult(
      success: json['success'] as bool? ?? true,
      filename: json['filename'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      engine: json['engine'] as String? ?? 'RapidOCR-ONNX',
      itemsCount: json['items_count'] as int? ?? itemsList.length,
      items: itemsList,
      pipelineVersion: json['pipeline_version'] as String? ?? 'V2',
      tokenSummary: tokenSummary,
      transactionCandidates: txList,
      transactionCandidatesCount: json['transaction_candidates_count'] as int? ?? txList.length,
      errorMessage: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'filename': filename,
      'width': width,
      'height': height,
      'engine': engine,
      'items_count': itemsCount,
      'items': items.map((i) => i.toJson()).toList(),
      'pipeline_version': pipelineVersion,
      'token_summary': tokenSummary,
      'transaction_candidates': transactionCandidates.map((t) => t.toJson()).toList(),
      'transaction_candidates_count': transactionCandidatesCount,
      if (errorMessage != null) 'error': errorMessage,
    };
  }

  @override
  String toString() =>
      'OcrResult(success: $success, items: $itemsCount, transactions: $transactionCandidatesCount, engine: $engine)';
}
