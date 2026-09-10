import '../../../../shared/enums/transaction_enums.dart';

/// Pure domain entity representing a financial transaction.
///
/// Fully decoupled from Flutter UI, Drift, SQLite, or any external framework.
class Transaction {
  final String id;
  final TransactionType type;
  final int amount; // Stored as integer in minor units (e.g., paise/cents)
  final String currency;
  final String title;
  final String? merchant;
  final String? categoryId;
  final DateTime date;
  final String? note;
  final TransactionSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'INR',
    required this.title,
    this.merchant,
    this.categoryId,
    required this.date,
    this.note,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? currency,
    String? title,
    String? merchant,
    String? categoryId,
    DateTime? date,
    String? note,
    TransactionSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      title: title ?? this.title,
      merchant: merchant ?? this.merchant,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.type == type &&
        other.amount == amount &&
        other.currency == currency &&
        other.title == title &&
        other.merchant == merchant &&
        other.categoryId == categoryId &&
        other.date == date &&
        other.note == note &&
        other.source == source &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      amount,
      currency,
      title,
      merchant,
      categoryId,
      date,
      note,
      source,
      createdAt,
      updatedAt,
    );
  }
}
