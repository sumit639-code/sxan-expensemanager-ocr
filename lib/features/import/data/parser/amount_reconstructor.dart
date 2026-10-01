import '../../domain/entities/ocr_document.dart';
import 'date_extractor.dart';

/// Representation of a parsed and reconstructed monetary amount.
class ReconstructedAmount {
  /// Monetary amount in integer minor units (paise / cents).
  /// Never loses digits; no floating point arithmetic in final value.
  final int amountMinor;

  /// True if a positive indicator (e.g. "+ ₹8,000" or "+ ₹1") was detected.
  final bool isIncome;

  /// Raw matched string representation before normalization.
  final String rawMatchedText;

  /// Clean normalized display representation (e.g. "₹5,000").
  final String formattedText;

  const ReconstructedAmount({
    required this.amountMinor,
    required this.isIncome,
    required this.rawMatchedText,
    required this.formattedText,
  });

  @override
  String toString() =>
      'ReconstructedAmount(minor: $amountMinor, income: $isIncome, raw: "$rawMatchedText")';
}

/// Representation of an OCR line containing both merchant title and monetary amount.
class ExtractedLineParts {
  final String merchantPart;
  final ReconstructedAmount amount;

  const ExtractedLineParts({required this.merchantPart, required this.amount});
}

/// Advanced reconstructor and validator for OCR monetary amounts.
///
/// Specifically addresses on-device OCR issues where symbols and numbers
/// may be split into separate tokens or lines (e.g. "₹", "5", ",", "000").
class AmountReconstructor {
  const AmountReconstructor._();

  /// Blacklisted phrases representing non-transaction totals, balances, and account summaries.
  static const List<String> balanceAndSummaryKeywords = [
    'available balance',
    'account balance',
    'closing balance',
    'opening balance',
    'ledger balance',
    'a/c bal',
    'ac bal',
    'bal:',
    'balance:',
    'total balance',
    'total spent',
    'total received',
    'total expense',
    'statement total',
    'subtotal',
    'convenience fee',
    'platform fee',
    'handling fee',
  ];

  /// Keywords that identify reference codes or IDs rather than monetary amounts.
  static const List<String> identifierKeywords = [
    'transaction id',
    'txn id',
    'upi ref',
    'utr no',
    'reference no',
    'order id',
    'rrn:',
    'upi transaction id',
    'coins redeemed',
    'coins',
    'debited from',
    'check balance',
    'payment location',
    'view history',
    'pay again',
    'share receipt',
  ];

