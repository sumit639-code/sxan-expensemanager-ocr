import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';

/// Screen for creating a new transaction or editing an existing one.
class AddEditTransactionPage extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final TransactionType? initialType;

  const AddEditTransactionPage({
    super.key,
    this.initialTransaction,
    this.initialType,
  });

  @override
  ConsumerState<AddEditTransactionPage> createState() =>
      _AddEditTransactionPageState();
}

class _AddEditTransactionPageState
    extends ConsumerState<AddEditTransactionPage> {
  final _formKey = GlobalKey<FormState>();

  late TransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _merchantController;
  late TextEditingController _noteController;
  late Category _selectedCategory;
  late DateTime _selectedDate;

  bool _isSubmitting = false;
  String? _amountError;
  String? _titleError;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;

    _type = initial?.type ?? widget.initialType ?? TransactionType.expense;

    final initialAmountStr = initial != null
        ? MoneyUtils.minorUnitsToDouble(initial.amount).toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: initialAmountStr);
    _titleController = TextEditingController(text: initial?.title ?? '');
    _merchantController = TextEditingController(text: initial?.merchant ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');

    _selectedDate = initial?.date ?? DateTime.now();

    final categories = CategoryConstants.getCategoriesForType(_type);
    if (initial?.categoryId != null) {
      _selectedCategory = CategoryConstants.getCategoryById(
        initial!.categoryId,
        _type,
      );
    } else {
      _selectedCategory = categories.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType newType) {
    if (_type == newType) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = newType;
      final categories = CategoryConstants.getCategoriesForType(newType);
      _selectedCategory = categories.first;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    setState(() {
      _amountError = null;
      _titleError = null;
    });

    final amountText = _amountController.text.trim();
    final titleText = _titleController.text.trim();
    bool hasError = false;

    if (amountText.isEmpty) {
      setState(() {
        _amountError = 'Enter an amount';
      });
      hasError = true;
    } else {
      final parsed = double.tryParse(amountText);
      if (parsed == null || parsed <= 0) {
        setState(() {
          _amountError = 'Amount must be greater than ₹0';
        });
        hasError = true;
      }
    }

    if (titleText.isEmpty) {
      setState(() {
        _titleError = 'Enter a title';
      });
      hasError = true;
    }

    if (hasError) {
      return;
    }

    final parsedAmount = double.parse(amountText);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final minorUnits = MoneyUtils.doubleToMinorUnits(parsedAmount);
      final now = DateTime.now();

      final transaction = Transaction(
        id:
            widget.initialTransaction?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: _type,
        amount: minorUnits,
        currency: 'INR',
        title: titleText,
        merchant: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        categoryId: _selectedCategory.id,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        source: widget.initialTransaction?.source ?? TransactionSource.manual,
        createdAt: widget.initialTransaction?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await ref.read(updateTransactionUseCaseProvider).execute(transaction);
      } else {
        await ref.read(addTransactionUseCaseProvider).execute(transaction);
      }

      if (!mounted) return;

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Transaction updated' : 'Transaction added',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryPurple,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final categories = CategoryConstants.getCategoriesForType(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Segmented Type Selector (Expense | Income)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.veryLightLavender,
                      borderRadius: AppSpacing.borderRadiusPill,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentTab(
                            label: 'Expense',
                            isSelected: _type == TransactionType.expense,
                            activeColor: AppColors.primaryPurple,
                            onTap: () => _onTypeChanged(TransactionType.expense),
                          ),
                        ),
                        Expanded(
                          child: _SegmentTab(
                            label: 'Income',
                            isSelected: _type == TransactionType.income,
                            activeColor: AppColors.successGreen,
                            onTap: () => _onTypeChanged(TransactionType.income),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Prominent Financial Amount Input
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '₹ ',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: _type == TransactionType.income
                                    ? AppColors.successGreen
                                    : AppColors.primaryPurple,
                              ),
                            ),
                            IntrinsicWidth(
                              child: TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  border: InputBorder.none,
                                ),
                                onChanged: (_) {
                                  if (_amountError != null) {
                                    setState(() {
                                      _amountError = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_amountError != null)
                          Text(
                            _amountError!,
                            style: const TextStyle(
                              color: AppColors.errorRed,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title Input
                  AppTextField(
                    label: 'Title *',
                    hintText: 'e.g. Grocery Shopping',
                    controller: _titleController,
                    errorText: _titleError,
                    onChanged: (val) {
                      if (_titleError != null && val.trim().isNotEmpty) {
                        setState(() {
                          _titleError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Merchant / Payee (Optional)
                  AppTextField(
                    label: 'Merchant / Payee (Optional)',
                    hintText: 'e.g. Walmart',
                    controller: _merchantController,
                  ),
                  const SizedBox(height: 20),

                  // Category Selection Grid
                  Text(
                    'Category *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories.map((cat) {
                      final isSelected = cat.id == _selectedCategory.id;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryPurple
                                : (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.white),
                            borderRadius: AppSpacing.borderRadiusPill,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 16,
                                color: isSelected ? AppColors.white : cat.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.white
                                      : primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),

                // Date Picker Tile
                Text(
                  'Date *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: AppSpacing.borderRadiusMedium,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: AppSpacing.borderRadiusMedium,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Note Input (Optional)
                AppTextField(
                  label: 'Note (Optional)',
                  hintText: 'Additional details...',
                  controller: _noteController,
                ),
                const SizedBox(height: 32),

                // Submit Button
                AppButton.primary(
                  label: _isEditing
                      ? 'Save Changes'
                      : (_type == TransactionType.income
                            ? 'Add Income'
                            : 'Add Expense'),
                  isLoading: _isSubmitting,
                  onPressed: _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: AppSpacing.borderRadiusPill,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.gray500,
          ),
        ),
      ),
    );
  }
}
