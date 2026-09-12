import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart' as pkg;

import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/datasources/ocr_api_config.dart';
import '../../data/datasources/python_ocr_api.dart';
import '../../data/parser/python_ocr_transaction_parser.dart';
import '../../data/parser/rule_based_transaction_parser.dart';
import '../../data/services/image_picker_service.dart';
import '../../data/services/image_preprocessor.dart';
import '../../data/services/local_transaction_ocr_extractor.dart';
import '../../data/services/mlkit_ocr_engine.dart';
import '../../data/services/python_api_transaction_extractor.dart';
import '../../data/services/real_transaction_extractor.dart';

import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/pending_import.dart';
import '../../domain/services/duplicate_detector.dart';
import '../../domain/services/ocr_engine.dart';
import '../../domain/services/transaction_extractor.dart';
import '../../domain/services/transaction_parser.dart';
import '../../domain/usecases/confirm_import_usecase.dart';
import '../../domain/usecases/process_screenshots_usecase.dart';
import 'import_state.dart';

/// Provider for the OCR API configuration (development bridge).
final ocrApiConfigProvider = Provider<OcrApiConfig>((ref) {
  final ocrSettings = ref.watch(
    settingsNotifierProvider.select((s) => s.ocrSettings),
  );
  return OcrApiConfig(
    baseUrl: ocrSettings.apiBaseUrl,
    apiVersion: ocrSettings.apiVersion,
  );
});

/// Provider for the Python OCR API client (development bridge).
final pythonOcrApiProvider = Provider<PythonOcrApi>((ref) {
  final config = ref.watch(ocrApiConfigProvider);
  final api = PythonOcrApi(config: config);
  ref.onDispose(() => api.close());
  return api;
});

/// Provider for the Python OCR transaction parser.
final pythonOcrTransactionParserProvider =
    Provider<PythonOcrTransactionParser>((ref) {
  return PythonOcrTransactionParser();
});

/// Provider for the image picker service.
final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerServiceImpl();
});

/// Provider for the image preprocessor.
final imagePreprocessorProvider = Provider<ImagePreprocessor>((ref) {
  return const ImagePreprocessor();
});

/// Provider for the on-device ML Kit OCR engine.
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Provider for the rule-based transaction parser.
final transactionParserProvider = Provider<TransactionParser>((ref) {
  return RuleBasedTransactionParser();
});

/// Provider for the on-device real transaction extractor.
final realTransactionExtractorProvider =
    Provider<RealTransactionExtractor>((ref) {
  return RealTransactionExtractor(
    ocrEngine: ref.watch(ocrEngineProvider),
    parser: ref.watch(transactionParserProvider),
    preprocessor: ref.watch(imagePreprocessorProvider),
  );
});

/// Provider for the singleton on-device TransactionOcr instance (V2).
final transactionOcrServiceProvider = Provider<pkg.TransactionOcr>((ref) {
  final ocr = pkg.TransactionOcr.local(
    config: const pkg.OcrConfig(
      detModelPath:
          'packages/transaction_ocr_flutter/assets/models/v1.0.0/det_v1.onnx',
      recModelPath:
          'packages/transaction_ocr_flutter/assets/models/v1.0.0/rec_v1.onnx',
      clsModelPath:
          'packages/transaction_ocr_flutter/assets/models/v1.0.0/cls_v1.onnx',
      keysPath:
          'packages/transaction_ocr_flutter/assets/models/v1.0.0/keys_v1.txt',
    ),
  );
  ref.onDispose(() => ocr.dispose());
  return ocr;
});

/// Provider for the on-device LocalTransactionOcrExtractor powered by transaction_ocr_flutter.
final localTransactionOcrExtractorProvider =
    Provider<LocalTransactionOcrExtractor>((ref) {
  return LocalTransactionOcrExtractor(
    ocrService: ref.watch(transactionOcrServiceProvider),
    fallbackParser: ref.watch(transactionParserProvider),
    preprocessor: ref.watch(imagePreprocessorProvider),
  );
});

/// Dynamic transaction extractor depending on selected engine mode in Settings.
///
/// - [OcrEngineMode.offline]: 100% on-device RapidOCR ONNX via `transaction_ocr_flutter`.
/// - [OcrEngineMode.api]: Development Python FastAPI server.
final transactionExtractorProvider = Provider<TransactionExtractor>((ref) {
  final mode = ref.watch(
    settingsNotifierProvider.select((s) => s.ocrSettings.engineMode),
  );

  switch (mode) {
    case OcrEngineMode.offline:
      return ref.watch(localTransactionOcrExtractorProvider);
    case OcrEngineMode.api:
      return ref.watch(pythonApiTransactionExtractorProvider);
  }
});

