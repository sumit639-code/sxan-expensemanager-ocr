import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/preferences_provider.dart';

/// Animated Splash Page establishing initial branding and determining route flow.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Staged Animation Intervals
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Stage 1 (0ms - 350ms): Logo entrance with subtle spring scale & fade
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    // Stage 2 (200ms - 500ms): App Title slides up & fades in
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Stage 3 (350ms - 650ms): Subtitle & Tagline slides up & fades in
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOut),
      ),
    );

    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Fast yet smooth splash time (~850ms)
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    final prefs = ref.read(appPreferencesProvider);
    final completed = await prefs.hasCompletedOnboarding();

    if (!mounted) return;
    if (completed) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.white;
    final primaryTextColor =
        isDark ? AppColors.white : AppColors.darkTextPrimary;
    final subtitleColor =
        isDark ? AppColors.lightLavender : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Ambient Glowing Circles in Background (subtle in light, vibrant in dark)
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark
                        ? AppColors.brightViolet.withValues(alpha: 0.22)
                        : AppColors.primaryPurple.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -50,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark
                        ? AppColors.deepPurple.withValues(alpha: 0.35)
                        : AppColors.brightViolet.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Centered Choreographed Brand Content
          Center(
            child: disableAnimations
                ? _buildStaticContent(primaryTextColor, subtitleColor, isDark)
                : _buildAnimatedContent(primaryTextColor, subtitleColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedContent(
    Color primaryTextColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Logo Icon with subtle Spring Scale & Fade
        FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: _buildLogoBox(isDark),
          ),
        ),
        const SizedBox(height: 24),

        // 2. Title "SXAN" with slide & fade
        FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleSlide,
            child: Text(
              'SXAN',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 3. Tagline "Simple. Smart. Yours." with slide & fade
        FadeTransition(
          opacity: _subtitleFade,
          child: SlideTransition(
            position: _subtitleSlide,
            child: Text(
              'Simple. Smart. Yours.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticContent(
    Color primaryTextColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoBox(isDark),
        const SizedBox(height: 24),
        Text(
          'SXAN',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simple. Smart. Yours.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoBox(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(
              alpha: isDark ? 0.35 : 0.15,
            ),
            blurRadius: isDark ? 32 : 24,
            offset: Offset(0, isDark ? 12 : 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? AppColors.brightViolet.withValues(alpha: 0.25)
              : AppColors.primaryPurple.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Image.asset(
        'assets/icon/sxan.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
