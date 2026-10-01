import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/storage/preferences_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../import/presentation/providers/import_providers.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../widgets/onboarding_illustrations.dart';

class OnboardingPageData {
  final String headline;
  final String description;

  const OnboardingPageData({
    required this.headline,
    required this.description,
  });
}

/// Comprehensive, smooth 6-step Onboarding & Setup experience.
/// Includes feature highlights, direct screenshot sharing OCR, bank SMS auto-sync,
/// privacy & spam restrictions, deep theme/currency customization, and launch.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController(text: 'Alex');
  final FocusNode _nameFocusNode = FocusNode();
  int _currentPage = 0;
  String? _nameError;

  static const List<OnboardingPageData> _introPages = [
    OnboardingPageData(
      headline: 'Smart & Effortless\nExpense Tracking',
      description:
          'Track daily expenses, monitor live balances, and gain clarity on where your money goes — 100% offline.',
    ),
    OnboardingPageData(
      headline: 'Snap or Direct Share\nPayment Receipts',
      description:
          'Take a screenshot in GPay, PhonePe, Paytm, or CRED and tap Share → ScanEx. Instant on-device OCR extracts details in milliseconds.',
    ),
    OnboardingPageData(
      headline: 'Automated Bank &\nUPI Alerts Sync',
      description:
          'ScanEx catches incoming bank & UPI transaction alerts in the background and stages them in your Inbox for 1-tap approval.',
    ),
    OnboardingPageData(
      headline: '100% Private\nZero Spam or OTPs',
      description:
          'Your privacy is guaranteed. OTPs, personal messages, and promotional spam are strictly ignored on-device. Once configured, you never have to worry.',
    ),
  ];

  static const int _totalPages = 6; // 4 intro slides + 1 customization slide + 1 done slide

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY', 'KRW'];
  final Map<String, String> _currencyLabels = {
    'INR': '₹ INR',
    'USD': '\$ USD',
    'EUR': '€ EUR',
    'GBP': '£ GBP',
    'JPY': '¥ JPY',
    'KRW': '₩ KRW',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentName = ref.read(userNameProvider);
      if (currentName.isNotEmpty && currentName != 'Alex') {
        _nameController.text = currentName;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final soundService = ref.read(soundServiceProvider);
    soundService.playImportComplete();

    final nameToSave = _nameController.text.trim();
    final finalName = nameToSave.isNotEmpty ? nameToSave : 'Alex';

    // Save user name & preferences
    await ref.read(settingsNotifierProvider.notifier).updateUserName(finalName);
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setUserName(finalName);
    await prefs.setOnboardingCompleted(true);

    if (!mounted) return;
    context.go('/home');
  }

  void _onNextPressed() {
    final soundService = ref.read(soundServiceProvider);
    soundService.playButton();

    if (_currentPage < _totalPages - 1) {
      if (_currentPage == 4) {
        // Validate name on customization step
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() {
            _nameError = 'Please enter your name';
          });
          return;
        }
        if (name.length > 50) {
          setState(() {
            _nameError = 'Name must be under 50 characters';
          });
          return;
        }
        ref.read(settingsNotifierProvider.notifier).updateUserName(name);
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsNotifierProvider);
    final primaryAccent = settings.accentColor.primary;

    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip Button (visible on slides 0..4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: _currentPage < _totalPages - 1
                    ? AppButton.text(
                        label: 'Skip',
                        onPressed: () {
                          ref.read(soundServiceProvider).playButton();
                          _completeOnboarding();
                        },
                      )
                    : const SizedBox(height: 48),
              ),
            ),

            // Center PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  if (index != 4) {
                    _nameFocusNode.unfocus();
                  }
                },
                itemBuilder: (context, index) {
                  // Slides 0..3: Value Proposition Slides
                  if (index < _introPages.length) {
                    return _buildIntroSlide(
                      index: index,
                      data: _introPages[index],
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      primaryAccent: primaryAccent,
                      settings: settings,
                      isDark: isDark,
                    );
                  }

                  // Slide 4: Deep Personalization (Name, Theme, Accent, Currency)
                  if (index == 4) {
                    return _buildCustomizationSlide(
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      primaryAccent: primaryAccent,
                      settings: settings,
                      isDark: isDark,
                    );
                  }

                  // Slide 5: Ready to Roll / Done
                  return _buildDoneSlide(
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    primaryAccent: primaryAccent,
                    settings: settings,
                    isDark: isDark,
                  );
                },
              ),
            ),

            // Bottom Navigation Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicators (6 dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 7,
                        width: _currentPage == index ? 24 : 7,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? primaryAccent
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                          borderRadius: AppSpacing.borderRadiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Primary Button
                  AppButton.primary(
                    label: _currentPage == _totalPages - 1
                        ? 'Start Managing Expenses 🚀'
                        : _currentPage == 4
                            ? 'Save & Continue →'
                            : 'Next →',
                    onPressed: _onNextPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSlide({
    required int index,
    required OnboardingPageData data,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color primaryAccent,
    required AppSettings settings,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnboardingIllustration(
                      pageIndex: index,
                      accentColor: settings.accentColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      data.headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                    if (index == 2) ...[
                      const SizedBox(height: 16),
                      // Permission trigger for Bank SMS step
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryAccent,
                          side: BorderSide(color: primaryAccent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.sms_rounded, size: 18),
                        label: const Text(
                          'Grant SMS Permission Now',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () async {
                          ref.read(soundServiceProvider).playButton();
                          await ref.read(bankSmsServiceProvider).requestPermission();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SMS Auto-Detection configured!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomizationSlide({
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color primaryAccent,
    required AppSettings settings,
    required bool isDark,
  }) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final soundService = ref.read(soundServiceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Friendly Header with live avatar
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: settings.accentColor.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _nameController.text.trim().isNotEmpty
                                ? _nameController.text.trim()[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalize ScanEx',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tailor the theme & currency to your liking.',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Name Field
                  AppTextField(
                    label: 'Your Name',
                    hintText: 'e.g. Alex',
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    errorText: _nameError,
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: primaryAccent,
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (_nameError != null) _nameError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  // 1. Theme Mode Selection
                  Text(
                    'THEME MODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: AppThemeMode.values.map((mode) {
                      final isSelected = settings.themeMode == mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            soundService.playButton();
                            notifier.updateThemeMode(mode);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryAccent.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? primaryAccent
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mode.icon,
                                  size: 18,
                                  color: isSelected
                                      ? primaryAccent
                                      : secondaryTextColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mode.label.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryAccent
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
                  const SizedBox(height: 18),

                  // 2. Accent Color Palette
                  Text(
                    'ACCENT COLOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AppAccentColor.values.map((accent) {
                        final isSelected = settings.accentColor == accent;
                        return GestureDetector(
                          onTap: () {
                            soundService.playButton();
                            notifier.updateAccentColor(accent);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? primaryAccent
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: accent.gradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.primary.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Primary Currency
                  Text(
                    'PRIMARY CURRENCY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currencies.map((code) {
                      final isSelected = settings.currencyCode == code;
                      final label = _currencyLabels[code] ?? code;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: primaryAccent.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? primaryAccent : primaryTextColor,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? primaryAccent
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            soundService.playButton();
                            notifier.updateCurrency(code);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoneSlide({
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color primaryAccent,
    required AppSettings settings,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnboardingIllustration(
                      pageIndex: 5,
                      accentColor: settings.accentColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "You're All Set, ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Alex'}!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your private, local-first financial hub is configured and ready to use.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature Checklist Cards
                    _buildChecklistItem(
                      icon: Icons.shield_outlined,
                      title: '100% Private & Offline',
                      subtitle: 'Zero cloud servers, zero ads, zero telemetry',
                      accent: primaryAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildChecklistItem(
                      icon: Icons.document_scanner_outlined,
                      title: 'On-Device Receipt OCR',
                      subtitle: 'Direct share from GPay, PhonePe, Paytm',
                      accent: primaryAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildChecklistItem(
                      icon: Icons.sms_outlined,
                      title: 'Bank SMS Smart Filtering',
                      subtitle: 'Spam, promo codes & OTPs automatically blocked',
                      accent: primaryAccent,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.successGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
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
