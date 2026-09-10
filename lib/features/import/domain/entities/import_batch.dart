/// Status of an import batch session.
enum ImportBatchStatus { processing, review, completed, failed, partial }

/// Domain concept representing one screenshot import session.
class ImportBatch {
  final String id;
  final DateTime createdAt;
  final ImportBatchStatus status;
  final int imageCount;
  final int transactionCount;

  const ImportBatch({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.imageCount,
    required this.transactionCount,
  });

  ImportBatch copyWith({
    String? id,
    DateTime? createdAt,
    ImportBatchStatus? status,
    int? imageCount,
    int? transactionCount,
  }) {
    return ImportBatch(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      imageCount: imageCount ?? this.imageCount,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportBatch &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.imageCount == imageCount &&
        other.transactionCount == transactionCount;
  }

  @override
  int get hashCode {
    return Object.hash(id, createdAt, status, imageCount, transactionCount);
  }
}
