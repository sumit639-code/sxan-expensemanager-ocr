import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';

/// High-precision parser for extracting structured financial transaction data
/// from bank and payment SMS messages (supporting Indian UPI, Cards, NetBanking,
/// and international transaction alerts).
class BankSmsParser {
  const BankSmsParser();

  /// Known bank sender codes mapped to human-readable bank names.
  static const Map<String, String> _bankSenderMap = {
    'HDFCBK': 'HDFC Bank',
    'HDFC': 'HDFC Bank',
    'SBINB': 'State Bank of India',
    'SBIINB': 'State Bank of India',
    'SBIPAY': 'State Bank of India',
    'SBISMS': 'State Bank of India',
    'SBIUPI': 'State Bank of India',
    'SBI': 'State Bank of India',
    'ICICIB': 'ICICI Bank',
    'ICICI': 'ICICI Bank',
    'AXISBK': 'Axis Bank',
    'AXIS': 'Axis Bank',
    'KOTAKB': 'Kotak Mahindra Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'PNBSMS': 'Punjab National Bank',
    'PNB': 'Punjab National Bank',
    'BOBSMS': 'Bank of Baroda',
    'BOB': 'Bank of Baroda',
    'CANBNK': 'Canara Bank',
    'CANARA': 'Canara Bank',
    'UNIONB': 'Union Bank of India',
    'UBI': 'Union Bank of India',
    'YESBNK': 'Yes Bank',
    'YESBANK': 'Yes Bank',
    'IDFCFB': 'IDFC FIRST Bank',
    'IDFC': 'IDFC FIRST Bank',
    'INDUSB': 'IndusInd Bank',
    'INDUS': 'IndusInd Bank',
    'PAYTM': 'Paytm',
    'PYTM': 'Paytm',
    'AIRTEL': 'Airtel Payments Bank',
    'AIRBNK': 'Airtel Payments Bank',
    'JUPITR': 'Jupiter',
    'FIMONY': 'Fi Money',
    'CRED': 'CRED',
    'GPAY': 'Google Pay',
    'PHONPE': 'PhonePe',
    'PHONEPE': 'PhonePe',
    'JIOPAY': 'JioPay',
    'RBLBNK': 'RBL Bank',
    'RBL': 'RBL Bank',
    'FEDERAL': 'Federal Bank',
    'FEDBNK': 'Federal Bank',
    'AUBANK': 'AU Small Finance Bank',
    'AUFINA': 'AU Small Finance Bank',
  };

