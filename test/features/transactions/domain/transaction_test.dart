import 'package:expense_app/core/utils/money_utils.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyUtils tests', () {
    test('converts double to minor units correctly', () {
      expect(MoneyUtils.doubleToMinorUnits(320.50), 32050);
      expect(MoneyUtils.doubleToMinorUnits(0.99), 99);
      expect(MoneyUtils.doubleToMinorUnits(100.00), 10000);
    });

    test('converts minor units to double correctly', () {
      expect(MoneyUtils.minorUnitsToDouble(32050), 320.50);
      expect(MoneyUtils.minorUnitsToDouble(99), 0.99);
      expect(MoneyUtils.minorUnitsToDouble(10000), 100.00);
    });

    test('formats minor units to currency string', () {
      final formatted = MoneyUtils.formatMinorUnits(
        32050,
        currency: 'INR',
        symbol: '₹',
      );
      expect(formatted.contains('320.50'), isTrue);
    });
  });

  group('Transaction entity tests', () {
    test('supports copyWith and equality', () {
      final now = DateTime.now();
      final tx1 = Transaction(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 5000000,
        title: 'Salary',
        date: now,
        source: TransactionSource.import,
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = tx1.copyWith(amount: 5500000);
      expect(tx2.amount, 5500000);
      expect(tx2.id, tx1.id);
      expect(tx2.title, tx1.title);
    });
  });
}
