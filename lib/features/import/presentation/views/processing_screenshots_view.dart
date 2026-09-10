import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Polished animated processing screen providing honest step-by-step progress feedback.
class ProcessingScreenshotsView extends StatelessWidget {
  final String currentStep;
  final double progress;
  final int imageCount;

  const ProcessingScreenshotsView({
    super.key,
    required this.currentStep,
    required this.progress,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = [
      'Reading screenshots',
      'Detecting transactions',
      'Preparing review',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing scanner icon container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brightViolet, AppColors.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Title & Subtitle
            Text(
              'Processing Screenshots',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              imageCount > 1
                  ? 'Analyzing $imageCount screenshots locally on your device'
                  : 'Analyzing screenshot locally on your device',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Smooth Progress Bar
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusPill,
              child: LinearProgressIndicator(
                value: progress.clamp(0.05, 1.0),
                minHeight: 8,
                backgroundColor: isDark
                    ? AppColors.darkSurface
                    : AppColors.gray200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Checklist Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.white,
                borderRadius: AppSpacing.borderRadiusLarge,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppColors.primaryPurple.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: steps.map((step) {
                  final isDone = _isStepDone(step);
                  final isCurrent = _isStepCurrent(step);

                  Color iconColor;
                  IconData icon;

                  if (isDone) {
                    iconColor = AppColors.successGreen;
                    icon = Icons.check_circle_rounded;
                  } else if (isCurrent) {
                    iconColor = AppColors.primaryPurple;
                    icon = Icons.radio_button_checked_rounded;
                  } else {
                    iconColor = isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.gray400;
                    icon = Icons.radio_button_unchecked_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: iconColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isDone || isCurrent
                                  ? (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary)
                                  : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.gray500),
                            ),
                          ),
                        ),
                        if (isCurrent)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryPurple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // On-Device Local Privacy Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.gray100,
                borderRadius: AppSpacing.borderRadiusPill,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.gray300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'On-Device Local OCR · 100% Offline & Private',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray600,
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

  bool _isStepDone(String step) {
    if (progress >= 0.95) {
      return true;
    }
    if (step.startsWith('Reading screenshots') && progress >= 0.45) {
      return true;
    }
    if (step.startsWith('Detecting transactions') && progress >= 0.85) {
      return true;
    }
    if (step.startsWith('Preparing review') && progress >= 0.95) {
      return true;
    }
    return false;
  }

  bool _isStepCurrent(String step) {
    final lowerCur = currentStep.toLowerCase();
    final lowerStep = step.toLowerCase();
    if (lowerStep.contains('reading') && (lowerCur.contains('reading') || lowerCur.contains('loading') || lowerCur.contains('preparing'))) {
      return progress < 0.45;
    }
    if (lowerStep.contains('detecting') && (lowerCur.contains('analyzing') || lowerCur.contains('parsing') || lowerCur.contains('detecting') || lowerCur.contains('duplicates'))) {
      return progress >= 0.45 && progress < 0.90;
    }
    if (lowerStep.contains('preparing review') && (lowerCur.contains('review') || progress >= 0.90)) {
      return true;
    }
    return false;
  }
}
