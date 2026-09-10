import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';

/// Modal bottom sheet allowing inline correction of an extracted transaction.
class EditExtractedTransactionSheet extends StatefulWidget {
  final ExtractedTransaction transaction;
  final ValueChanged<ExtractedTransaction> onSave;
  final VoidCallback onDelete;

  const EditExtractedTransactionSheet({
    super.key,
    required this.transaction,
    required this.onSave,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required ExtractedTransaction transaction,
    required ValueChanged<ExtractedTransaction> onSave,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditExtractedTransactionSheet(
        transaction: transaction,
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

  final List<String> _categories = [
    'food',
    'transport',
    'shopping',
    'groceries',
    'entertainment',
    'bills',
    'health',
    'income',
    'other',
  ];

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
    final amountMinor = (parsedDecimal * 100).round();

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                  ),
                  tooltip: 'Delete transaction',
                  onPressed: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Toggle (Expense / Income)
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Expense',
                    isSelected: _type == TransactionType.expense,
                    color: AppColors.primaryPurple,
                    onTap: () =>
                        setState(() => _type = TransactionType.expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    label: 'Income',
                    isSelected: _type == TransactionType.income,
                    color: AppColors.successGreen,
                    onTap: () => setState(() => _type = TransactionType.income),
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
              children: _categories.map((cat) {
                final isSelected = _categoryId == cat;
                return ChoiceChip(
                  label: Text(_capitalize(cat)),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _categoryId = val ? cat : null);
                  },
                  selectedColor: AppColors.primaryPurple.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryPurple
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
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save Action Button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusMedium,
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
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
