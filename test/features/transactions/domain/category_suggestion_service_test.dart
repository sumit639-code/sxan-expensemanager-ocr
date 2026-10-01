import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/features/transactions/domain/services/category_suggestion_service.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';

void main() {
  group('CategorySuggestionService', () {
    test('suggests Food for Swiggy, Zomato, and restaurant keywords', () {
      final swiggy = CategorySuggestionService.suggestCategory(
        title: 'Paid to Swiggy',
        merchant: 'Swiggy Instamart',
        type: TransactionType.expense,
      );
      expect(swiggy, isNotNull);
      expect(swiggy!.categoryId, 'food');
      expect(swiggy.categoryName, 'Food');

      final zomato = CategorySuggestionService.suggestCategory(
        title: 'Dinner order',
        merchant: 'ZOMATO',
        type: TransactionType.expense,
      );
      expect(zomato, isNotNull);
      expect(zomato!.categoryId, 'food');

      final cafe = CategorySuggestionService.suggestCategory(
        title: 'Morning coffee',
        merchant: 'Blue Tokai Cafe',
        type: TransactionType.expense,
      );
      expect(cafe, isNotNull);
      expect(cafe!.categoryId, 'food');
    });

    test('suggests Transport for Uber, Ola, Rapido, and fuel', () {
      final uber = CategorySuggestionService.suggestCategory(
        title: 'Ride to office',
        merchant: 'Uber India',
        type: TransactionType.expense,
      );
      expect(uber, isNotNull);
      expect(uber!.categoryId, 'transport');

      final fuel = CategorySuggestionService.suggestCategory(
        title: 'Petrol pump',
        merchant: 'Indian Oil Fuel Station',
        type: TransactionType.expense,
      );
      expect(fuel, isNotNull);
      expect(fuel!.categoryId, 'transport');
    });

    test('suggests Shopping for Amazon and Flipkart', () {
      final amazon = CategorySuggestionService.suggestCategory(
        title: 'Purchase on Amazon.in',
        merchant: 'Amazon',
        type: TransactionType.expense,
      );
      expect(amazon, isNotNull);
      expect(amazon!.categoryId, 'shopping');

      final flipkart = CategorySuggestionService.suggestCategory(
        title: 'Order delivered',
        merchant: 'Flipkart Internet',
        type: TransactionType.expense,
      );
      expect(flipkart, isNotNull);
      expect(flipkart!.categoryId, 'shopping');
    });

    test('suggests Entertainment for Netflix, Spotify, movies', () {
      final netflix = CategorySuggestionService.suggestCategory(
        title: 'Monthly Subscription',
        merchant: 'Netflix Entertainment',
        type: TransactionType.expense,
      );
      expect(netflix, isNotNull);
      expect(netflix!.categoryId, 'entertainment');
    });

    test('suggests Salary for payroll, stipend, and earnings', () {
      final salary = CategorySuggestionService.suggestCategory(
        title: 'Monthly Salary Credit',
        merchant: 'Acme Corp Payroll',
        type: TransactionType.income,
      );
      expect(salary, isNotNull);
      expect(salary!.categoryId, 'salary');
    });

    test('suggests Freelance for Upwork, Fiverr, and clients', () {
      final gig = CategorySuggestionService.suggestCategory(
        title: 'Milestone payment',
        merchant: 'Upwork Global',
        type: TransactionType.income,
      );
      expect(gig, isNotNull);
      expect(gig!.categoryId, 'freelance');
    });

    test('suggests Investment for dividends, mutual funds, Zerodha', () {
      final inv = CategorySuggestionService.suggestCategory(
        title: 'Dividend Credit',
        merchant: 'Zerodha Broking Ltd',
        type: TransactionType.income,
      );
      expect(inv, isNotNull);
      expect(inv!.categoryId, 'investment');
    });

    test('respects word boundaries and does not trigger false positives', () {
      // "super" should not trigger "uber"
      final superStore = CategorySuggestionService.suggestCategory(
        title: 'Supermarket visit',
        merchant: 'Super store',
        type: TransactionType.expense,
      );
      // Might match shopping or null, but MUST NOT be transport
      if (superStore != null) {
        expect(superStore.categoryId, isNot('transport'));
      }
    });

    test('is whitespace and case tolerant', () {
      final messy = CategorySuggestionService.suggestCategory(
        title: '   SWIGGY    ORDER   ',
        merchant: '   swiggy   ',
        type: TransactionType.expense,
      );
      expect(messy, isNotNull);
      expect(messy!.categoryId, 'food');
    });

    test('suggestCategoryOrFallback returns other/other_income when no keywords match', () {
      final unknownExpense = CategorySuggestionService.suggestCategoryOrFallback(
        title: 'Xyz Qwerty 1234',
        type: TransactionType.expense,
      );
      expect(unknownExpense.categoryId, 'other');

      final unknownIncome = CategorySuggestionService.suggestCategoryOrFallback(
        title: 'Xyz Unknown 9999',
        type: TransactionType.income,
      );
      expect(unknownIncome.categoryId, 'other_income');
    });
  });
}