  /// Checks whether [text] is an account balance or summary statement line.
  static bool isBlacklistedBalanceOrSummary(String text) {
    final lower = text.toLowerCase().trim();
    for (final kw in balanceAndSummaryKeywords) {
      if (lower.contains(kw)) return true;
    }
    // Match standalone "Total", "Total: ₹...", or monthly summary footers like "August 2026 + ₹3,700.97"
    if (RegExp(
      r'^\s*total\s*[:₹\d\s,.]*$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    // Monthly summary line: e.g. "August 2026 + ₹3,700.97"
    if (RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4}\s*[+₹]',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// Checks whether [text] represents a reference number, order ID, or phone number.
  static bool isIdentifierOrPhone(String text) {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    for (final kw in identifierKeywords) {
      if (lower.contains(kw)) return true;
    }

    // Hard-reject UPI VPA handles (e.g. "paytmqr6mqm7q@ptys", "MYBMTCDQR@ybl")
    if (clean.contains('@')) {
      return true;
    }

    // Bare numeric token 7 or more digits without currency symbol (e.g. 12-digit UPI IDs, 32-digit internal IDs)
    if (RegExp(r'^\d{7,}$').hasMatch(clean)) {
      return true;
    }

    // Numbers with multiple leading zeros (e.g. "004415604898", "08840")
    if (RegExp(r'^0\d+$').hasMatch(clean)) {
      return true;
    }

    // Bank account suffix pattern e.g. "- 8840", "Indian Bank - 8840", "xx8840", "**8840"
    if (RegExp(r'^(?:.*-\s*|\*{2,}|x{2,})\d{3,5}$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // Phone number pattern e.g. +91 9876543210 or 9876543210
    if (RegExp(r'^(?:\+91[\s-]?)?[6-9]\d{9}$').hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Normalizes OCR symbol misreads (R20 -> ₹20, 75,000 -> ₹5,000, 7205 -> ₹205).
  static String normalizeSymbol(String text) {
    var s = text.trim();
    // Prefix 'Rs.' / 'Rs' / 'INR' -> ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)(?:Rs\.?|INR)\s*(\d)', caseSensitive: false),
      (m) => '${m[1]}₹${m[2]}',
    );
    // Leading 'R' / 'r' + digit -> ₹
    s = s.replaceAllMapped(RegExp(r'^([+-]?\s*)[Rr]\s*(\d)'), (m) => '${m[1]}₹${m[2]}');
    // Leading '#' / '＃' + digit -> ₹
    s = s.replaceAllMapped(RegExp(r'^([+-]?\s*)[#＃]\s*(\d)'), (m) => '${m[1]}₹${m[2]}');
    // Leading Chinese artifact '买' / '尐' / '￥' / '¥' / '尺' -> ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[\u4e70\u5c10\uffe5\u00a5\u5c3a]\s*(\d)'),
      (m) => '${m[1]}₹${m[2]}',
    );
    // Leading '?' / '¿' / '*' before digits -> ₹
    s = s.replaceAllMapped(RegExp(r'^([+-]?\s*)[\?\¿\*]\s*(\d)'), (m) => '${m[1]}₹${m[2]}');
    // Leading 'z' / 'Z' before digits with thousands comma -> ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[zZ]\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]}₹${m[2]}',
    );
    // Leading 'F' / 'f' before digits -> ₹ (e.g. 'F50' -> '₹50', 'F1,500' -> '₹1,500')
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[Ff]\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]}₹${m[2]}',
    );
    // Leading '7' before 1 to 5 digits (OCR misread of '₹' as '7'):
    // e.g. '76' -> '₹6', '715' -> '₹15', '724' -> '₹24', '735' -> '₹35', '750' -> '₹50'
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)7(\d{1,5}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]}₹${m[2]}',
    );
    // Remove space after ₹
    s = s.replaceAllMapped(RegExp(r'₹\s+(\d)'), (m) => '₹${m[1]}');
    return s;
  }

  /// Extracts and reconstructs a monetary amount from a line of text.
  ///
  /// Handles:
  /// - "+ ₹8,000" / "+ ₹1" (Income)
  /// - "₹40", "₹349", "₹2,500", "₹5,000", "₹2,200", "₹1,500", "₹1,299"
  /// - "R20", "R205", "R2,200", "7205", "75,000" (OCR normalizations)
  /// - "Rs. 420", "Rs 420", "INR 420"
  /// - Decimal amounts: "₹420.50" -> 42050 paise, "₹200.90" -> 20090 paise
  /// - Indian comma formatting: "1,00,000" -> 10000000 paise
  ///
  /// Returns null if the line is a balance, ID, date, or non-monetary text.
  static ReconstructedAmount? parseAmount(String text) {
    if (isBlacklistedBalanceOrSummary(text)) return null;
    if (isIdentifierOrPhone(text)) return null;

    final trimmed = text
        .replaceAll('\u200B', '') // zero-width space
        .replaceAll('\u200C', '') // zero-width non-joiner
        .replaceAll('\u200D', '') // zero-width joiner
        .replaceAll('\u00A0', ' ') // non-breaking space
        .replaceAll('\uFEFF', '') // byte order mark
        .trim();
    if (trimmed.isEmpty) return null;

    final normalizedRaw = normalizeSymbol(trimmed);

    final hasCurrencySymbol =
        normalizedRaw.contains('₹') ||
        RegExp(
          r'(?:\binr\b|\brs\b\.?|\brs\.)',
          caseSensitive: false,
        ).hasMatch(normalizedRaw);
    if (!hasCurrencySymbol && DateExtractor.parseDate(normalizedRaw) != null) {
      return null;
    }

    final hasIncomePlus =
        RegExp(
          r'^\s*\+\s*(?:₹|\bINR\b|\bRs\b\.?|\d)',
          caseSensitive: false,
        ).hasMatch(normalizedRaw) ||
        RegExp(
          r'(?:₹|\bINR\b|\bRs\b\.?)\s*\+\s*\d',
          caseSensitive: false,
        ).hasMatch(normalizedRaw);

    // Normalize currency symbols cleanly without corrupting spaces or leaving dangling periods
    final normalized = normalizedRaw
        .replaceAll('₹', ' ₹ ')
        .replaceAll(
          RegExp(r'\b(?:inr|rs)\b\.?\s*', caseSensitive: false),
          ' ₹ ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final currencyMatch = RegExp(
      r'₹\s*([+-]?\s*[\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (currencyMatch != null) {
      final rawNum = currencyMatch.group(1)!.replaceAll('+', '').replaceAll('-', '').trim();
      final minorUnits = _toMinorUnits(rawNum);
      if (minorUnits != null && minorUnits > 0) {
        return ReconstructedAmount(
          amountMinor: minorUnits,
          isIncome: hasIncomePlus || normalizedRaw.startsWith('+'),
          rawMatchedText: trimmed,
          formattedText: '${hasIncomePlus ? "+ " : ""}₹$rawNum',
        );
      }
    }

    // 2. Standalone comma-formatted amount: e.g. "5,000", "2,500", "2,200", "8,000", "1,500"
    final standaloneCommaMatch = RegExp(
      r'^[+-]?\s*(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?)$',
    ).firstMatch(normalizedRaw);

    if (standaloneCommaMatch != null) {
      final rawNum = standaloneCommaMatch.group(1)!;
      final minorUnits = _toMinorUnits(rawNum);
      if (minorUnits != null && minorUnits > 0) {
        return ReconstructedAmount(
          amountMinor: minorUnits,
          isIncome: hasIncomePlus || normalizedRaw.startsWith('+'),
          rawMatchedText: trimmed,
          formattedText: '₹$rawNum',
        );
      }
    }

    // 3. Standalone decimal amount: e.g. "+ ₹8,000", "+ 8,000.00", "200.90", or "1,500.00"
    final standaloneDecimal = RegExp(
      r'^[+-]?\s*([\d,]+\.\d{1,2})$',
    ).firstMatch(normalizedRaw);

    if (standaloneDecimal != null) {
      final rawNum = standaloneDecimal.group(1)!;
      final minorUnits = _toMinorUnits(rawNum);
      if (minorUnits != null && minorUnits > 0) {
        return ReconstructedAmount(
          amountMinor: minorUnits,
          isIncome: hasIncomePlus || normalizedRaw.startsWith('+'),
          rawMatchedText: trimmed,
          formattedText: '₹$rawNum',
        );
      }
    }

    return null;
  }

  /// Parses a plain numeric string on the right-side of a transaction row (e.g. "40", "349", "80", "200.90").
  ///
  /// Rejects years (2020..2030), phone numbers, reference IDs, and negative/zero values.
  static ReconstructedAmount? parseRightSideCandidate(String text) {
    if (isBlacklistedBalanceOrSummary(text)) return null;
    if (isIdentifierOrPhone(text)) return null;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // First try standard amount parsing
    final standard = parseAmount(trimmed);
    if (standard != null) return standard;

    // Match plain number with optional decimals and commas (e.g. "40", "349", "200.90", "0.50", "3,700.97")
    if (RegExp(
      r'^[+-]?\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)$',
    ).hasMatch(trimmed)) {
      final cleanNum = trimmed.replaceAll('+', '').replaceAll('-', '').trim();
      final minor = _toMinorUnits(cleanNum);
      if (minor != null && minor > 0) {
        // Exclude standalone year numbers (e.g. 2020..2035) or bare 7+ digit IDs
        if (!cleanNum.contains('.') && !cleanNum.contains(',')) {
          final intVal = int.tryParse(cleanNum);
          if (intVal != null && intVal >= 2020 && intVal <= 2035) return null;
          if (cleanNum.length >= 7) return null;
          if (cleanNum.startsWith('0') && cleanNum.length > 1) return null;
        }

        final isIncome = trimmed.startsWith('+');
        return ReconstructedAmount(
          amountMinor: minor,
          isIncome: isIncome,
          rawMatchedText: trimmed,
          formattedText: '${isIncome ? "+ " : ""}₹$cleanNum',
        );
      }
    }

    return null;
  }


  /// Splits a line that contains both merchant and amount on the same horizontal baseline.
  ///
  /// Examples from real OCR:
  /// - "ASHISH KUMAR NAYAK ₹40" -> merchant: "ASHISH KUMAR NAYAK", amount: 40
  /// - "JIO ₹349" -> merchant: "JIO", amount: 349
  /// - "Bishal BhanjDeo ₹2,500" -> merchant: "Bishal BhanjDeo", amount: 2500
  /// - "SBI ATM CASH WITHDRAWAL ₹5,000" -> merchant: "SBI ATM CASH WITHDRAWAL", amount: 5000
  /// - "ICCL Mutual Funds Autopay ₹1,500" -> merchant: "ICCL Mutual Funds Autopay", amount: 1500
  /// - "PARIKSIT INCORPORATION INDIA ... + ₹8,000" -> merchant: "PARIKSIT INCORPORATION INDIA ...", amount: 8000
  static ExtractedLineParts? splitCombinedMerchantAndAmount(String line) {
    final clean = line
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\uFEFF', '')
        .trim();
    if (clean.isEmpty) return null;
    if (isBlacklistedBalanceOrSummary(clean)) return null;
    if (isIdentifierOrPhone(clean)) return null;

    // If the entire line is already a standalone pure amount (e.g. "₹40", "Rs. 420", "5,000"),
    // then there is no merchant on this line!
    if (RegExp(
      r'^[+-]?\s*(?:₹|\binr\b|\brs\b\.?|\brs\.)?\s*[\d,]+(?:\.\d{1,2})?\s*$',
      caseSensitive: false,
    ).hasMatch(clean)) {
      return null;
    }

    // Pattern: text followed by currency amount at the end of line
    final match = RegExp(
      r'^(.*?)\s+([+-]?\s*(?:₹|\bINR\b|\bRs\.?|\bRs\b)?\s*[\d,]+(?:\.\d{1,2})?)\s*$',
      caseSensitive: false,
    ).firstMatch(clean);

    if (match != null) {
      final merchantPart = match.group(1)!.trim();
      final amountPart = match.group(2)!.trim();

      // Reject if merchant part is simply a currency indicator like "Rs." or "INR"
      if (RegExp(
        r'^(?:rs\.?|inr|₹)$',
        caseSensitive: false,
      ).hasMatch(merchantPart)) {
        return null;
      }

      // Reject if merchant part is a date
      if (DateExtractor.parseDate(merchantPart) != null) {
        return null;
      }

      if (merchantPart.length >= 2) {
        final amt =
            parseAmount(amountPart) ?? parseRightSideCandidate(amountPart);
        if (amt != null) {
          return ExtractedLineParts(merchantPart: merchantPart, amount: amt);
        }
      }
    }

    return null;
  }

  /// Reconstructs split OCR tokens into a single [ReconstructedAmount].
  ///
  /// Solves the critical issue where OCR produces:
  /// ["₹", "5", ",", "000"] -> 500000 paise
  /// ["₹5", ",", "000"] -> 500000 paise
  /// ["5", ",", "000"] -> 500000 paise
  /// ["+", "₹", "8,000"] -> 800000 paise (Income)
  /// ["₹", "1,500"] -> 150000 paise
  static ReconstructedAmount? reconstructFromTokens(List<String> rawTokens) {
    if (rawTokens.isEmpty) return null;

    final tokens = rawTokens
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    // Check if any token indicates income
    final hasIncome = tokens.any((t) => t.contains('+'));

    // Check if currency symbol exists
    final hasCurrency = tokens.any(
      (t) =>
          t.contains('₹') ||
          RegExp(r'\b(inr|rs)\b', caseSensitive: false).hasMatch(t),
    );

    // Gather digit and comma sequences
    final buffer = StringBuffer();
    bool insideAmount = false;

    for (final tok in tokens) {
      final cleanTok = tok.replaceAll('+', '').replaceAll('₹', '').trim();
      if (cleanTok.isEmpty) {
        // Just '+' or '₹'
        if (tok.contains('₹')) insideAmount = true;
        continue;
      }

      // If token is digits and/or commas/periods
      if (RegExp(r'^[\d,.]+$').hasMatch(cleanTok)) {
        buffer.write(cleanTok);
        insideAmount = true;
      } else if (insideAmount) {
        // Reached non-numeric token after finding amount
        break;
      }
    }

    final combinedDigits = buffer.toString();
    if (combinedDigits.isEmpty) return null;

    final minor = _toMinorUnits(combinedDigits);
    if (minor == null || minor <= 0) return null;

    // Reject long numeric IDs that don't have currency indicator
    if (!hasCurrency && combinedDigits.length >= 9) return null;

    return ReconstructedAmount(
      amountMinor: minor,
      isIncome: hasIncome,
      rawMatchedText: tokens.join(' '),
      formattedText: '${hasIncome ? "+ " : ""}₹$combinedDigits',
    );
  }

  /// Reconstructs amounts from a list of OCR elements in a line or spatial region.
  static ReconstructedAmount? reconstructFromElements(
    List<OcrElement> elements,
  ) {
    if (elements.isEmpty) return null;
    final tokens = elements.map((e) => e.text).toList();
    return reconstructFromTokens(tokens);
  }

  /// Converts a numeric string with optional commas and decimals into minor units (paise).
  ///
  /// Examples:
  /// "40" -> 4000
  /// "349" -> 34900
  /// "2,500" -> 250000
  /// "5,000" -> 500000
  /// "2,200" -> 220000
  /// "1,500" -> 150000
  /// "8,000" -> 800000
  /// "1,299" -> 129900
  /// "420.50" -> 42050
  /// "1,00,000" -> 10000000
  ///
  /// NEVER drops digits. Handles Indian comma grouping cleanly.
  static int? _toMinorUnits(String rawStr) {
    final clean = rawStr.replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;

    // Check for decimal point
    if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length != 2) return null;

      final wholePartStr = parts[0].replaceAll(',', '');
      final whole = int.tryParse(wholePartStr);
      if (whole == null) return null;

      var decimalStr = parts[1];
      if (decimalStr.length == 1) {
        decimalStr += '0';
      } else if (decimalStr.length > 2) {
        decimalStr = decimalStr.substring(0, 2);
      }

      final decimals = int.tryParse(decimalStr);
      if (decimals == null) return null;

      return (whole * 100) + decimals;
    }

    // Integer amount (no decimals)
    final digitsOnly = clean.replaceAll(',', '');
    final whole = int.tryParse(digitsOnly);
    if (whole == null) return null;

    return whole * 100;
  }
}
