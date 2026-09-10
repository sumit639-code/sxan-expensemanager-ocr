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
                        'Review Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Check details before adding to your account',
                        style: TextStyle(
                          fontSize: 12,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: AppSpacing.borderRadiusMedium,
                        ),
                        child: Text(
                          formattedTotal,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Select All Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onToggleSelectAll();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isAllSelected,
                          onChanged: (_) {
                            HapticFeedback.selectionClick();
                            onToggleSelectAll();
                          },
                          activeColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Text(
                          'Select all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$selectedCount of $totalCount selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Partial Failure Banner (if any screenshot failed)
        if (failedImages.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.amber.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$totalCount ${totalCount == 1 ? 'transaction' : 'transactions'} found. ${failedImages.length} ${failedImages.length == 1 ? 'screenshot' : 'screenshots'} could not be read.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.amber[300] : Colors.amber[900],
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

        // Transaction List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isSelected = selectedIds.contains(tx.id);

              return ExtractedTransactionTile(
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
              );
            },
          ),
        ),

        // Bottom Sticky Action Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            child: SizedBox(
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMedium,
                  ),
                  elevation: selectedCount > 0 ? 3 : 0,
                ),
                child: Text(
                  selectedCount > 0
                      ? 'Add $selectedCount ${selectedCount == 1 ? 'transaction' : 'transactions'}'
                      : 'Add transactions',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
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