/// Optional development extractor connecting to local Python server.
final pythonApiTransactionExtractorProvider =
    Provider<TransactionExtractor>((ref) {
  return PythonApiTransactionExtractor(
    api: ref.watch(pythonOcrApiProvider),
    parser: ref.watch(pythonOcrTransactionParserProvider),
    preprocessor: ref.watch(imagePreprocessorProvider),
    fallbackExtractor: ref.watch(realTransactionExtractorProvider),
  );
});



/// Provider for the duplicate detector.
final duplicateDetectorProvider = Provider<DuplicateDetector>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return DuplicateDetector(repository);
});

/// Provider for the ProcessScreenshotsUseCase.
final processScreenshotsUseCaseProvider = Provider<ProcessScreenshotsUseCase>((
  ref,
) {
  final extractor = ref.watch(transactionExtractorProvider);
  final duplicateDetector = ref.watch(duplicateDetectorProvider);
  return ProcessScreenshotsUseCase(extractor, duplicateDetector);
});

/// Provider for the ConfirmImportUseCase.
final confirmImportUseCaseProvider = Provider<ConfirmImportUseCase>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return ConfirmImportUseCase(repository);
});

/// Controller managing the state of the Screenshot Import flow.
class ImportController extends StateNotifier<ImportState> {
  final ImagePickerService _pickerService;
  final ImagePreprocessor _preprocessor;
  final ProcessScreenshotsUseCase _processUseCase;
  final ConfirmImportUseCase _confirmUseCase;

  ImportController({
    required ImagePickerService pickerService,
    required ImagePreprocessor preprocessor,
    required ProcessScreenshotsUseCase processUseCase,
    required ConfirmImportUseCase confirmUseCase,
  }) : _pickerService = pickerService,
       _preprocessor = preprocessor,
       _processUseCase = processUseCase,
       _confirmUseCase = confirmUseCase,
       super(const ImportState());

  /// Opens gallery to pick one or more screenshots.
  Future<void> pickScreenshots() async {
    final picked = await _pickerService.pickScreenshots();
    if (picked.isEmpty) return;

    final processed = _preprocessor.validateImages(picked);
    final validPaths = processed
        .where((p) => p.isValid)
        .map((p) => p.path)
        .toList();

    if (validPaths.isEmpty) {
      state = state.copyWith(
        status: ImportStatus.error,
        fatalErrorMessage: 'None of the selected files were valid images.',
      );
      return;
    }

    state = state.copyWith(
      status: ImportStatus.preview,
      selectedImagePaths: validPaths,
      errors: const [],
      fatalErrorMessage: null,
    );
  }

  /// Appends additional screenshots to the preview.
  Future<void> addMoreScreenshots() async {
    final picked = await _pickerService.pickScreenshots();
    if (picked.isEmpty) return;

    final processed = _preprocessor.validateImages(picked);
    final validPaths = processed
        .where((p) => p.isValid)
        .map((p) => p.path)
        .toList();

    final currentSet = state.selectedImagePaths.toSet();
    currentSet.addAll(validPaths);

    state = state.copyWith(selectedImagePaths: currentSet.toList());
  }

  /// Directly sets paths (useful for testing and drag-and-drop).
  void setImages(List<String> paths) {
    if (paths.isEmpty) {
      state = const ImportState();
      return;
    }
    state = state.copyWith(
      status: ImportStatus.preview,
      selectedImagePaths: paths,
      fatalErrorMessage: null,
    );
  }

  /// Sets up state for reviewing an existing PendingImport.
  void loadPendingImport(PendingImport pendingImport) {
    final defaultSelectedIds = <String>{};
    for (final tx in pendingImport.extractedTransactions) {
      if (!tx.isDuplicate) {
        defaultSelectedIds.add(tx.id);
      }
    }
    if (defaultSelectedIds.isEmpty && pendingImport.extractedTransactions.isNotEmpty) {
      defaultSelectedIds.addAll(pendingImport.extractedTransactions.map((tx) => tx.id));
    }

    state = state.copyWith(
      status: ImportStatus.review,
      selectedImagePaths: pendingImport.imagePaths,
      extractedTransactions: pendingImport.extractedTransactions,
      selectedTransactionIds: defaultSelectedIds,
      errors: const [],
      fatalErrorMessage: null,
    );
  }

  /// Removes a single screenshot from the preview list.
  void removeScreenshot(String path) {
    final updated = List<String>.from(state.selectedImagePaths)..remove(path);
    if (updated.isEmpty) {
      state = const ImportState();
    } else {
      state = state.copyWith(selectedImagePaths: updated);
    }
  }

