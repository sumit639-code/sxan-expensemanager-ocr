import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/import/data/services/image_picker_service.dart';
import 'package:expense_app/features/import/data/services/image_preprocessor.dart';
import 'package:expense_app/features/import/data/services/mock_transaction_extractor.dart';
import 'package:expense_app/features/import/domain/services/duplicate_detector.dart';
import 'package:expense_app/features/import/domain/usecases/confirm_import_usecase.dart';
import 'package:expense_app/features/import/domain/usecases/process_screenshots_usecase.dart';
import 'package:expense_app/features/import/presentation/providers/import_providers.dart';
import 'package:expense_app/features/import/presentation/providers/import_state.dart';

import '../domain/duplicate_detector_test.dart';

class FakeImagePickerService implements ImagePickerService {
  List<String> nextResults = [];

  @override
  Future<List<String>> pickScreenshots() async => nextResults;
}

void main() {
  group('ImportController', () {
    late FakeImagePickerService fakePicker;
    late FakeTransactionRepository fakeRepo;
    late ImportController controller;

    setUp(() {
      fakePicker = FakeImagePickerService();
      fakeRepo = FakeTransactionRepository();

      final extractor = MockTransactionExtractor(stepDelay: Duration.zero);
      final duplicateDetector = DuplicateDetector(fakeRepo);
      final processUseCase = ProcessScreenshotsUseCase(
        extractor,
        duplicateDetector,
      );
      final confirmUseCase = ConfirmImportUseCase(fakeRepo);

      controller = ImportController(
        pickerService: fakePicker,
        preprocessor: const ImagePreprocessor(),
        processUseCase: processUseCase,
        confirmUseCase: confirmUseCase,
      );
    });

    test('initial state is default ImportState with initial status', () {
      expect(controller.state.status, ImportStatus.initial);
      expect(controller.state.selectedImagePaths, isEmpty);
      expect(controller.state.extractedTransactions, isEmpty);
    });

    test(
      'pickScreenshots transitions to preview on valid image selection',
      () async {
        fakePicker.nextResults = ['test_receipt1.png', 'test_receipt2.jpg'];

        await controller.pickScreenshots();

        expect(controller.state.status, ImportStatus.preview);
        expect(controller.state.selectedImagePaths.length, 2);
      },
    );

    test(
      'removeScreenshot removes an image and resets to initial if none left',
      () {
        controller.setImages(['img1.png', 'img2.png']);
        expect(controller.state.selectedImagePaths.length, 2);

        controller.removeScreenshot('img1.png');
        expect(controller.state.selectedImagePaths, ['img2.png']);
        expect(controller.state.status, ImportStatus.preview);

        controller.removeScreenshot('img2.png');
        expect(controller.state.selectedImagePaths, isEmpty);
        expect(controller.state.status, ImportStatus.initial);
      },
    );

    test(
      'startProcessing extracts transactions and enters review state',
      () async {
        controller.setImages(['shot1.png', 'shot2.png']);

        await controller.startProcessing();

        expect(controller.state.status, ImportStatus.review);
        expect(controller.state.extractedTransactions, isNotEmpty);
        expect(controller.state.totalCount, greaterThan(0));

        // Duplicates should exist and should NOT be selected by default
        final duplicates = controller.state.extractedTransactions.where(
          (t) => t.isDuplicate,
        );
        expect(duplicates, isNotEmpty);

        for (final dup in duplicates) {
          expect(
            controller.state.selectedTransactionIds.contains(dup.id),
            isFalse,
          );
        }
      },
    );

    test('toggleSelectAll selects all and clears all appropriately', () async {
      controller.setImages(['shot1.png']);
      await controller.startProcessing();

      final total = controller.state.totalCount;

      // Initially all unique transactions are selected
      expect(controller.state.isAllSelected, isTrue);
      expect(controller.state.selectedCount, total);

      // Deselect all
      controller.toggleSelectAll();
      expect(controller.state.selectedCount, 0);
      expect(controller.state.isAllSelected, isFalse);

      // Select all again
      controller.toggleSelectAll();
      expect(controller.state.selectedCount, total);
      expect(controller.state.isAllSelected, isTrue);
    });

    test(
      'keepDuplicate and skipDuplicate adjust selection correctly',
      () async {
        controller.setImages(['shot1.png', 'shot2.png']);
        await controller.startProcessing();

        final dup = controller.state.extractedTransactions.firstWhere(
          (t) => t.isDuplicate,
        );

        // Initially unselected
        expect(
          controller.state.selectedTransactionIds.contains(dup.id),
          isFalse,
        );

        // Keep it
        controller.keepDuplicate(dup.id);
        expect(
          controller.state.selectedTransactionIds.contains(dup.id),
          isTrue,
        );

        // Skip it
        controller.skipDuplicate(dup.id);
        expect(
          controller.state.selectedTransactionIds.contains(dup.id),
          isFalse,
        );
      },
    );

    test('updateExtractedTransaction modifies item in place', () async {
      controller.setImages(['shot1.png']);
      await controller.startProcessing();

      final first = controller.state.extractedTransactions.first;
      final edited = first.copyWith(title: 'Edited Title', amount: 99900);

      controller.updateExtractedTransaction(edited);

      final updatedInState = controller.state.extractedTransactions.firstWhere(
        (t) => t.id == first.id,
      );
      expect(updatedInState.title, 'Edited Title');
      expect(updatedInState.amount, 99900);
    });

    test('deleteExtractedTransaction removes item from review list', () async {
      controller.setImages(['shot1.png']);
      await controller.startProcessing();

      final countBefore = controller.state.totalCount;
      final firstId = controller.state.extractedTransactions.first.id;

      controller.deleteExtractedTransaction(firstId);

      expect(controller.state.totalCount, countBefore - 1);
      expect(
        controller.state.extractedTransactions.any((t) => t.id == firstId),
        isFalse,
      );
      expect(
        controller.state.selectedTransactionIds.contains(firstId),
        isFalse,
      );
    });

    test(
      'confirmImport saves selected transactions and marks completed',
      () async {
        controller.setImages(['shot1.png']);
        await controller.startProcessing();

        final selectedCount = controller.state.selectedCount;
        expect(selectedCount, greaterThan(0));

        final success = await controller.confirmImport();

        expect(success, isTrue);
        expect(controller.state.status, ImportStatus.completed);
        expect(controller.state.importedCount, selectedCount);

        final saved = await fakeRepo.getAllTransactions();
        expect(saved.length, selectedCount);
      },
    );
  });
}
