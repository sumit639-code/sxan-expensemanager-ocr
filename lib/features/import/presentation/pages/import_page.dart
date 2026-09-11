import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/import_providers.dart';
import '../providers/import_state.dart';
import '../views/preview_screenshots_view.dart';
import '../views/processing_screenshots_view.dart';
import '../views/review_transactions_view.dart';
import '../views/select_screenshots_view.dart';

/// Main container page for the screenshot import and extraction workflow.
class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    // Listen for completion to show feedback and navigate
    ref.listen<ImportState>(importControllerProvider, (previous, next) {
      if (next.status == ImportStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${next.importedCount} ${next.importedCount == 1 ? 'transaction' : 'transactions'} added successfully',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Reset state before navigating (provider is not autoDispose)
        controller.reset();
        // Return to Transactions list
        context.go('/transactions');
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop:
          state.status == ImportStatus.initial ||
          state.status == ImportStatus.completed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _showDiscardConfirmation(context, isDark);
        if (shouldLeave == true && context.mounted) {
          controller.reset();
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getAppBarTitle(state.status),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (state.status == ImportStatus.initial ||
                  state.status == ImportStatus.completed) {
                context.pop();
              } else {
                final shouldLeave = await _showDiscardConfirmation(
                  context,
                  isDark,
                );
                if (shouldLeave == true && context.mounted) {
                  controller.reset();
                  context.pop();
                }
              }
            },
          ),
          actions: [
            if (state.status == ImportStatus.preview)
              TextButton(
                onPressed: () => controller.reset(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.errorRed),
                ),
              ),
            if (state.status == ImportStatus.review)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Reprocess screenshots',
                onPressed: () => controller.startProcessing(),
              ),
          ],
        ),
        body: _buildCurrentView(context, state, controller),
      ),
    );
  }

  Widget _buildCurrentView(
    BuildContext context,
    ImportState state,
    ImportController controller,
  ) {
    switch (state.status) {
      case ImportStatus.initial:
        return SelectScreenshotsView(
          onSelectScreenshots: controller.pickScreenshots,
        );

      case ImportStatus.preview:
        return PreviewScreenshotsView(
          imagePaths: state.selectedImagePaths,
          onRemoveImage: controller.removeScreenshot,
          onAddMore: controller.addMoreScreenshots,
          onContinue: controller.startProcessing,
        );

      case ImportStatus.processing:
        return ProcessingScreenshotsView(
          currentStep: state.currentProcessingStep,
          progress: state.processingProgress,
          imageCount: state.selectedImagePaths.length,
        );

      case ImportStatus.review:
        return ReviewTransactionsView(
          transactions: state.extractedTransactions,
          selectedIds: state.selectedTransactionIds,
          failedImages: state.failedImagePaths,
          errors: state.errors,
          debugOcrText: state.debugOcrText,
          onToggleTransaction: controller.toggleTransactionSelection,
          onToggleSelectAll: controller.toggleSelectAll,
          onUpdateTransaction: controller.updateExtractedTransaction,
          onDeleteTransaction: controller.deleteExtractedTransaction,
          onKeepDuplicate: controller.keepDuplicate,
          onSkipDuplicate: controller.skipDuplicate,
          onConfirmImport: () => controller.confirmImport(),
          onRetry: controller.startProcessing,
          onChooseDifferentScreenshots: controller.pickScreenshots,
        );

      case ImportStatus.completed:
        return const Center(child: CircularProgressIndicator());

      case ImportStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.errorRed,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Extraction Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  state.fatalErrorMessage ??
                      'Something went wrong during import.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gray600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => controller.reset(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
    }
  }

  String _getAppBarTitle(ImportStatus status) {
    switch (status) {
      case ImportStatus.initial:
        return 'Scan History';
      case ImportStatus.preview:
        return 'Selected Screenshots';
      case ImportStatus.processing:
        return 'Processing';
      case ImportStatus.review:
        return 'Review Transactions';
      case ImportStatus.completed:
        return 'Import Complete';
      case ImportStatus.error:
        return 'Import Failed';
    }
  }

  Future<bool?> _showDiscardConfirmation(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Import?'),
        content: const Text(
          'Are you sure you want to exit? Your selected screenshots and unconfirmed transactions will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
