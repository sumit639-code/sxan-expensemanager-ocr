import 'package:flutter/material.dart';

/// Supported theme modes.
enum AppThemeMode {
  system('system', 'System Default', Icons.brightness_auto_rounded),
  light('light', 'Light Mode', Icons.light_mode_rounded),
  dark('dark', 'Dark Mode', Icons.dark_mode_rounded);

  final String value;
  final String label;
  final IconData icon;

  const AppThemeMode(this.value, this.label, this.icon);

  static AppThemeMode fromString(String? val) {
    return AppThemeMode.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppThemeMode.system,
    );
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Curated high-contrast accent colors that harmonize with the design tokens.
enum AppAccentColor {
  violet(
    'violet',
    'Royal Violet',
    Color(0xFF8B5CF6),
    Color(0xFFC4B5FD),
    LinearGradient(
      colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  purple(
    'purple',
    'Brand Purple',
    Color(0xFF6C5CE7),
    Color(0xFFA29BFE),
    LinearGradient(
      colors: [Color(0xFF8E7CFF), Color(0xFF6C5CE7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  indigo(
    'indigo',
    'Electric Indigo',
    Color(0xFF6366F1),
    Color(0xFFA5B4FC),
    LinearGradient(
      colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  blue(
    'blue',
    'Ocean Blue',
    Color(0xFF0984E3),
    Color(0xFF74B9FF),
    LinearGradient(
      colors: [Color(0xFF00CEC9), Color(0xFF0984E3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  teal(
    'teal',
    'Vibrant Teal',
    Color(0xFF14B8A6),
    Color(0xFF5EEAD4),
    LinearGradient(
      colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  green(
    'green',
    'Emerald Green',
    Color(0xFF10B981),
    Color(0xFF6EE7B7),
    LinearGradient(
      colors: [Color(0xFF34D399), Color(0xFF059669)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  orange(
    'orange',
    'Sunset Orange',
    Color(0xFFF97316),
    Color(0xFFFDBA74),
    LinearGradient(
      colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  rose(
    'rose',
    'Radiant Rose',
    Color(0xFFF43F5E),
    Color(0xFFFDA4AF),
    LinearGradient(
      colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  final String value;
  final String label;
  final Color primary;
  final Color secondary;
  final LinearGradient gradient;

  const AppAccentColor(
    this.value,
    this.label,
    this.primary,
    this.secondary,
    this.gradient,
  );

  static AppAccentColor fromString(String? val) {
    if (val == 'emerald') return AppAccentColor.green;
    return AppAccentColor.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppAccentColor.purple,
    );
  }
}

/// Curated typography presets for app-wide font customization.
enum AppFontPreset {
  modern(
    'modern',
    'Modern Sans',
    'sans-serif',
    FontWeight.w700,
    FontWeight.w400,
    0.0,
    'Clean, balanced neo-grotesque design',
    Icons.font_download_outlined,
  ),
  bold(
    'bold',
    'Bold Impact',
    'sans-serif',
    FontWeight.w900,
    FontWeight.w500,
    -0.5,
    'Punchy, heavyweight high-contrast display',
    Icons.format_bold_rounded,
  ),
  rounded(
    'rounded',
    'Rounded Soft',
    'sans-serif-rounded',
    FontWeight.w700,
    FontWeight.w400,
    0.2,
    'Approachable, friendly curved styling',
    Icons.circle_outlined,
  ),
  mono(
    'mono',
    'Financial Mono',
    'monospace',
    FontWeight.w700,
    FontWeight.w400,
    -0.3,
    'Technical ledger figures & tabular spacing',
    Icons.pin_outlined,
  ),
  serif(
    'serif',
    'Elegant Serif',
    'serif',
    FontWeight.w700,
    FontWeight.w400,
    0.2,
    'Classic private-wealth editorial elegance',
    Icons.menu_book_rounded,
  ),
  condensed(
    'condensed',
    'Compact Condensed',
    'sans-serif-condensed',
    FontWeight.w700,
    FontWeight.w400,
    -0.4,
    'Space-efficient, high-density data views',
    Icons.view_headline_rounded,
  ),
  geometric(
    'geometric',
    'Geometric Crisp',
    'sans-serif',
    FontWeight.w600,
    FontWeight.w400,
    0.5,
    'Pure architectural symmetry and clean lines',
    Icons.crop_square_rounded,
  ),
  minimalist(
    'minimalist',
    'Minimalist Light',
    'sans-serif-light',
    FontWeight.w500,
    FontWeight.w300,
    0.8,
    'Airy, refined, extended luxury letterspacing',
    Icons.space_bar_rounded,
  );

  final String value;
  final String label;
  final String fontFamily;
  final FontWeight headlineWeight;
  final FontWeight bodyWeight;
  final double letterSpacingDelta;
  final String description;
  final IconData icon;

  const AppFontPreset(
    this.value,
    this.label,
    this.fontFamily,
    this.headlineWeight,
    this.bodyWeight,
    this.letterSpacingDelta,
    this.description,
    this.icon,
  );

  static AppFontPreset fromString(String? val) {
    return AppFontPreset.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppFontPreset.modern,
    );
  }
}

/// Card corner rounding options.
enum AppCardRounding {
  sharp('sharp', 'Sharp', 6.0, Icons.crop_square_rounded, 'Crisp 6px edges'),
  compact('compact', 'Compact', 12.0, Icons.rounded_corner_rounded, 'Neat 12px corners'),
  rounded('rounded', 'Rounded', 18.0, Icons.circle_outlined, 'Smooth 18px curves'),
  pill('pill', 'Extra Pill', 26.0, Icons.panorama_fish_eye_rounded, 'Soft 26px pill');

  final String value;
  final String label;
  final double radius;
  final IconData icon;
  final String description;

  const AppCardRounding(
    this.value,
    this.label,
    this.radius,
    this.icon,
    this.description,
  );

  static AppCardRounding fromString(String? val) {
    return AppCardRounding.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppCardRounding.rounded,
    );
  }
}

/// Card surface presentation styles.
enum AppCardStyle {
  elevated('elevated', 'Soft Shadow', Icons.layers_rounded, 'Gentle ambient drop shadow'),
  bordered('bordered', 'Flat Border', Icons.border_all_rounded, 'Crisp clean outline border'),
  glass('glass', 'Glassmorphic', Icons.blur_on_rounded, 'Frosted glass translucent sheen');

  final String value;
  final String label;
  final IconData icon;
  final String description;

  const AppCardStyle(this.value, this.label, this.icon, this.description);

  static AppCardStyle fromString(String? val) {
    return AppCardStyle.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppCardStyle.elevated,
    );
  }
}

/// Preferences controlling dashboard layout and widget visibility.
class DashboardPreferences {
  final bool showBalance;
  final bool showRecentTransactions;
  final bool showSpendingSummary;
  final bool showQuickActions;

  const DashboardPreferences({
    this.showBalance = true,
    this.showRecentTransactions = true,
    this.showSpendingSummary = true,
    this.showQuickActions = true,
  });

  DashboardPreferences copyWith({
    bool? showBalance,
    bool? showRecentTransactions,
    bool? showSpendingSummary,
    bool? showQuickActions,
  }) {
    return DashboardPreferences(
      showBalance: showBalance ?? this.showBalance,
      showRecentTransactions:
          showRecentTransactions ?? this.showRecentTransactions,
      showSpendingSummary: showSpendingSummary ?? this.showSpendingSummary,
      showQuickActions: showQuickActions ?? this.showQuickActions,
    );
  }

  Map<String, dynamic> toJson() => {
    'show_balance': showBalance,
    'show_recent': showRecentTransactions,
    'show_summary': showSpendingSummary,
    'show_quick_actions': showQuickActions,
  };

  factory DashboardPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DashboardPreferences();
    return DashboardPreferences(
      showBalance: json['show_balance'] as bool? ?? true,
      showRecentTransactions: json['show_recent'] as bool? ?? true,
      showSpendingSummary: json['show_summary'] as bool? ?? true,
      showQuickActions: json['show_quick_actions'] as bool? ?? true,
    );
  }
}

/// Supported OCR processing engine modes.
enum OcrEngineMode {
  offline(
    'offline',
    'Offline (On-Device ONNX)',
    '100% private, local ML model running on your device',
  ),
  api(
    'api',
    'Python API (Development)',
    'FastAPI development server (http://127.0.0.1:8000)',
  );

  final String value;
  final String label;
  final String description;

  const OcrEngineMode(this.value, this.label, this.description);

  static OcrEngineMode fromString(String? val) {
    return OcrEngineMode.values.firstWhere(
      (e) => e.value == val,
      orElse: () => OcrEngineMode.offline,
    );
  }
}

/// Supported Python API Endpoint versions.
enum PythonApiVersion {
  v1(
    'v1',
    'V1 (/extract)',
    '/extract',
    'Standard OCR line & bounding box extraction (Backward compatible)',
  ),
  v2(
    'v2',
    'V2 (/extract/v2)',
    '/extract/v2',
    'Enhanced pipeline with transaction candidates & token classification',
  );

  final String value;
  final String label;
  final String endpoint;
  final String description;

  const PythonApiVersion(this.value, this.label, this.endpoint, this.description);

  static PythonApiVersion fromString(String? val) {
    return PythonApiVersion.values.firstWhere(
      (e) => e.value == val,
      orElse: () => PythonApiVersion.v2,
    );
  }
}

/// Settings for OCR import engine and pipeline.
class OcrSettings {
  final OcrEngineMode engineMode;
  final String apiBaseUrl;
  final PythonApiVersion apiVersion;
  final bool reviewBeforeSaving;
  final bool duplicateDetection;

  const OcrSettings({
    this.engineMode = OcrEngineMode.offline,
    this.apiBaseUrl = 'http://127.0.0.1:8000',
    this.apiVersion = PythonApiVersion.v2,
    this.reviewBeforeSaving = true,
    this.duplicateDetection = true,
  });

  OcrSettings copyWith({
    OcrEngineMode? engineMode,
    String? apiBaseUrl,
    PythonApiVersion? apiVersion,
    bool? reviewBeforeSaving,
    bool? duplicateDetection,
  }) {
    return OcrSettings(
      engineMode: engineMode ?? this.engineMode,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiVersion: apiVersion ?? this.apiVersion,
      reviewBeforeSaving: reviewBeforeSaving ?? this.reviewBeforeSaving,
      duplicateDetection: duplicateDetection ?? this.duplicateDetection,
    );
  }

  Map<String, dynamic> toJson() => {
    'engine_mode': engineMode.value,
    'api_base_url': apiBaseUrl,
    'api_version': apiVersion.value,
    'review_before_saving': reviewBeforeSaving,
    'duplicate_detection': duplicateDetection,
  };

  factory OcrSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OcrSettings();
    return OcrSettings(
      engineMode: OcrEngineMode.fromString(json['engine_mode'] as String?),
      apiBaseUrl: json['api_base_url'] as String? ?? 'http://127.0.0.1:8000',
      apiVersion: PythonApiVersion.fromString(json['api_version'] as String?),
      reviewBeforeSaving: json['review_before_saving'] as bool? ?? true,
      duplicateDetection: json['duplicate_detection'] as bool? ?? true,
    );
  }
}

/// Unified application settings container.
class AppSettings {
  final String userName;
  final AppThemeMode themeMode;
  final AppAccentColor accentColor;
  final String currencyCode;
  final DashboardPreferences dashboardPreferences;
  final OcrSettings ocrSettings;
  final bool soundEnabled;
  final double soundVolume;
  final AppFontPreset fontPreset;
  final AppCardRounding cardRounding;
  final AppCardStyle cardStyle;
  final bool autoDetectBankSms;
  final List<String> smsExcludedKeywords;

  static const List<String> defaultSmsExcludedKeywords = [
    'loan',
    'pre-approved',
    'bonus',
    'voucher',
    'coupon',
    'recharge',
    'rummy',
    'win',
    'lottery',
    'cashback offer',
  ];

  const AppSettings({
    this.userName = 'Alex',
    this.themeMode = AppThemeMode.system,
    this.accentColor = AppAccentColor.purple,
    this.currencyCode = 'INR',
    this.dashboardPreferences = const DashboardPreferences(),
    this.ocrSettings = const OcrSettings(),
    this.soundEnabled = true,
    this.soundVolume = 0.8,
    this.fontPreset = AppFontPreset.modern,
    this.cardRounding = AppCardRounding.rounded,
    this.cardStyle = AppCardStyle.elevated,
    this.autoDetectBankSms = true,
    this.smsExcludedKeywords = defaultSmsExcludedKeywords,
  });

  AppSettings copyWith({
    String? userName,
    AppThemeMode? themeMode,
    AppAccentColor? accentColor,
    String? currencyCode,
    DashboardPreferences? dashboardPreferences,
    OcrSettings? ocrSettings,
    bool? soundEnabled,
    double? soundVolume,
    AppFontPreset? fontPreset,
    AppCardRounding? cardRounding,
    AppCardStyle? cardStyle,
    bool? autoDetectBankSms,
    List<String>? smsExcludedKeywords,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      currencyCode: currencyCode ?? this.currencyCode,
      dashboardPreferences:
          dashboardPreferences ?? this.dashboardPreferences,
      ocrSettings: ocrSettings ?? this.ocrSettings,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      fontPreset: fontPreset ?? this.fontPreset,
      cardRounding: cardRounding ?? this.cardRounding,
      cardStyle: cardStyle ?? this.cardStyle,
      autoDetectBankSms: autoDetectBankSms ?? this.autoDetectBankSms,
      smsExcludedKeywords: smsExcludedKeywords ?? this.smsExcludedKeywords,
    );
  }
}
