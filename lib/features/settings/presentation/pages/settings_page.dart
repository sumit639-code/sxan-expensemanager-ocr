import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/sound_service.dart';
import '../../../import/presentation/providers/import_providers.dart';
import '../../../import/presentation/providers/pending_import_providers.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/settings_providers.dart';
import '../widgets/sms_exceptions_sheet.dart';

/// Clean, modular Settings Hub navigating to dedicated sub-pages for Customization & Data.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final soundService = ref.read(soundServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: AppSpacing.navPillClearance,
          ),
          children: [
            // 0. PROFILE & PERSONALIZATION
            const _SectionHeader(
              title: 'Profile',
              icon: Icons.person_outline_rounded,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Your Name',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.userName,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {
                    soundService.playButton();
                    _editUserName(context, ref, settings.userName);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. APPEARANCE & CUSTOMIZATION
            const _SectionHeader(
              title: 'Appearance',
              icon: Icons.palette_outlined,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: settings.accentColor.gradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.color_lens_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'UI Customization',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${settings.themeMode.label} • ${settings.accentColor.label} • ${settings.fontPreset.label}',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    soundService.playButton();
                    context.push('/settings/customization');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. DATA MANAGEMENT
            const _SectionHeader(
              title: 'Data & Storage',
              icon: Icons.storage_rounded,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_shared_outlined,
                      color: AppColors.successGreen,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Data Management',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Local database metrics, JSON export & data reset',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    soundService.playButton();
                    context.push('/settings/data');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. SOUND & AUDIO FEEDBACK
            const _SectionHeader(
              title: 'Sound & Audio',
              icon: Icons.volume_up_outlined,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                SwitchListTile(
                  title: const Text(
                    'Sound Effects',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Subtle clicks and confirmation chimes for transactions and buttons',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  value: settings.soundEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (enabled) {
                    notifier.updateSoundEnabled(enabled);
                    if (enabled) {
                      soundService.playButton();
                    }
                  },
                ),
                if (settings.soundEnabled) ...[
                  Divider(color: borderColor, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              '${(settings.soundVolume * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.soundVolume,
                          activeColor: primaryColor,
                          inactiveColor: primaryColor.withValues(alpha: 0.2),
                          onChanged: (val) {
                            notifier.updateSoundVolume(val);
                          },
                          onChangeEnd: (_) {
                            soundService.playButton();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // 4. NOTIFICATIONS
            const _SectionHeader(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Inbox Ready Alerts',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Get notified when shared screenshot transactions are ready in your inbox',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    soundService.playButton();
                    await ref
                        .read(shareImportServiceProvider)
                        .requestNotificationPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications active for inbox readiness'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. BANK SMS DETECTION & BACKGROUND SYNC
            const _SectionHeader(
              title: 'Bank SMS Detection',
              icon: Icons.sms_outlined,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                SwitchListTile(
                  title: const Text(
                    'Auto-detect Bank SMS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.autoDetectBankSms
                        ? 'Active: incoming bank & UPI alerts are parsed and staged in your Inbox'
                        : 'Off: background SMS listening is disabled to conserve battery',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  value: settings.autoDetectBankSms,
                  activeThumbColor: primaryColor,
                  onChanged: (enabled) async {
                    soundService.playButton();
                    await notifier.updateAutoDetectBankSms(enabled);
                    await ref.read(bankSmsServiceProvider).setDetectionEnabled(enabled);
                    if (enabled) {
                      await ref.read(bankSmsServiceProvider).requestPermission();
                    }
                  },
                ),
                if (settings.autoDetectBankSms) ...[
                  Divider(color: borderColor, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.battery_charging_full_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Background Reliability',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Allow unrestricted background activity so Android does not delay alerts',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () async {
                      soundService.playButton();
                      await ref.read(bankSmsServiceProvider).openBatteryOptimizationSettings();
                    },
                  ),
                  Divider(color: borderColor, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.filter_list_off_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Ignored SMS Keywords & Exceptions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${settings.smsExcludedKeywords.length} active filters • Ignore promotional alerts',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      soundService.playButton();
                      SmsExceptionsSheet.show(context);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // 5. OCR ENGINE
            const _SectionHeader(
              title: 'OCR Scanner',
              icon: Icons.document_scanner_outlined,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: const Icon(Icons.memory_rounded, size: 22),
                  title: const Text(
                    'Engine Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.ocrSettings.engineMode.label,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<OcrEngineMode>(
                      value: settings.ocrSettings.engineMode,
                      dropdownColor: cardBg,
                      items: OcrEngineMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(
                            mode.label.split(' ').first,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (mode) {
                        if (mode != null) {
                          soundService.playButton();
                          notifier.updateOcrEngineMode(mode);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. ABOUT APP
            const _SectionHeader(
              title: 'About',
              icon: Icons.info_outline_rounded,
            ),
            _SettingsCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_outlined, size: 22),
                  title: const Text(
                    'ScanEx Expense Manager',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Version 1.0.0 (Phase 11.7)\n100% Offline • Private • On-Device ONNX OCR',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor, height: 1.4),
                  ),
                ),
                Divider(color: borderColor, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brightViolet.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.brightViolet,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Play Protect & Security Guide',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Why APK sideloading shows a prompt & why ScanEx is 100% safe',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    soundService.playButton();
                    _showPlayProtectSafetyDialog(context, primaryColor, isDark);
                  },
                ),
                Divider(color: borderColor, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Replay Welcome & Setup Tour',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'View feature animations & walkthrough again',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    soundService.playButton();
                    context.push('/onboarding');
                  },
                ),
                Divider(color: borderColor, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Developer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Sumit Kumar Dandia',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Creator',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayProtectSafetyDialog(
      BuildContext context, Color primaryColor, bool isDark) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.successGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Play Protect & Safety',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Why did Google Play Protect show a warning?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Play Protect automatically warns users whenever an APK is installed directly (sideloaded) outside the Google Play Store and signed with an open-source key.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.gray500),
              ),
              const SizedBox(height: 14),
              const Text(
                'Why ScanEx is 100% Safe:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _buildSafetyPoint(
                Icons.code_rounded,
                '100% Open Source',
                'Every single line of code is open and auditable on GitHub.',
              ),
              const SizedBox(height: 6),
              _buildSafetyPoint(
                Icons.cloud_off_rounded,
                '100% Local & Offline',
                'No remote servers or cloud databases. Data never leaves your device.',
              ),
              const SizedBox(height: 6),
              _buildSafetyPoint(
                Icons.block_rounded,
                'Zero Telemetry / Ads',
                'No tracking SDKs, no advertisement trackers, no data brokers.',
              ),
              const SizedBox(height: 14),
              const Text(
                'How to install on other devices:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'When the "Blocked by Play Protect" dialog appears -> Tap "More details" -> Tap "Install anyway".',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brightViolet),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  static Widget _buildSafetyPoint(
      IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.successGreen),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editUserName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Your Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(settingsNotifierProvider.notifier).updateUserName(newName);
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  final Color cardBg;
  final Color borderColor;
  final List<Widget> children;

  const _SettingsCard({
    required this.cardBg,
    required this.borderColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rounding = ref.watch(appCardRoundingProvider);
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rounding.radius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}
