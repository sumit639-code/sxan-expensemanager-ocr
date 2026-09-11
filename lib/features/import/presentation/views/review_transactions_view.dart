import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../widgets/edit_extracted_transaction_sheet.dart';
import '../widgets/extracted_transaction_tile.dart';

/// Screen allowing the user to review, edit, select/deselect, and confirm extracted transactions.
class ReviewTransactionsView extends StatelessWidget {
  final List<ExtractedTransaction> transactions;
  final Set<String> selectedIds;
  final List<String> failedImages;
  final List<String> errors;
  final String? debugOcrText;
  final ValueChanged<String> onToggleTransaction;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<ExtractedTransaction> onUpdateTransaction;
  final ValueChanged<String> onDeleteTransaction;
  final ValueChanged<String> onKeepDuplicate;
  final ValueChanged<String> onSkipDuplicate;
  final VoidCallback onConfirmImport;
  final VoidCallback onRetry;
  final VoidCallback onChooseDifferentScreenshots;

  const ReviewTransactionsView({
    super.key,
    required this.transactions,
    required this.selectedIds,
    required this.failedImages,
    required this.errors,
    this.debugOcrText,
    required this.onToggleTransaction,
    required this.onToggleSelectAll,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    required this.onKeepDuplicate,
    required this.onSkipDuplicate,
    required this.onConfirmImport,
    required this.onRetry,
    required this.onChooseDifferentScreenshots,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = transactions.length;
    final selectedCount = selectedIds.length;
    final isAllSelected = totalCount > 0 && selectedCount == totalCount;

    // Calculate total amount for selected transactions
    int selectedTotalMinor = 0;
    for (final tx in transactions) {
      if (selectedIds.contains(tx.id) && tx.amount != null) {
        selectedTotalMinor += tx.amount!;
      }
    }

    final formattedTotal = MoneyUtils.formatMinorUnits(selectedTotalMinor);

    // Empty State: No transactions found
    if (totalCount == 0) {
      return _buildEmptyState(context, isDark);
    }

    final needsReviewCount = transactions.where((tx) =>
      tx.confidence <= 0.85 ||
      tx.isDuplicate ||
      tx.amount == null ||
      tx.date == null
    ).length;

    return Column(
      children: [
        // Summary Header & Select All Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review transactions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$totalCount ${totalCount == 1 ? 'transaction' : 'transactions'} · $selectedCount selected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (kDebugMode &&
                          (debugOcrText != null || transactions.isNotEmpty))
                        IconButton(
                          icon: const Icon(Icons.bug_report_outlined, size: 20),
                          tooltip: 'Debug Inspector',
                          onPressed: () =>
                              _showDebugExtractionSheet(context, isDark),
                        ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToggleSelectAll();
                        },
                        borderRadius: AppSpacing.borderRadiusMedium,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withValues(
                              alpha: isAllSelected ? 0.15 : 0.08,
                            ),
                            borderRadius: AppSpacing.borderRadiusMedium,
                            border: Border.all(
                              color: AppColors.primaryPurple.withValues(
                                alpha: isAllSelected ? 0.4 : 0.2,
                              ),
                            ),
                          ),
                          child: Text(
                            isAllSelected ? 'Deselect all' : 'Select all',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Contextual Warning Banner: Transactions needing review
        if (needsReviewCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: AppSpacing.borderRadiusMedium,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$needsReviewCount ${needsReviewCount == 1 ? 'transaction needs' : 'transactions need'} review',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Partial Failure Banner (if any screenshot failed)
        if (failedImages.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusMedium,
              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.errorRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${failedImages.length} ${failedImages.length == 1 ? 'screenshot' : 'screenshots'} could not be processed.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.red[300] : AppColors.errorRed,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onRetry();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

        // Transaction List with Dismissible Swipe-to-delete
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isSelected = selectedIds.contains(tx.id);

              return Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.errorRed,
                    borderRadius: AppSpacing.borderRadiusLarge,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  HapticFeedback.mediumImpact();
                  onDeleteTransaction(tx.id);
                },
                child: ExtractedTransactionTile(
                  transaction: tx,
                  isSelected: isSelected,
                  onToggle: (_) {
                    HapticFeedback.selectionClick();
                    onToggleTransaction(tx.id);
                  },
                  onTap: () {
                    EditExtractedTransactionSheet.show(
                      context,
                      transaction: tx,
                      onSave: onUpdateTransaction,
                      onDelete: () => onDeleteTransaction(tx.id),
                    );
                  },
                  onDelete: () => onDeleteTransaction(tx.id),
                  onKeepDuplicate: () {
                    HapticFeedback.selectionClick();
                    onKeepDuplicate(tx.id);
                  },
                  onSkipDuplicate: () {
                    HapticFeedback.selectionClick();
                    onSkipDuplicate(tx.id);
                  },
                ),
              );
            },
          ),
        ),

