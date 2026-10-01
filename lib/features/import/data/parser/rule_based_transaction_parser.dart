import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/ocr_document.dart';
import '../../domain/services/transaction_parser.dart';
import 'amount_reconstructor.dart';
import 'date_extractor.dart';
import 'layout_row_segmenter.dart';

/// Production-grade modular layout-aware parser for converting an [OcrDocument]
/// into candidate [ExtractedTransaction] models.
///
/// Follows an explainable pipeline:
/// 1. Spatial Layout Segmentation (Layout A, Layout B, Single Receipt)
/// 2. Split Amount Token & Digit Reconstruction (NEVER drops digits, e.g. "₹5,000" -> 500000 paise)
/// 3. Date Parsing (Relative "8 hours ago", GPay "7 September", and full timestamps)
/// 4. Merchant / Payee Extraction & UI Chrome Filtering
/// 5. Direction Inference (Income vs Expense via "+", "Received from", "Credited to")
/// 6. Category Inference via local extensible dictionary
/// 7. Explainable Confidence Scoring (High, Medium, Low)
class RuleBasedTransactionParser implements TransactionParser {
  final Uuid _uuid;
  final LayoutRowSegmenter _segmenter;

  RuleBasedTransactionParser({Uuid? uuid, LayoutRowSegmenter? segmenter})
    : _uuid = uuid ?? const Uuid(),
      _segmenter = segmenter ?? const LayoutRowSegmenter();

