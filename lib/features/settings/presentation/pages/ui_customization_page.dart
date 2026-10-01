import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/sound_service.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/settings_providers.dart';

/// Dedicated UI Customization Page allowing users to personalize theme mode,
/// select from 8 curated contrast-safe accent presets, and preview changes in real time.
class UICustomizationPage extends ConsumerWidget {
  const UICustomizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = ref.watch(appThemeModeProvider);
    final currentAccent = ref.watch(appAccentColorProvider);
    final currentFont = ref.watch(appFontPresetProvider);
    final currentRounding = ref.watch(appCardRoundingProvider);
    final currentCardStyle = ref.watch(appCardStyleProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final soundService = ref.read(soundServiceProvider);

    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Customization'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. LIVE PREVIEW CARD
            Text(
              'LIVE PREVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            _LiveThemePreviewCard(
              accent: currentAccent,
              fontPreset: currentFont,
              rounding: currentRounding,
              cardStyle: currentCardStyle,
              isDark: isDark,
            ),
            const SizedBox(height: 28),

            // 2. THEME MODE SELECTION
            Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(currentRounding.radius),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: AppThemeMode.values.map((mode) {
                  final isSelected = currentTheme == mode;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        soundService.playButton();
                        settingsNotifier.updateThemeMode(mode);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? currentAccent.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular((currentRounding.radius * 0.7).clamp(6.0, 16.0)),
                          border: Border.all(
                            color: isSelected
                                ? currentAccent.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mode.icon,
                              size: 22,
                              color: isSelected
                                  ? currentAccent.primary
                                  : secondaryTextColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? currentAccent.primary
                                    : primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // 3. ACCENT COLOR PALETTE
            Text(
              'ACCENT COLOR PRESETS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(currentRounding.radius),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppAccentColor.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final accent = AppAccentColor.values[index];
                  final isSelected = currentAccent == accent;

                  return GestureDetector(
                    onTap: () {
                      soundService.playButton();
                      settingsNotifier.updateAccentColor(accent);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: accent.gradient,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: accent.primary.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          accent.label.split(' ').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? accent.primary
                                : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // 4. CARD CORNER ROUNDING CUSTOMIZATION
            Text(
              'CARD CORNER ROUNDING',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(currentRounding.radius),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: AppCardRounding.values.map((rounding) {
                  final isSelected = currentRounding == rounding;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        soundService.playButton();
                        settingsNotifier.updateCardRounding(rounding);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? currentAccent.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(rounding.radius),
                          border: Border.all(
                            color: isSelected
                                ? currentAccent.primary
                                : borderColor,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? currentAccent.primary
                                    : (isDark ? AppColors.darkElevated : AppColors.gray200),
                                borderRadius: BorderRadius.circular(rounding.radius * 0.7),
                              ),
                              child: Icon(
                                rounding.icon,
                                size: 16,
                                color: isSelected ? Colors.white : secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rounding.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? currentAccent.primary
                                    : primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${rounding.radius.toInt()}px',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? currentAccent.primary
                                    : secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // 5. CARD SURFACE STYLE
            Text(
              'CARD SURFACE STYLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(currentRounding.radius),
                side: BorderSide(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: AppCardStyle.values.map((style) {
                  final isSelected = currentCardStyle == style;
                  final isLast = style == AppCardStyle.values.last;
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? currentAccent.primary.withValues(alpha: 0.14)
                                : (isDark
                                    ? AppColors.darkElevated
                                    : AppColors.lightSurfaceVariant),
                            borderRadius: BorderRadius.circular(currentRounding.radius * 0.6),
                            border: Border.all(
                              color: isSelected
                                  ? currentAccent.primary
                                  : borderColor,
                            ),
                          ),
                          child: Icon(
                            style.icon,
                            color: isSelected
                                ? currentAccent.primary
                                : secondaryTextColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          style.label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                            color: isSelected ? currentAccent.primary : primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          style.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? currentAccent.primary
                              : secondaryTextColor.withValues(alpha: 0.5),
                          size: 22,
                        ),
                        onTap: () {
                          soundService.playButton();
                          settingsNotifier.updateCardStyle(style);
                        },
                      ),
                      if (!isLast) Divider(color: borderColor, height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // 6. FONT & TYPOGRAPHY STYLE
            Text(
              'TYPOGRAPHY & FONTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(currentRounding.radius),
                side: BorderSide(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppFontPreset.values.length,
                separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
                itemBuilder: (context, index) {
                  final preset = AppFontPreset.values[index];
                  final isSelected = currentFont == preset;
                  return ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? currentAccent.primary.withValues(alpha: 0.14)
                            : (isDark
                                ? AppColors.darkElevated
                                : AppColors.lightSurfaceVariant),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? currentAccent.primary
                              : borderColor,
                        ),
                      ),
                      child: Icon(
                        preset.icon,
                        color: isSelected
                            ? currentAccent.primary
                            : secondaryTextColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      preset.label,
                      style: TextStyle(
                        fontFamily: preset.fontFamily,
                        fontWeight: preset.headlineWeight,
                        fontSize: 14,
                        color: isSelected ? currentAccent.primary : primaryTextColor,
                        letterSpacing: preset.letterSpacingDelta,
                      ),
                    ),
                    subtitle: Text(
                      preset.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: currentAccent.primary,
                            size: 22,
                          )
                        : null,
                    onTap: () {
                      soundService.playButton();
                      settingsNotifier.updateFontPreset(preset);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // 7. ACCESSIBILITY & CONTRAST CALLOUT
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkElevated
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(currentRounding.radius),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: currentAccent.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All presets automatically compute contrast-safe text tones so balances, buttons, and navigation remain accessible.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
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

/// Dynamic live preview card reflecting the selected accent, font preset, corner rounding, and card style.
class _LiveThemePreviewCard extends StatelessWidget {
  final AppAccentColor accent;
  final AppFontPreset fontPreset;
  final AppCardRounding rounding;
  final AppCardStyle cardStyle;
  final bool isDark;

  const _LiveThemePreviewCard({
    required this.accent,
    required this.fontPreset,
    required this.rounding,
    required this.cardStyle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = accent.primary;
    final onPrimary = primaryColor.computeLuminance() > 0.55
        ? AppColors.lightTextPrimary
        : AppColors.white;

    Color cardBg;
    List<BoxShadow>? shadows;
    Border border;

    switch (cardStyle) {
      case AppCardStyle.elevated:
        cardBg = isDark ? AppColors.darkSurface : AppColors.white;
        border = Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        );
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ];
        break;
      case AppCardStyle.bordered:
        cardBg = isDark ? AppColors.darkSurface : AppColors.white;
        border = Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.8,
        );
        shadows = null;
        break;
      case AppCardStyle.glass:
        cardBg = isDark
            ? const Color(0xCC1A1829)
            : Colors.white.withValues(alpha: 0.85);
        border = Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : primaryColor.withValues(alpha: 0.22),
          width: 1.5,
        );
        shadows = [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];
        break;
    }

    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(rounding.radius),
        border: border,
        boxShadow: shadows,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header + Category Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Spending',
                    style: TextStyle(
                      fontFamily: fontPreset.fontFamily,
                      fontSize: 13,
                      fontWeight: fontPreset.bodyWeight,
                      color: secondaryTextColor,
                      letterSpacing: fontPreset.letterSpacingDelta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹12,450.00',
                    style: TextStyle(
                      fontFamily: fontPreset.fontFamily,
                      fontSize: 22,
                      fontWeight: fontPreset.headlineWeight,
                      color: primaryTextColor,
                      letterSpacing: -0.4 + fontPreset.letterSpacingDelta,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(rounding.radius * 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Shopping',
                      style: TextStyle(
                        fontFamily: fontPreset.fontFamily,
                        fontSize: 11,
                        fontWeight: fontPreset.headlineWeight,
                        color: primaryColor,
                        letterSpacing: fontPreset.letterSpacingDelta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Row 2: Action Button + Active Navigation Icon Preview
          Row(
            children: [
              // Button in Accent Color with harmonized rounding
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Add Expense',
                  style: TextStyle(
                    fontFamily: fontPreset.fontFamily,
                    fontWeight: fontPreset.headlineWeight,
                    letterSpacing: fontPreset.letterSpacingDelta,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular((rounding.radius * 0.7).clamp(6.0, 20.0)),
                  ),
                  elevation: 0,
                ),
              ),
              const Spacer(),

              // Selected Nav representation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular((rounding.radius * 0.7).clamp(6.0, 16.0)),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Tab',
                      style: TextStyle(
                        fontFamily: fontPreset.fontFamily,
                        fontSize: 12,
                        fontWeight: fontPreset.headlineWeight,
                        color: primaryColor,
                        letterSpacing: fontPreset.letterSpacingDelta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
