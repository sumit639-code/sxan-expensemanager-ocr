import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../analysis/domain/entities/analysis_period.dart';

/// Header widget rendering a time-adaptive greeting, user avatar,
/// and interactive period selector.
class DashboardHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onAvatarPressed;
  final AnalysisPeriod? selectedPeriod;
  final VoidCallback? onPeriodPressed;

  const DashboardHeader({
    super.key,
    this.userName = 'Alex',
    this.onAvatarPressed,
    this.selectedPeriod,
    this.onPeriodPressed,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  String _getPeriodSubtitle(AnalysisPeriod period) {
    switch (period.type) {
      case AnalysisPeriodType.today:
        return DateFormat('EEEE, d MMM').format(period.startDate);
      case AnalysisPeriodType.thisWeek:
        final startFmt = DateFormat('d MMM').format(period.startDate);
        final endFmt = DateFormat('d MMM').format(period.endDate);
        return '$startFmt – $endFmt';
      case AnalysisPeriodType.thisMonth:
      case AnalysisPeriodType.lastMonth:
        return DateFormat('MMMM yyyy').format(period.startDate);
      case AnalysisPeriodType.last3Months:
        final startFmt = DateFormat('MMM').format(period.startDate);
        final endFmt = DateFormat('MMM yyyy').format(period.endDate);
        return '$startFmt – $endFmt';
      case AnalysisPeriodType.thisYear:
        return DateFormat('yyyy').format(period.startDate);
      case AnalysisPeriodType.custom:
        final startFmt = DateFormat('d MMM').format(period.startDate);
        final endFmt = DateFormat('d MMM yyyy').format(period.endDate);
        return '$startFmt – $endFmt';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()} $userName 👋',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Small steps. Bigger freedom.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),

            // Circular Avatar Button
            Material(
              color: AppColors.primaryPurple,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAvatarPressed,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Period Selector Bar
        if (selectedPeriod != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _getPeriodSubtitle(selectedPeriod!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              InkWell(
                borderRadius: AppSpacing.borderRadiusPill,
                onTap: onPeriodPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusPill,
                    border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedPeriod!.displayLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
