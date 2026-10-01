import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/pending_import.dart';
import '../providers/import_providers.dart';
import '../providers/pending_import_providers.dart';
import '../widgets/screenshot_viewer_modal.dart';

/// Screen displaying all staged Pending Imports received via Android Share Target,
/// background screenshot processing, and Bank SMS auto-detection.
class PendingImportsPage extends ConsumerWidget {
  const PendingImportsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(shareImportServiceProvider).recoverOrphanedProcessingImports(autoResume: true);
    await ref.read(pendingImportRepositoryProvider).refreshActive();
  }

  void _showSmsActionSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.gray700 : AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bank SMS Detection',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Read and parse transactions from your bank messages into the inbox for instant review.',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.travel_explore_rounded, color: AppColors.primaryPurple),
                ),
                title: const Text('Deep Scan Inbox (500 SMS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Recommended: thoroughly scans past 500 bank, UPI, and card alerts'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _scanSmsInbox(context, ref, limit: 500);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.all_inclusive_rounded, color: Colors.blue),
                ),
                title: const Text('Full History Scan (1,500+ SMS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Scans entire inbox history for all transactions (takes a few seconds)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _scanSmsInbox(context, ref, limit: 2000);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                ),
                title: const Text('Quick Scan (Latest 100 SMS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Fast check of recent incoming messages'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _scanSmsInbox(context, ref, limit: 100);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.paste_rounded, color: AppColors.successGreen),
                ),
                title: const Text('Paste Bank SMS Text', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Test or import an SMS message directly'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPasteSmsDialog(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanSmsInbox(BuildContext context, WidgetRef ref, {int limit = 500}) async {
    // Show active progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Scanning Bank Messages...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  limit >= 1000
                      ? 'Scanning your complete SMS inbox history for bank & UPI transactions. Please wait...'
                      : 'Scanning up to $limit messages for debit, credit, and UPI spends...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    int count = 0;
    try {
      count = await ref.read(bankSmsServiceProvider).scanInboxSms(limit: limit);
      await ref.read(pendingImportRepositoryProvider).refreshActive();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog
      }
    }

    if (context.mounted) {
      if (count > 0) {
        ref.read(soundServiceProvider).playImportComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $count bank transaction${count > 1 ? 's' : ''} added to Inbox!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new bank transactions found in scanned SMS messages.'),
          ),
        );
      }
    }
  }

  Future<void> _showPasteSmsDialog(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Bank SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a bank transaction SMS below:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. HDFC Bank: Rs 450.00 debited from a/c **4321 on 22-09-26 to SWIGGY...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Parse & Add to Inbox'),
          ),
        ],
      ),
    );

    if (confirmed == true && textController.text.trim().isNotEmpty && context.mounted) {
      final pending = await ref.read(bankSmsServiceProvider).parseRawSmsText(textController.text.trim());
      if (context.mounted) {
        if (pending != null) {
          ref.read(soundServiceProvider).playImportComplete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bank transaction parsed and staged in Inbox!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not detect a financial transaction in this message.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmAndAddAll(
    BuildContext context,
    WidgetRef ref,
    List<PendingImport> readyImports,
    int totalTxCount,
    int totalAmountMinor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add All Transactions?'),
        content: Text(
          'Confirm adding $totalTxCount pending transactions totaling ${MoneyUtils.formatMinorUnits(totalAmountMinor)} to your account? All ready items will be imported into SQLite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add All Now'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final count = await ref
          .read(importControllerProvider.notifier)
          .bulkConfirmPendingImports(readyImports);
      if (context.mounted) {
        ref.read(soundServiceProvider).playImportComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $count transactions!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(activePendingImportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sms_rounded),
            tooltip: 'Bank SMS Detection',
            onPressed: () => _showSmsActionSheet(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: asyncPending.when(
          data: (imports) {
            if (imports.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.75,
                  child: _buildEmptyState(context, ref, isDark),
                ),
              );
            }

            final readyImports = imports.where((e) => e.isReadyForReview).toList();
            final totalReadyTxCount = readyImports.fold<int>(
              0,
              (sum, item) => sum + item.transactionCount,
            );
            final totalReadyAmountMinor = readyImports.fold<int>(
              0,
              (sum, item) => sum + item.extractedTransactions.fold<int>(0, (tSum, tx) => tSum + (tx.amount ?? 0)),
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // Bulk Review & Add All Banner (when multiple transactions or batches are ready)
                if (totalReadyTxCount > 1 || readyImports.length > 1) ...[
                  _buildBulkActionBar(
                    context,
                    ref,
                    isDark,
                    readyImports,
                    totalReadyTxCount,
                    totalReadyAmountMinor,
                  ),
                  const SizedBox(height: 16),
                ],

                for (int i = 0; i < imports.length; i++) ...[
                  _PendingImportCard(item: imports[i]),
                  if (i < imports.length - 1) const SizedBox(height: 16),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Error loading pending imports: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    List<PendingImport> readyImports,
    int totalCount,
    int totalAmountMinor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryPurple.withValues(alpha: 0.15)
            : const Color(0xFFF3F0FF),
        borderRadius: AppSpacing.borderRadiusLarge,
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalCount ready transaction${totalCount > 1 ? 's' : ''}',
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                MoneyUtils.formatMinorUnits(totalAmountMinor),
                style: AppTypography.financialAmountSmall.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Review All ($totalCount)',
                  onPressed: () {
                    ref.read(importControllerProvider.notifier).loadMultiplePendingImports(readyImports);
                    context.push('/import');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.primary(
                  label: 'Add All ($totalCount)',
                  onPressed: () => _confirmAndAddAll(
                    context,
                    ref,
                    readyImports,
                    totalCount,
                    totalAmountMinor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : AppColors.veryLightLavender),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 40,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Inbox is Empty',
              style: AppTypography.titleLarge.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bank SMS alerts and shared payment screenshots will appear here for your review.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              label: 'Scan Bank SMS',
              onPressed: () => _showSmsActionSheet(context, ref),
            ),
            const SizedBox(height: 10),
            AppButton.outline(
              label: 'Back to Dashboard',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingImportCard extends ConsumerWidget {
  final PendingImport item;

  const _PendingImportCard({required this.item});

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM, h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hasImages = item.imagePaths.isNotEmpty && File(item.imagePaths.first).existsSync();

    final isSms = item.source.toLowerCase().contains('sms');

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppSpacing.borderRadiusLarge,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status Badge + Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(item.status),
              Text(
                _formatTime(item.createdAt),
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Middle: Image thumbnail / SMS icon + Information
          Row(
            children: [
              if (hasImages) ...[
                GestureDetector(
                  onTap: () {
                    ScreenshotViewerModal.show(
                      context,
                      imagePaths: item.imagePaths,
                      title: item.source,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.file(
                          File(item.imagePaths.first),
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                        if (item.imagePaths.length > 1)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.80),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+${item.imagePaths.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ] else ...[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isSms
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : AppColors.primaryPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSms
                          ? const Color(0xFF10B981).withValues(alpha: 0.25)
                          : AppColors.primaryPurple.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSms ? Icons.sms_rounded : Icons.account_balance_rounded,
                    color: isSms ? const Color(0xFF10B981) : AppColors.primaryPurple,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
              ],

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.imagePaths.length > 1
                          ? '${item.imagePaths.length} Screenshots Shared'
                          : item.source,
                      style: AppTypography.labelLarge.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.isProcessing) ...[
                      Text(
                        item.imagePaths.length > 1
                            ? 'Analyzing ${item.imagePaths.length} screenshots...'
                            : 'Analyzing screenshot...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ] else if (item.isReadyForReview) ...[
                      if (item.extractedTransactions.length == 1) ...[
                        Row(
                          children: [
                            Text(
                              item.extractedTransactions.first.formattedAmount,
                              style: AppTypography.financialAmountSmall.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.extractedTransactions.first.title != null) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '• ${item.extractedTransactions.first.title!}',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        Text(
                          '${item.transactionCount} transactions detected',
                          style: AppTypography.financialAmountSmall.copyWith(
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ] else if (item.isFailed) ...[
                      Text(
                        item.errorMessage ?? "Couldn't extract transaction",
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          if (item.isReadyForReview) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Discard',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Discard Import?'),
                          content: const Text(
                            'Are you sure you want to discard this pending import? Any extracted transactions will be deleted.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Discard',
                                style: TextStyle(color: AppColors.errorRed),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(pendingImportRepositoryProvider).delete(item.id);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton.primary(
                    label: item.transactionCount > 1
                        ? 'Review & Import (${item.transactionCount})'
                        : 'Review & Import',
                    onPressed: () {
                      ref.read(importControllerProvider.notifier).loadPendingImport(item);
                      context.push('/import');
                    },
                  ),
                ),
              ],
            ),
          ] else if (item.isFailed) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.text(
                  label: 'Dismiss',
                  onPressed: () async {
                    await ref.read(pendingImportRepositoryProvider).delete(item.id);
                  },
                ),
                if (item.imagePaths.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  AppButton.secondary(
                    label: 'Retry OCR',
                    onPressed: () async {
                      await ref
                          .read(shareImportServiceProvider)
                          .retryPendingImport(item.id);
                    },
                  ),
                ],
              ],
            ),
          ] else if (item.isProcessing) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                AppButton.text(
                  label: 'Discard',
                  onPressed: () async {
                    await ref.read(pendingImportRepositoryProvider).delete(item.id);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PendingImportStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case PendingImportStatus.processing:
        bg = AppColors.primaryPurple.withValues(alpha: 0.12);
        fg = AppColors.primaryPurple;
        label = 'Processing';
        icon = Icons.sync_rounded;
      case PendingImportStatus.readyForReview:
        bg = AppColors.successGreen.withValues(alpha: 0.12);
        fg = AppColors.successGreen;
        label = 'Ready to Review';
        icon = Icons.check_circle_outline_rounded;
      case PendingImportStatus.failed:
        bg = AppColors.errorRed.withValues(alpha: 0.12);
        fg = AppColors.errorRed;
        label = 'Needs Attention';
        icon = Icons.error_outline_rounded;
      case PendingImportStatus.completed:
        bg = AppColors.gray200;
        fg = AppColors.gray700;
        label = 'Completed';
        icon = Icons.done_all_rounded;
      case PendingImportStatus.discarded:
        bg = AppColors.gray200;
        fg = AppColors.gray700;
        label = 'Discarded';
        icon = Icons.delete_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
