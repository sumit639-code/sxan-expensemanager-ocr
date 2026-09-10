import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/export_csv_service.dart';
import '../../../import/presentation/providers/import_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/settings_providers.dart';

/// Full Settings & Customization Page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // 0. PROFILE & PERSONALIZATION SECTION
            const _SectionHeader(
              title: 'Profile & Personalization',
              icon: Icons.person_outline_rounded,
            ),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primaryPurple,
                    size: 22,
                  ),
                  title: const Text(
                    'Your Name',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.userName,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editUserName(context, ref, settings.userName),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. APPEARANCE SECTION
            const _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
            _SettingsCard(
              children: [
                // Theme Mode Selector
                _SettingTile(
                  title: 'Theme Mode',
                  subtitle: settings.themeMode.label,
                  leadingIcon: settings.themeMode.icon,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemeMode>(
                      value: settings.themeMode,
                      dropdownColor:
                          isDark ? AppColors.darkSurface : AppColors.white,
                      items: AppThemeMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(mode.icon, size: 16),
                              const SizedBox(width: 8),
                              Text(mode.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (mode) {
                        if (mode != null) notifier.updateThemeMode(mode);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Accent Color Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accent Color',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selected: ${settings.accentColor.label}',
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: AppAccentColor.values.map((color) {
                          final isSelected = settings.accentColor == color;
                          return GestureDetector(
                            onTap: () => notifier.updateAccentColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: color.gradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? AppColors.white : Colors.black)
                                      : Colors.transparent,
                                  width: isSelected ? 3 : 0,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.primary.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        Icons.check_rounded,
                                        color: AppColors.white,
                                        size: 22,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. DASHBOARD CUSTOMIZATION SECTION
            const _SectionHeader(
              title: 'Dashboard Preferences',
              icon: Icons.dashboard_customize_outlined,
            ),
            _SettingsCard(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Show Total Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Display net balance card on home screen', style: TextStyle(fontSize: 12)),
                  value: settings.dashboardPreferences.showBalance,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateDashboardPreferences(
                      settings.dashboardPreferences.copyWith(showBalance: val),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Show Spending Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Display monthly income and expense totals', style: TextStyle(fontSize: 12)),
                  value: settings.dashboardPreferences.showSpendingSummary,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateDashboardPreferences(
                      settings.dashboardPreferences.copyWith(showSpendingSummary: val),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Show Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Display add, scan, and analytics shortcuts', style: TextStyle(fontSize: 12)),
                  value: settings.dashboardPreferences.showQuickActions,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateDashboardPreferences(
                      settings.dashboardPreferences.copyWith(showQuickActions: val),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Show Recent Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Display recent activity feed on dashboard', style: TextStyle(fontSize: 12)),
                  value: settings.dashboardPreferences.showRecentTransactions,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateDashboardPreferences(
                      settings.dashboardPreferences.copyWith(showRecentTransactions: val),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. OCR & IMPORT SETTINGS
            const _SectionHeader(title: 'OCR & Screenshot Import', icon: Icons.document_scanner_outlined),
            _SettingsCard(
              children: [
                // OCR Engine Mode Selector
                _SettingTile(
                  title: 'OCR Engine Mode',
                  subtitle: settings.ocrSettings.engineMode.description,
                  leadingIcon: settings.ocrSettings.engineMode == OcrEngineMode.offline
                      ? Icons.memory_rounded
                      : Icons.cloud_sync_rounded,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<OcrEngineMode>(
                      value: settings.ocrSettings.engineMode,
                      dropdownColor:
                          isDark ? AppColors.darkSurface : AppColors.white,
                      items: OcrEngineMode.values.map((mode) {
                        final isOffline = mode == OcrEngineMode.offline;
                        return DropdownMenuItem(
                          value: mode,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOffline ? Icons.offline_bolt_rounded : Icons.terminal_rounded,
                                size: 16,
                                color: isOffline ? AppColors.successGreen : AppColors.primaryPurple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOffline ? 'Offline (ONNX)' : 'Python API',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (mode) {
                        if (mode != null) notifier.updateOcrEngineMode(mode);
                      },
                    ),
                  ),
                ),
                if (settings.ocrSettings.engineMode == OcrEngineMode.api) ...[
                  const Divider(height: 1),
                  // Endpoint Version Selector (V1 vs V2)
                  _SettingTile(
                    title: 'API Version & Endpoint',
                    subtitle: settings.ocrSettings.apiVersion.description,
                    leadingIcon: Icons.route_rounded,
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<PythonApiVersion>(
                        value: settings.ocrSettings.apiVersion,
                        dropdownColor:
                            isDark ? AppColors.darkSurface : AppColors.white,
                        items: PythonApiVersion.values.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  v == PythonApiVersion.v2
                                      ? Icons.auto_awesome_rounded
                                      : Icons.history_rounded,
                                  size: 15,
                                  color: v == PythonApiVersion.v2
                                      ? AppColors.brightViolet
                                      : AppColors.gray600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  v.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (version) {
                          if (version != null) {
                            notifier.updateOcrApiVersion(version);
                          }
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link_rounded, size: 22, color: AppColors.primaryPurple),
                    title: const Text('Python Server Endpoint', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${settings.ocrSettings.apiBaseUrl}${settings.ocrSettings.apiVersion.endpoint}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _editApiUrl(context, ref, settings.ocrSettings.apiBaseUrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.network_check_rounded, size: 22, color: AppColors.primaryPurple),
                    title: const Text('Test Endpoint Connection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Send a health check probe to verify backend response', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryPurple),
                    onTap: () => _testApiConnection(context, ref),
                  ),
                ],
                const Divider(height: 1),
                _SettingTile(
                  title: 'Model & Rules Version',
                  subtitle: settings.ocrSettings.engineMode == OcrEngineMode.offline
                      ? 'Local ONNX: v1.0.0 · Rules: v1.0.0'
                      : 'Remote FastAPI Server (${settings.ocrSettings.apiBaseUrl}${settings.ocrSettings.apiVersion.endpoint})',
                  leadingIcon: Icons.rule_folder_outlined,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (settings.ocrSettings.engineMode == OcrEngineMode.offline
                              ? AppColors.successGreen
                              : AppColors.primaryPurple)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      settings.ocrSettings.engineMode == OcrEngineMode.offline
                          ? '100% Offline'
                          : 'Dev: ${settings.ocrSettings.apiVersion.value.toUpperCase()}',
                      style: TextStyle(
                        color: settings.ocrSettings.engineMode == OcrEngineMode.offline
                            ? AppColors.successGreen
                            : AppColors.primaryPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Review Before Saving', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Inspect extracted items before adding to SQLite', style: TextStyle(fontSize: 12)),
                  value: settings.ocrSettings.reviewBeforeSaving,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateOcrSettings(
                      settings.ocrSettings.copyWith(reviewBeforeSaving: val),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Duplicate Detection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Automatically flag duplicate screenshot imports', style: TextStyle(fontSize: 12)),
                  value: settings.ocrSettings.duplicateDetection,
                  activeTrackColor: settings.accentColor.primary,
                  onChanged: (val) {
                    notifier.updateOcrSettings(
                      settings.ocrSettings.copyWith(duplicateDetection: val),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. DATA MANAGEMENT SECTION
            const _SectionHeader(title: 'Data Management', icon: Icons.storage_rounded),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: AppColors.primaryPurple),
                  title: const Text('Export Transactions (CSV)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export all transactions to standard CSV format', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _exportCsv(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
                  title: const Text('Clear All Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
                  subtitle: const Text('Permanently delete all SQLite transaction records', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.errorRed),
                  onTap: () => _confirmClearAll(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. ABOUT SECTION
            const _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
            const _SettingsCard(
              children: [
                _SettingTile(
                  title: 'ScanEx Expense Tracker',
                  subtitle: 'Version 1.0.0+1 · Local-First Architecture',
                  leadingIcon: Icons.verified_user_outlined,
                ),
                Divider(height: 1),
                _SettingTile(
                  title: 'Privacy & Security',
                  subtitle: 'All financial data & OCR models run 100% on your device. Zero telemetry.',
                  leadingIcon: Icons.lock_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _editUserName(BuildContext context, WidgetRef ref, String currentName) {
    final textController = TextEditingController(text: currentName);
    String? localError;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(width: 8),
                  Text('Your Name'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update the name displayed on your dashboard greeting.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'e.g. Alex',
                      errorText: localError,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    onChanged: (val) {
                      if (localError != null) {
                        setDialogState(() => localError = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmed = textController.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() => localError = 'Please enter your name');
                      return;
                    }
                    if (trimmed.length > 50) {
                      setDialogState(
                        () => localError = 'Name is too long (max 50 chars)',
                      );
                      return;
                    }
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateUserName(trimmed);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Name updated to "$trimmed"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportCsv(BuildContext context, WidgetRef ref) async {
    final transactions = await ref.read(transactionRepositoryProvider).getAllTransactions();
    if (transactions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export.')),
        );
      }
      return;
    }

    final csvContent = ExportCsvService.generateCsv(transactions);

    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.primaryPurple),
                SizedBox(width: 8),
                Text('CSV Export Ready'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated ${transactions.length} transaction records in standard CSV format.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    csvContent.length > 300
                        ? '${csvContent.substring(0, 300)}...\n[${transactions.length} total rows]'
                        : csvContent,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy CSV'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard!')),
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text('Delete All Transactions?'),
            ],
          ),
          content: const Text(
            'This action cannot be undone. All your locally recorded expense and income records will be permanently removed from SQLite storage.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(transactionRepositoryProvider).clearAllTransactions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All transactions deleted.')),
                  );
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _editApiUrl(BuildContext context, WidgetRef ref, String currentUrl) {
    final textController = TextEditingController(text: currentUrl);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.terminal_rounded, color: AppColors.primaryPurple),
              SizedBox(width: 8),
              Text('Python API Base URL'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the endpoint of your running FastAPI server:\n• Localhost: http://127.0.0.1:8000\n• Android Emulator: http://10.0.2.2:8000\n• Real Phone on LAN: http://192.168.x.x:8000',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://127.0.0.1:8000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  ref.read(settingsNotifierProvider.notifier).updateOcrApiBaseUrl(text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _testApiConnection(BuildContext context, WidgetRef ref) async {
    final ocrSettings = ref.read(settingsNotifierProvider).ocrSettings;
    final api = ref.read(pythonOcrApiProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Testing ${ocrSettings.apiBaseUrl}${ocrSettings.apiVersion.endpoint}...'),
      ),
    );

    final result = await api.testEndpoint();

    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final isSuccess = result.success;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: isSuccess ? AppColors.successGreen : AppColors.errorRed,
                ),
                const SizedBox(width: 8),
                Text(isSuccess ? 'Server Online' : 'Connection Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Endpoint: ${ocrSettings.apiBaseUrl}${ocrSettings.apiVersion.endpoint}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'API Version: ${ocrSettings.apiVersion.label}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Response Time: ${result.latencyMs} ms',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${result.message}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSuccess ? AppColors.successGreen : AppColors.errorRed,
                  ),
                ),
                if (!isSuccess) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Troubleshooting Tips:\n1. Ensure FastAPI server is running: `uvicorn main:app --reload --port 8000`\n2. For Android USB: run `adb reverse tcp:8000 tcp:8000`\n3. For Android Emulator: use `http://10.0.2.2:8000`',
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.gray600),
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: AppSpacing.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusLarge,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final Widget? trailing;

  const _SettingTile({
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(leadingIcon, size: 22, color: AppColors.primaryPurple),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing,
    );
  }
}