        // Bottom Sticky Action Button with Selected Total
        Container(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: AppSpacing.navPillClearance,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.gray600,
                      ),
                    ),
                    Text(
                      formattedTotal,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCount > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            onConfirmImport();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.gray300,
                      disabledForegroundColor: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray500,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusMedium,
                      ),
                      elevation: selectedCount > 0 ? 3 : 0,
                    ),
                    child: Text(
                      selectedCount > 0
                          ? 'Import $selectedCount ${selectedCount == 1 ? 'transaction' : 'transactions'}'
                          : 'Import 0 transactions',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final bool isConnectionError = errors.any(
      (e) =>
          e.toLowerCase().contains("connect") ||
          e.toLowerCase().contains("server"),
    );
    final bool isOcrEmpty = errors.any(
      (e) => e.toLowerCase().contains("couldn't read text"),
    );

    String title = "No transactions found";
    String message =
        "No recognizable transactions were found. You can try another screenshot.";

    if (isConnectionError) {
      title = "OCR Service Offline";
      message = errors.firstWhere(
        (e) =>
            e.toLowerCase().contains("connect") ||
            e.toLowerCase().contains("server"),
        orElse: () => "Couldn't connect to the Python OCR service.",
      );
    } else if (isOcrEmpty) {
      title = "Couldn't read text";
      message =
          "Couldn't read text from this screenshot. Please ensure the image is clear and not blurry.";
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 32,
          right: 32,
          top: 32,
          bottom: AppSpacing.navPillClearance,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isConnectionError
                    ? Icons.wifi_off_rounded
                    : isOcrEmpty
                        ? Icons.text_snippet_outlined
                        : Icons.search_off_rounded,
                size: 48,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusMedium,
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onChooseDifferentScreenshots,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusMedium,
                    ),
                  ),
                  child: const Text('Choose Different'),
                ),
              ],
            ),
            if (kDebugMode &&
                debugOcrText != null &&
                debugOcrText!.isNotEmpty) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => _showDebugExtractionSheet(context, isDark),
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Inspect OCR & Parsing (Debug)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDebugExtractionSheet(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Debug Extraction Inspector',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• OCR Engine: Local transaction_ocr_flutter (RapidOCR ONNX)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        SizedBox(height: 2),
                        Text('• Model Version: v1.0.0 (det_v1.onnx / rec_v1.onnx)', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 2),
                        Text('• Rules Version: v1.0.0 (rules_manifest.json)', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 2),
                        Text('• Status: 100% Offline (On-Device)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),

                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OCR EXTRACTIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Text('----------------------------------------'),

                  SelectableText(
                    debugOcrText ?? '(No OCR text captured)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DETECTED TRANSACTIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Text('----------------------------------------'),
                  if (transactions.isEmpty)
                    const Text(
                      '(None detected)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    )
                  else
                    ...transactions.map(
                      (tx) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${tx.merchant ?? tx.title} | ${tx.formattedAmount} (${tx.type.name})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
