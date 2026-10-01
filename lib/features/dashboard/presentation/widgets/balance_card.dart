import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../analysis/domain/entities/analysis_data.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Prominent gradient Balance Card featuring Net Balance / Cash Flow,
/// period comparison badge, and embedded Income/Expense breakdown.
class BalanceCard extends ConsumerWidget {
  final int netCashFlowMinor;
  final int incomeMinor;
  final int expenseMinor;
  final PeriodComparison? comparison;

  const BalanceCard({
    super.key,
    required this.netCashFlowMinor,
    this.incomeMinor = 0,
    this.expenseMinor = 0,
    this.comparison,
  });

  /// Backward-compatible constructor
  factory BalanceCard.legacy({
    Key? key,
    required int totalBalanceMinorUnits,
    required double monthlyChangePercentage,
  }) {
    return BalanceCard(
      key: key,
      netCashFlowMinor: totalBalanceMinorUnits,
      comparison: PeriodComparison(
        prevTotalIncomeMinor: 0,
        prevTotalExpenseMinor: 0,
        expensePercentageChange: monthlyChangePercentage,
        expenseComparisonText: '${monthlyChangePercentage.toStringAsFixed(0)}% this month',
        isExpenseHigher: monthlyChangePercentage > 0,
        isRoughlyUnchanged: monthlyChangePercentage.abs() < 1.0,
        hasPreviousData: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(appAccentColorProvider);
    final rounding = ref.watch(appCardRoundingProvider);
    final cardRadius = BorderRadius.circular((rounding.radius * 1.3).clamp(12.0, 32.0));

    final isNegative = netCashFlowMinor < 0;
    final formattedBalance = MoneyUtils.formatMinorUnits(
      netCashFlowMinor.abs(),
      currency: 'INR',
      symbol: '₹',
    );
    final formattedIncome = MoneyUtils.formatMinorUnits(
      incomeMinor,
      currency: 'INR',
      symbol: '₹',
    );
    final formattedExpense = MoneyUtils.formatMinorUnits(
      expenseMinor,
      currency: 'INR',
      symbol: '₹',
    );

    final comp = comparison;
    String badgeText = 'No previous data';
    IconData? badgeIcon;

    if (comp != null && comp.hasPreviousData) {
      badgeText = comp.expenseComparisonText;
      if (comp.expensePercentageChange != null && !comp.isRoughlyUnchanged) {
        badgeIcon = comp.isExpenseHigher
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: accent.gradient,
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: accent.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          children: [
            // Background Decorative Wave Custom Painter
            Positioned.fill(child: CustomPaint(painter: _TrendCurvePainter())),

            // Content Container
            Padding(
              padding: AppSpacing.padding24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightLavender,
                          letterSpacing: 0.2,
                        ),
                      ),

                      // Period Comparison Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.18),
                          borderRadius: AppSpacing.borderRadiusPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badgeIcon != null) ...[
                              Icon(
                                badgeIcon,
                                size: 12,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Big Financial Net Amount
                  Text(
                    '${isNegative ? '-' : ''}$formattedBalance',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider Line
                  Container(
                    height: 1,
                    color: AppColors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 14),

                  // Income & Expenses Split Sub-row
                  Row(
                    children: [
                      // Income Column
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.south_west_rounded,
                                size: 14,
                                color: AppColors.successGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Income',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.lightLavender,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  formattedIncome,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Expenses Column
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.north_east_rounded,
                                size: 14,
                                color: AppColors.errorRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.lightLavender,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  formattedExpense,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for background decorative wave curve.
class _TrendCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.9,
      size.width * 0.65,
      size.height * 0.3,
      size.width,
      size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
