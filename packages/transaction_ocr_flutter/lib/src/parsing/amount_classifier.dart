import '../core/models/amount_classification.dart';
import '../core/models/bounding_box.dart';
import 'universal_date_detector.dart';

/// App-agnostic financial amount candidate classifier.
///
/// Features:
///   1. Multi-layer rejection before accepting text as a financial amount:
///      - Hard-rejects dates, times, relative timestamps via [UniversalDateDetector].
///      - Hard-rejects generic UI labels, navigation buttons, and system chrome.
///      - Hard-rejects alpha-dominant merchant names with embedded numbers (e.g., "OD07SNACKS").
///      - Hard-rejects UPI VPAs, account numbers, and 12-digit reference IDs (UTRs).
///   2. Normalizes OCR symbol misreads:
///      - `R20` -> `₹20`, `R2,500` -> `₹2,500`, `买205` -> `₹205`
///      - `75,000` -> `₹5,000` (leading 7 before thousands comma in Indian OCR context)
///      - `7205` -> `₹205` (leading 7 before 3-digit amount)
///   3. Supports amounts anywhere in 2D space: left-aligned, right-aligned, centered,
///      in cards, receipts, and statement tables.
///   4. Preserves exact integer minor units (paise/cents) without floating-point rounding errors:
///      - `₹200.90` -> `20090` paise
///      - `₹3,700.97` -> `370097` paise
class AmountClassifier {
  static const Set<String> _uiLabels = {
    'searchtransactions',
    'search transactions',
    'status',
    'payment method',
    'paymentmethod',
    'date',
    'amount',
    'amo',
    'search',
    'filter',
    'all',
    'today',
    'yesterday',
    // Generic UI action & navigation labels
    'coinsredeemed',
    'viewhistory',
    'payagain',
    'sharereceipt',
    'debitedfrom',
    'checkbalance',
    'paymentlocation',
    'openmaps',
    'upitransactionid',
    'transactionid',
    'referencenumber',
    'investment',
    'explore',
    'insurance',
    'history',
    'help',
    'viaupi',
    'receivedin',
    'upiintent',
  };

  static final RegExp _reStatusBar = RegExp(r'[^\u0000-\u007F\u20B9]');
  static final RegExp _reRPrefix = RegExp(r'^[+-]?\s*[#＃Rr\u4e70\u5c10\uffe5\u00a5\u5c3a]\s*\d');
  static final RegExp _rePlainNumber = RegExp(
    r'^\s*\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?\s*$'
    r'|'
    r'^\s*\d+(?:\.\d{1,2})?\s*$',
  );

  // Right-alignment threshold
  static const double amountXThreshold = 0.40;

