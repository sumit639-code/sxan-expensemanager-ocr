import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

/// Row of 4 quick action buttons (Expense, Income, Import, Insights).
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: 'Expense',
          icon: Icons.remove_rounded,
          onTap: () => context.push('/add?type=expense'),
        ),
        _ActionButton(
          label: 'Income',
          icon: Icons.add_rounded,
          onTap: () => context.push('/add?type=income'),
        ),
        _ActionButton(
          label: 'Import',
          icon: Icons.document_scanner_rounded,
          isHighlight: true,
          onTap: () => context.push('/import'),
        ),
        _ActionButton(
          label: 'Insights',
          icon: Icons.bar_chart_rounded,
          onTap: () => context.push('/insights'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlight;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    final gradient = LinearGradient(
      colors: [primaryColor, secondaryColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    BorderRadius buttonRadius = const BorderRadius.all(Radius.circular(16));
    final cardShape = theme.cardTheme.shape;
    if (cardShape is RoundedRectangleBorder) {
      final radius = cardShape.borderRadius.resolve(Directionality.maybeOf(context));
      buttonRadius = BorderRadius.circular((radius.topLeft.x * 0.75).clamp(8.0, 20.0));
    }

    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final bg = isHighlight ? gradient : null;

    final containerColor = isHighlight
        ? null
        : (isDark ? AppColors.darkSurface : AppColors.white);

    final border = isHighlight
        ? null
        : Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          );

    final iconColor = isHighlight ? AppColors.white : primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: buttonRadius,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: bg,
                color: containerColor,
                border: border,
                borderRadius: buttonRadius,
                boxShadow: isHighlight
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }
}
