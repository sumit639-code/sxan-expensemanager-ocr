/// Semantic roles assigned to OCR tokens during universal extraction.
enum SemanticRole {
  amountPrimary,
  amountSecondary,
  merchantCandidate,
  personCandidate,
  date,
  time,
  dateTime,
  directionSignal,
  status,
  transactionReference,
  accountNumber,
  balance,
  reward,
  promotion,
  navigation,
  systemChrome,
  header,
  unknown;

  String get label {
    switch (this) {
      case SemanticRole.amountPrimary:
        return 'AMOUNT_PRIMARY';
      case SemanticRole.amountSecondary:
        return 'AMOUNT_SECONDARY';
      case SemanticRole.merchantCandidate:
        return 'MERCHANT_CANDIDATE';
      case SemanticRole.personCandidate:
        return 'PERSON_CANDIDATE';
      case SemanticRole.date:
        return 'DATE';
      case SemanticRole.time:
        return 'TIME';
      case SemanticRole.dateTime:
        return 'DATETIME';
      case SemanticRole.directionSignal:
        return 'DIRECTION_SIGNAL';
      case SemanticRole.status:
        return 'STATUS';
      case SemanticRole.transactionReference:
        return 'TRANSACTION_REFERENCE';
      case SemanticRole.accountNumber:
        return 'ACCOUNT_NUMBER';
      case SemanticRole.balance:
        return 'BALANCE';
      case SemanticRole.reward:
        return 'REWARD';
      case SemanticRole.promotion:
        return 'PROMOTION';
      case SemanticRole.navigation:
        return 'NAVIGATION';
      case SemanticRole.systemChrome:
        return 'SYSTEM_CHROME';
      case SemanticRole.header:
        return 'HEADER';
      case SemanticRole.unknown:
        return 'UNKNOWN';
    }
  }

  static SemanticRole fromLabel(String? label) {
    if (label == null) return SemanticRole.unknown;
    final upper = label.trim().toUpperCase();
    for (final r in SemanticRole.values) {
      if (r.label == upper || r.name.toUpperCase() == upper) {
        return r;
      }
    }
    return SemanticRole.unknown;
  }
}
