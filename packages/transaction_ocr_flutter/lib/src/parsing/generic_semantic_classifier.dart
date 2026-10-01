import '../core/models/bounding_box.dart';
import '../core/models/ocr_item.dart';
import '../core/models/semantic_role.dart';
import 'amount_classifier.dart';
import 'universal_date_detector.dart';

/// App-agnostic semantic classifier for OCR items.
///
/// Discovers semantic roles (e.g. primary amount, merchant, date, direction signal,
/// status, transaction ref, system chrome) using lexical morphology, regular expressions,
/// and geometric positioning without relying on specific app names.
class GenericSemanticClassifier {
  static final RegExp _reBattery = RegExp(r'^\s*\d{1,3}%\s*$');
  static final RegExp _reNetwork = RegExp(
    r'(?:[·•\*\-~]*\s*(?:5g|4g|3g|lte|volte|wifi|三)[·•\*\-~]*\s*)+',
    caseSensitive: false,
  );
  static final RegExp _reVpa = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z0-9]{2,}$');
  static final RegExp _rePhone = RegExp(r'^\s*(?:\+91[\-\s]?)?[6-9]\d{9}\s*$');
  static final RegExp _reUtrOrRef = RegExp(
    r'(?:upi\s*transaction\s*id|utr|rrn|txn\s*id|transaction\s*id|ref\s*(?:no|id)|order\s*id|google\s*transaction\s*id)\s*[:\-\s]*([0-9a-zA-Z]{6,36})',
    caseSensitive: false,
  );

  static final RegExp _reBankAccount = RegExp(
    r'(?:a\/c|acct|account|bank\s*account|\*{2,}|x{2,}|\bxx)\s*(?:no\.?|number)?\s*[:\-\s]*(\d{3,6})',
    caseSensitive: false,
  );

  static final RegExp _reStatus = RegExp(
    r'^\s*(?:payment|transaction|transfer|paid)?\s*(?:successful|successfully|completed|success|failed|declined|pending|processing)\s*$',
    caseSensitive: false,
  );

  static final RegExp _reHeader = RegExp(
    r'^\s*(?:payment\s+details|transaction\s+details|transfer\s+details|bill\s+details|receipt\s+details|summary)\s*$',
    caseSensitive: false,
  );

  static const Set<String> _navigationWords = {
    'back', 'home', 'settings', 'help', 'close', 'menu', 'search',
    'filter', 'all', 'share', 'done', 'openmaps', 'payagain',
    'sharereceipt', 'checkbalance', 'viewhistory', 'history', 'explore',
  };

  static const Set<String> _rewardPromotionWords = {
    'cashback', 'reward', 'rewards', 'points', 'coins', 'coin',
    'scratchcard', 'youvewon', "you'vewon", 'checknow', 'redeemed',
    'discount', 'coupon', 'offer', 'offers',
  };

  /// Classifies a single [OcrItem] and returns its candidate roles with confidence scores.
  static Map<SemanticRole, double> classifyItem(
    OcrItem item, {
    int imgWidth = 0,
    int imgHeight = 0,
    bool isSingleReceipt = false,
  }) {
    final scores = <SemanticRole, double>{};
    final raw = item.text.trim();
    final norm = item.textNormalized.trim();
    final lower = norm.toLowerCase();
    final cleanNoSpaces = lower.replaceAll(RegExp(r'\s+'), '');

    if (raw.isEmpty && norm.isEmpty) {
      scores[SemanticRole.unknown] = 1.0;
      return scores;
    }

    // 1. Date and Time Check
    final dateRes = UniversalDateDetector.detect(norm);
    if (dateRes.isAny) {
      if (dateRes.isDateTime) {
        scores[SemanticRole.dateTime] = dateRes.confidence;
      } else if (dateRes.isTime) {
        scores[SemanticRole.time] = dateRes.confidence;
        if (imgHeight > 0 && item.centerY < imgHeight * 0.08) {
          scores[SemanticRole.systemChrome] = 0.90;
        }
      } else if (dateRes.isDate) {
        scores[SemanticRole.date] = dateRes.confidence;
      }
      return scores;
    }

    // 2. System Chrome (Battery, Network/5G/LTE symbols, top status bar clock)
    if (_reBattery.hasMatch(raw) || _reNetwork.hasMatch(raw) || raw.contains('·三5G三') || raw.contains('5G')) {
      scores[SemanticRole.systemChrome] = 0.95;
      return scores;
    }

    if (imgHeight > 0 && item.centerY < imgHeight * 0.06 && raw.length <= 8 && !raw.contains('₹')) {
      scores[SemanticRole.systemChrome] = 0.85;
    }

    // 3. Navigation and Common Actions
    if (_navigationWords.contains(cleanNoSpaces) || cleanNoSpaces == 'searchtransactions') {
      scores[SemanticRole.navigation] = 0.95;
      return scores;
    }

    // 4. Status Indicators (Payment successful, failed, completed)
    if (_reStatus.hasMatch(norm) || cleanNoSpaces == 'paymentsuccessful' || cleanNoSpaces == 'transactionsuccessful') {
      scores[SemanticRole.status] = 0.98;
      return scores;
    }

    // 5. Section Headers (Transaction details, Payment details)
    if (_reHeader.hasMatch(norm) || cleanNoSpaces == 'paymentdetails' || cleanNoSpaces == 'transactiondetails') {
      scores[SemanticRole.header] = 0.95;
      return scores;
    }

    // 6. Direction Signals (Paid to, Sent to, Received from, Refund, Debited from)
    final directionScore = _evaluateDirection(lower, cleanNoSpaces);
    if (directionScore > 0) {
      scores[SemanticRole.directionSignal] = directionScore;
    }

    // 7. Transaction References / UTR / VPAs / Phone numbers
    if (_reUtrOrRef.hasMatch(norm) || cleanNoSpaces.contains('transactionid')) {
      scores[SemanticRole.transactionReference] = 0.98;
      return scores;
    }

    if (_reVpa.hasMatch(cleanNoSpaces) || (norm.contains('@') && norm.length >= 5)) {
      scores[SemanticRole.transactionReference] = 0.92;
      return scores;
    }

    if (_rePhone.hasMatch(norm)) {
      scores[SemanticRole.transactionReference] = 0.70;
      return scores;
    }

    // Bare long digit string without spaces (e.g. 12-digit UPI reference "004415604898", "623889506547")
    final bareDigits = cleanNoSpaces.replaceAll(RegExp(r'[^\d]'), '');
    if (bareDigits.length >= 9 && bareDigits == cleanNoSpaces) {
      scores[SemanticRole.transactionReference] = 0.95;
      return scores;
    }

    // 8. Bank Account Number / Suffix
    if (_reBankAccount.hasMatch(norm) || RegExp(r'^(?:.*-\s*|\*{2,}|x{2,})\d{3,5}$', caseSensitive: false).hasMatch(norm)) {
      scores[SemanticRole.accountNumber] = 0.95;
      return scores;
    }

    // 9. Rewards / Promotions / Balances
    final isReward = _rewardPromotionWords.any((w) => cleanNoSpaces.contains(w));
    if (isReward) {
      scores[SemanticRole.reward] = 0.90;
      scores[SemanticRole.promotion] = 0.85;
      if (cleanNoSpaces.contains('balance')) {
        scores[SemanticRole.balance] = 0.95;
      }
      return scores;
    }

    if (cleanNoSpaces.contains('balance') || cleanNoSpaces == 'checkbalance' || cleanNoSpaces.startsWith('availbal')) {
      scores[SemanticRole.balance] = 0.95;
      return scores;
    }

    // 10. Financial Amount Classification
    final amtCls = AmountClassifier.classify(
      norm,
      bbox: item.bbox,
      imgWidth: imgWidth,
      imgHeight: imgHeight,
      isSingleReceipt: isSingleReceipt,
    );

    if (amtCls.isAmount && (amtCls.parsedMinorUnits ?? 0) > 0) {
      // Differentiate primary vs secondary amounts (fees, taxes, discounts, small balances)
      if (lower.contains('fee') || lower.contains('tax') || lower.contains('discount')) {
        scores[SemanticRole.amountSecondary] = 0.85;
      } else {
        var baseScore = 0.80;
        if (amtCls.hasCurrencySymbol) baseScore += 0.15;
        if (norm.contains(',') || norm.contains('.')) baseScore += 0.05;
        scores[SemanticRole.amountPrimary] = baseScore.clamp(0.0, 1.0);
      }
      return scores;
    }

    // 11. Merchant / Person Candidate Evaluation
    final merchantScore = _evaluateMerchantCandidate(norm, lower, item.bbox);
    if (merchantScore > 0) {
      scores[SemanticRole.merchantCandidate] = merchantScore;
      if (_rePersonName.hasMatch(norm)) {
        scores[SemanticRole.personCandidate] = merchantScore;
      }
    }

    if (scores.isEmpty) {
      scores[SemanticRole.unknown] = 0.50;
    }

    return scores;
  }

  static double _evaluateDirection(String lower, String clean) {
    if (clean.startsWith('paidto') ||
        clean.startsWith('paymentto') ||
        clean.startsWith('sentto') ||
        clean.startsWith('transferredto') ||
        clean.startsWith('debitedfrom') ||
        clean.startsWith('paidvia') ||
        clean == 'debited' ||
        clean == 'spent' ||
        clean == 'paid') {
      return 0.95;
    }

    if (clean.startsWith('receivedfrom') ||
        clean.startsWith('receivedin') ||
        clean.startsWith('creditedto') ||
        clean == 'credited' ||
        clean == 'received' ||
        clean == 'refund' ||
        clean.contains('cashbackreceived')) {
      return 0.95;
    }

    if (clean == 'to' || clean == 'from') {
      return 0.80;
    }

    return 0.0;
  }

  static final RegExp _rePersonName = RegExp(r'^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+$');

  static double _evaluateMerchantCandidate(String norm, String lower, BoundingBox bbox) {
    // Must have at least 2 characters and not be pure punctuation
    if (norm.length < 2) return 0.0;

    final letters = RegExp(r'[a-zA-Z]').allMatches(norm).length;
    final digits = RegExp(r'\d').allMatches(norm).length;

    // Reject pure digits or digit-dominant tokens
    if (letters == 0) return 0.0;
    if (digits > letters && digits >= 4) return 0.0;

    var score = 0.70;

    // Entity with capital letters (e.g. "Rahul Sharma", "Blinkit", "Cafe 47", "7-Eleven")
    if (RegExp(r'^[A-Z0-9]').hasMatch(norm)) {
      score += 0.15;
    }

    // Contains typical entity terms (Store, Cafe, Petrol Pump, Pvt Ltd, Mart, Shop, Tech)
    if (RegExp(r'\b(?:store|cafe|petrol|pump|mart|shop|tech|solutions|service|services|hospital|clinic|bakery|restaurant|dhaba|tea|chai)\b', caseSensitive: false).hasMatch(norm)) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }
}
