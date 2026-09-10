import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_period.dart';

/// Modal bottom sheet allowing users to select or customize the analysis time frame.
class PeriodSelectionSheet extends StatelessWidget {
  final AnalysisPeriod currentPeriod;
  final ValueChanged<AnalysisPeriod> onPeriodSelected;

  const PeriodSelectionSheet({
    super.key,
    required this.currentPeriod,
    required this.onPeriodSelected,
  });

  static Future<AnalysisPeriod?> show(
    BuildContext context, {
    required AnalysisPeriod currentPeriod,
  }) {
    return showModalBottomSheet<AnalysisPeriod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PeriodSelectionSheet(
        currentPeriod: currentPeriod,
        onPeriodSelected: (period) => Navigator.of(ctx).pop(period),
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: currentPeriod.type == AnalysisPeriodType.custom
          ? DateTimeRange(start: currentPeriod.startDate, end: currentPeriod.endDate)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );

    if (picked != null) {
      final period = AnalysisPeriod(
        type: AnalysisPeriodType.custom,
        startDate: DateTime(picked.start.year, picked.start.month, picked.start.day),
        endDate: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
      );
      onPeriodSelected(period);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = isDark ? AppColors.darkElevated : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final standardTypes = [
      AnalysisPeriodType.today,
      AnalysisPeriodType.thisWeek,
      AnalysisPeriodType.thisMonth,
      AnalysisPeriodType.lastMonth,
      AnalysisPeriodType.last3Months,
      AnalysisPeriodType.thisYear,
    ];

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Time Period',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: secondaryColor,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Standard Period Tiles
          for (final type in standardTypes) ...[
            _PeriodTile(
              label: type.label,
              isSelected: currentPeriod.type == type,
              onTap: () {
                onPeriodSelected(AnalysisPeriod.fromType(type));
              },
              primaryColor: primaryColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
            ),
            const SizedBox(height: 6),
          ],

          // Custom Range Tile
          _PeriodTile(
            label: currentPeriod.type == AnalysisPeriodType.custom
                ? 'Custom: ${DateFormat('MMM d').format(currentPeriod.startDate)} – ${DateFormat('MMM d').format(currentPeriod.endDate)}'
                : 'Custom Range...',
            isSelected: currentPeriod.type == AnalysisPeriodType.custom,
            icon: Icons.date_range_rounded,
            onTap: () => _pickCustomRange(context),
            primaryColor: primaryColor,
            textColor: textColor,
            secondaryColor: secondaryColor,
          ),
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color primaryColor;
  final Color textColor;
  final Color secondaryColor;

  const _PeriodTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    required this.primaryColor,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.12)
          : (isDark ? AppColors.darkSurface : AppColors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? primaryColor
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? primaryColor : secondaryColor,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primaryColor : textColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 20, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