  /// Parses a bank SMS message. Returns [ExtractedTransaction] if a valid financial
  /// transaction is detected; returns `null` if the message is an OTP, promotion,
  /// or non-financial alert.
  ExtractedTransaction? parse({
    required String body,
    String? sender,
    DateTime? timestamp,
    List<String>? excludedKeywords,
  }) {
    if (body.trim().isEmpty) return null;

    final singleLineBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. Filter out OTPs, promotional messages, and custom excluded keywords
    if (_isOtpOrSpam(singleLineBody, excludedKeywords: excludedKeywords, sender: sender)) {
      return null;
    }

    // 2. Identify transaction type
    final type = _extractTransactionType(singleLineBody);
    if (type == null) {
      return null;
    }

    // 3. Extract transaction amount
    final amountPaise = _extractAmount(singleLineBody);
    if (amountPaise == null || amountPaise <= 0) {
      return null;
    }

    // 4. Identify Bank Name
    final bankName = _extractBankName(singleLineBody, sender);

    // 5. Extract Account / Card reference
    final accountRef = _extractAccountRef(singleLineBody);

    // 6. Extract From and To snippets
    final fromSnippet = _extractFromSnippet(body, singleLineBody: singleLineBody);
    final toSnippet = _extractToSnippet(body, singleLineBody: singleLineBody);

    // 7. Extract Merchant / Counterparty (using both multiline structure and single line)
    var merchant = _extractMerchant(body, singleLineBody: singleLineBody, type: type);
    if (merchant == null && type == TransactionType.expense && toSnippet != null) {
      merchant = _cleanAndValidateMerchant(toSnippet);
    } else if (merchant == null && type == TransactionType.income && fromSnippet != null) {
      merchant = _cleanAndValidateMerchant(fromSnippet);
    }

    // 8. Extract Date
    final date = _extractDate(singleLineBody) ?? timestamp ?? DateTime.now();

    // 9. Build user-facing title: ONLY the clean words after "to" (or "from") if it exists
    final String effectiveTitle;
    if (type == TransactionType.expense) {
      final target = merchant ?? toSnippet;
      if (target != null && target.trim().isNotEmpty) {
        var wordsAfterTo = target
            .replaceAll(RegExp(r'^(?:to|paid to|towards)\s*[:\s-]*\s*', caseSensitive: false), '')
            .trim();
        if (RegExp(r'\s+and\s+', caseSensitive: false).hasMatch(wordsAfterTo)) {
          wordsAfterTo = wordsAfterTo.split(RegExp(r'\s+and\s+', caseSensitive: false)).first.trim();
        }
        if (RegExp(r'\s+for\s+', caseSensitive: false).hasMatch(wordsAfterTo)) {
          wordsAfterTo = wordsAfterTo.split(RegExp(r'\s+for\s+', caseSensitive: false)).first.trim();
        }
        effectiveTitle = wordsAfterTo.isNotEmpty ? wordsAfterTo : '$bankName Expense';
      } else {
        effectiveTitle = '$bankName Expense';
      }
    } else {
      final target = merchant ?? fromSnippet;
      if (target != null && target.trim().isNotEmpty) {
        var wordsAfterFrom = target
            .replaceAll(RegExp(r'^(?:from|received from|by)\s*[:\s-]*\s*', caseSensitive: false), '')
            .trim();
        if (RegExp(r'\s+and\s+', caseSensitive: false).hasMatch(wordsAfterFrom)) {
          wordsAfterFrom = wordsAfterFrom.split(RegExp(r'\s+and\s+', caseSensitive: false)).first.trim();
        }
        effectiveTitle = wordsAfterFrom.isNotEmpty ? wordsAfterFrom : '$bankName Income';
      } else {
        effectiveTitle = '$bankName Income';
      }
    }

    // Sync merchant with clean title if merchant was empty
    if (merchant == null &&
        effectiveTitle != '$bankName Expense' &&
        effectiveTitle != '$bankName Income') {
      merchant = effectiveTitle;
    }

    // 10. Build structured Description / Note containing clean references and full SMS body
    final headerParts = <String>[];
    if (fromSnippet != null && fromSnippet.isNotEmpty) {
      headerParts.add('From: $fromSnippet');
    }
    if (toSnippet != null && toSnippet.isNotEmpty) {
      headerParts.add('To: $toSnippet');
    }
    if (fromSnippet == null && accountRef != null) {
      headerParts.add('Account: $accountRef');
    }
    if (bankName.isNotEmpty &&
        bankName != 'Bank' &&
        (fromSnippet == null ||
            !fromSnippet.toLowerCase().contains(bankName.toLowerCase()))) {
      headerParts.add('Bank: $bankName');
    }
    final refNo = _extractRefNumber(singleLineBody);
    if (refNo != null) {
      headerParts.add('Ref: $refNo');
    }

    final wholeMessage = body.trim();
    final note = headerParts.isNotEmpty
        ? '${headerParts.join('\n')}\n\n$wholeMessage'
        : wholeMessage;

    final id =
        'sms_${(timestamp ?? DateTime.now()).millisecondsSinceEpoch}_${singleLineBody.hashCode.abs().toString().padLeft(6, '0')}';

    return ExtractedTransaction(
      id: id,
      amount: amountPaise,
      currency: 'INR',
      title: effectiveTitle,
      merchant: merchant,
      type: type,
      date: date,
      confidence: 0.95,
      amountConfidence: 0.98,
      merchantConfidence: merchant != null ? 0.90 : 0.60,
      dateConfidence: 0.95,
      typeConfidence: 0.98,
      rawText: singleLineBody,
      sourceReference: bankName.isNotEmpty ? bankName : (sender ?? 'SMS'),
      source: TransactionSource.sms,
      note: note,
    );
  }

