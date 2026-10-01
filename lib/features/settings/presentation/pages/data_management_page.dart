import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/export_csv_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

/// Dedicated Data Management Page displaying local storage metrics,
/// privacy assurance, JSON/CSV export options, and safe destructive data reset.
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _isExporting = false;
  bool _isClearing = false;

  Future<void> _exportJson(List<Transaction> transactions) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final exportList = transactions.map((t) => {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'currency': t.currency,
        'type': t.type.value,
        'category_id': t.categoryId,
        'date': t.date.toIso8601String(),
        'merchant': t.merchant,
        'note': t.note,
        'source': t.source.value,
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'app': 'ScanEx Expense Manager',
        'exported_at': DateTime.now().toIso8601String(),
        'total_transactions': transactions.length,
        'transactions': exportList,
      });

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/scanex_transactions_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        ref.read(soundServiceProvider).playTransactionImported();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${transactions.length} transactions to ${file.path.split('/').last.split('\\').last}'),
            action: SnackBarAction(
              label: 'Copy JSON',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(soundServiceProvider).playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv(List<Transaction> transactions) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final csvString = ExportCsvService.generateCsv(transactions);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/scanex_transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);

      if (mounted) {
        ref.read(soundServiceProvider).playTransactionImported();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported (${transactions.length} records)'),
            action: SnackBarAction(
              label: 'Copy CSV',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvString));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(soundServiceProvider).playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmClearAllData(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
            SizedBox(width: 10),
            Text('Delete all transactions?'),
          ],
        ),
        content: Text(
          'This will permanently remove your locally stored transactions ($count records). '
          'Your app preferences, appearance settings, and OCR models will remain intact.\n\n'
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearing = true);
      try {
        await ref.read(clearAllTransactionsUseCaseProvider).execute();
        if (mounted) {
          ref.read(soundServiceProvider).playButton();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All local transactions have been deleted.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ref.read(soundServiceProvider).playError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear data: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final transactionsAsync = ref.watch(watchAllTransactionsProvider);
    final transactions = transactionsAsync.valueOrNull ?? [];
    final transactionCount = transactions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. PRIVACY BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkElevated
                    : AppColors.lightSurfaceVariant,
                borderRadius: AppSpacing.borderRadiusLarge,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 22,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Offline & Private',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your transaction data is stored locally on this device. No cloud storage, tracking, or remote synchronization.',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. STORAGE & METRICS SECTION
            Text(
              'YOUR DATA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLarge,
                side: BorderSide(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Transactions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$transactionCount records stored',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    trailing: Text(
                      '$transactionCount',
                      style: AppTypography.headlineSmall.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Divider(color: borderColor, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
                        color: AppColors.successGreen,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Database Engine',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'SQLite via Drift (Encapsulated on-device)',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. EXPORT ACTIONS
            Text(
              'EXPORT DATA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLarge,
                side: BorderSide(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.code_rounded, size: 22),
                    title: const Text(
                      'Export as JSON',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Portable, structured format with all transaction fields',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    trailing: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined, size: 20),
                    onTap: _isExporting ? null : () => _exportJson(transactions),
                  ),
                  Divider(color: borderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.table_chart_outlined, size: 22),
                    title: const Text(
                      'Export as CSV',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Spreadsheet-friendly format for Excel or Google Sheets',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    trailing: const Icon(Icons.file_download_outlined, size: 20),
                    onTap: _isExporting ? null : () => _exportCsv(transactions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 4. DESTRUCTIVE ACTIONS
            const Text(
              'DANGER ZONE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLarge,
                side: BorderSide(
                  color: AppColors.errorRed.withValues(alpha: 0.3),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.errorRed,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Clear All Data',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorRed,
                  ),
                ),
                subtitle: Text(
                  'Permanently delete all locally stored transactions',
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
                trailing: _isClearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.errorRed,
                        ),
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.errorRed,
                      ),
                onTap: _isClearing || transactionCount == 0
                    ? null
                    : () => _confirmClearAllData(transactionCount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