  /// Classifies text as a valid amount candidate.
  static AmountClassification classify(
    String? text, {
    BoundingBox? bbox,
    int imgWidth = 0,
    int imgHeight = 0,
    bool isSingleReceipt = false,
    bool allowLeftAligned = true,
  }) {
    if (text == null || text.trim().isEmpty) {
      return _reject(text ?? '', 'empty text');
    }

    final stripped = text.trim();
    final strippedLower = stripped.toLowerCase();
    final cleanForLabel = strippedLower.replaceAll(RegExp(r'\s+'), '');

    // ── LAYER 1: Hard reject dates, times, and UI chrome ─────────────
    final dateRes = UniversalDateDetector.detect(stripped);
    if (dateRes.isAny) {
      return _reject(text, dateRes.isTime ? 'time_pattern' : 'date_label_pattern');
    }

    if (_uiLabels.contains(cleanForLabel)) {
      return _reject(text, 'ui_label');
    }

    // Hard-reject UPI VPA handles (e.g. "paytmqr6mqm7q@ptys", "MYBMTCDQR@ybl", "**2240@okbizaxis")
    if (stripped.contains('@')) {
      return _reject(text, 'vpa_handle');
    }

    // Hard-reject coin reward point text and prize banners
    if (cleanForLabel.contains('coins') ||
        cleanForLabel.contains('redeemed') ||
        cleanForLabel.contains('youvewon') ||
        cleanForLabel.contains("you'vewon") ||
        cleanForLabel.contains('checknow')) {
      return _reject(text, 'reward_points_count');
    }

    // Hard-reject bank account suffix lines (e.g. "- 8840", "Indian Bank - 8840", "xx8840", "**8840")
    if (RegExp(r'^(?:.*-\s*|\*{2,}|x{2,})\d{3,5}$', caseSensitive: false).hasMatch(stripped)) {
      return _reject(text, 'bank_account_suffix');
    }

    // Reject if contains unexpected non-ASCII (status bar garbage), but allow known currency misreads
    final nonAsciiNonRupee = stripped
        .replaceAll('₹', '')
        .replaceAll(RegExp(r'[\u4e70\u5c10\uffe5\u00a5\u5c3a\¿\?]'), '');
    if (_reStatusBar.hasMatch(nonAsciiNonRupee)) {
      return _reject(text, 'non_ascii_garbage');
    }

    // Reject if alpha-dominant token with embedded digits (e.g., "OD07SNACKS")
    final digitCount = RegExp(r'\d').allMatches(stripped).length;
    final alphaCount = RegExp(r'[A-Za-z]').allMatches(stripped).length;
    if (alphaCount >= 2 && digitCount >= 1 && alphaCount > digitCount) {
      return _reject(text, 'alpha_dominant_token');
    }

    // ── LAYER 2: Normalize symbol misreads and check structure ────────
    final normalized = normalizeSymbol(stripped);
    final noCurr = normalized.replaceAll(RegExp(r'^[₹#＃\+\-\s]+'), '').trim();
    final isValidNumber = noCurr.isNotEmpty && _rePlainNumber.hasMatch(noCurr);

    if (!isValidNumber) {
      return _reject(text, 'no_valid_number');
    }

    final parsedVal = parseValue(noCurr);
    if (parsedVal == null || parsedVal <= 0) {
      return _reject(text, 'zero_or_negative_amount');
    }

    // ── LAYER 2B: Strict Guard against UPI/Bank IDs and Non-Currency Numbers ──
    final hasRupee = stripped.contains('₹') || normalized.contains('₹');
    final hasRPrefix = _reRPrefix.hasMatch(stripped) || _reRPrefix.hasMatch(normalized);
    final hasCurrency = hasRupee ||
        hasRPrefix ||
        strippedLower.startsWith('rs') ||
        normalized.toLowerCase().startsWith('rs') ||
        normalized.startsWith('₹') ||
        normalized.contains('₹');

    // Hard-reject any non-currency candidate in top status bar (top 9% of screen)
    if (imgHeight > 0 && bbox != null && bbox.center.y < imgHeight * 0.09 && !hasCurrency) {
      return _reject(text, 'status_bar_element');
    }

    // If there is NO currency symbol:
    if (!hasCurrency) {
      // 1. Reject bare unformatted numbers with 7 or more digits (e.g. 12-digit UPI IDs "004415604898", "623889506547")
      final bareDigits = noCurr.replaceAll(RegExp(r'[^\d]'), '');
      if (bareDigits.length >= 7) {
        return _reject(text, 'unformatted_large_identifier');
      }

      // 2. Reject numbers with multiple leading zeros (e.g. "004415604898", "08840", "0123")
      if (RegExp(r'^0\d+').hasMatch(noCurr)) {
        return _reject(text, 'leading_zero_identifier');
      }

      // 3. Reject 4-digit calendar years (2020..2035) without formatting
      if (RegExp(r'^20[2-3]\d$').hasMatch(noCurr)) {
        return _reject(text, 'calendar_year_number');
      }
    }

    // ── LAYER 3: Detect sign presence ─────────────────────
    final hasSign = stripped.startsWith('+') ||
        stripped.startsWith('-') ||
        normalized.startsWith('+') ||
        normalized.startsWith('-');

    // ── LAYER 4: Accept or reject based on pattern + spatial context ──
    // Accept: explicit currency symbol AND valid number
    if ((hasCurrency || hasRupee) && isValidNumber) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: signed amount (+1000, -500, +1,000, +2,500, +1)
    if (hasSign && isValidNumber) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: explicit ₹ symbol with digits
    if (hasRupee && digitCount > 0) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: plain number — with spatial check, formatting, or universal mode
    if (isValidNumber && digitCount > 0) {
      final isRight = bbox == null || imgWidth <= 0
          ? true
          : ((bbox.minX / imgWidth) >= amountXThreshold || (bbox.center.x / imgWidth) >= 0.45);

      // Guard: Reject single isolated digits (e.g. "7") on the left without currency
      if (!isRight && noCurr.length == 1 && !hasCurrency) {
        return _reject(text, 'single_digit_left_aligned', spatialRightAligned: false);
      }

      if (isRight) {
        return _accept(text, normalized, noCurr, spatialRightAligned: true);
      } else if (noCurr.contains(',') || noCurr.contains('.')) {
        // Formatted numbers like 2,200 or 500.00 are valid amounts anywhere
        return _accept(text, normalized, noCurr, spatialRightAligned: false);
      } else if (isSingleReceipt || allowLeftAligned) {
        // In receipts, tables, or universal layouts, accept plain numbers (e.g. "293", "36", "50", "10")
        return _accept(text, normalized, noCurr, spatialRightAligned: false);
      } else {
        return _reject(text, 'plain_number_but_left_aligned', spatialRightAligned: false);
      }
    }

    return _reject(text, 'no_amount_pattern_matched');
  }

