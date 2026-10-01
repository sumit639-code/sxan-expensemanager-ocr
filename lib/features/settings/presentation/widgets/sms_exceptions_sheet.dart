import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../providers/settings_providers.dart';

/// Modal bottom sheet allowing users to customize keywords and exception phrases
/// that should be ignored during Bank SMS detection.
class SmsExceptionsSheet extends ConsumerStatefulWidget {
  const SmsExceptionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SmsExceptionsSheet(),
    );
  }

  @override
  ConsumerState<SmsExceptionsSheet> createState() => _SmsExceptionsSheetState();
}

class _SmsExceptionsSheetState extends ConsumerState<SmsExceptionsSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> _quickSuggestions = [
    'loan',
    'recharge',
    'bonus',
    'rummy',
    'dream11',
    'win',
    'lottery',
    'voucher',
    'coupon',
    'insurance',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addKeyword(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    ref.read(soundServiceProvider).playButton();
    ref.read(settingsNotifierProvider.notifier).addSmsExcludedKeyword(clean);
    _textController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsNotifierProvider);
    final soundService = ref.read(soundServiceProvider);
    final activeKeywords = settings.smsExcludedKeywords;

    final primaryColor = settings.accentColor.primary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.gray600;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBg =
        isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF8FAFC);

    return AppBottomSheet(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_list_off_rounded,
              color: Colors.amber,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SMS Filters & Exceptions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      headerTrailing: TextButton(
        onPressed: () {
          soundService.playButton();
          ref
              .read(settingsNotifierProvider.notifier)
              .resetSmsExcludedKeywords();
        },
        child: const Text('Reset', style: TextStyle(fontSize: 13)),
      ),
      maxHeightFactor: 0.88,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      bottomAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusMedium,
            ),
          ),
          onPressed: () {
            soundService.playButton();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Done',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Informational description banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5)
                  : Colors.amber.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusSmall,
              border: Border.all(
                color: isDark
                    ? borderColor
                    : Colors.amber.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextSecondary : Colors.amber[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SMS containing any of these keywords will be ignored automatically.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Input field to add custom keyword
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type keyword (e.g. bonus, rummy)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor.withValues(alpha: 0.7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: AppSpacing.borderRadiusMedium,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppSpacing.borderRadiusMedium,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppSpacing.borderRadiusMedium,
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addKeyword,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMedium,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _addKeyword(_textController.text),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick suggestions
          Row(
            children: [
              Text(
                'Suggestions:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickSuggestions.map((suggestion) {
                      final alreadyAdded = activeKeywords.any(
                        (k) => k.toLowerCase() == suggestion.toLowerCase(),
                      );
                      if (alreadyAdded) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => _addKeyword(suggestion),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.gray100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              '+ $suggestion',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active rules chip list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE RULES (${activeKeywords.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: secondaryTextColor,
                ),
              ),
              if (activeKeywords.isNotEmpty)
                Text(
                  'Tap ✕ to remove',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: activeKeywords.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No exception rules set. All bank SMS will be parsed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activeKeywords.map((kw) {
                        return Container(
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 4,
                            top: 4,
                            bottom: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.primaryPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? borderColor
                                  : AppColors.primaryPurple.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                kw,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  soundService.playButton();
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(settingsNotifierProvider.notifier)
                                      .removeSmsExcludedKeyword(kw);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.redAccent.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
