import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Modal dialog/sheet allowing users to inspect original screenshot receipts with pinch-to-zoom, pan, and multi-image navigation.
class ScreenshotViewerModal extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String? title;

  const ScreenshotViewerModal({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.title,
  });

  /// Helper to display the screenshot viewer modal dialog.
  static Future<void> show(
    BuildContext context, {
    required List<String> imagePaths,
    int initialIndex = 0,
    String? title,
  }) {
    if (imagePaths.isEmpty) return Future.value();

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => ScreenshotViewerModal(
        imagePaths: imagePaths,
        initialIndex: initialIndex,
        title: title,
      ),
    );
  }

  @override
  State<ScreenshotViewerModal> createState() => _ScreenshotViewerModalState();
}

class _ScreenshotViewerModalState extends State<ScreenshotViewerModal> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    HapticFeedback.lightImpact();
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final validPaths = widget.imagePaths.where((p) => p.isNotEmpty).toList();
    if (validPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalImages = validPaths.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Center interactive zoomable image area
            Center(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalImages,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentIndex = index;
                    _resetZoom();
                  });
                },
                itemBuilder: (context, index) {
                  final imgFile = File(validPaths[index]);
                  if (!imgFile.existsSync()) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          borderRadius: AppSpacing.borderRadiusLarge,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: AppColors.errorRed,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Image file not found on device',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              validPaths[index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GestureDetector(
                    onDoubleTap: () {
                      if (_transformController.value != Matrix4.identity()) {
                        _resetZoom();
                      } else {
                        HapticFeedback.lightImpact();
                        _transformController.value = Matrix4.identity()
                          ..scale(2.2);
                      }
                    },
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.8,
                      maxScale: 4.5,
                      clipBehavior: Clip.none,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              imgFile,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title / Index badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title ??
                              (totalImages > 1
                                  ? 'Receipt ${_currentIndex + 1} of $totalImages'
                                  : 'Original Receipt Screenshot'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions: Reset Zoom + Close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reset Zoom',
                        icon: const Icon(Icons.zoom_out_map_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.60),
                        ),
                        onPressed: _resetZoom,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.60),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Navigation Dots (if multiple images)
            if (totalImages > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalImages, (index) {
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
