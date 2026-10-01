import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/entities/pending_import.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingImport Entity & Serialization', () {
    test('toJson and fromJson correctly round-trip all fields', () {
      final now = DateTime(2026, 9, 11, 14, 30);
      final tx = ExtractedTransaction(
        id: 'tx_123',
        date: DateTime(2026, 9, 10),
        amount: 25000,
        title: 'Swiggy Food Order',
        merchant: 'Swiggy',
        type: TransactionType.expense,
        confidence: 0.95,
      );

      final import = PendingImport(
        id: 'import_999',
        imagePaths: ['/data/user/0/cache/shared_1.jpg'],
        createdAt: now,
        status: PendingImportStatus.readyForReview,
        extractedTransactions: [tx],
        errorMessage: null,
        source: 'Shared from another app',
      );

      final json = import.toJson();
      final restored = PendingImport.fromJson(json);

      expect(restored.id, equals('import_999'));
      expect(restored.imagePaths, equals(['/data/user/0/cache/shared_1.jpg']));
      expect(restored.createdAt, equals(now));
      expect(restored.status, equals(PendingImportStatus.readyForReview));
      expect(restored.transactionCount, equals(1));
      expect(restored.extractedTransactions.first.title, equals('Swiggy Food Order'));
      expect(restored.extractedTransactions.first.amount, equals(25000));
      expect(restored.isReadyForReview, isTrue);
      expect(restored.isProcessing, isFalse);
      expect(restored.isFailed, isFalse);
    });

    test('PendingImport state helper getters return correct values', () {
      final proc = PendingImport(
        id: '1',
        imagePaths: const [],
        createdAt: DateTime(2026),
        status: PendingImportStatus.processing,
      );
      expect(proc.isProcessing, isTrue);
      expect(proc.isReadyForReview, isFalse);

      final failed = PendingImport(
        id: '2',
        imagePaths: const [],
        createdAt: DateTime(2026),
        status: PendingImportStatus.failed,
        errorMessage: 'OCR Timeout',
      );
      expect(failed.isFailed, isTrue);
      expect(failed.errorMessage, equals('OCR Timeout'));
    });
  });
}
