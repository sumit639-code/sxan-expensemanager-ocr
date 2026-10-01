import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_section_title.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import 'dashboard_empty_state.dart';
import 'transaction_tile.dart';

/// Section rendering recent transactions list with "See all" navigation or empty state card.
class RecentTransactions extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onAddFirstPressed;

  const RecentTransactions({
    super.key,
    required this.transactions,
    this.onAddFirstPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: 'Recent Transactions',
          trailing: transactions.isNotEmpty
              ? AppButton.text(
                  label: 'See all',
                  onPressed: () => context.push('/transactions'),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          DashboardEmptyState(onAddFirstPressed: onAddFirstPressed)
        else
          Column(
            children: [
              for (int i = 0; i < transactions.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 58, color: Colors.transparent),
                TransactionTile(
                  transaction: transactions[i],
                  onTap: () {
                    context.push('/transactions/${transactions[i].id}');
                  },
                ),
              ],
            ],
          ),
      ],
    );
  }
}
