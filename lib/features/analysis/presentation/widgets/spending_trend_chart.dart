import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/features/analysis/domain/entities/analysis_data.dart';

/// Interactive financial spending trend chart adapting to the selected analysis period.
class SpendingTrendChart extends StatefulWidget {
  final List<TrendBucket> buckets;

  const SpendingTrendChart({super.key, required this.buckets});

  @override
  State<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends State<SpendingTrendChart> {
  int? _selectedBucketIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (widget.buckets.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          'No activity in this period',
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
      );
    }

    final maxExpenseMinor = widget.buckets.fold<int>(
      0,
      (prev, b) => math.max(prev, b.expenseMinor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Bar Tooltip Info
        if (_selectedBucketIndex != null &&
            _selectedBucketIndex! < widget.buckets.length) ...[
          Builder(
            builder: (context) {
              final b = widget.buckets[_selectedBucketIndex!];
              final amountMajor = (b.expenseMinor / 100).toStringAsFixed(0);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${b.label}: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    Text(
                      '₹$amountMajor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Chart Bar Canvas
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final bucketCount = widget.buckets.length;
              final maxBarWidth = math.min(
                (availableWidth / bucketCount) * 0.65,
                32.0,
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < widget.buckets.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final b = widget.buckets[i];
                        final isSelected = _selectedBucketIndex == i;
                        final ratio = maxExpenseMinor > 0
                            ? (b.expenseMinor / maxExpenseMinor).clamp(0.0, 1.0)
                            : 0.0;
                        final barHeight = math.max(ratio * 110, 4.0);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedBucketIndex = isSelected ? null : i;
                            });
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Bar Container
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: maxBarWidth,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isSelected
                                        ? [
                                            primaryColor,
                                            primaryColor.withValues(alpha: 0.7),
                                          ]
                                        : [
                                            b.expenseMinor > 0
                                                ? primaryColor.withValues(
                                                    alpha: 0.85,
                                                  )
                                                : (isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.lightBorder),
                                            b.expenseMinor > 0
                                                ? primaryColor.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : (isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.lightBorder),
                                          ],
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: primaryColor.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // X-Axis Label
                              SizedBox(
                                width: maxBarWidth + 12,
                                child: Text(
                                  b.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
