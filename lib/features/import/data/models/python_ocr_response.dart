import 'dart:math' as math;
import 'dart:ui';

/// Strongly-typed response model from the Python RapidOCR-ONNX API (supports V1 and V2 endpoints).
class PythonOcrResponse {
  final bool success;
  final String? filename;
  final List<PythonOcrItem> items;
  final List<PythonTransactionCandidate> transactionCandidates;
  final String? message;
  final Map<String, dynamic>? metadata;

  const PythonOcrResponse({
    required this.success,
    this.filename,
    this.items = const [],
    this.transactionCandidates = const [],
    this.message,
    this.metadata,
  });

  factory PythonOcrResponse.fromJson(Map<String, dynamic> json) {
    // 1. Parse raw OCR items / tokens
    final rawItems = json['items'] ?? json['tokens'] ?? json['data'] ?? json['results'];
    final itemsList = <PythonOcrItem>[];

    if (rawItems is List) {
      for (int i = 0; i < rawItems.length; i++) {
        final itemJson = rawItems[i];
        if (itemJson is Map<String, dynamic>) {
          itemsList.add(PythonOcrItem.fromJson(itemJson, defaultIndex: i + 1));
        }
      }
    }

    // 2. Parse V2 transaction candidates if present
    final rawCandidates = json['transaction_candidates'] ?? json['candidates'];
    final candidatesList = <PythonTransactionCandidate>[];

    if (rawCandidates is List) {
      for (int i = 0; i < rawCandidates.length; i++) {
        final candJson = rawCandidates[i];
        if (candJson is Map<String, dynamic>) {
          candidatesList.add(PythonTransactionCandidate.fromJson(candJson, defaultIndex: i + 1));
        }
      }
    }

    return PythonOcrResponse(
      success: json['success'] as bool? ?? true,
      filename: json['filename'] as String?,
      items: itemsList,
      transactionCandidates: candidatesList,
      message: json['message'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    if (filename != null) 'filename': filename,
    'items': items.map((e) => e.toJson()).toList(),
    if (transactionCandidates.isNotEmpty)
      'transaction_candidates':
          transactionCandidates.map((e) => e.toJson()).toList(),
    if (message != null) 'message': message,
    if (metadata != null) 'metadata': metadata,
  };

  @override
  String toString() =>
      'PythonOcrResponse(success: $success, items: ${items.length}, candidates: ${transactionCandidates.length}, file: $filename)';
}

/// A candidate transaction extracted directly by the Python V2 endpoint (`/extract/v2`).
class PythonTransactionCandidate {
  final String? id;
  final int? amount;
  final double? amountDouble;
  final String? currency;
  final String? merchant;
  final String? title;
  final String? rawDate;
  final DateTime? date;
  final String? type; // 'expense', 'income', 'DEBIT', 'CREDIT'
  final double confidence;
  final String? category;
  final String? status;
  final Map<String, dynamic>? rawJson;

  const PythonTransactionCandidate({
    this.id,
    this.amount,
    this.amountDouble,
    this.currency,
    this.merchant,
    this.title,
    this.rawDate,
    this.date,
    this.type,
    this.confidence = 1.0,
    this.category,
    this.status,
    this.rawJson,
  });

  factory PythonTransactionCandidate.fromJson(
    Map<String, dynamic> json, {
    int defaultIndex = 1,
  }) {
    final rawAmt = json['amount'] ?? json['amount_cents'] ?? json['parsed_amount'];
    int? parsedAmount;
    double? parsedAmountDouble;

    if (rawAmt is num) {
      if (rawAmt is int) {
        parsedAmount = rawAmt;
        parsedAmountDouble = rawAmt.toDouble();
      } else {
        parsedAmountDouble = rawAmt.toDouble();
        parsedAmount = (rawAmt * 100).round();
      }
    }

    final rawScore = json['confidence'] ?? json['score'] ?? json['composite_score'];
    final confidence = rawScore is num ? rawScore.toDouble().clamp(0.0, 1.0) : 1.0;

    final dateStr = json['date']?.toString() ?? json['timestamp']?.toString();
    DateTime? parsedDate;
    if (dateStr != null) {
      parsedDate = DateTime.tryParse(dateStr);
    }

    return PythonTransactionCandidate(
      id: json['id']?.toString() ?? 'candidate_$defaultIndex',
      amount: parsedAmount,
      amountDouble: parsedAmountDouble,
      currency: json['currency']?.toString() ?? 'INR',
      merchant: json['merchant']?.toString() ?? json['receiver']?.toString() ?? json['payee']?.toString(),
      title: json['title']?.toString() ?? json['description']?.toString(),
      rawDate: dateStr,
      date: parsedDate,
      type: json['type']?.toString() ?? json['direction']?.toString(),
      confidence: confidence,
      category: json['category']?.toString(),
      status: json['status']?.toString(),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (amount != null) 'amount': amount,
    if (currency != null) 'currency': currency,
    if (merchant != null) 'merchant': merchant,
    if (title != null) 'title': title,
    if (rawDate != null) 'date': rawDate,
    if (type != null) 'type': type,
    'confidence': confidence,
    if (category != null) 'category': category,
    if (status != null) 'status': status,
  };
}

/// A single extracted OCR item/token from the Python RapidOCR-ONNX API.
class PythonOcrItem {
  final int readingIndex;
  final String text;
  final String? textNormalized;
  final double compositeScore;
  final Rect? boundingBox;
  final dynamic rawBbox;
  final bool isNumericAmount;
  final int? parsedIntegerAmount;
  final String? currency;
  final String? tokenType;

  const PythonOcrItem({
    required this.readingIndex,
    required this.text,
    this.textNormalized,
    this.compositeScore = 1.0,
    this.boundingBox,
    this.rawBbox,
    this.isNumericAmount = false,
    this.parsedIntegerAmount,
    this.currency,
    this.tokenType,
  });

  /// Best effective text (prefers normalized text when present, falls back to text).
  String get effectiveText {
    final norm = textNormalized?.trim();
    if (norm != null && norm.isNotEmpty) return norm;
    return text.trim();
  }

  factory PythonOcrItem.fromJson(
    Map<String, dynamic> json, {
    int defaultIndex = 0,
  }) {
    final rawIndex = json['reading_index'] ?? json['index'] ?? defaultIndex;
    final readingIndex = rawIndex is num ? rawIndex.toInt() : defaultIndex;

    final text = (json['text'] ?? '').toString();
    final textNorm = json['text_normalized']?.toString();

    final rawScore = json['composite_score'] ?? json['score'] ?? json['confidence'];
    final compositeScore = rawScore is num
        ? rawScore.toDouble().clamp(0.0, 1.0)
        : 1.0;

    final rawBbox = json['bbox'] ?? json['bounding_box'] ?? json['box'];
    final boundingBox = _parseBoundingBox(rawBbox);

    final isNumeric = json['is_numeric_amount'] as bool? ?? false;

    final rawAmt = json['parsed_integer_amount'] ?? json['amount'];
    final parsedInt = rawAmt is num ? rawAmt.toInt() : null;

    final currency = json['currency']?.toString();
    final tokenType = json['token_type']?.toString() ?? json['type']?.toString();

    return PythonOcrItem(
      readingIndex: readingIndex,
      text: text,
      textNormalized: textNorm,
      compositeScore: compositeScore,
      boundingBox: boundingBox,
      rawBbox: rawBbox,
      isNumericAmount: isNumeric,
      parsedIntegerAmount: parsedInt,
      currency: currency,
      tokenType: tokenType,
    );
  }

  Map<String, dynamic> toJson() => {
    'reading_index': readingIndex,
    'text': text,
    if (textNormalized != null) 'text_normalized': textNormalized,
    'composite_score': compositeScore,
    if (rawBbox != null) 'bbox': rawBbox,
    'is_numeric_amount': isNumericAmount,
    if (parsedIntegerAmount != null)
      'parsed_integer_amount': parsedIntegerAmount,
    if (currency != null) 'currency': currency,
    if (tokenType != null) 'token_type': tokenType,
  };

  /// Parses flexible bbox formats from RapidOCR / PaddleOCR / ONNX:
  /// 1. 4 polygon points: `[[x1,y1],[x2,y2],[x3,y3],[x4,y4]]`
  /// 2. 4 flat numbers: `[x, y, w, h]` or `[left, top, right, bottom]`
  static Rect? _parseBoundingBox(dynamic raw) {
    if (raw == null || raw is! List || raw.isEmpty) return null;

    try {
      // Format 1: List of points [[x, y], [x, y], ...]
      if (raw.first is List) {
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = -double.infinity;
        double maxY = -double.infinity;

        for (final pt in raw) {
          if (pt is List && pt.length >= 2) {
            final x = (pt[0] as num).toDouble();
            final y = (pt[1] as num).toDouble();
            minX = math.min(minX, x);
            minY = math.min(minY, y);
            maxX = math.max(maxX, x);
            maxY = math.max(maxY, y);
          }
        }

        if (minX.isFinite && minY.isFinite && maxX > minX && maxY > minY) {
          return Rect.fromLTRB(minX, minY, maxX, maxY);
        }
      }

      // Format 2: Flat list of 4 numbers [x, y, w, h] or [l, t, r, b]
      if (raw.length == 4 && raw.every((e) => e is num)) {
        final a = (raw[0] as num).toDouble();
        final b = (raw[1] as num).toDouble();
        final c = (raw[2] as num).toDouble();
        final d = (raw[3] as num).toDouble();

        // If c > a and d > b, it could be [l, t, r, b]
        if (c > a && d > b) {
          return Rect.fromLTRB(a, b, c, d);
        }
        // Otherwise treat as [x, y, width, height]
        if (c > 0 && d > 0) {
          return Rect.fromLTWH(a, b, c, d);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  String toString() =>
      'PythonOcrItem(#$readingIndex: "$text", type: $tokenType, score: $compositeScore, amt: $parsedIntegerAmount)';
}
