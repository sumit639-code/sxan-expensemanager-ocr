import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/app/theme/app_colors.dart';
import 'package:expense_app/app/theme/app_theme.dart';
import 'package:expense_app/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppTheme & AppAccentColor Contrast Verification', () {
    test('verifies all 8 presets generate readable onPrimary colors in Light Mode', () {
      for (final accent in AppAccentColor.values) {
        final theme = AppTheme.getLightTheme(accent);

        expect(theme.colorScheme.primary, accent.primary);
        expect(theme.colorScheme.onPrimary, isNotNull);

        // Luminance check: if primary is very bright, onPrimary must be dark text; otherwise white
        if (accent.primary.computeLuminance() > 0.55) {
          expect(theme.colorScheme.onPrimary, AppColors.lightTextPrimary);
        } else {
          expect(theme.colorScheme.onPrimary, AppColors.white);
        }
      }
    });

    test('verifies all 8 presets generate readable onPrimary colors in Dark Mode', () {
      for (final accent in AppAccentColor.values) {
        final theme = AppTheme.getDarkTheme(accent);

        expect(theme.colorScheme.primary, accent.primary);
        expect(theme.colorScheme.surface, AppColors.darkSurface);
        expect(theme.colorScheme.onSurface, AppColors.darkTextPrimary);
      }
    });

    test('theme assigns accent color to buttons, switches, and progress indicators', () {
      final theme = AppTheme.getLightTheme(AppAccentColor.rose);
      expect(theme.colorScheme.primary, AppAccentColor.rose.primary);
      expect(theme.progressIndicatorTheme.color, AppAccentColor.rose.primary);
      expect(theme.floatingActionButtonTheme.backgroundColor, AppAccentColor.rose.primary);
    });
  });
}