  /// Detects whether the text is an OTP, login security message, custom ignored keyword, or marketing spam.
  bool _isOtpOrSpam(String text, {List<String>? excludedKeywords, String? sender}) {
    final lower = text.toLowerCase();
    final senderLower = sender?.toLowerCase() ?? '';

    // Check user-configured exclusion keywords
    if (excludedKeywords != null && excludedKeywords.isNotEmpty) {
      for (final kw in excludedKeywords) {
        final cleanKw = kw.trim().toLowerCase();
        if (cleanKw.isNotEmpty && (lower.contains(cleanKw) || senderLower.contains(cleanKw))) {
          return true;
        }
      }
    }

    // OTP detection
    final isOtp = lower.contains('otp') ||
        lower.contains('one time password') ||
        lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('secret code') ||
        lower.contains('do not share');

    if (isOtp) {
      return true;
    }

    // Promotional spam & marketing keywords
    if (lower.contains('apply now') ||
        lower.contains('apply for') ||
        lower.contains('pre-approved loan') ||
        lower.contains('pre-approved') ||
        lower.contains('pre approved') ||
        lower.contains('get personal loan') ||
        lower.contains('personal loan') ||
        lower.contains('instant loan') ||
        lower.contains('loan up to') ||
        lower.contains('congratulations! you are eligible') ||
        lower.contains('congratulations') ||
        lower.contains('upgrade your card') ||
        lower.contains('credit limit of rs') ||
        lower.contains('increase your limit') ||
        lower.contains('credit card offer') ||
        lower.contains('zero interest loan') ||
        lower.contains('claim reward') ||
        lower.contains('claim your') ||
        lower.contains('reward points') ||
        lower.contains('rewards point') ||
        lower.contains('redeem points') ||
        lower.contains('cashback offer') ||
        lower.contains('earn cashback') ||
        lower.contains('flat off') ||
        lower.contains('voucher') ||
        lower.contains('coupon') ||
        lower.contains('promo code') ||
        lower.contains('win up to') ||
        lower.contains('chance to win') ||
        lower.contains('lucky winner') ||
        lower.contains('lottery') ||
        lower.contains('bonus credited') ||
        lower.contains('wallet bonus') ||
        lower.contains('recharge now') ||
        lower.contains('pack expiring') ||
        lower.contains('plan expires') ||
        lower.contains('plan expired') ||
        lower.contains('dont miss') ||
        lower.contains("don't miss") ||
        lower.contains('offer valid') ||
        lower.contains('hurry') ||
        lower.contains('click here') ||
        lower.contains('click on') ||
        lower.contains('tap here') ||
        lower.contains('download the app') ||
        lower.contains('visit http') ||
        lower.contains('bit.ly')) {
      return true;
    }

    return false;
  }

  /// Determines whether the transaction is an expense or income.
  TransactionType? _extractTransactionType(String text) {
    final lower = text.toLowerCase();

    // Debit patterns
    final debitPattern = RegExp(
      r'\b(?:debited|debit|spent|paid|sent|withdrawn|charged|deducted|purchase of|txn of|transferred to|deducted from|payment of|transfer of|auto-debited|swiped at|used at|purchase at|cleared)\b',
      caseSensitive: false,
    );

    // Credit patterns
    final creditPattern = RegExp(
      r'\b(?:credited|credit|received|deposited|refunded|refund|cashback|added to|transferred from|received from|salary|reversed|reversal|credited with|credited by)\b',
      caseSensitive: false,
    );

    final hasDebit = debitPattern.hasMatch(lower);
    final hasCredit = creditPattern.hasMatch(lower);

    if (hasDebit && !hasCredit) {
      return TransactionType.expense;
    }
    if (hasCredit && !hasDebit) {
      return TransactionType.income;
    }

    if (hasDebit && hasCredit) {
      // Find which verb appears closest to the transaction amount
      final debitMatch = debitPattern.firstMatch(lower);
      final creditMatch = creditPattern.firstMatch(lower);

      if (debitMatch != null && creditMatch != null) {
        return debitMatch.start < creditMatch.start
            ? TransactionType.expense
            : TransactionType.income;
      }
    }

    return null;
  }

