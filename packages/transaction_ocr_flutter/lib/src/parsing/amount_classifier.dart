import '../core/models/amount_classification.dart';
import '../core/models/bounding_box.dart';

/// V2 Robust Amount Candidate Classifier.
/// Direct port of Python `src/ocr/amount_classifier.py`.
///
/// Features:
///   1. Multi-layer rejection before accepting text as a financial amount:
///      - Hard-rejects known non-amount patterns (time, date labels, status bar garbage, UI labels).
///      - Hard-rejects alpha-dominant merchant names with embedded numbers (e.g., "OD07SNACKS").
///   2. Normalizes OCR symbol misreads:
///      - `R20` -> `₹20`, `R2,500` -> `₹2,500`, `买205` -> `₹205`
///      - `75,000` -> `₹5,000` (leading 7 before thousands comma)
///      - `7205` -> `₹205` (leading 7 before 3-digit amount)
///   3. Enforces spatial right-alignment check (left-x >= 50% image width) for plain numbers without currency symbols.
class AmountClassifier {
  // Rejection Patterns
  static final RegExp _reTime = RegExp(r'^\s*\d{1,2}:\d{2}(\s*[APap][Mm])?\s*\??\s*$');

  static final RegExp _reDateLabel = RegExp(
    r'^\s*(?:'
    r'\d{1,2}\s*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*(?:\s*\d{2,4})?(?:at.*)?'
    r'|'
    r'(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4}'
    r'|'
    r'\d+\s+(?:hour|hours|day|days|min|mins|minute|minutes)\s+ago'
    r'|'
    r'(?:yesterday|today)'
    r')\s*$',
    caseSensitive: false,
  );

  static final RegExp _reStatusBar = RegExp(r'[^\u0000-\u007F\u20B9]');

  static const Set<String> _uiLabels = {
    'searchtransactions',
    'search transactions',
    'status',
    'payment method',
    'date',
    'amount',
    'amo',
    'search',
    'paymentmethod',
    'filter',
    'all',
    'today',
    'yesterday',
  };

  static final RegExp _reRPrefix = RegExp(r'^[Rr\u4e70\u5c10\uffe5\u00a5]\s*\d');
  static final RegExp _rePlainNumber = RegExp(
    r'^\s*\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?\s*$'
    r'|'
    r'^\s*\d+(?:\.\d{1,2})?\s*$',
  );

  // Right-alignment threshold (bbox minX / imgWidth >= 0.40)
  static const double amountXThreshold = 0.40;

  /// Classifies text as a valid amount candidate.
  static AmountClassification classify(
    String? text, {
    BoundingBox? bbox,
    int imgWidth = 0,
    int imgHeight = 0,
  }) {
    if (text == null || text.trim().isEmpty) {
      return _reject(text ?? '', 'empty text');
    }

    final stripped = text.trim();
    final strippedLower = stripped.toLowerCase();
    final cleanForLabel = strippedLower.replaceAll(RegExp(r'\s+'), '');

    // ── LAYER 1: Hard reject known non-amount patterns ──────────────
    if (_reTime.hasMatch(stripped)) {
      return _reject(text, 'time_pattern');
    }

    if (_reDateLabel.hasMatch(stripped)) {
      return _reject(text, 'date_label_pattern');
    }

    if (_uiLabels.contains(cleanForLabel)) {
      return _reject(text, 'ui_label');
    }

    // Reject if contains CJK or unexpected non-ASCII (status bar garbage)
    final nonAsciiNonRupee = stripped.replaceAll('₹', '');
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
    final noCurr = normalized.replaceAll(RegExp(r'^[₹\+\-\s]+'), '').trim();
    final isValidNumber = noCurr.isNotEmpty && _rePlainNumber.hasMatch(noCurr);

    // ── LAYER 3: Detect currency symbol presence ─────────────────────
    final hasRupee = stripped.contains('₹') || normalized.contains('₹');
    final hasRPrefix = _reRPrefix.hasMatch(stripped) || _reRPrefix.hasMatch(normalized);
    final hasCurrency = hasRupee ||
        hasRPrefix ||
        strippedLower.startsWith('rs') ||
        normalized.toLowerCase().startsWith('rs') ||
        normalized.startsWith('₹');
    final hasSign = stripped.startsWith('+') ||
        stripped.startsWith('-') ||
        normalized.startsWith('+') ||
        normalized.startsWith('-');

    // ── LAYER 4: Accept or reject based on pattern + spatial context ──
    // Accept: explicit currency symbol AND valid number
    if ((hasCurrency || hasRupee) && isValidNumber) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: signed amount (+1000, -500, +1,000)
    if (hasSign && isValidNumber) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: explicit ₹ symbol with digits
    if (hasRupee && digitCount > 0) {
      return _accept(text, normalized, noCurr);
    }

    // Accept: plain number — with spatial check or strong financial format
    if (isValidNumber && digitCount > 0) {
      if (bbox != null && imgWidth > 0) {
        final minX = bbox.minX;
        final cx = bbox.center.x;
        final isRight = (minX / imgWidth) >= amountXThreshold || (cx / imgWidth) >= 0.45;
        if (isRight) {
          return _accept(text, normalized, noCurr, spatialRightAligned: true);
        } else if (noCurr.contains(',') || noCurr.contains('.')) {
          // Strong formatting signal even if centered
          return _accept(text, normalized, noCurr, spatialRightAligned: false);
        } else {
          return _reject(text, 'plain_number_but_left_aligned', spatialRightAligned: false);
        }
      } else {
        // No spatial info available — accept if has comma grouping or >= 2 digits
        if (noCurr.contains(',') || noCurr.contains('.') || noCurr.length >= 2) {
          return _accept(text, normalized, noCurr);
        }
        return _reject(text, 'plain_number_no_spatial_context');
      }
    }

    return _reject(text, 'no_amount_pattern_matched');
  }

