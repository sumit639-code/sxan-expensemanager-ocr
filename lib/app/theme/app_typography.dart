import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/app_settings.dart';

/// Centralized, bold, and modern typography system for the financial application.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Roboto';

  // --- Display Styles (Hero numbers & Large Promos) ---
  static const TextStyle displayLarge = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // --- Headlines (Page & Major Section Headings) ---
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // --- Titles (Card Headers, Section Titles & Prominent Items) ---
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // --- Body Styles (Readable content, notes, instructions) ---
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // --- Label Styles (Action controls, buttons, chips, tabs) ---
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // --- Specialized Financial Hierarchy Tokens ---
  /// Large financial balance and net-worth figures (e.g. ₹1,42,850.00).
  static const TextStyle financialAmountLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Standard transaction list and summary figures (e.g. ₹2,200.00).
  static const TextStyle financialAmount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Compact monetary amounts inside badges, chips, or mini-tiles.
  static const TextStyle financialAmountSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Standard button label typography.
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Pill navigation bar labels.
  static const TextStyle navigationLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.1,
  );

  /// Secondary captions, hints, and timestamp tags.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static TextTheme createTextTheme(
    Color primaryTextColor,
    Color secondaryTextColor, {
    AppFontPreset fontPreset = AppFontPreset.modern,
  }) {
    final family = fontPreset.fontFamily;
    final headlineWeight = fontPreset.headlineWeight;
    final bodyWeight = fontPreset.bodyWeight;
    final delta = fontPreset.letterSpacingDelta;

    return TextTheme(
      displayLarge: displayLarge.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (displayLarge.letterSpacing ?? -0.8) + delta,
        color: primaryTextColor,
      ),
      displayMedium: displayMedium.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (displayMedium.letterSpacing ?? -0.5) + delta,
        color: primaryTextColor,
      ),
      displaySmall: displaySmall.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (displaySmall.letterSpacing ?? -0.3) + delta,
        color: primaryTextColor,
      ),
      headlineLarge: headlineLarge.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (headlineLarge.letterSpacing ?? -0.3) + delta,
        color: primaryTextColor,
      ),
      headlineMedium: headlineMedium.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (headlineMedium.letterSpacing ?? -0.2) + delta,
        color: primaryTextColor,
      ),
      headlineSmall: headlineSmall.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (headlineSmall.letterSpacing ?? -0.1) + delta,
        color: primaryTextColor,
      ),
      titleLarge: titleLarge.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (titleLarge.letterSpacing ?? -0.1) + delta,
        color: primaryTextColor,
      ),
      titleMedium: titleMedium.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        color: primaryTextColor,
      ),
      titleSmall: titleSmall.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        color: primaryTextColor,
      ),
      bodyLarge: bodyLarge.copyWith(
        fontFamily: family,
        fontWeight: bodyWeight,
        color: primaryTextColor,
      ),
      bodyMedium: bodyMedium.copyWith(
        fontFamily: family,
        fontWeight: bodyWeight,
        color: secondaryTextColor,
      ),
      bodySmall: bodySmall.copyWith(
        fontFamily: family,
        fontWeight: bodyWeight,
        color: secondaryTextColor,
      ),
      labelLarge: labelLarge.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        letterSpacing: (labelLarge.letterSpacing ?? 0.2) + delta,
        color: primaryTextColor,
      ),
      labelMedium: labelMedium.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        color: secondaryTextColor,
      ),
      labelSmall: labelSmall.copyWith(
        fontFamily: family,
        fontWeight: headlineWeight,
        color: secondaryTextColor,
      ),
    );
  }
}
