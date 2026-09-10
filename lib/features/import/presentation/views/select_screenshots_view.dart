import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Landing screen for the screenshot import workflow.
///
/// Places the "Select Screenshots" hero and action prominently in the center,
/// with concise, short-form highlights below instead of bulky cards.
class SelectScreenshotsView extends ConsumerWidget {
  final VoidCallback onSelectScreenshots;

  const SelectScreenshotsView({super.key, required this.onSelectScreenshots});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final ocrSettings = ref.watch(ocrSettingsProvider);
    final isOffline = ocrSettings.engineMode == OcrEngineMode.offline;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CENTERED HERO & ACTION CARD
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.deepPurple,
                  AppColors.primaryPurple,
                  AppColors.brightViolet,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppSpacing.borderRadiusLarge,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    size: 32,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Scan History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Select payment history screenshots to automatically extract transactions.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Primary Action Button (Right in the middle)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSelectScreenshots,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                    label: const Text(
                      'Select Screenshots',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Switch Engine Mode Pill
                InkWell(
                  onTap: () {
                    final notifier = ref.read(settingsNotifierProvider.notifier);
                    if (isOffline) {
                      notifier.updateOcrEngineMode(OcrEngineMode.api);
                      notifier.updateOcrApiVersion(PythonApiVersion.v2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(
                            '🌐 Switched to Python API V2 (${ocrSettings.apiBaseUrl}/extract/v2)',
                          ),
                        ),
                      );
                    } else if (ocrSettings.apiVersion == PythonApiVersion.v2) {
                      notifier.updateOcrApiVersion(PythonApiVersion.v1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(
                            '🌐 Switched to Python API V1 (${ocrSettings.apiBaseUrl}/extract)',
                          ),
                        ),
                      );
                    } else {
                      notifier.updateOcrEngineMode(OcrEngineMode.offline);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 2),
                          content: Text('⚡ Switched to Offline On-Device ONNX OCR'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground.withValues(alpha: 0.6)
                          : AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOffline
                              ? Icons.offline_bolt_rounded
                              : (ocrSettings.apiVersion == PythonApiVersion.v2
                                  ? Icons.auto_awesome_rounded
                                  : Icons.terminal_rounded),
                          size: 14,
                          color: isOffline
                              ? AppColors.successGreen
                              : AppColors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOffline
                              ? 'Offline ONNX'
                              : 'API (${ocrSettings.apiVersion.label.split(' ').first})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: AppColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. SHORT-FORM HIGHLIGHT POINTS (Compact, not big cards)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Highlights',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: AppSpacing.borderRadiusLarge,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _ShortPointRow(
                  icon: Icons.photo_library_outlined,
                  title: 'Multiple Screenshots',
                  subtitle: 'GPay, Paytm, PhonePe, or cards in one go',
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                _ShortPointRow(
                  icon: Icons.shield_outlined,
                  title: 'Private & Local-First',
                  subtitle: '100% on-device processing, zero cloud storage',
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                _ShortPointRow(
                  icon: Icons.copy_rounded,
                  title: 'Duplicate Detection',
                  subtitle: 'Automatically flags duplicate transactions',
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                _ShortPointRow(
                  icon: Icons.edit_note_rounded,
                  title: 'Review & Confirm',
                  subtitle: 'Inspect and edit details before saving to records',
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortPointRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const _ShortPointRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: secondaryTextColor,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
