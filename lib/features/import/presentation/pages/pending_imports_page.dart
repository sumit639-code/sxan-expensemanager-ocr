import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/pending_import.dart';
import '../providers/import_providers.dart';
import '../providers/pending_import_providers.dart';

/// Screen displaying all staged Pending Imports received via Android Share Target or background imports.
class PendingImportsPage extends ConsumerWidget {
  const PendingImportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(activePendingImportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Imports'),
      ),
      body: asyncPending.when(
        data: (imports) {
          if (imports.isEmpty) {
            return _buildEmptyState(context, isDark);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            itemCount: imports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = imports[index];
              return _PendingImportCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading pending imports: $err'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
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
              'No Pending Imports',
              style: AppTypography.titleLarge.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share payment screenshots directly to SXAN from Google Pay, PhonePe, or your gallery to review them here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
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

          // Middle: Image thumbnail + Information
          Row(
            children: [
              if (item.imagePaths.isNotEmpty && File(item.imagePaths.first).existsSync()) ...[
                ClipRRect(
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
                            ? 'Analyzing ${item.imagePaths.length} screenshots with on-device OCR...'
                            : 'Analyzing screenshot with on-device OCR...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ] else if (item.isReadyForReview) ...[
                      Text(
                        item.imagePaths.length > 1
                            ? '${item.transactionCount} transaction${item.transactionCount > 1 ? 's' : ''} found across ${item.imagePaths.length} images'
                            : '${item.transactionCount} transaction${item.transactionCount > 1 ? 's' : ''} detected',
                        style: AppTypography.financialAmountSmall.copyWith(
                          color: AppColors.successGreen,
                        ),
                      ),
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
                            'Are you sure you want to discard this pending import? The screenshot and extracted transactions will be permanently deleted.',
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
                    label: 'Review & Import',
                    onPressed: () {
                      ref.read(importControllerProvider.notifier).loadPendingImport(item);
                      // Route to Review Screen
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
                const SizedBox(width: 8),
                AppButton.secondary(
                  label: 'Retry OCR',
                  onPressed: () async {
                    await ref
                        .read(shareImportServiceProvider)
                        .processSharedImages(item.imagePaths);
                    await ref.read(pendingImportRepositoryProvider).delete(item.id, cleanupImages: false);
                  },
                ),
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
