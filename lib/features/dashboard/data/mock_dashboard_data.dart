import '../../../shared/enums/transaction_enums.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../domain/models/dashboard_summary.dart';

/// Isolated mock dataset for Phase 3 UI design.
class MockDashboardData {
  MockDashboardData._();

  static final DateTime _now = DateTime.now();

  static final List<Transaction> mockTransactions = [
    Transaction(
      id: 'mock-1',
      type: TransactionType.expense,
      amount: 32000, // ₹320.00
      currency: 'INR',
      title: 'Lunch',
      merchant: 'Food & Dining',
      categoryId: 'food',
      date: _now,
      source: TransactionSource.manual,
      createdAt: _now,
      updatedAt: _now,
    ),
    Transaction(
      id: 'mock-2',
      type: TransactionType.expense,
      amount: 24500, // ₹245.00
      currency: 'INR',
      title: 'Uber Ride',
      merchant: 'Transport',
      categoryId: 'transport',
      date: _now.subtract(const Duration(hours: 4)),
      source: TransactionSource.manual,
      createdAt: _now,
      updatedAt: _now,
    ),
    Transaction(
      id: 'mock-3',
      type: TransactionType.expense,
      amount: 184000, // ₹1,840.00
      currency: 'INR',
      title: 'Supermarket Groceries',
      merchant: 'Shopping',
      categoryId: 'shopping',
      date: _now.subtract(const Duration(days: 1)),
      source: TransactionSource.screenshot,
      createdAt: _now,
      updatedAt: _now,
    ),
    Transaction(
      id: 'mock-4',
      type: TransactionType.income,
      amount: 7250000, // ₹72,500.00
      currency: 'INR',
      title: 'Monthly Salary',
      merchant: 'Employer Inc',
      categoryId: 'income',
      date: DateTime(_now.year, _now.month, 1),
      source: TransactionSource.import,
      createdAt: _now,
      updatedAt: _now,
    ),
  ];

  static final DashboardSummary mockSummary = DashboardSummary(
    totalBalance: 4826000, // ₹48,260.00
    incomeTotal: 7250000, // ₹72,500.00
    expenseTotal: 2424000, // ₹24,240.00
    monthlyChangePercentage: 12.0,
    recentTransactions: mockTransactions,
  );
}
