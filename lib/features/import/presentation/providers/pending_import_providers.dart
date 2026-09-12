import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/pending_import_repository.dart';
import '../../data/services/share_import_service.dart';
import '../../domain/entities/pending_import.dart';
import 'import_providers.dart';

/// Provider for the [PendingImportRepository] singleton.
final pendingImportRepositoryProvider =
    Provider<PendingImportRepository>((ref) {
  final repo = PendingImportRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// StreamProvider providing real-time list of active pending imports (processing, ready, failed).
final activePendingImportsProvider =
    StreamProvider<List<PendingImport>>((ref) {
  final repo = ref.watch(pendingImportRepositoryProvider);
  return repo.watchActive();
});

/// Provider for the number of active pending imports (ready, processing, or needs attention).
final pendingImportCountProvider = Provider<int>((ref) {
  final asyncValue = ref.watch(activePendingImportsProvider);
  return asyncValue.maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});

/// Provider for the [ShareImportService].
final shareImportServiceProvider = Provider<ShareImportService>((ref) {
  final repo = ref.watch(pendingImportRepositoryProvider);
  final processUseCase = ref.watch(processScreenshotsUseCaseProvider);

  final service = ShareImportService(
    repository: repo,
    processUseCase: processUseCase,
  );

  return service;
});