  /// Extracts the transaction monetary amount in minor units (paise).
  int? _extractAmount(String text) {
    // Regex matching amounts, taking care to avoid "Avl Bal", "Bal:", "Limit:"
    // 1. Matches: "Rs. 1,234.50", "Rs 500", "INR 99.00", "₹1,250"
    final pattern = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      // Alternative: "debited for 450.00" or "spent 350.00"
      final altPattern = RegExp(
        r'\b(?:debited|credited|spent|paid|for)\s+(?:by|of|for)?\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final altMatch = altPattern.firstMatch(text);
      if (altMatch != null) {
        return _parseAmountStringToPaise(altMatch.group(1));
      }
      return null;
    }

    // If multiple amounts are present (e.g. Transaction amount + Available Balance),
    // we want the transaction amount, NOT the balance.
    for (final match in matches) {
      final startIndex = match.start;
      final precedingText = text.substring(0, startIndex).toLowerCase();

      // Check if this amount is tagged as balance or limit
      final isBalance = precedingText.endsWith('bal ') ||
          precedingText.endsWith('bal: ') ||
          precedingText.endsWith('bal.') ||
          precedingText.endsWith('balance ') ||
          precedingText.endsWith('balance: ') ||
          precedingText.endsWith('avl bal ') ||
          precedingText.endsWith('avl bal: ') ||
          precedingText.endsWith('available bal ') ||
          precedingText.endsWith('available balance ') ||
          precedingText.endsWith('limit ') ||
          precedingText.endsWith('limit: ');

      if (!isBalance) {
        final rawAmount = match.group(1);
        final paise = _parseAmountStringToPaise(rawAmount);
        if (paise != null && paise > 0) {
          return paise;
        }
      }
    }

    // If all were tagged as balance, fallback to first match
    return _parseAmountStringToPaise(matches.first.group(1));
  }

