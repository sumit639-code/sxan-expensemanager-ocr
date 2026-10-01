import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';
import 'screenshot_viewer_modal.dart';

/// List tile representing an extracted transaction during review.
///
/// Supports selection checkbox, tap-to-edit, low-confidence warning,
/// duplicate indicators with Keep/Skip quick actions, debug raw OCR viewer in debug mode, and deletion.
class ExtractedTransactionTile extends StatelessWidget {
  final ExtractedTransaction transaction;
  final bool isSelected;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onKeepDuplicate;
  final VoidCallback? onSkipDuplicate;
  final VoidCallback? onViewScreenshot;

  const ExtractedTransactionTile({
    super.key,
    required this.transaction,
    required this.isSelected,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    this.onKeepDuplicate,
    this.onSkipDuplicate,
    this.onViewScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type == TransactionType.income;

    final displayTitle = (transaction.merchant?.trim().isNotEmpty == true)
        ? transaction.merchant!
        : (transaction.title?.trim().isNotEmpty == true
              ? transaction.title!
              : 'Unlabeled Transaction');

    final displayDate = transaction.date != null
        ? DateFormat('MMM d').format(transaction.date!)
        : 'No date';

    final categoryLabel = transaction.categoryId != null
        ? _capitalize(transaction.categoryId!)
        : 'Uncategorized';

    final formattedAmount = transaction.amount != null
        ? MoneyUtils.formatMinorUnits(
            transaction.amount!,
            currency: transaction.currency,
          )
        : '₹ --';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: AppSpacing.borderRadiusMedium,
        border: Border.all(
          color: transaction.isDuplicate
              ? Colors.amber.withValues(alpha: 0.6)
              : (isSelected
                    ? AppColors.primaryPurple.withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          width: transaction.isDuplicate || isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.primaryPurple.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Duplicate Warning Banner (if duplicate)
          if (transaction.isDuplicate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      transaction.duplicateSource == DuplicateSource.intraBatch
                          ? 'Possible duplicate (in this batch)'
                          : 'Possible duplicate',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[300] : Colors.amber[900],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: isSelected ? onSkipDuplicate : onKeepDuplicate,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        isSelected ? 'Skip' : 'Import anyway',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.errorRed
                              : AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Tile Content
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                children: [
                  // Checkbox with accessible, comfortable 44x44 touch target
                  Semantics(
                    label: 'Select $displayTitle, $formattedAmount',
                    checked: isSelected,
                    button: true,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle(!isSelected);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: onToggle,
                          activeColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Category/Merchant Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColors.successGreen.withValues(alpha: 0.12)
                          : AppColors.primaryPurple.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusMedium,
                    ),
                    child: Icon(
                      _getCategoryIcon(transaction.categoryId, isIncome),
                      size: 20,
                      color: isIncome
                          ? AppColors.successGreen
                          : AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, Category & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_buildConfidenceBadge(isDark) != null) ...[
                              const SizedBox(width: 6),
                              _buildConfidenceBadge(isDark)!,
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.gray600,
                              ),
                            ),
                            const Text(
                              ' · ',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                            Text(
                              isIncome ? 'Income' : 'Expense',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.gray600,
                              ),
                            ),
                            if (categoryLabel != 'Uncategorized') ...[
                              const Text(
                                ' · ',
                                style: TextStyle(color: AppColors.gray400),
                              ),
                              Flexible(
                                child: Text(
                                  categoryLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.gray500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (transaction.warnings.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: transaction.warnings.map((w) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 10,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      w,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.amber[300]
                                            : Colors.amber[900],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Amount & Edit hint
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isIncome ? '+' : ''}$formattedAmount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isIncome
                              ? AppColors.successGreen
                              : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onViewScreenshot != null ||
                              (transaction.sourceReference != null &&
                                  File(transaction.sourceReference!).existsSync())) ...[
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                if (onViewScreenshot != null) {
                                  onViewScreenshot!();
                                } else if (transaction.sourceReference != null) {
                                  ScreenshotViewerModal.show(
                                    context,
                                    imagePaths: [transaction.sourceReference!],
                                    title: displayTitle,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_search_rounded,
                                      size: 13,
                                      color: AppColors.primaryPurple,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Receipt',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (transaction.note != null && transaction.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : AppColors.gray100.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.gray600,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Note / Full Message',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.note!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark
                                  ? AppColors.darkTextPrimary.withValues(alpha: 0.95)
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Development-Only Debug Expansion for OCR inspection
          if (kDebugMode &&
              transaction.rawText != null &&
              transaction.rawText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : AppColors.gray100,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.gray200,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    size: 12,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'OCR Conf: ${(transaction.confidence * 100).toInt()}% · Ref: ${transaction.sourceReference ?? "img"}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () =>
                        _showRawOcrDialog(context, transaction, isDark),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Inspect OCR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildConfidenceBadge(bool isDark) {
    if (transaction.confidence <= 0.60 || transaction.needsReview || transaction.amount == null || transaction.date == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Needs review',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.amber,
          ),
        ),
      );
    } else if (transaction.confidence < 0.85) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Review suggested',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.lightLavender : AppColors.primaryPurple,
          ),
        ),
      );
    }
    return null;
  }

  static void _showRawOcrDialog(
    BuildContext context,
    ExtractedTransaction tx,
    bool isDark,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'OCR Debug Inspection: ${tx.merchant ?? tx.title ?? "Item"}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confidence: ${(tx.confidence * 100).toStringAsFixed(1)}% (${tx.confidenceLabel})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Source Image: ${tx.sourceReference ?? "N/A"}',
                style: const TextStyle(fontSize: 12, color: AppColors.gray600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Raw OCR Lines:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.gray100,
                  borderRadius: AppSpacing.borderRadiusSmall,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  ),
                ),
                child: SelectableText(
                  tx.rawText ?? 'No raw text available.',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static IconData _getCategoryIcon(String? categoryId, bool isIncome) {
    if (isIncome) return Icons.arrow_downward_rounded;
    switch (categoryId?.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'health':
        return Icons.medical_services_outlined;
      default:
        return Icons.credit_card_rounded;
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
