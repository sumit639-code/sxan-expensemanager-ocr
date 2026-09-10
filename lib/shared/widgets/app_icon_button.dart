import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Reusable icon button respecting the minimum touch target requirement (~44px).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final defaultBg =
        backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant);

    final button = Material(
      color: defaultBg,
      borderRadius: AppSpacing.borderRadiusMedium,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.borderRadiusMedium,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          alignment: Alignment.center,
          padding: AppSpacing.padding8,
          child: Icon(
            icon,
            size: 22,
            color: onPressed == null ? AppColors.gray500 : defaultIconColor,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