  int? _parseAmountStringToPaise(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '').trim();
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  /// Extracts the Bank or Provider Name.
  String _extractBankName(String text, String? sender) {
    if (sender != null && sender.isNotEmpty) {
      // Sender is often like "VK-HDFCBK" or "AX-SBINB"
      final cleanSender = sender.replaceAll(RegExp(r'^[A-Za-z]{2}-'), '').toUpperCase();
      for (final entry in _bankSenderMap.entries) {
        if (cleanSender.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    final lower = text.toLowerCase();
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('sbi') || lower.contains('state bank')) return 'State Bank of India';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Mahindra Bank';
    if (lower.contains('punjab national') || lower.contains('pnb')) return 'Punjab National Bank';
    if (lower.contains('bank of baroda') || lower.contains('bob')) return 'Bank of Baroda';
    if (lower.contains('canara')) return 'Canara Bank';
    if (lower.contains('union bank')) return 'Union Bank of India';
    if (lower.contains('idfc')) return 'IDFC FIRST Bank';
    if (lower.contains('yes bank')) return 'Yes Bank';
    if (lower.contains('indusind')) return 'IndusInd Bank';
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('google pay') || lower.contains('gpay')) return 'Google Pay';
    if (lower.contains('phonepe')) return 'PhonePe';

    return 'Bank';
  }

  /// Extracts Account number or Card reference.
  String? _extractAccountRef(String text) {
    final pattern = RegExp(
      r'(?:a\/c|acct|acc|account|card|card ending)\s*(?:no\.?)?\s*(?:ending\s*)?([xX*]*\d{3,4})',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    if (match != null) {
      final num = match.group(1);
      return 'A/C **${num?.replaceAll(RegExp(r'[xX*]'), '')}';
    }
    return null;
  }

  /// Strips security disclaimers, block card alerts, and customer care numbers
  /// that often appear at the end of bank messages.
  String _stripDisclaimers(String text) {
    final disclaimerPattern = RegExp(
      r'(?:\b(?:if not (?:done )?by (?:you|u)|not you\??|if not you|to block(?: your)?|to report|forward (?:this )?sms|call \d{4,}|\bsms block\b)).*$',
      caseSensitive: false,
      dotAll: true,
    );
    return text.replaceAll(disclaimerPattern, '').trim();
  }

  /// Extracts Merchant / Payee / Counterparty from the message.
  String? _extractMerchant(
    String originalText, {
    required String singleLineBody,
    required TransactionType type,
  }) {
    // 1. Structured Multiline messages (e.g. "To RABI COSMETICS" on its own line)
    final lines = originalText.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = _stripDisclaimers(rawLine).trim();
      if (line.isEmpty) continue;

      if (type == TransactionType.expense) {
        final lineMatch = RegExp(
          r'^(?:to|paid to|towards|vpa)[:\s-]+\s*([A-Za-z0-9\s\.\@\-_&]+)$',
          caseSensitive: false,
        ).firstMatch(line);
        if (lineMatch != null) {
          final cand = _cleanAndValidateMerchant(lineMatch.group(1));
          if (cand != null) return cand;
        }
      } else {
        final lineMatch = RegExp(
          r'^(?:from|by|received from|sender)[:\s-]+\s*([A-Za-z0-9\s\.\@\-_&]+)$',
          caseSensitive: false,
        ).firstMatch(line);
        if (lineMatch != null) {
          final cand = _cleanAndValidateMerchant(lineMatch.group(1));
          if (cand != null) return cand;
        }
      }
    }

    // 2. Clean single-line body with disclaimers removed for inline sentence matching
    final cleaned = _stripDisclaimers(singleLineBody);

    if (type == TransactionType.expense) {
      // 2a. Expense patterns: to <Merchant>, at <Merchant>, info: <Merchant>, towards <Merchant>, paid to <Merchant>, swiped at <Merchant>
      final expensePattern = RegExp(
        r'\b(?:to|at|info:|towards|transfer to|paid to|vpa|swiped at|used at|purchase at|at pos)\s+([A-Za-z0-9\s\.\@\-_&]+?)(?:\s+(?:using\b|via\b|on\s+\d|ref\b|avl\b|avail\b|bal\b|balance\b|upi\b|and\b|for\b|with\b|dated\b|through\b|not\b|if\b|call\b|block\b|help\b|query\b|desc\b|msg\b|message\b)|\/|\.|\,|\;|\:|\?|\!|$|\n)',
        caseSensitive: false,
      );
      for (final match in expensePattern.allMatches(cleaned)) {
        final cand = _cleanAndValidateMerchant(match.group(1));
        if (cand != null) return cand;
      }
    } else {
      // 2b. Income patterns: from <Sender>, received from <Sender>, transferred by <Sender>, refund from <Sender>
      final incomePattern = RegExp(
        r'\b(?:from|received from|transferred by|remitted by|by transfer from|refund from|cashback from|deposited by)\s+([A-Za-z0-9\s\.\@\-_&]+?)(?:\s+(?:using\b|via\b|on\s+\d|ref\b|avl\b|avail\b|bal\b|balance\b|upi\b|and\b|for\b|with\b|dated\b|through\b|not\b|if\b|call\b|block\b|help\b|query\b|desc\b|msg\b|message\b)|\/|\.|\,|\;|\:|\?|\!|$|\n)',
        caseSensitive: false,
      );
      for (final match in incomePattern.allMatches(cleaned)) {
        final cand = _cleanAndValidateMerchant(match.group(1));
        if (cand != null) return cand;
      }

      // Alternative for income: "by <Sender>" when not followed by amount or card/account
      final byPattern = RegExp(
        r'\bby\s+([A-Za-z0-9\s\.\@\-_&]+?)(?:\s+(?:using\b|via\b|on\s+\d|ref\b|avl\b|avail\b|bal\b|balance\b|upi\b|and\b|for\b|with\b|dated\b|through\b|not\b|if\b|call\b|block\b|help\b|query\b|desc\b|msg\b|message\b)|\/|\.|\,|\;|\:|\?|\!|$|\n)',
        caseSensitive: false,
      );
      for (final match in byPattern.allMatches(cleaned)) {
        final cand = _cleanAndValidateMerchant(match.group(1));
        if (cand != null) return cand;
      }
    }

    // 3. Look for UPI pattern: UPI/Ref/Merchant or UPI/Merchant
    final upiPattern = RegExp(r'UPI(?:\/|-)[A-Za-z0-9]+\/([A-Za-z0-9\s\-_]+)');
    for (final match in upiPattern.allMatches(cleaned)) {
      final cand = _cleanAndValidateMerchant(match.group(1));
      if (cand != null) return cand;
    }

    return null;
  }

  String? _cleanAndValidateMerchant(String? raw) {
    if (raw == null) return null;
    var candidate = raw.trim();
    if (candidate.isEmpty) return null;

    // Strip trailing slashes or sub-descriptors: e.g. "RAMESH SHARMA / UPI-Ref 123" -> "RAMESH SHARMA"
    if (candidate.contains(' / ')) {
      candidate = candidate.split(' / ').first.trim();
    } else if (candidate.contains('/')) {
      if (!RegExp(r'\ba/c\b', caseSensitive: false).hasMatch(candidate)) {
        candidate = candidate.split('/').first.trim();
      }
    }

    // Clean up prefix artifacts including leading "to", "paid to", etc.
    candidate = candidate.replaceAll(
      RegExp(r'^(?:to|paid to|towards|vpa\s+|info:\s*|transfer\s+from\s*|from\s*)', caseSensitive: false),
      '',
    );
    // Split on words like "and", "for", "with", "dated", "through", "bal", "balance", "msg", "message"
    if (RegExp(r'\s+(?:and|for|with|dated|through|bal|balance|msg|message)\s+', caseSensitive: false).hasMatch(candidate)) {
      candidate = candidate.split(RegExp(r'\s+(?:and|for|with|dated|through|bal|balance|msg|message)\s+', caseSensitive: false)).first.trim();
    }
    // Clean up trailing prepositions e.g. "using", "via", "on", "ref" (using word boundary)
    candidate = candidate.replaceAll(
      RegExp(r'\s+(?:using|via|on|ref)\b', caseSensitive: false),
      '',
    ).trim();
    // Clean up UPI addresses like "swiggy@icici" into "Swiggy"
    if (candidate.contains('@')) {
      candidate = candidate.split('@').first;
    }

    // Clean up leading/trailing punctuation
    candidate = candidate.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '').trim();
    if (candidate.length < 2) return null;

    // Limit candidate word length to 4 words max (merchants/payees are not long sentences)
    final words = candidate.split(RegExp(r'\s+'));
    if (words.length > 4) {
      candidate = words.take(4).join(' ');
    }

    final lower = candidate.toLowerCase();

    // Rejection 1: Account or Card references (User's own account, not merchant)
    if (lower.contains('card ending') ||
        lower.contains('account ending') ||
        lower.contains('a/c ending') ||
        lower.contains('acct ending') ||
        lower.contains('your card') ||
        lower.contains('your account') ||
        lower.contains('your a/c') ||
        lower == 'card' ||
        lower == 'account' ||
        lower == 'a/c' ||
        lower == 'acct') {
      return null;
    }

    // Rejection 2: Security & Disclaimer phrases
    if (lower.contains('block') ||
        lower.contains('dispute') ||
        lower.contains('report') ||
        lower.contains('not you') ||
        lower.contains('call ') ||
        lower.contains('sms ')) {
      return null;
    }

    // Rejection 3: Single blacklisted generic words
    const blacklist = {
      'your', 'account', 'bank', 'the', 'rs', 'inr', 'ref', 'avl', 'bal',
      'credit', 'debit', 'card', 'upi', 'transfer', 'via', 'using', 'no',
      'neft', 'imps', 'rtgs', 'cash', 'atm', 'pos', 'branch', 'limit', 'message'
    };
    if (blacklist.contains(lower)) return null;

    return _capitalizeWords(candidate);
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length <= 3 && word == word.toUpperCase()) return word; // Keep acronyms like PVR, KFC
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// Extracts Reference Number (e.g. UPI Ref, IMPS Ref, Txn ID).
  String? _extractRefNumber(String text) {
    final pattern = RegExp(
      r'\b(?:ref(?:\s+no\.?|\s+id)?|txn(?:\s+id|\s+no\.?)?|rrn)\s*[:.]?\s*([A-Za-z0-9]{6,20})\b',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    return match?.group(1);
  }

  /// Extracts the source / sender snippet (e.g. "HDFC Bank A/C *2711", "a/c **4321", "Ramesh Sharma").
  String? _extractFromSnippet(String originalText, {required String singleLineBody}) {
    // 1. Multiline check: line starting with "From"
    final lines = originalText.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = _stripDisclaimers(rawLine).trim();
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^(?:from|received from|debited from|sent from)[:\s-]+\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) {
        final snippet = _cleanSnippet(match.group(1));
        if (snippet != null && snippet.isNotEmpty) return snippet;
      }
    }

