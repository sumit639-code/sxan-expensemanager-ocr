import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, text }

/// Reusable button supporting Primary, Secondary, Outline, and Text variants.
///
/// Meets the minimum touch target requirement (~48px) and supports loading/disabled states.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget childWidget;

    if (isLoading) {
      final spinnerColor = variant == AppButtonVariant.primary
          ? AppColors.white
          : (isDark ? AppColors.lightLavender : AppColors.primaryPurple);
      childWidget = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      );
    } else {
      final labelWidget = Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _getTextColor(isDark),
        ),
      );

      if (icon != null) {
        childWidget = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            labelWidget,
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: _getTextColor(isDark)),
          ],
        );
      } else {
        childWidget = labelWidget;
      }
    }

    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: Size(fullWidth ? double.infinity : 88, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: const RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      elevation: 0,
      backgroundColor: _getBackgroundColor(isDark),
      foregroundColor: _getTextColor(isDark),
      side: _getBorderSide(isDark),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: variant == AppButtonVariant.text
          ? TextButton(
              onPressed: isLoading ? null : onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                foregroundColor: _getTextColor(isDark),
              ),
              child: childWidget,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: childWidget,
            ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    if (onPressed == null) {
      return isDark ? AppColors.darkSurfaceVariant : AppColors.gray300;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primaryPurple;
      case AppButtonVariant.secondary:
        return isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.veryLightLavender;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color _getTextColor(bool isDark) {
    if (onPressed == null) {
      return AppColors.gray500;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.white;
      case AppButtonVariant.secondary:
        return isDark ? AppColors.lightLavender : AppColors.primaryPurple;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return isDark ? AppColors.brightViolet : AppColors.primaryPurple;
    }
  }

  BorderSide? _getBorderSide(bool isDark) {
    if (variant == AppButtonVariant.secondary && onPressed != null) {
      return BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1,
      );
    }
    if (variant == AppButtonVariant.outline && onPressed != null) {
      return BorderSide(
        color: isDark ? AppColors.primaryPurple : AppColors.primaryPurple,
        width: 1.5,
      );
    }
    return BorderSide.none;
  }
}
