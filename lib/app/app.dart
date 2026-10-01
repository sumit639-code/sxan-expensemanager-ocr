import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/presentation/providers/import_providers.dart';
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

class _ExpenseAppState extends ConsumerState<ExpenseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shareService = ref.read(shareImportServiceProvider);
      shareService.onNotificationTapped = (pendingImportId) {
        appRouter.push('/imports/pending');
      };
      shareService.onSharedImagesReceived = (paths) {
        appRouter.push('/imports/pending');
      };
      shareService.initialize();
      shareService.requestNotificationPermission();

      // Initialize Bank SMS service for real-time transaction detection
      ref.read(bankSmsServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync pending imports and auto-resume any interrupted OCR jobs
      ref.read(pendingImportRepositoryProvider).refreshActive();
      ref
          .read(shareImportServiceProvider)
          .recoverOrphanedProcessingImports(autoResume: true);
      ref.read(bankSmsServiceProvider).initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final accentColor = ref.watch(appAccentColorProvider);
    final fontPreset = ref.watch(appFontPresetProvider);
    final cardRounding = ref.watch(appCardRoundingProvider);

    return MaterialApp.router(
      title: 'SXAN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(accentColor, fontPreset, cardRounding),
      darkTheme: AppTheme.getDarkTheme(accentColor, fontPreset, cardRounding),
      themeMode: themeMode.toThemeMode(),
      routerConfig: appRouter,
    );
  }
}

