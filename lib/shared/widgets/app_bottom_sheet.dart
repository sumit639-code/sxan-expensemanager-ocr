import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Standard, reusable modal bottom-sheet container that guarantees content and
/// action buttons are never hidden behind Android system navigation bars,
/// gesture navigation areas, or soft keyboards.
class AppBottomSheet extends StatelessWidget {
  /// The title displayed in the sheet header.
  final Widget? title;

  /// Optional widget displayed on the left side of the header.
  final Widget? headerLeading;

  /// Optional widget displayed on the right side of the header (defaults to close button if title is present).
  final Widget? headerTrailing;

  /// Main scrollable or layout content of the bottom sheet.
  final Widget child;

  /// Bottom sticky or pinned action area (e.g. Save, Apply Filters, Reset buttons).
  final Widget? bottomAction;

  /// Content horizontal/vertical padding.
  final EdgeInsetsGeometry padding;

  /// Maximum height of the sheet as a factor of screen height (defaults to 0.90).
  final double maxHeightFactor;

  /// Whether the child is automatically wrapped in a SingleChildScrollView.
  final bool autoScroll;

  const AppBottomSheet({
    super.key,
    this.title,
    this.headerLeading,
    this.headerTrailing,
    required this.child,
    this.bottomAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.maxHeightFactor = 0.90,
    this.autoScroll = false,
  });

  /// Standard helper method to show an [AppBottomSheet].
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    bool useRootNavigator = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => builder(ctx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxScreenHeight = MediaQuery.sizeOf(context).height;

    // Dynamically calculate the real system navigation bar / gesture inset.
    // On Android edge-to-edge, viewPadding.bottom retains the navigation bar height
    // even when modal sheet routes zero out padding.bottom.
    final navBarInset = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      MediaQuery.paddingOf(context).bottom,
    );

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxScreenHeight * maxHeightFactor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle Pill
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: AppSpacing.borderRadiusPill,
                  ),
                ),
              ),

              // Header Row (if title or leading/trailing is specified)
              if (title != null || headerLeading != null || headerTrailing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                  child: Row(
                    children: [
                      if (headerLeading != null) ...[
                        headerLeading!,
                        const SizedBox(width: 8),
                      ],
                      if (title != null)
                        Expanded(
                          child: DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            child: title!,
                          ),
                        ),
                      if (headerTrailing != null)
                        headerTrailing!
                      else if (title != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),

              // Body Content
              Flexible(
                child: autoScroll
                    ? SingleChildScrollView(
                        padding: padding,
                        child: child,
                      )
                    : Padding(
                        padding: padding,
                        child: child,
                      ),
              ),

              // Bottom Action Area (with guaranteed navigation bar safe clearance)
              if (bottomAction != null)
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(top: BorderSide(color: borderColor, width: 1)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    14 + (keyboardInset == 0 ? math.max(navBarInset, 18.0) : 6),
                  ),
                  child: bottomAction!,
                )
              else if (keyboardInset == 0)
                // Safe bottom padding when there's no action button
                SizedBox(height: math.max(navBarInset, 16.0) + 8),
            ],
          ),
        ),
      ),
    );
  }
}