  /// Normalizes common OCR symbol misreads:
  ///   `R20` -> `₹20`, `+ R2,500` -> `+ ₹2,500`, `买205` -> `₹205`
  ///   `75,000` -> `₹5,000` (leading 7 before thousands comma in OCR context)
  ///   `7205` -> `₹205` (leading 7 before 3-digit amount)
  static String normalizeSymbol(String text) {
    var s = text.trim();
    // Prefix '+/-' with 'Rs.' / 'Rs' / 'INR' -> +/- ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)(?:Rs\.?|INR)\s*(\d)', caseSensitive: false),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? 'R' / 'r' + digit -> [+-] ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[Rr]\s*(\d)'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? '#' / '＃' + digit -> [+-] ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[#＃]\s*(\d)'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? Chinese artifact '买' / '尐' / '￥' / '¥' / '尺' -> [+-] ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[\u4e70\u5c10\uffe5\u00a5\u5c3a]\s*(\d)'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? '?' / '¿' / '*' before digits -> [+-] ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[\?\¿\*]\s*(\d)'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? 'z' / 'Z' before digits with thousands comma -> [+-] ₹
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[zZ]\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? 'F' / 'f' before digits -> [+-] ₹ (e.g. 'F50' -> '₹50', 'F1,500' -> '₹1,500')
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)[Ff]\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? '7' before N,NNN thousands pattern -> [+-] ₹N,NNN (e.g. '75,000' -> '₹5,000')
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)7(\d{1,2},\d{3}(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Leading [+-]? '7' before 2 to 4 digits (OCR misread of '₹' as '7'):
    // e.g. '735' -> '₹35', '715' -> '₹15', '724' -> '₹24', '750' -> '₹50', '7205' -> '₹205'
    // Preserves legitimate 2-digit amounts like '75' (does not strip to 5)
    s = s.replaceAllMapped(
      RegExp(r'^([+-]?\s*)7(\d{2,4}(?:\.\d{1,2})?)\b'),
      (m) => '${m[1]?.trim() ?? ""} ₹${m[2]}'.trim(),
    );
    // Remove space after ₹: '₹ 5,000' -> '₹5,000'
    s = s.replaceAllMapped(RegExp(r'₹\s+(\d)'), (m) => '₹${m[1]}');
    // Ensure format '+ ₹' or '- ₹' has clean spacing: '+₹500' -> '+ ₹500'
    s = s.replaceAllMapped(RegExp(r'^([+-])\s*₹'), (m) => '${m[1]} ₹');
    return s;
  }

  /// Parses cleaned numeric string to num (int or double).
  static num? parseValue(String noCurrStr) {
    if (noCurrStr.isEmpty) return null;
    try {
      final clean = noCurrStr.replaceAll(',', '').replaceAll(' ', '');
      if (clean.contains('.')) {
        final val = double.parse(clean);
        return double.parse(val.toStringAsFixed(2));
      }
      return int.parse(clean);
    } catch (_) {
      return null;
    }
  }

  /// Parses cleaned numeric string directly to integer minor units (paise/cents).
  /// Preserves exact decimals without floating-point precision loss.
  /// Examples:
  ///   "20" -> 2000
  ///   "205" -> 20500
  ///   "2,200" -> 220000
  ///   "5,000" -> 500000
  ///   "75,000" -> 7500000
  ///   "200.90" -> 20090
  ///   "3,700.97" -> 370097
  ///   "0.50" -> 50
  static int? parseMinorUnits(String noCurrStr) {
    if (noCurrStr.isEmpty) return null;
    try {
      final clean = noCurrStr.replaceAll(',', '').replaceAll(' ', '').trim();
      if (clean.isEmpty) return null;
      if (clean.contains('.')) {
        final parts = clean.split('.');
        final whole = int.parse(parts[0]);
        var fracStr = parts[1];
        if (fracStr.length == 1) {
          fracStr = '${fracStr}0';
        } else if (fracStr.length > 2) {
          fracStr = fracStr.substring(0, 2);
        }
        final frac = int.parse(fracStr);
        return (whole * 100) + frac;
      }
      final whole = int.parse(clean);
      return whole * 100;
    } catch (_) {
      return null;
    }
  }

  static AmountClassification _accept(
    String original,
    String normalized,
    String noCurr, {
    bool? spatialRightAligned,
  }) {
    final parsed = parseValue(noCurr);
    final minorUnits = parseMinorUnits(noCurr);
    final hasRupee = normalized.contains('₹');
    return AmountClassification(
      isAmount: true,
      parsedValue: parsed,
      parsedMinorUnits: minorUnits,
      normalizedText: normalized,
      rejectionReason: null,
      hasCurrencySymbol: hasRupee || original.trim().startsWith('R'),
      spatialRightAligned: spatialRightAligned,
    );
  }

  static AmountClassification _reject(
    String original,
    String reason, {
    bool? spatialRightAligned,
  }) {
    return AmountClassification(
      isAmount: false,
      parsedValue: null,
      parsedMinorUnits: null,
      normalizedText: original,
      rejectionReason: reason,
      hasCurrencySymbol: false,
      spatialRightAligned: spatialRightAligned,
    );
  }
}
