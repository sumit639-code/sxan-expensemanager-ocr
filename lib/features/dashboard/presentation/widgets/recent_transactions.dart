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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 58, color: Colors.transparent),
            itemBuilder: (context, index) {
              final item = transactions[index];
              return TransactionTile(
                transaction: item,
                onTap: () {
                  context.push('/transactions/${item.id}');
                },
              );
            },
          ),
      ],
    );
  }
}
