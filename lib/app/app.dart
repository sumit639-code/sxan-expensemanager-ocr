import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/presentation/providers/pending_import_providers.dart';
import '../features/settings/presentation/providers/settings_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root ExpenseApp widget delegating navigation to GoRouter and themes to AppTheme.
class ExpenseApp extends ConsumerStatefulWidget {
  const ExpenseApp({super.key});

  @override
  ConsumerState<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends ConsumerState<ExpenseApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shareService = ref.read(shareImportServiceProvider);
      shareService.onNotificationTapped = (pendingImportId) {
        appRouter.push('/imports/pending');
      };
      shareService.onSharedImagesReceived = (paths) {
        appRouter.push('/imports/pending');
      };
      shareService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final accentColor = ref.watch(appAccentColorProvider);

    return MaterialApp.router(
      title: 'SXAN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(accentColor),
      darkTheme: AppTheme.getDarkTheme(accentColor),
      themeMode: themeMode.toThemeMode(),
      routerConfig: appRouter,
    );
  }
}

