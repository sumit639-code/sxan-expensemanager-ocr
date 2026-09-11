import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../shared/enums/transaction_enums.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';
import 'add_edit_transaction_page.dart';

/// Transaction Details View displaying item metadata, edit, and deletion actions.
class TransactionDetailsPage extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailsPage({super.key, required this.transactionId});

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This transaction will be permanently removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: AppColors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      HapticFeedback.lightImpact();
      await ref.read(deleteTransactionUseCaseProvider).execute(tx.id);
      if (!context.mounted) return;

      context.pop();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.brightViolet,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await ref.read(addTransactionUseCaseProvider).execute(tx);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final asyncTransactions = ref.watch(watchAllTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          asyncTransactions.when(
            data: (transactions) {
              final tx = transactions.firstWhere(
                (t) => t.id == transactionId,
                orElse: () => Transaction(
                  id: '',
                  type: TransactionType.expense,
                  amount: 0,
                  title: '',
                  date: DateTime.now(),
                  source: TransactionSource.manual,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              if (tx.id.isEmpty) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          AddEditTransactionPage(initialTransaction: tx),
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncTransactions.when(
          data: (transactions) {
            final tx = transactions.firstWhere(
              (t) => t.id == transactionId,
              orElse: () => Transaction(
                id: '',
                type: TransactionType.expense,
                amount: 0,
                title: '',
                date: DateTime.now(),
                source: TransactionSource.manual,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            if (tx.id.isEmpty) {
              return const Center(child: Text('Transaction not found'));
            }

            final isIncome = tx.type == TransactionType.income;
            final category = CategoryConstants.getCategoryById(
              tx.categoryId,
              tx.type,
            );
            final formattedAmount = MoneyUtils.formatMinorUnits(
              tx.amount,
              currency: tx.currency,
              symbol: '₹',
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: AppSpacing.navPillClearance,
              ),
              child: Column(
                children: [
                  // Main Amount Card Header
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isIncome
                                ? AppColors.successGreen.withValues(alpha: 0.12)
                                : AppColors.primaryPurple.withValues(
                                    alpha: 0.12,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            category.icon,
                            size: 28,
                            color: isIncome
                                ? AppColors.successGreen
                                : AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tx.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${isIncome ? '+' : '−'} $formattedAmount',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isIncome
                                ? AppColors.successGreen
                                : primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Metadata Detail Rows
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Type',
                          value: isIncome ? 'Income' : 'Expense',
                        ),
                        const Divider(height: 20),
                        _DetailRow(label: 'Category', value: category.name),
                        if (tx.merchant != null) ...[
                          const Divider(height: 20),
                          _DetailRow(label: 'Merchant', value: tx.merchant!),
                        ],
                        const Divider(height: 20),
                        _DetailRow(
                          label: 'Date',
                          value: DateFormat(
                            'EEEE, MMMM d, yyyy · h:mm a',
                          ).format(tx.date),
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          label: 'Source',
                          value: tx.source.value.toUpperCase(),
                        ),
                        if (tx.note != null && tx.note!.isNotEmpty) ...[
                          const Divider(height: 20),
                          _DetailRow(label: 'Note', value: tx.note!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Destructive Delete Button
                  AppButton.secondary(
                    label: 'Delete Transaction',
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => _confirmAndDelete(context, ref, tx),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          ),
          error: (err, stack) => const Center(
            child: Text('Something went wrong. Please try again.'),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
