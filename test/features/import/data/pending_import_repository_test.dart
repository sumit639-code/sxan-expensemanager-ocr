import 'dart:io';
import 'package:expense_app/features/import/data/repositories/pending_import_repository.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/entities/pending_import.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PendingImportRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pending_test_');
    repository = PendingImportRepository(
      storageFile: File('${tempDir.path}/test_pending.json'),
    );
  });

  tearDown(() async {
    repository.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PendingImportRepository Logic', () {
    test('save, getById, and markCompleted', () async {
      final item = PendingImport(
        id: 'test_1',
        imagePaths: ['/tmp/dummy.jpg'],
        createdAt: DateTime.now(),
        status: PendingImportStatus.readyForReview,
        extractedTransactions: const [
          ExtractedTransaction(
            id: 'tx_1',
            title: 'Coffee',
            amount: 15000,
            type: TransactionType.expense,
          ),
        ],
      );

      await repository.save(item);
      final fetched = await repository.getById('test_1');
      expect(fetched, isNotNull);
      expect(fetched!.id, equals('test_1'));
      expect(fetched.extractedTransactions.length, equals(1));
      expect(fetched.extractedTransactions.first.amount, equals(15000));

      await repository.markCompleted('test_1');
      final completed = await repository.getById('test_1');
      expect(completed!.status, equals(PendingImportStatus.completed));

      final active = await repository.getAllActive();
      expect(active.any((i) => i.id == 'test_1'), isFalse);
    });

    test('delete removes item from repository', () async {
      final item = PendingImport(
        id: 'test_del',
        imagePaths: [],
        createdAt: DateTime.now(),
        status: PendingImportStatus.processing,
      );

      await repository.save(item);
      expect(await repository.getById('test_del'), isNotNull);

      await repository.delete('test_del');
      expect(await repository.getById('test_del'), isNull);
    });
  });
}
