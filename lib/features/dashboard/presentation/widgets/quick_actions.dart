import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Row of 4 quick action buttons (Add, Scan, Analytics, More).
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  void _showMoreBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.gray300,
                    borderRadius: AppSpacing.borderRadiusPill,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Quick Utilities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primaryPurple,
                  ),
                ),
                title: const Text(
                  'Export Data (CSV)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Export all transactions in Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brightViolet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.brightViolet,
                  ),
                ),
                title: const Text(
                  'App Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Themes, currency & preferences'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.filter_list_rounded,
                    color: AppColors.successGreen,
                  ),
                ),
                title: const Text(
                  'Filter History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Advanced search and date filters'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/transactions');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: 'Add',
          icon: Icons.add_rounded,
          onTap: () => context.push('/add'),
        ),
        _ActionButton(
          label: 'Scan',
          icon: Icons.document_scanner_rounded,
          isHighlight: true,
          onTap: () => context.push('/import'),
        ),
        _ActionButton(
          label: 'Analytics',
          icon: Icons.bar_chart_rounded,
          onTap: () => context.push('/insights'),
        ),
        _ActionButton(
          label: 'More',
          icon: Icons.more_horiz_rounded,
          onTap: () => _showMoreBottomSheet(context),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlight;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final bg = isHighlight
        ? const LinearGradient(
            colors: [AppColors.brightViolet, AppColors.primaryPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final containerColor = isHighlight
        ? null
        : (isDark ? AppColors.darkSurface : AppColors.white);

    final border = isHighlight
        ? null
        : Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          );

    final iconColor = isHighlight ? AppColors.white : AppColors.primaryPurple;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppSpacing.borderRadiusMedium,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: bg,
                color: containerColor,
                border: border,
                borderRadius: AppSpacing.borderRadiusMedium,
                boxShadow: isHighlight
                    ? [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }
}
