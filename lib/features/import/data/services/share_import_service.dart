import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/pending_import.dart';
import '../../domain/usecases/process_screenshots_usecase.dart';
import '../repositories/pending_import_repository.dart';

/// Callback invoked when a user taps a notification to review a pending import.
typedef NotificationTapCallback = void Function(String pendingImportId);

/// Callback invoked when images are received via share intent.
typedef SharedImagesReceivedCallback = void Function(List<String> paths);

/// Service managing the Android Share Target integration and background OCR processing.
///
/// Converts shared images into staged PendingImports, coordinates OCR extraction,
/// triggers local notifications on completion, and safely manages cached image lifecycles.
class ShareImportService {
  static const MethodChannel _shareChannel =
      MethodChannel('com.expenseapp.expense_app/share_target');
  static const MethodChannel _notificationChannel =
      MethodChannel('com.expenseapp.expense_app/notifications');

  final PendingImportRepository _repository;
  final ProcessScreenshotsUseCase _processUseCase;

  NotificationTapCallback? onNotificationTapped;
  SharedImagesReceivedCallback? onSharedImagesReceived;
  final Set<String> _recentBatchSignatures = {};
  bool _isInitialized = false;

  ShareImportService({
    required PendingImportRepository repository,
    required ProcessScreenshotsUseCase processUseCase,
  })  : _repository = repository,
        _processUseCase = processUseCase;