  /// Normalizes common OCR symbol misreads:
  ///   `R20` -> `₹20`, `R2,500` -> `₹2,500`, `买205` -> `₹205`
  ///   `75,000` -> `₹5,000` (leading 7 before thousands comma)
  ///   `7205` -> `₹205` (leading 7 before 3-digit amount)
  static String normalizeSymbol(String text) {
    var s = text.trim();
    // Prefix 'Rs.' / 'Rs' / 'INR' -> ₹
    s = s.replaceAllMapped(RegExp(r'^(?:Rs\.?|INR)\s*(\d)', caseSensitive: false), (m) => '₹${m[1]}');
    // Leading 'R' / 'r' + digit -> ₹
    s = s.replaceAllMapped(RegExp(r'^[Rr]\s*(\d)'), (m) => '₹${m[1]}');
    // Leading Chinese artifact '买' / '尐' / '￥' -> ₹
    s = s.replaceAllMapped(RegExp(r'^[\u4e70\u5c10\uffe5\u00a5]\s*(\d)'), (m) => '₹${m[1]}');
    // Leading '?' / '¿' / '*' before digits -> ₹
    s = s.replaceAllMapped(RegExp(r'^[\?\¿\*]\s*(\d)'), (m) => '₹${m[1]}');
    // Leading 'z' / 'Z' before digits with thousands comma -> ₹ (e.g. 'z5,000' -> '₹5,000', 'z500' -> '₹500')
    s = s.replaceAllMapped(RegExp(r'^[zZ]\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)\b'), (m) => '₹${m[1]}');
    // Leading 'F' / 'f' before thousands format -> ₹ (e.g. 'F5,000' -> '₹5,000')
    s = s.replaceAllMapped(RegExp(r'^[Ff]\s*(\d{1,2},\d{3})\b'), (m) => '₹${m[1]}');
    // Leading '7' before N,NNN thousands pattern -> ₹N,NNN (e.g. '75,000' -> '₹5,000')
    s = s.replaceAllMapped(RegExp(r'^7(\d{1,2},\d{3}(?:\.\d{1,2})?)\b'), (m) => '₹${m[1]}');
    // Leading '7' before exactly 3-digit amount -> ₹NNN (e.g. '7205' -> '₹205', '7500' -> '₹500')
    s = s.replaceAllMapped(RegExp(r'^7(\d{3}(?:\.\d{1,2})?)\b'), (m) => '₹${m[1]}');
    // Remove space after ₹: '₹ 5,000' -> '₹5,000'
    s = s.replaceAllMapped(RegExp(r'^₹\s+(\d)'), (m) => '₹${m[1]}');
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