  @override
  List<ExtractedTransaction> parse(OcrDocument document) {
    if (document.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PARSER] Empty document received');
      }
      return const [];
    }

    final sourceName = _extractFileName(document.imagePath ?? 'Screenshot');

    // 1. Segment document lines into layout-aware candidate rows
    final segmentedRows = _segmenter.segmentDocument(document);

    int amountCandidates = 0;
    for (final l in document.lines) {
      if (AmountReconstructor.parseAmount(l.text) != null ||
          AmountReconstructor.splitCombinedMerchantAndAmount(l.text) != null) {
        amountCandidates++;
      }
    }

    final results = <ExtractedTransaction>[];
    int rejectedCount = 0;

    for (final row in segmentedRows) {
      final tx = _buildTransactionFromRow(row, sourceName);
      if (tx != null) {
        results.add(tx);
      } else {
        rejectedCount++;
        if (kDebugMode) {
          debugPrint(
            '[PARSER] Rejected row: ${row.amount.formattedText} - ${row.merchantRaw} (non-transaction or invalid)',
          );
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[PARSER] Lines received: ${document.lines.length}');
      debugPrint('[PARSER] Amount candidates: $amountCandidates');
      debugPrint('[PARSER] Transaction rows: ${segmentedRows.length}');
      debugPrint('[PARSER] Accepted: ${results.length}');
      debugPrint('[PARSER] Rejected: $rejectedCount');
      debugPrint('[IMPORT] Final transactions: ${results.length}');
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Transaction Construction from Segmented Row
  // ---------------------------------------------------------------------------
  ExtractedTransaction? _buildTransactionFromRow(
    SegmentedTransactionRow row,
    String sourceName,
  ) {
    final amountMinor = row.amount.amountMinor;
    if (amountMinor <= 0) return null;

    // 1. Merchant Extraction
    final cleanedMerchant = _cleanMerchant(row.merchantRaw);
    final effectiveTitle =
        (cleanedMerchant != null && cleanedMerchant.isNotEmpty)
        ? cleanedMerchant
        : (row.layoutType == DetectedLayoutType.singleReceipt
              ? 'Screenshot Transaction'
              : 'Transaction');

    // 2. Date Extraction
    final dateResult = row.dateResult;
    final effectiveDate = dateResult?.date ?? DateTime.now();

    // 3. Direction (Income vs Expense)
    final type = _determineType(row);

    // 4. Category Inference
    final category = _inferCategory(
      cleanedMerchant,
      row.lines.map((l) => l.text).toList(),
      type,
    );

    // 5. Confidence Calculation
    final confidence = _calculateConfidence(
      hasAmount: true,
      hasExplicitMerchant:
          cleanedMerchant != null && cleanedMerchant.length >= 2,
      hasExplicitDate: dateResult != null,
      hasExplicitYear: dateResult?.hasExplicitYear ?? false,
      hasDirectionHeader: row.hasDirectionHeader || row.isIncomeSignal,
      hasCategory: category != null,
      layoutType: row.layoutType,
    );

    // 6. Debug Summary (inspectable in kDebugMode)
    final rawDebug = _buildDebugString(
      row,
      cleanedMerchant,
      effectiveDate,
      type,
      confidence,
    );

    return ExtractedTransaction(
      id: _uuid.v4(),
      merchant: cleanedMerchant,
      title: effectiveTitle,
      amount: amountMinor,
      currency: 'INR',
      type: type,
      categoryId: category,
      date: effectiveDate,
      confidence: confidence,
      sourceReference: sourceName,
      rawText: rawDebug,
    );
  }

  // ---------------------------------------------------------------------------
  // Clean Merchant Name
  // ---------------------------------------------------------------------------
  String? _cleanMerchant(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();

    // If text contains an attached amount at the end, extract just the merchant part
    final split = AmountReconstructor.splitCombinedMerchantAndAmount(text);
    if (split != null) {
      text = split.merchantPart;
    }

    // Strip duplicate avatar initial at the beginning (e.g. "A ASHISH KUMAR NAYAK" -> "ASHISH KUMAR NAYAK")
    // In GPay, the avatar icon contains the first letter of the merchant. When OCR reads the avatar,
    // it produces "A ASHISH" or "J JIO" or "B Bishal". But preserve multi-part names like "M S SATYAM".
    final avatarMatch = RegExp(
      r'^([A-Za-z])\s+([A-Za-z])',
      caseSensitive: false,
    ).firstMatch(text);
    if (avatarMatch != null) {
      final initial = avatarMatch.group(1)!.toUpperCase();
      final nextInitial = avatarMatch.group(2)!.toUpperCase();
      if (initial == nextInitial) {
        text = text.replaceFirst(RegExp(r'^[A-Za-z]\s+'), '').trim();
      }
    }

    // Skip dates or amounts that slipped through
    if (DateExtractor.parseDate(text) != null) return null;
    if (AmountReconstructor.parseAmount(text) != null) return null;
    if (AmountReconstructor.isBlacklistedBalanceOrSummary(text)) return null;
    if (AmountReconstructor.isIdentifierOrPhone(text)) return null;

    // Remove common prefixes
    text = text.replaceAll(
      RegExp(
        r'^(paid to|payment to|sent to|transfer to|to:?|received from|from:?)\s*',
        caseSensitive: false,
      ),
      '',
    );

    // Remove common business suffixes
    text = text.replaceAll(
      RegExp(
        r'\s+(private limited|pvt\.?\s*ltd\.?|llc|inc\.?|india)$',
        caseSensitive: false,
      ),
      '',
    );

    // Skip generic app headers and status keywords
    if (_isGenericAppHeader(text)) return null;
    if (_isGenericStatusKeyword(text)) return null;

    text = text.trim();
    if (text.length < 2 || text.length > 100) return null;
    return text;
  }

  bool _isGenericAppHeader(String s) {
    final lower = s.toLowerCase();
    const generic = [
      'payment details',
      'transaction details',
      'transfer details',
      'bill payment',
      'debited from',
      'credited to',
      'search transactions',
      'status',
      'payment method',
      'date',
      'amount',
      'history',
      'help',
      'explore',
      'summary',
      'receipt',
    ];
    return generic.contains(lower);
  }

  bool _isGenericStatusKeyword(String s) {
    final lower = s.toLowerCase();
    const keywords = [
      'successful',
      'completed',
      'paid',
      'sent',
      'received',
      'failed',
      'done',
      'ok',
      'share',
      'repeat',
      'view details',
      'split with friends',
    ];
    return keywords.contains(lower);
  }

  // ---------------------------------------------------------------------------
  // Direction Determination
  // ---------------------------------------------------------------------------
  TransactionType _determineType(SegmentedTransactionRow row) {
    // Explicit income signal: "+ ₹..." or "Received from" or "Credited to"
    if (row.isIncomeSignal) {
      return TransactionType.income;
    }

    final rowText = row.lines.map((l) => l.text).join(' ').toLowerCase();
    if (rowText.contains('received from') ||
        rowText.contains('credited to') ||
        rowText.contains('money received') ||
        rowText.contains('refund') ||
        rowText.contains('cashback') ||
        rowText.contains('salary')) {
      return TransactionType.income;
    }

    // Default for Layout A and Layout B debit is Expense
    return TransactionType.expense;
  }


  // ---------------------------------------------------------------------------
  // Category Inference
  // ---------------------------------------------------------------------------
  String? _inferCategory(
    String? merchant,
    List<String> lines,
    TransactionType type,
  ) {
    if (type == TransactionType.income) {
      return 'income';
    }

    final text = '${merchant ?? ""} ${lines.join(" ")}'.toLowerCase();

    // Food & Dining
    if (_containsAny(text, [
      'swiggy',
      'zomato',
      'starbucks',
      'mcdonald',
      'kfc',
      'domino',
      'pizza',
      'burger',
      'restaurant',
      'cafe',
      'coffee',
      'bakery',
      'eats',
      'biryani',
      'od07 snacks',
      'snacks',
      'sweet',
      'hotel',
      'mistanna bhandar',
    ])) {
      return 'food';
    }

    // Transport & Fuel
    if (_containsAny(text, [
      'uber',
      'ola',
      'rapido',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'hpcl',
      'bpcl',
      'ioc',
      'indian oil',
      'shell',
      'parking',
      'toll',
      'fastag',
      'satyam service sta',
      'service sta',
    ])) {
      return 'transport';
    }

    // Bills, Telecom & Utilities
    if (_containsAny(text, [
      'electricity',
      'bescom',
      'water',
      'gas',
      'broadband',
      'wifi',
      'airtel',
      'jio',
      'reliance jio',
      'infocomm',
      'vi',
      'vodafone',
      'recharge',
      'dth',
      'tata play',
      'maintenance',
      'autopay',
      'mutual funds',
      'iccl',
    ])) {
      return 'bills';
    }

    // Groceries
    if (_containsAny(text, [
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'supermarket',
      'grocery',
      'fruits',
      'vegetables',
      'milk',
      'dairy',
      'provisions',
      'nature basket',
    ])) {
      return 'groceries';
    }

    // Shopping & Retail
    if (_containsAny(text, [
      'amazon',
      'flipkart',
      'myntra',
      'zara',
      'h&m',
      'ajio',
      'meesho',
      'nykaa',
      'retail',
      'clothing',
      'fashion',
      'electronics',
      'croma',
      'reliance digital',
      'store',
      'krishna store',
      'hemant store',
      'sri ram store',
    ])) {
      return 'shopping';
    }

    // Entertainment
    if (_containsAny(text, [
      'netflix',
      'spotify',
      'prime video',
      'hotstar',
      'disney',
      'cinema',
      'pvr',
      'inox',
      'bookmyshow',
      'theatre',
      'gaming',
      'steam',
      'playstation',
    ])) {
      return 'entertainment';
    }

    // Cash Withdrawal / Banking
    if (_containsAny(text, ['atm cash withdrawal', 'cash withdrawal', 'atm'])) {
      return 'other';
    }

    // Health
    if (_containsAny(text, [
      'apollo',
      'pharmacy',
      'medplus',
      'chemist',
      'hospital',
      'clinic',
      'doctor',
      'practo',
      'diagnostic',
      'pathology',
      'medical',
    ])) {
      return 'health';
    }

    return null;
  }

  bool _containsAny(String text, List<String> terms) {
    for (final t in terms) {
      if (text.contains(t)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Confidence Scoring
  // ---------------------------------------------------------------------------
  double _calculateConfidence({
    required bool hasAmount,
    required bool hasExplicitMerchant,
    required bool hasExplicitDate,
    required bool hasExplicitYear,
    required bool hasDirectionHeader,
    required bool hasCategory,
    required DetectedLayoutType layoutType,
  }) {
    if (!hasAmount) return 0.0;

    double score = 0.50; // Base score for valid reconstructed amount

    if (hasExplicitMerchant) score += 0.20;
    if (hasExplicitDate) score += 0.10;
    if (hasExplicitYear) score += 0.05;
    if (hasDirectionHeader) score += 0.05;
    if (hasCategory) score += 0.05;
    if (layoutType != DetectedLayoutType.singleReceipt) score += 0.03;

    return score.clamp(0.35, 0.96);
  }

  // ---------------------------------------------------------------------------
  // Debug Inspection String Builder
  // ---------------------------------------------------------------------------
  String _buildDebugString(
    SegmentedTransactionRow row,
    String? merchant,
    DateTime date,
    TransactionType type,
    double confidence,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=== DETECTED TRANSACTION ===');
    buffer.writeln('Layout: ${row.layoutType.name}');
    buffer.writeln('Title/Merchant: ${merchant ?? "Unlabeled"}');
    buffer.writeln(
      'Amount: ${row.amount.formattedText} (${row.amount.amountMinor} paise)',
    );
    buffer.writeln(
      'Date: ${date.toIso8601String().substring(0, 10)} (raw: "${row.dateResult?.rawMatchedText}")',
    );
    buffer.writeln('Type: ${type.name.toUpperCase()}');
    buffer.writeln('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('');
    buffer.writeln('--- ROW OCR LINES ---');
    for (final l in row.lines) {
      final box = l.boundingBox != null
          ? '[L:${l.boundingBox!.left.toInt()}, T:${l.boundingBox!.top.toInt()}, R:${l.boundingBox!.right.toInt()}, B:${l.boundingBox!.bottom.toInt()}]'
          : '[No BBox]';
      buffer.writeln('$box "${l.text}"');
    }
    return buffer.toString().trim();
  }

  static String _extractFileName(String path) {
    if (path.isEmpty) return 'Screenshot';
    final normalized = path.replaceAll(r'\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : 'Screenshot';
  }
}
