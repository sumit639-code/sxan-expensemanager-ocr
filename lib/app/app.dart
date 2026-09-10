import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/providers/settings_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root ExpenseApp widget delegating navigation to GoRouter and themes to AppTheme.
class ExpenseApp extends ConsumerWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final accentColor = ref.watch(appAccentColorProvider);

    return MaterialApp.router(
      title: 'Expense App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(accentColor),
      darkTheme: AppTheme.getDarkTheme(accentColor),
      themeMode: themeMode.toThemeMode(),
      routerConfig: appRouter,
    );
  }
}

