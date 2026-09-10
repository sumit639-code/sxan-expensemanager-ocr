/// Defines whether a transaction is an income or an expense.
enum TransactionType {
  income('income'),
  expense('expense');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String val) {
    return TransactionType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Defines the origin or source of a transaction entry.
enum TransactionSource {
  manual('manual'),
  screenshot('screenshot'),
  import('import');

  final String value;
  const TransactionSource(this.value);

  static TransactionSource fromString(String val) {
    return TransactionSource.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TransactionSource.manual,
    );
  }
}
