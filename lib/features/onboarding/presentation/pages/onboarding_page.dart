import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/storage/preferences_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../widgets/onboarding_illustrations.dart';

class OnboardingPageData {
  final String headline;
  final String description;

  const OnboardingPageData({required this.headline, required this.description});
}

/// 4-Step Onboarding experience including interactive value propositions and name personalization.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  String? _nameError;

  static const List<OnboardingPageData> _introPages = [
    OnboardingPageData(
      headline: 'Track Your Money\nBetter',
      description:
          'Simple, smart, and built to make managing your money easier.',
    ),
    OnboardingPageData(
      headline: 'Add Expenses\nin Seconds',
      description:
          'Add transactions manually or let the app read your payment history.',
    ),
    OnboardingPageData(
      headline: 'Your Money.\nYour View.',
      description:
          'Understand where your money goes with simple, meaningful insights.',
    ),
  ];

  static const int _totalPages = 4; // 3 intro slides + 1 name setup slide

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding([String? customName]) async {
    final nameToSave = (customName ?? _nameController.text).trim();
    final finalName = nameToSave.isNotEmpty ? nameToSave : 'Alex';

    // Save user name in SettingsNotifier & AppPreferences
    await ref.read(settingsNotifierProvider.notifier).updateUserName(finalName);
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setUserName(finalName);
    await prefs.setOnboardingCompleted(true);

    if (!mounted) return;
    context.go('/home');
  }

  void _onNextPressed() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      // Name step validation
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() {
          _nameError = 'Please enter your name';
        });
        return;
      }
      if (name.length > 50) {
        setState(() {
          _nameError = 'Name is too long (maximum 50 characters)';
        });
        return;
      }
      _completeOnboarding(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            // Top Bar: Skip Button (visible on slides 0..2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: _currentPage < _totalPages - 1
                    ? AppButton.text(
                        label: 'Skip',
                        onPressed: () => _completeOnboarding(),
                      )
                    : const SizedBox(height: 48),
              ),
            ),

            // Center PageView (3 intro slides + 1 name setup slide)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index < _introPages.length) {
                    final item = _introPages[index];
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OnboardingIllustration(pageIndex: index),
                                    const SizedBox(height: 24),
                                    Text(
                                      item.headline,
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
                                      item.description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: secondaryTextColor,
                                        height: 1.4,
                                      ),
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

                  // Slide 3: Personalization & Name Setup
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Friendly profile avatar badge
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.brightViolet,
                                          AppColors.primaryPurple,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryPurple
                                              .withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _nameController.text.trim().isNotEmpty
                                          ? Text(
                                              _nameController.text
                                                  .trim()[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              size: 48,
                                              color: AppColors.white,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  Text(
                                    "What's your name?",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "We'll use your name to personalize your experience.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Name text input field
                                  AppTextField(
                                    label: 'Your name',
                                    hintText: 'e.g. Alex',
                                    controller: _nameController,
                                    errorText: _nameError,
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                      color: AppColors.primaryPurple,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (_nameError != null) {
                                          _nameError = null;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
                  // Page Indicators (4 dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primaryPurple
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          borderRadius: AppSpacing.borderRadiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Primary Button
                  AppButton.primary(
                    label: _currentPage == _totalPages - 1
                        ? 'Get Started →'
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
}