  /// Initiates the extraction pipeline.
  Future<void> startProcessing() async {
    if (state.selectedImagePaths.isEmpty) return;

    state = state.copyWith(
      status: ImportStatus.processing,
      currentProcessingStep: 'Preparing screenshots...',
      processingProgress: 0.05,
      errors: const [],
    );

    // Throttle progress updates to prevent flooding the widget rebuild queue
    // when ONNX inference fires many rapid onProgress callbacks.
    DateTime lastProgressUpdate = DateTime.now();
    const progressThrottleMs = 150;

    try {
      final imagePaths = List<String>.from(state.selectedImagePaths);

      final result = await _processUseCase.execute(
        imagePaths,
        onProgress: (step, progress) {
          if (!mounted) return;
          final now = DateTime.now();
          final elapsed = now.difference(lastProgressUpdate).inMilliseconds;
          // Always update on significant milestones, throttle the rest
          final isSignificant = progress >= 0.95 || progress <= 0.06;
          if (elapsed >= progressThrottleMs || isSignificant) {
            lastProgressUpdate = now;
            state = state.copyWith(
              currentProcessingStep: step,
              processingProgress: progress,
            );
          }
        },
      );

      if (!mounted) return;

      // Default selection: select all non-duplicates. Duplicates are unselected by default.
      final defaultSelectedIds = <String>{};
      for (final tx in result.transactions) {
        if (!tx.isDuplicate) {
          defaultSelectedIds.add(tx.id);
        }
      }

      state = state.copyWith(
        status: ImportStatus.review,
        extractedTransactions: result.transactions,
        selectedTransactionIds: defaultSelectedIds,
        failedImagePaths: result.failedImages,
        errors: result.errors,
        debugOcrText: result.debugOcrText,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[IMPORT ERROR] Pipeline failure: $e\n$stackTrace');
      }
      if (!mounted) return;
      state = state.copyWith(
        status: ImportStatus.error,
        fatalErrorMessage: 'An error occurred during processing: $e',
      );
    }
  }

  /// Toggles select-all for all extracted transactions.
  void toggleSelectAll() {
    if (state.isAllSelected) {
      state = state.copyWith(selectedTransactionIds: const {});
    } else {
      final allIds = state.extractedTransactions.map((tx) => tx.id).toSet();
      state = state.copyWith(selectedTransactionIds: allIds);
    }
  }

  /// Toggles selection of an individual transaction.
  void toggleTransactionSelection(String id) {
    final current = Set<String>.from(state.selectedTransactionIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedTransactionIds: current);
  }

  /// Selects a duplicate transaction (User chose to Keep).
  void keepDuplicate(String id) {
    final current = Set<String>.from(state.selectedTransactionIds);
    current.add(id);
    state = state.copyWith(selectedTransactionIds: current);
  }

  /// Deselects a duplicate transaction (User chose to Skip).
  void skipDuplicate(String id) {
    final current = Set<String>.from(state.selectedTransactionIds);
    current.remove(id);
    state = state.copyWith(selectedTransactionIds: current);
  }

  /// Updates an extracted transaction in place with edited values.
  void updateExtractedTransaction(ExtractedTransaction updated) {
    final list = state.extractedTransactions.map((tx) {
      return tx.id == updated.id ? updated : tx;
    }).toList();

    state = state.copyWith(extractedTransactions: list);
  }

  /// Removes an extracted transaction from the review list entirely.
  void deleteExtractedTransaction(String id) {
    final list = state.extractedTransactions
        .where((tx) => tx.id != id)
        .toList();
    final selected = Set<String>.from(state.selectedTransactionIds)..remove(id);
    state = state.copyWith(
      extractedTransactions: list,
      selectedTransactionIds: selected,
    );
  }

  /// Confirms and commits the selected transactions to SQLite.
  Future<bool> confirmImport() async {
    final toSave = state.selectedTransactions;
    if (toSave.isEmpty) return false;

    final totalAmount = state.selectedTotalAmount;

    try {
      final saved = await _confirmUseCase.execute(toSave);
      if (!mounted) return false;
      state = state.copyWith(
        status: ImportStatus.completed,
        importedCount: saved.length,
        importedTotalAmount: totalAmount,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        status: ImportStatus.error,
        fatalErrorMessage: 'Failed to save imported transactions: $e',
      );
      return false;
    }
  }

  /// Resets the import flow back to initial state.
  void reset() {
    if (!mounted) return;
    state = const ImportState();
  }
}

/// Provider for [ImportController] and [ImportState].
///
/// NOT auto-disposed: the import flow is a multi-step workflow with long-running
/// async OCR operations. Auto-dispose can kill the notifier mid-processing,
/// causing state-setter crashes. The controller is manually [reset()] when the
/// user finishes or exits the import flow.
final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>((ref) {
      return ImportController(
        pickerService: ref.watch(imagePickerServiceProvider),
        preprocessor: ref.watch(imagePreprocessorProvider),
        processUseCase: ref.watch(processScreenshotsUseCaseProvider),
        confirmUseCase: ref.watch(confirmImportUseCaseProvider),
      );
    });