  /// Initialize listeners for incoming Android share intents and notifications.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Listen for runtime incoming share intents (app already running)
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedImagesReceived') {
        final rawList = call.arguments as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          final paths = rawList.map((e) => e.toString()).toList();
          await processSharedImages(paths);
        }
      }
    });

    // 2. Listen for runtime notification clicks
    _notificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTapped') {
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      }
    });

    // 3. Check if app was launched via Share Target (cold start)
    try {
      final initial =
          await _shareChannel.invokeMethod<List<dynamic>>('getInitialSharedImages');
      if (initial != null && initial.isNotEmpty) {
        await _shareChannel.invokeMethod('clearInitialSharedImages');
        final paths = initial.map((e) => e.toString()).toList();
        await processSharedImages(paths);
      }
    } catch (e) {
      debugPrint('Error getting initial shared images: $e');
    }

    // 4. Check if app was launched via Notification tap (cold start)
    try {
      final payload =
          await _notificationChannel.invokeMethod<String>('getLaunchPayload');
      if (payload != null && payload.isNotEmpty) {
        await _notificationChannel.invokeMethod('clearLaunchPayload');
        onNotificationTapped?.call(payload);
      }
    } catch (e) {
      debugPrint('Error checking notification launch payload: $e');
    }

    // 5. Recover and auto-resume any orphaned processing imports left over if app was terminated during OCR
    await recoverOrphanedProcessingImports(autoResume: true);

    // 6. Request notification permission on Android 13+ if not already granted
    await requestNotificationPermission();
  }

  /// Recover and automatically resume any interrupted OCR imports.
  Future<void> recoverOrphanedProcessingImports({bool autoResume = true}) async {
    try {
      final all = await _repository.getAll();
      for (final item in all) {
        if (item.status == PendingImportStatus.processing) {
          final imagesExist = item.imagePaths.isNotEmpty &&
              item.imagePaths.every((p) => File(p).existsSync());
          if (imagesExist && autoResume) {
            debugPrint('[ShareImportService] Auto-resuming interrupted import: ${item.id}');
            await _repository.delete(item.id, cleanupImages: false);
            unawaited(processSharedImages(item.imagePaths));
          } else {
            final updated = item.copyWith(
              status: PendingImportStatus.failed,
              errorMessage: 'Processing was interrupted. Tap Retry OCR.',
            );
            await _repository.save(updated);
          }
        }
      }
    } catch (e) {
      debugPrint('Error recovering orphaned pending imports: $e');
    }
  }

  /// Retry OCR extraction for a failed or interrupted pending import.
  Future<void> retryPendingImport(String pendingImportId) async {
    final item = await _repository.getById(pendingImportId);
    if (item == null) return;

    await _repository.delete(pendingImportId, cleanupImages: false);
    await processSharedImages(item.imagePaths);
  }

  /// Request notification permission on Android 13+ if not already granted.
  Future<void> requestNotificationPermission() async {
    try {
      await _notificationChannel
          .invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Process shared image file paths into a staged PendingImport with offline OCR.
  Future<PendingImport?> processSharedImages(List<String> paths) async {
    if (paths.isEmpty) return null;

    final signature = paths.join('|');
    if (_recentBatchSignatures.contains(signature)) {
      debugPrint('[ShareImportService] Ignored rapid duplicate share intent for: $signature');
      return null;
    }
    _recentBatchSignatures.add(signature);
    Timer(const Duration(seconds: 8), () {
      _recentBatchSignatures.remove(signature);
    });

    // Check if there is already an active (processing or readyForReview) pending import with identical paths
    final activeImports = await _repository.getAllActive();
    final isAlreadyPending = activeImports.any((item) =>
        item.imagePaths.length == paths.length &&
        setEquals(item.imagePaths.toSet(), paths.toSet()));
    if (isAlreadyPending) {
      debugPrint('[ShareImportService] Ignored duplicate share for identical active paths.');
      return null;
    }

    final importId = 'import_${DateTime.now().millisecondsSinceEpoch}_${paths.hashCode.abs().toString().padLeft(4, '0')}';

    // 1. Initial pending import in processing state
    var pending = PendingImport(
      id: importId,
      imagePaths: paths,
      createdAt: DateTime.now(),
      status: PendingImportStatus.processing,
      source: 'Shared from another app',
    );
    await _repository.save(pending);

    // Notify UI now that the pending item is safely in database
    onSharedImagesReceived?.call(paths);

    // 2. Run existing offline OCR extraction pipeline
    try {
      final result = await _processUseCase.execute(paths);

      if (result.transactions.isNotEmpty) {
        pending = pending.copyWith(
          status: PendingImportStatus.readyForReview,
          extractedTransactions: result.transactions,
        );
        await _repository.save(pending);

        // Show local Android notification
        await showInboxReadyNotification(
          count: result.transactions.length,
          pendingImportId: pending.id,
        );
      } else {
        pending = pending.copyWith(
          status: PendingImportStatus.failed,
          errorMessage: "Couldn't find a transaction in the shared image",
        );
        await _repository.save(pending);

        await showNotification(
          id: pending.id.hashCode.abs(),
          title: 'No transaction detected',
          body: "Couldn't find a transaction in the shared image. Tap to view.",
          payload: pending.id,
        );
      }
    } catch (e) {
      debugPrint('Share OCR processing failed: $e');
      pending = pending.copyWith(
        status: PendingImportStatus.failed,
        errorMessage: "Couldn't process shared image: $e",
      );
      await _repository.save(pending);

      await showNotification(
        id: pending.id.hashCode.abs(),
        title: "Couldn't process shared image",
        body: 'An error occurred while analyzing the screenshot.',
        payload: pending.id,
      );
    }

    return pending;
  }

  /// Show a high-priority heads-up notification that the inbox has transactions ready.
  Future<void> showInboxReadyNotification({
    required int count,
    String? pendingImportId,
  }) async {
    final txLabel = count == 1 ? 'transaction' : 'transactions';
    await showNotification(
      id: pendingImportId?.hashCode.abs() ?? 1001,
      title: 'Inbox ready for review',
      body: '$count $txLabel ready in your inbox. Tap to review.',
      payload: pendingImportId ?? 'inbox',
    );
  }

  /// Trigger a local device notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _notificationChannel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload ?? '',
      });
    } catch (e) {
      debugPrint('Failed to trigger native notification: $e');
    }
  }
}
