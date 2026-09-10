import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/transaction_filter.dart';

/// Modal bottom sheet providing granular filtering and sorting options for transactions.
class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilter initialFilter;
  final ValueChanged<TransactionFilter> onApply;

  const TransactionFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<TransactionFilter?> show(
    BuildContext context, {
    required TransactionFilter currentFilter,
  }) {
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFilterSheet(
        initialFilter: currentFilter,
        onApply: (newFilter) {
          Navigator.of(ctx).pop(newFilter);
        },
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionType? _selectedType;
  late DateFilterPreset _selectedDatePreset;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  late String? _selectedCategoryId;
  late AmountFilterPreset _selectedAmountPreset;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TransactionSource? _selectedSource;
  late TransactionSortOrder _selectedSortOrder;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialFilter.type;
    _selectedDatePreset = widget.initialFilter.datePreset;
    _customStartDate = widget.initialFilter.customStartDate;
    _customEndDate = widget.initialFilter.customEndDate;
    _selectedCategoryId = widget.initialFilter.categoryId;
    _selectedAmountPreset = widget.initialFilter.amountPreset;
    _selectedSource = widget.initialFilter.source;
    _selectedSortOrder = widget.initialFilter.sortOrder;

    final minMajor = widget.initialFilter.customMinAmountMinor != null
        ? (widget.initialFilter.customMinAmountMinor! / 100).toStringAsFixed(0)
        : '';
    final maxMajor = widget.initialFilter.customMaxAmountMinor != null
        ? (widget.initialFilter.customMaxAmountMinor! / 100).toStringAsFixed(0)
        : '';
    _minAmountController = TextEditingController(text: minMajor);
    _maxAmountController = TextEditingController(text: maxMajor);
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedType = null;
      _selectedDatePreset = DateFilterPreset.all;
      _customStartDate = null;
      _customEndDate = null;
      _selectedCategoryId = null;
      _selectedAmountPreset = AmountFilterPreset.all;
      _minAmountController.clear();
      _maxAmountController.clear();
      _selectedSource = null;
      _selectedSortOrder = TransactionSortOrder.newestFirst;
    });
  }

  void _apply() {
    int? customMin;
    int? customMax;
    if (_selectedAmountPreset == AmountFilterPreset.custom) {
      final minVal = double.tryParse(_minAmountController.text.trim());
      final maxVal = double.tryParse(_maxAmountController.text.trim());
      if (minVal != null) customMin = (minVal * 100).round();
      if (maxVal != null) customMax = (maxVal * 100).round();
    }

    final newFilter = widget.initialFilter.copyWith(
      type: _selectedType,
      clearType: _selectedType == null,
      datePreset: _selectedDatePreset,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
      clearCustomDates: _selectedDatePreset != DateFilterPreset.custom,
      categoryId: _selectedCategoryId,
      clearCategory: _selectedCategoryId == null,
      amountPreset: _selectedAmountPreset,
      customMinAmountMinor: customMin,
      customMaxAmountMinor: customMax,
      clearCustomAmounts: _selectedAmountPreset != AmountFilterPreset.custom,
      source: _selectedSource,
      clearSource: _selectedSource == null,
      sortOrder: _selectedSortOrder,
    );

    widget.onApply(newFilter);
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_customStartDate != null && _customEndDate != null)
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDatePreset = DateFilterPreset.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final allCategories = [
      ...CategoryConstants.expenseCategories,
      ...CategoryConstants.incomeCategories,
    ];
    // deduplicate by id
    final uniqueCategories = <String, String>{};
    for (final c in allCategories) {
      uniqueCategories[c.id] = c.name;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.tune_rounded, size: 20, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filter Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: secondaryTextColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Filter Sections
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Transaction Type
                  _buildSectionTitle('TRANSACTION TYPE', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSelectableChip(
                        label: 'All Types',
                        isSelected: _selectedType == null,
                        onTap: () => setState(() => _selectedType = null),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                      _buildSelectableChip(
                        label: 'Expenses',
                        isSelected: _selectedType == TransactionType.expense,
                        onTap: () => setState(() => _selectedType = TransactionType.expense),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                      _buildSelectableChip(
                        label: 'Income',
                        isSelected: _selectedType == TransactionType.income,
                        onTap: () => setState(() => _selectedType = TransactionType.income),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Date Range
                  _buildSectionTitle('DATE PERIOD', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in DateFilterPreset.values)
                        if (preset != DateFilterPreset.custom)
                          _buildSelectableChip(
                            label: preset.label,
                            isSelected: _selectedDatePreset == preset,
                            onTap: () => setState(() => _selectedDatePreset = preset),
                            primaryColor: primaryColor,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textColor: textColor,
                          ),
                      _buildSelectableChip(
                        label: _selectedDatePreset == DateFilterPreset.custom &&
                                _customStartDate != null &&
                                _customEndDate != null
                            ? '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}'
                            : 'Custom Range...',
                        isSelected: _selectedDatePreset == DateFilterPreset.custom,
                        icon: Icons.date_range_rounded,
                        onTap: _pickCustomDateRange,
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Category
                  _buildSectionTitle('CATEGORY', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSelectableChip(
                        label: 'All Categories',
                        isSelected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                      for (final entry in uniqueCategories.entries)
                        _buildSelectableChip(
                          label: entry.value,
                          isSelected: _selectedCategoryId == entry.key,
                          onTap: () => setState(() => _selectedCategoryId = entry.key),
                          primaryColor: primaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textColor: textColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Amount Range
                  _buildSectionTitle('AMOUNT', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in AmountFilterPreset.values)
                        if (preset != AmountFilterPreset.custom)
                          _buildSelectableChip(
                            label: preset.label,
                            isSelected: _selectedAmountPreset == preset,
                            onTap: () => setState(() => _selectedAmountPreset = preset),
                            primaryColor: primaryColor,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textColor: textColor,
                          ),
                      _buildSelectableChip(
                        label: 'Custom Range',
                        isSelected: _selectedAmountPreset == AmountFilterPreset.custom,
                        onTap: () => setState(() => _selectedAmountPreset = AmountFilterPreset.custom),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                    ],
                  ),
                  if (_selectedAmountPreset == AmountFilterPreset.custom) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minAmountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Min (₹)',
                              labelStyle: TextStyle(color: secondaryTextColor, fontSize: 12),
                              filled: true,
                              fillColor: surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('to', style: TextStyle(color: secondaryTextColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxAmountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Max (₹)',
                              labelStyle: TextStyle(color: secondaryTextColor, fontSize: 12),
                              filled: true,
                              fillColor: surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 5. Source
                  _buildSectionTitle('TRANSACTION SOURCE', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSelectableChip(
                        label: 'All Sources',
                        isSelected: _selectedSource == null,
                        onTap: () => setState(() => _selectedSource = null),
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                      ),
                      for (final src in TransactionSource.values)
                        _buildSelectableChip(
                          label: src.value.toUpperCase(),
                          isSelected: _selectedSource == src,
                          onTap: () => setState(() => _selectedSource = src),
                          primaryColor: primaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textColor: textColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 6. Sort Order
                  _buildSectionTitle('SORT BY', secondaryTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sort in TransactionSortOrder.values)
                        _buildSelectableChip(
                          label: sort.label,
                          isSelected: _selectedSortOrder == sort,
                          onTap: () => setState(() => _selectedSortOrder = sort),
                          primaryColor: primaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textColor: textColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Text(
                      'Reset All',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : surfaceColor,
          borderRadius: AppSpacing.borderRadiusPill,
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : primaryColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
