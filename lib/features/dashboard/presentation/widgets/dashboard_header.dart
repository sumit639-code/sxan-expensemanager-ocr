import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../analysis/domain/entities/analysis_period.dart';
import '../../../import/presentation/providers/pending_import_providers.dart';

/// Header widget rendering a time-adaptive greeting, user avatar,
/// and interactive period selector.
class DashboardHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final pendingCount = ref.watch(pendingImportCountProvider);

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

            Row(
              children: [
                // Permanent Inbox Button with Red Badge on Pending
                Material(
                  color: pendingCount > 0
                      ? (isDark ? const Color(0x33EF4444) : const Color(0x1AEF4444))
                      : (isDark ? AppColors.darkSurface : AppColors.gray100),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => context.push('/imports/pending'),
                    customBorder: const CircleBorder(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: pendingCount > 0
                                  ? const Color(0xFFEF4444)
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                              width: pendingCount > 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Icon(
                            pendingCount > 0
                                ? Icons.inbox_rounded
                                : Icons.inbox_outlined,
                            size: 22,
                            color: pendingCount > 0
                                ? const Color(0xFFEF4444)
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                        if (pendingCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBackground
                                      : AppColors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

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
