import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../transactions/domain/services/category_suggestion_service.dart';
import '../../domain/entities/extracted_transaction.dart';
import 'screenshot_viewer_modal.dart';

/// Modal bottom sheet allowing inline correction of an extracted transaction.
class EditExtractedTransactionSheet extends StatefulWidget {
  final ExtractedTransaction transaction;
  final List<String> imagePaths;
  final ValueChanged<ExtractedTransaction> onSave;
  final VoidCallback onDelete;

  const EditExtractedTransactionSheet({
    super.key,
    required this.transaction,
    this.imagePaths = const [],
    required this.onSave,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required ExtractedTransaction transaction,
    List<String> imagePaths = const [],
    required ValueChanged<ExtractedTransaction> onSave,
    required VoidCallback onDelete,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditExtractedTransactionSheet(
        transaction: transaction,
        imagePaths: imagePaths,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<EditExtractedTransactionSheet> createState() =>
      _EditExtractedTransactionSheetState();
}

class _EditExtractedTransactionSheetState
    extends State<EditExtractedTransactionSheet> {
  late TextEditingController _titleController;
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  bool _userExplicitlyChangedCategory = false;

  void _onTypeChanged(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      final validCategories = CategoryConstants.getCategoriesForType(newType)
          .map((c) => c.id)
          .toSet();
      if (_categoryId != null && !validCategories.contains(_categoryId)) {
        _categoryId = null;
      }
      if (_categoryId == null && !_userExplicitlyChangedCategory) {
        final suggestion = CategorySuggestionService.suggest(
          title: _titleController.text,
          merchant: _merchantController.text,
          type: newType,
        );
        _categoryId = suggestion.categoryId;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _titleController = TextEditingController(text: tx.title ?? '');
    _merchantController = TextEditingController(text: tx.merchant ?? '');

    // Amount formatted from minor units (paise) to decimal
    final initialDecimal = tx.amount != null
        ? (tx.amount! / 100).toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: initialDecimal);

    _noteController = TextEditingController(text: tx.note ?? '');
    _type = tx.type;
    _date = tx.date ?? DateTime.now();
    _categoryId = tx.categoryId;
    if (_categoryId != null && _categoryId!.trim().isNotEmpty) {
      _userExplicitlyChangedCategory = true;
    } else {
      final suggestion = CategorySuggestionService.suggest(
        title: _titleController.text,
        merchant: _merchantController.text,
        type: _type,
      );
      _categoryId = suggestion.categoryId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    final parsedDecimal = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final amountMinor = MoneyUtils.doubleToMinorUnits(parsedDecimal);

    final updated = widget.transaction.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      merchant: _merchantController.text.trim().isNotEmpty
          ? _merchantController.text.trim()
          : null,
      amount: amountMinor > 0 ? amountMinor : null,
      type: _type,
      date: _date,
      categoryId: _categoryId,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This candidate will be removed from the import list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onDelete();
      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final refPath = widget.transaction.sourceReference;
    final availableImages = <String>[];
    if (refPath != null && File(refPath).existsSync()) {
      availableImages.add(refPath);
    }
    for (final p in widget.imagePaths) {
      if (!availableImages.contains(p) && File(p).existsSync()) {
        availableImages.add(p);
      }
    }

    return AppBottomSheet(
      title: const Text('Edit Transaction'),
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (availableImages.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.image_search_rounded,
                color: AppColors.primaryPurple,
              ),
              tooltip: 'View Original Screenshot',
              onPressed: () {
                HapticFeedback.selectionClick();
                ScreenshotViewerModal.show(
                  context,
                  imagePaths: availableImages,
                  title: widget.transaction.merchant ??
                      widget.transaction.title ??
                      'Screenshot',
                );
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.errorRed,
            ),
            tooltip: 'Delete transaction',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      maxHeightFactor: 0.90,
      autoScroll: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      bottomAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Original Screenshot quick inspection banner
          if (availableImages.isNotEmpty) ...[
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                ScreenshotViewerModal.show(
                  context,
                  imagePaths: availableImages,
                  title: widget.transaction.merchant ??
                      widget.transaction.title ??
                      'Screenshot',
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap to inspect original receipt screenshot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.open_in_full_rounded,
                      size: 14,
                      color: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Type Toggle (Expense / Income)
          Row(
            children: [
              Expanded(
                  child: _TypeButton(
                    label: 'Expense',
                    isSelected: _type == TransactionType.expense,
                    color: primaryColor,
                    onTap: () => _onTypeChanged(TransactionType.expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    label: 'Income',
                    isSelected: _type == TransactionType.income,
                    color: AppColors.successGreen,
                    onTap: () => _onTypeChanged(TransactionType.income),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                prefixStyle: TextStyle(fontWeight: FontWeight.w700),
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Merchant Input
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant / Payee',
                hintText: 'e.g. Swiggy, Uber, Starbucks',
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title / Description',
                hintText: 'e.g. Dinner, Ride to work',
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Date Picker Row
            InkWell(
              onTap: _pickDate,
              borderRadius: AppSpacing.borderRadiusMedium,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(_date)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Chips
            Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryConstants.getCategoriesForType(_type).map((cat) {
                final isSelected = _categoryId == cat.id;
                return ChoiceChip(
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      _userExplicitlyChangedCategory = true;
                      _categoryId = val ? cat.id : null;
                    });
                  },
                  selectedColor: primaryColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? primaryColor
                        : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.gray700),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Note Input
            TextField(
              controller: _noteController,
              minLines: 5,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Note / Full Message (Optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: AppSpacing.borderRadiusMedium,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
