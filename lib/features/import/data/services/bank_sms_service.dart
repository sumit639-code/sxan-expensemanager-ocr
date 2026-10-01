import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../settings/data/services/settings_service.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/pending_import.dart';
import '../../domain/services/duplicate_detector.dart';
import '../parser/bank_sms_parser.dart';
import '../repositories/pending_import_repository.dart';

/// Service responsible for scanning, receiving, and parsing Bank SMS messages
/// and staging detected transactions into the user's Inbox (PendingImports).
class BankSmsService {
  static const MethodChannel _smsChannel =
      MethodChannel('com.expenseapp.expense_app/sms');
  static const MethodChannel _notificationChannel =
      MethodChannel('com.expenseapp.expense_app/notifications');

  final BankSmsParser _parser;
  final PendingImportRepository _repository;
  final DuplicateDetector _duplicateDetector;
  final SettingsService? _settingsService;

  bool _isInitialized = false;

  BankSmsService({
    required PendingImportRepository repository,
    required DuplicateDetector duplicateDetector,
    SettingsService? settingsService,
    BankSmsParser parser = const BankSmsParser(),
  })  : _repository = repository,
        _duplicateDetector = duplicateDetector,
        _settingsService = settingsService,
        _parser = parser;

  /// Initializes SMS listeners and checks for any background SMS caught while app was inactive.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Listen for real-time incoming SMS alerts from Android broadcast receiver
    _smsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final sender = args['sender'] as String?;
          final body = args['body'] as String? ?? '';
          final timestampMs = args['timestamp'] as num?;
          final timestamp = timestampMs != null
              ? DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt())
              : DateTime.now();

          await processIncomingSms(
            body: body,
            sender: sender,
            timestamp: timestamp,
          );
        }
      }
    });

    // 2. Process any pending background SMS received before engine attached
    try {
      final pendingList = await _smsChannel
          .invokeMethod<List<dynamic>>('getPendingSmsFromBackground');
      if (pendingList != null && pendingList.isNotEmpty) {
        for (final item in pendingList) {
          if (item is Map) {
            final sender = item['sender'] as String?;
            final body = item['body'] as String? ?? '';
            final timestampMs = item['timestamp'] as num?;
            final timestamp = timestampMs != null
                ? DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt())
                : DateTime.now();

            await processIncomingSms(
              body: body,
              sender: sender,
              timestamp: timestamp,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[BankSmsService] Error checking background SMS: $e');
    }
  }

  /// Checks if SMS permissions (READ_SMS and RECEIVE_SMS) are granted.
  Future<bool> checkPermission() async {
    try {
      final granted =
          await _smsChannel.invokeMethod<bool>('checkSmsPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('[BankSmsService] checkPermission error: $e');
      return false;
    }
  }

  /// Requests SMS permissions from the user.
  Future<void> requestPermission() async {
    try {
      await _smsChannel.invokeMethod('requestSmsPermission');
    } catch (e) {
      debugPrint('[BankSmsService] requestPermission error: $e');
    }
  }

  /// Synchronizes the enabled/disabled state of background SMS detection with native Android.
  Future<void> setDetectionEnabled(bool enabled) async {
    try {
      await _smsChannel.invokeMethod('setSmsDetectionEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[BankSmsService] setDetectionEnabled error: $e');
    }
  }

  /// Requests the user to disable aggressive OEM battery optimization for SXAN.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final success = await _smsChannel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return success ?? false;
    } catch (e) {
      debugPrint('[BankSmsService] openBatteryOptimizationSettings error: $e');
      return false;
    }
  }

  static final Map<String, DateTime> _recentlyProcessedSms = {};

  /// Processes a single incoming SMS message and stages it in the inbox if it's a valid transaction.
  Future<PendingImport?> processIncomingSms({
    required String body,
    String? sender,
    DateTime? timestamp,
  }) async {
    final cleanBody = body.trim();
    final now = DateTime.now();
    final lastSeen = _recentlyProcessedSms[cleanBody];
    if (lastSeen != null && now.difference(lastSeen).inMilliseconds < 2000) {
      debugPrint('[BankSmsService] Ignored duplicate OS broadcast echo within 2s');
      return null;
    }
    _recentlyProcessedSms[cleanBody] = now;

    final excludedKeywords = _settingsService?.loadSettings().smsExcludedKeywords;
    final parsed = _parser.parse(
      body: body,
      sender: sender,
      timestamp: timestamp,
      excludedKeywords: excludedKeywords,
    );

    if (parsed == null) return null;

    // Check duplicate detection against database
    final checkedList = await _duplicateDetector.detectDuplicates([parsed]);
    var tx = checkedList.first;

    // Check if we already have an active pending import with this exact transaction
    final active = await _repository.getAllActive();
    final isAlreadyPending = active.any((pending) => pending.extractedTransactions
        .any((existing) => existing.normalizedFingerprint == tx.normalizedFingerprint));

    if (isAlreadyPending) {
      // Mark as duplicate so user can review it in the inbox rather than silently dropping!
      tx = tx.copyWith(
        isDuplicate: true,
        duplicateSource: DuplicateSource.intraBatch,
      );
    }

    final bankTitle = tx.sourceReference ?? 'Bank';
    final importId =
        'sms_${DateTime.now().millisecondsSinceEpoch}_${tx.amount ?? 0}';

    final pending = PendingImport(
      id: importId,
      imagePaths: const [],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [tx],
      source: 'Bank SMS: $bankTitle',
    );

    await _repository.save(pending);

    // Notify user via local Android notification
    await _showNotification(
      title: tx.isDuplicate ? 'Possible Duplicate SMS' : 'Bank Transaction Detected',
      body: '${tx.formattedAmount} • ${tx.title ?? bankTitle}',
      payload: pending.id,
    );

    return pending;
  }

  /// Scans recent messages from the phone's SMS inbox, parses transactions,
  /// detects any duplicates of the same message or existing records, and stages them for review.
  ///
  /// Returns the number of transactions staged.
  Future<int> scanInboxSms({int limit = 500}) async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        await requestPermission();
        final nowGranted = await checkPermission();
        if (!nowGranted) return 0;
      }

      final rawList = await _smsChannel.invokeMethod<List<dynamic>>(
        'getRecentSms',
        {'limit': limit},
      );

      if (rawList == null || rawList.isEmpty) return 0;

      final parsedTransactions = <ExtractedTransaction>[];
      final activeImports = await _repository.getAllActive();
      final activeFingerprints = <String>{};
      for (final pi in activeImports) {
        for (final tx in pi.extractedTransactions) {
          activeFingerprints.add(tx.normalizedFingerprint);
        }
      }

      final excludedKeywords =
          _settingsService?.loadSettings().smsExcludedKeywords;

      for (final raw in rawList) {
        if (raw is Map) {
          final address = raw['address'] as String?;
          final body = raw['body'] as String? ?? '';
          final dateMs = raw['date'] as num?;
          final date = dateMs != null
              ? DateTime.fromMillisecondsSinceEpoch(dateMs.toInt())
              : null;

          final tx = _parser.parse(
            body: body,
            sender: address,
            timestamp: date,
            excludedKeywords: excludedKeywords,
          );

          if (tx != null) {
            parsedTransactions.add(tx);
          }
        }
      }

      if (parsedTransactions.isEmpty) return 0;

      // Run duplicate check against existing database and intra-batch
      final checked =
          await _duplicateDetector.detectDuplicates(parsedTransactions);

      // Identify fingerprints that have duplicate occurrences within this batch
      final intraBatchFp = checked
          .where((tx) => tx.duplicateSource == DuplicateSource.intraBatch)
          .map((tx) => tx.normalizedFingerprint)
          .toSet();

      // Filter transactions to stage:
      // - Include new unique transactions (!tx.isDuplicate)
      // - Include intra-batch duplicates of the same message so user can review them
      // - Include the primary counterpart of an intra-batch duplicate so user can compare both
      final newToStage = checked.where((tx) {
        // Avoid re-staging items already sitting in an active pending batch (unless intra-batch duplicate)
        if (activeFingerprints.contains(tx.normalizedFingerprint) &&
            !intraBatchFp.contains(tx.normalizedFingerprint)) {
          return false;
        }

        if (!tx.isDuplicate) return true;
        if (tx.duplicateSource == DuplicateSource.intraBatch) return true;
        if (intraBatchFp.contains(tx.normalizedFingerprint)) return true;

        return false;
      }).toList();

      if (newToStage.isEmpty) return 0;

      // Group into pending imports by bank or stage as one batch
      final batchId = 'sms_scan_${DateTime.now().millisecondsSinceEpoch}';
      final duplicateCount = newToStage.where((tx) => tx.isDuplicate).length;
      final pendingBatch = PendingImport(
        id: batchId,
        imagePaths: const [],
        createdAt: DateTime.now(),
        status: PendingImportStatus.readyForReview,
        extractedTransactions: newToStage,
        source: duplicateCount > 0
            ? 'Bank SMS (${newToStage.length} detected, $duplicateCount duplicates)'
            : 'Bank SMS (${newToStage.length} detected)',
      );

      await _repository.save(pendingBatch);

      if (newToStage.isNotEmpty) {
        await _showNotification(
          title: 'Bank SMS Synced',
          body: duplicateCount > 0
              ? '${newToStage.length} transactions staged ($duplicateCount duplicate(s) for review)'
              : '${newToStage.length} new transactions staged in Inbox',
          payload: batchId,
        );
      }

      return newToStage.length;
    } catch (e) {
      debugPrint('[BankSmsService] scanInboxSms error: $e');
      return 0;
    }
  }

  /// Parses manually pasted SMS text and stages it into the Inbox for review.
  Future<PendingImport?> parseRawSmsText(String text, {DateTime? date}) async {
    final parsed = _parser.parse(
      body: text,
      timestamp: date ?? DateTime.now(),
    );

    if (parsed == null) return null;

    final checked = await _duplicateDetector.detectDuplicates([parsed]);
    final tx = checked.first;

    final importId = 'sms_paste_${DateTime.now().millisecondsSinceEpoch}';
    final bankName = tx.sourceReference ?? 'Bank';

    final pending = PendingImport(
      id: importId,
      imagePaths: const [],
      createdAt: DateTime.now(),
      status: PendingImportStatus.readyForReview,
      extractedTransactions: [tx],
      source: 'Pasted SMS: $bankName',
    );

    await _repository.save(pending);
    return pending;
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _notificationChannel.invokeMethod('showNotification', {
        'id': 2001,
        'title': title,
        'body': body,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('[BankSmsService] Error showing notification: $e');
    }
  }
}