    // 2. Inline check in cleaned single line
    final cleaned = _stripDisclaimers(singleLineBody);
    final inlineMatch = RegExp(
      r'\b(?:debited from|sent from|received from|transferred from|transfer from|from)\s+([A-Za-z0-9\s\.\@\-_&*/]+?)(?:\s+(?:to\b|using\b|via\b|on\s+\d|ref\b|avl\b|avail\b|bal\b|balance\b|upi\b|and\b|for\b|with\b|dated\b|through\b|not\b|if\b|call\b|block\b|help\b|query\b|desc\b|msg\b|message\b)|\.|\,|\;|\:|\?|\!|$)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (inlineMatch != null) {
      final snippet = _cleanSnippet(inlineMatch.group(1));
      if (snippet != null && snippet.isNotEmpty) return snippet;
    }

    return null;
  }

  /// Extracts the recipient / counterparty snippet (e.g. "RABI COSMETICS", "SWIGGY", "A/C ending 1234").
  String? _extractToSnippet(String originalText, {required String singleLineBody}) {
    // 1. Multiline check: line starting with "To"
    final lines = originalText.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = _stripDisclaimers(rawLine).trim();
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^(?:to|paid to|transferred to|credited to|towards)[:\s-]+\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) {
        final snippet = _cleanSnippet(match.group(1));
        if (snippet != null && snippet.isNotEmpty) return snippet;
      }
    }

    // 2. Inline check in cleaned single line
    final cleaned = _stripDisclaimers(singleLineBody);
    final inlineMatch = RegExp(
      r'\b(?:paid to|transferred to|credited to|towards|transfer to|to|at)\s+([A-Za-z0-9\s\.\@\-_&*/]+?)(?:\s+(?:from\b|using\b|via\b|on\s+\d|ref\b|avl\b|avail\b|bal\b|balance\b|upi\b|and\b|for\b|with\b|dated\b|through\b|not\b|if\b|call\b|block\b|help\b|query\b|desc\b|msg\b|message\b)|\.|\,|\;|\:|\?|\!|\/|$|\n)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (inlineMatch != null) {
      final snippet = _cleanSnippet(inlineMatch.group(1));
      if (snippet != null && snippet.isNotEmpty) return snippet;
    }

    return null;
  }

  /// Cleans and validates extracted snippet text for From / To.
  String? _cleanSnippet(String? raw) {
    if (raw == null) return null;
    var cand = raw.trim();
    if (cand.isEmpty) return null;

    cand = _stripDisclaimers(cand).trim();
    if (cand.isEmpty) return null;

    // Strip leading "to" / "paid to" / "from" prefix if captured
    cand = cand.replaceAll(
      RegExp(r'^(?:to|paid to|transferred to|towards|transfer to|from|received from|debited from|sent from)\s*[:\s-]*\s*', caseSensitive: false),
      '',
    ).trim();

    // Split on words like "and", "for", "with", "dated", "through", "msg", "message", "bal", "balance"
    if (RegExp(r'\s+(?:and|for|with|dated|through|msg|message|bal|balance)\s+', caseSensitive: false).hasMatch(cand)) {
      cand = cand.split(RegExp(r'\s+(?:and|for|with|dated|through|msg|message|bal|balance)\s+', caseSensitive: false)).first.trim();
    }

    // Strip trailing markers
    cand = cand.replaceAll(
      RegExp(r'\s+(?:on\s+\d|ref\b|avl\b|avail\b|bal\b|upi\s+ref|using\b|via\b|credited\b|debited\b).*$', caseSensitive: false),
      '',
    ).trim();

    // Standardize A/C casing
    cand = cand.replaceAll(RegExp(r'\ba/c\b', caseSensitive: false), 'A/C');

    // Strip trailing slashes or sub-descriptors without splitting A/C
    cand = cand.replaceAll(
      RegExp(r'\s*\/\s*(?:upi|ref|rrn|txn|imp|neft).*$', caseSensitive: false),
      '',
    ).trim();
    if (cand.contains(' / ')) {
      cand = cand.split(' / ').first.trim();
    } else if (cand.contains('/') && !RegExp(r'\ba/c\b', caseSensitive: false).hasMatch(cand)) {
      cand = cand.split('/').first.trim();
    }

    // Clean leading/trailing punctuation
    cand = cand.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '').trim();

    if (cand.length < 2) return null;

    // Limit word length to 4 words max if not an account string
    if (!RegExp(r'\ba/c\b', caseSensitive: false).hasMatch(cand)) {
      final words = cand.split(RegExp(r'\s+'));
      if (words.length > 4) {
        cand = words.take(4).join(' ');
      }
    }

    final lower = cand.toLowerCase();
    if (lower.contains('block') ||
        lower.contains('call ') ||
        lower.contains('report') ||
        lower.contains('fraud') ||
        lower.contains('not you') ||
        lower.contains('if not') ||
        lower == 'card' ||
        lower == 'account' ||
        lower == 'a/c') {
      return null;
    }

    if (cand.length > 50) {
      cand = cand.substring(0, 50).trim();
    }

    return cand;
  }

  /// Extracts date from SMS text.
  DateTime? _extractDate(String text) {
    // 1. DD-MM-YYYY or DD/MM/YYYY or DD-MM-YY
    final numDatePattern = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b');
    final numMatch = numDatePattern.firstMatch(text);
    if (numMatch != null) {
      try {
        final day = int.parse(numMatch.group(1)!);
        final month = int.parse(numMatch.group(2)!);
        var year = int.parse(numMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // 2. DD-MMM-YY or DD-MMM-YYYY (e.g. 22-Sep-26 or 22-SEP-2026)
    final textDatePattern = RegExp(
      r'\b(\d{1,2})[-/\s]([A-Za-z]{3})[-/\s](\d{2,4})\b',
      caseSensitive: false,
    );
    final textMatch = textDatePattern.firstMatch(text);
    if (textMatch != null) {
      try {
        final day = int.parse(textMatch.group(1)!);
        final monthStr = textMatch.group(2)!.toLowerCase();
        var year = int.parse(textMatch.group(3)!);
        if (year < 100) year += 2000;

        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final month = months[monthStr];
        if (month != null) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    return null;
  }
}
