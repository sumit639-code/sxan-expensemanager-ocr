import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../settings/domain/entities/app_settings.dart';

/// Rich, responsive vector-style custom illustrations for the ScanEx setup experience.
class OnboardingIllustration extends StatefulWidget {
  final int pageIndex;
  final AppAccentColor? accentColor;

  const OnboardingIllustration({
    super.key,
    required this.pageIndex,
    this.accentColor,
  });

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = widget.accentColor?.primary ?? AppColors.primaryPurple;
    final secondaryAccent =
        widget.accentColor?.secondary ?? AppColors.brightViolet;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220, minHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Radial Glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      secondaryAccent.withValues(alpha: isDark ? 0.20 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildGraphicForPage(
                  widget.pageIndex,
                  primaryAccent,
                  secondaryAccent,
                  isDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphicForPage(
    int index,
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    switch (index) {
      case 0:
        return _buildExpenseManagerGraphic(primaryAccent, secondaryAccent, isDark);
      case 1:
        return _buildScreenshotOcrGraphic(primaryAccent, secondaryAccent, isDark);
      case 2:
        return _buildBankSmsGraphic(primaryAccent, secondaryAccent, isDark);
      case 3:
        return _buildPrivacySpamFilterGraphic(primaryAccent, secondaryAccent, isDark);
      case 4:
        return _buildPersonalizationGraphic(primaryAccent, secondaryAccent, isDark);
      case 5:
        return _buildCelebrationGraphic(primaryAccent, secondaryAccent, isDark);
      default:
        return _buildExpenseManagerGraphic(primaryAccent, secondaryAccent, isDark);
    }
  }

  /// Page 0: Manage Expenses — Financial command card with live indicators
  Widget _buildExpenseManagerGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryAccent, primaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TOTAL BALANCE',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.contactless_rounded,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '₹ 48,250.00',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadge(
              Icons.arrow_downward_rounded,
              '+₹65,000 Income',
              AppColors.successGreen,
            ),
            const SizedBox(width: 8),
            _buildBadge(
              Icons.arrow_upward_rounded,
              '-₹16,750 Spent',
              AppColors.errorRed,
            ),
          ],
        ),
      ],
    );
  }

  /// Page 1: Screenshot & Direct Share OCR — Receipt mockup + scanner beam
  Widget _buildScreenshotOcrGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Simulated Payment App Receipt
            Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryAccent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.successGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Payment to Swiggy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'UPI • Success',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '₹420',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Scanner Laser Line
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Positioned(
                  left: 10,
                  right: 10,
                  top: 8 + (_pulseAnimation.value - 0.96) * 260,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          primaryAccent,
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryAccent.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // OCR Extracted Tag Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: primaryAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 12, color: primaryAccent),
              const SizedBox(width: 4),
              Text(
                'Instant On-Device OCR • Direct Share',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primaryAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Page 2: Bank SMS Auto-Detection — Notification card syncing into Inbox
  Widget _buildBankSmsGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bank SMS incoming bubble
        Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.veryLightLavender,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryAccent.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sms_rounded,
                  color: primaryAccent,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HDFC Bank Alert',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rs 1,450.00 debited from a/c XX4921 for Amazon...',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.gray500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Downward sync indicator
        Icon(
          Icons.arrow_downward_rounded,
          size: 16,
          color: primaryAccent,
        ),
        const SizedBox(height: 6),
        // Staged Inbox Item
        Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.successGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.move_to_inbox_rounded,
                color: AppColors.successGreen,
                size: 14,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Staged in Inbox',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
              Text(
                '1-Tap Add ✓',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Page 3: Privacy & Spam/OTP Restriction — Shield filter
  Widget _buildPrivacySpamFilterGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Allowed Card
            Container(
              width: 105,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 12, color: AppColors.successGreen),
                      SizedBox(width: 4),
                      Text(
                        'SAVED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successGreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Bank Debits\n• UPI Credits\n• Card Alerts',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Blocked Card
            Container(
              width: 105,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel_rounded,
                          size: 12, color: AppColors.errorRed),
                      SizedBox(width: 4),
                      Text(
                        'BLOCKED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• OTP Codes\n• Promo Spam\n• Personal SMS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Shield badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primaryAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security_rounded, size: 12, color: primaryAccent),
              const SizedBox(width: 4),
              Text(
                '100% Local & On-Device Processing',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: primaryAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Page 4: Personalization — Palette swatches & dynamic theme preview
  Widget _buildPersonalizationGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildThemePill(Icons.brightness_auto_rounded, 'System', primaryAccent, true),
            const SizedBox(width: 6),
            _buildThemePill(Icons.dark_mode_rounded, 'Dark', primaryAccent, false),
            const SizedBox(width: 6),
            _buildThemePill(Icons.light_mode_rounded, 'Light', primaryAccent, false),
          ],
        ),
        const SizedBox(height: 12),
        // Swatches preview row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildColorDot(const Color(0xFF6C5CE7), true),
            _buildColorDot(const Color(0xFF8B5CF6), false),
            _buildColorDot(const Color(0xFF6366F1), false),
            _buildColorDot(const Color(0xFF0984E3), false),
            _buildColorDot(const Color(0xFF10B981), false),
            _buildColorDot(const Color(0xFFF97316), false),
          ],
        ),
      ],
    );
  }

  /// Page 5: Celebration / All Set
  Widget _buildCelebrationGraphic(
    Color primaryAccent,
    Color secondaryAccent,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryAccent, primaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: AppColors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.successGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 12, color: AppColors.successGreen),
              SizedBox(width: 4),
              Text(
                'Everything Ready • 100% Private',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePill(
      IconData icon, String label, Color accent, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? accent : AppColors.gray400.withValues(alpha: 0.3),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: active ? accent : AppColors.gray500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? accent : AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color, bool selected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: selected ? 20 : 15,
      height: selected ? 20 : 15,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: AppColors.white, width: 2)
            : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}
