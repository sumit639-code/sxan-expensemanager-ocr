import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:expense_app/features/import/domain/entities/extracted_transaction.dart';
import 'package:expense_app/features/import/domain/entities/pending_import.dart';
import 'package:expense_app/features/import/domain/usecases/confirm_import_usecase.dart';
import 'package:expense_app/features/import/domain/usecases/process_screenshots_usecase.dart';
import 'package:expense_app/features/import/domain/services/transaction_extractor.dart';
import 'package:expense_app/features/import/domain/services/duplicate_detector.dart';
import 'package:expense_app/features/import/presentation/providers/import_providers.dart';
import 'package:expense_app/features/import/presentation/providers/import_state.dart';
import 'package:expense_app/features/import/data/services/image_picker_service.dart';
import 'package:expense_app/features/import/data/services/image_preprocessor.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/features/transactions/domain/repositories/transaction_repository.dart';

class MockTransactionRepository implements TransactionRepository {
  final List<Transaction> added = [];

  @override
  Future<void> addTransaction(Transaction transaction) async {
    added.add(transaction);
  }

  @override
  Future<void> addTransactions(List<Transaction> transactions) async {
    added.addAll(transactions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockImagePickerService implements ImagePickerService {
  @override
  Future<List<String>> pickScreenshots() async => [];
}

class MockTransactionExtractor implements TransactionExtractor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDuplicateDetector extends DuplicateDetector {
  MockDuplicateDetector(super.repository);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockTransactionRepository mockTxRepo;
  late ConfirmImportUseCase confirmUseCase;
  late ImportController controller;

  setUp(() {
    mockTxRepo = MockTransactionRepository();
    confirmUseCase = ConfirmImportUseCase(mockTxRepo);
    controller = ImportController(
      pickerService: MockImagePickerService(),
      preprocessor: const ImagePreprocessor(),
      processUseCase: ProcessScreenshotsUseCase(
        MockTransactionExtractor(),
        MockDuplicateDetector(mockTxRepo),
      ),
      confirmUseCase: confirmUseCase,
      pendingImportRepo: null,
    );
  });

  test('loadMultiplePendingImports aggregates transactions from all batches', () {
    final batch1 = PendingImport(
      id: 'batch_1',
      imagePaths: const ['img1.png'],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [
        ExtractedTransaction(
          id: 'tx_1',
          amount: 50000,
          title: 'Swiggy',
          merchant: 'Swiggy',
          date: DateTime(2026, 9, 22),
          source: TransactionSource.screenshot,
        ),
      ],
    );

    final batch2 = PendingImport(
      id: 'batch_2',
      imagePaths: const [],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [
        ExtractedTransaction(
          id: 'tx_2',
          amount: 150000,
          title: 'Amazon Pay',
          merchant: 'Amazon Pay',
          date: DateTime(2026, 9, 22),
          source: TransactionSource.sms,
        ),
        ExtractedTransaction(
          id: 'tx_3',
          amount: 25000,
          title: 'Chai Point',
          merchant: 'Chai Point',
          date: DateTime(2026, 9, 22),
          source: TransactionSource.sms,
        ),
      ],
    );

    controller.loadMultiplePendingImports([batch1, batch2]);

    expect(controller.currentState.status, ImportStatus.review);
    expect(controller.currentState.totalCount, 3);
    expect(controller.currentState.selectedCount, 3);
    expect(controller.currentState.selectedTotalAmount, 225000); // 500 + 1500 + 250 = 2250.00
    expect(controller.currentState.currentPendingImportIds, ['batch_1', 'batch_2']);
  });

  test('bulkConfirmPendingImports commits transactions directly to repository', () async {
    final batch1 = PendingImport(
      id: 'batch_1',
      imagePaths: const [],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [
        ExtractedTransaction(
          id: 'tx_1',
          amount: 45000,
          title: 'Zomato',
          merchant: 'Zomato',
          date: DateTime(2026, 9, 22),
          source: TransactionSource.sms,
        ),
      ],
    );

    final batch2 = PendingImport(
      id: 'batch_2',
      imagePaths: const [],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [
        ExtractedTransaction(
          id: 'tx_2',
          amount: 120000,
          title: 'Salary',
          type: TransactionType.income,
          date: DateTime(2026, 9, 22),
          source: TransactionSource.sms,
        ),
      ],
    );

    final count = await controller.bulkConfirmPendingImports([batch1, batch2]);

    expect(count, 2);
    expect(mockTxRepo.added.length, 2);
    expect(mockTxRepo.added[0].amount, 45000);
    expect(mockTxRepo.added[0].source, TransactionSource.sms);
    expect(mockTxRepo.added[1].amount, 120000);
    expect(mockTxRepo.added[1].type, TransactionType.income);
  });
}
