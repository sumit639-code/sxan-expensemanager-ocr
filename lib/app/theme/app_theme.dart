import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/app_settings.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// AppTheme configures Material 3 ThemeData for Light and Dark themes with customizable accent colors.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => getLightTheme(AppAccentColor.purple);
  static ThemeData get darkTheme => getDarkTheme(AppAccentColor.purple);

  /// Computes a high-contrast foreground color based on background luminance.
  static Color _getAccessibleForeground(Color background) {
    // Relative luminance above 0.55 indicates a bright color requiring dark text
    return background.computeLuminance() > 0.55
        ? AppColors.lightTextPrimary
        : AppColors.white;
  }

  static ThemeData getLightTheme([
    AppAccentColor accent = AppAccentColor.purple,
    AppFontPreset fontPreset = AppFontPreset.modern,
    AppCardRounding cardRounding = AppCardRounding.rounded,
  ]) {
    final primaryColor = accent.primary;
    final secondaryColor = accent.secondary;
    final onPrimary = _getAccessibleForeground(primaryColor);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontPreset.fontFamily,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: onPrimary,
        primaryContainer: primaryColor.withValues(alpha: 0.12),
        onPrimaryContainer: primaryColor,
        secondary: secondaryColor,
        onSecondary: AppColors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightBorderSubtle,
        error: AppColors.errorRed,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      canvasColor: AppColors.lightBackground,
      cardColor: AppColors.lightSurface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMedium,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        shape: const CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryColor.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMedium,
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLarge,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: AppTypography.createTextTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
        fontPreset: fontPreset,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: AppTypography.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRounding.radius),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData getDarkTheme([
    AppAccentColor accent = AppAccentColor.purple,
    AppFontPreset fontPreset = AppFontPreset.modern,
    AppCardRounding cardRounding = AppCardRounding.rounded,
  ]) {
    final primaryColor = accent.primary;
    final secondaryColor = accent.secondary;
    final onPrimary = _getAccessibleForeground(primaryColor);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontPreset.fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: onPrimary,
        primaryContainer: primaryColor.withValues(alpha: 0.20),
        onPrimaryContainer: AppColors.white,
        secondary: secondaryColor,
        onSecondary: AppColors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkBorderSubtle,
        error: AppColors.errorRed,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMedium,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        shape: const CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryColor.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMedium,
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLarge,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: AppTypography.createTextTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
        fontPreset: fontPreset,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: AppTypography.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRounding.radius),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
