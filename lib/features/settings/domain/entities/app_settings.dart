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
  purple(
    'purple',
    'Royal Violet',
    Color(0xFF6C5CE7),
    Color(0xFFA29BFE),
    LinearGradient(
      colors: [Color(0xFF8E7CFF), Color(0xFF6C5CE7)],
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
  emerald(
    'emerald',
    'Emerald Green',
    Color(0xFF00B894),
    Color(0xFF55EFC4),
    LinearGradient(
      colors: [Color(0xFF55EFC4), Color(0xFF00B894)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  orange(
    'orange',
    'Sunset Orange',
    Color(0xFFE17055),
    Color(0xFFFAB1A0),
    LinearGradient(
      colors: [Color(0xFFFDCB6E), Color(0xFFE17055)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  rose(
    'rose',
    'Vibrant Rose',
    Color(0xFFE84393),
    Color(0xFFFD79A8),
    LinearGradient(
      colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
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
    return AppAccentColor.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AppAccentColor.purple,
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

  const AppSettings({
    this.userName = 'Alex',
    this.themeMode = AppThemeMode.system,
    this.accentColor = AppAccentColor.purple,
    this.currencyCode = 'INR',
    this.dashboardPreferences = const DashboardPreferences(),
    this.ocrSettings = const OcrSettings(),
  });

  AppSettings copyWith({
    String? userName,
    AppThemeMode? themeMode,
    AppAccentColor? accentColor,
    String? currencyCode,
    DashboardPreferences? dashboardPreferences,
    OcrSettings? ocrSettings,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      currencyCode: currencyCode ?? this.currencyCode,
      dashboardPreferences:
          dashboardPreferences ?? this.dashboardPreferences,
      ocrSettings: ocrSettings ?? this.ocrSettings,
    );
  }
}
