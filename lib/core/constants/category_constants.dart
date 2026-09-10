import 'package:flutter/material.dart';

import '../../shared/enums/transaction_enums.dart';
import '../../shared/models/category_model.dart';

/// Pre-seeded transaction categories for Expense and Income.
class CategoryConstants {
  CategoryConstants._();

  static const List<Category> expenseCategories = [
    Category(
      id: 'food',
      name: 'Food',
      type: TransactionType.expense,
      icon: Icons.restaurant_rounded,
      color: Color(0xFF8B35F5),
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      type: TransactionType.expense,
      icon: Icons.directions_car_rounded,
      color: Color(0xFF3B82F6),
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      type: TransactionType.expense,
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899),
    ),
    Category(
      id: 'bills',
      name: 'Bills',
      type: TransactionType.expense,
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      type: TransactionType.expense,
      icon: Icons.movie_rounded,
      color: Color(0xFF10B981),
    ),
    Category(
      id: 'health',
      name: 'Health',
      type: TransactionType.expense,
      icon: Icons.medical_services_rounded,
      color: Color(0xFFEF4444),
    ),
    Category(
      id: 'education',
      name: 'Education',
      type: TransactionType.expense,
      icon: Icons.school_rounded,
      color: Color(0xFF6366F1),
    ),
    Category(
      id: 'travel',
      name: 'Travel',
      type: TransactionType.expense,
      icon: Icons.flight_rounded,
      color: Color(0xFF14B8A6),
    ),
    Category(
      id: 'personal',
      name: 'Personal',
      type: TransactionType.expense,
      icon: Icons.person_rounded,
      color: Color(0xFFA855F7),
    ),
    Category(
      id: 'other',
      name: 'Other',
      type: TransactionType.expense,
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280),
    ),
  ];

  static const List<Category> incomeCategories = [
    Category(
      id: 'salary',
      name: 'Salary',
      type: TransactionType.income,
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF10B981),
    ),
    Category(
      id: 'freelance',
      name: 'Freelance',
      type: TransactionType.income,
      icon: Icons.laptop_mac_rounded,
      color: Color(0xFF3B82F6),
    ),
    Category(
      id: 'business',
      name: 'Business',
      type: TransactionType.income,
      icon: Icons.storefront_rounded,
      color: Color(0xFF8B35F5),
    ),
    Category(
      id: 'investment',
      name: 'Investment',
      type: TransactionType.income,
      icon: Icons.trending_up_rounded,
      color: Color(0xFFF59E0B),
    ),
    Category(
      id: 'gift',
      name: 'Gift',
      type: TransactionType.income,
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFEC4899),
    ),
    Category(
      id: 'other_income',
      name: 'Other',
      type: TransactionType.income,
      icon: Icons.attach_money_rounded,
      color: Color(0xFF6B7280),
    ),
  ];

  static List<Category> getCategoriesForType(TransactionType type) {
    return type == TransactionType.income
        ? incomeCategories
        : expenseCategories;
  }

  static Category getCategoryById(String? id, TransactionType type) {
    final list = getCategoriesForType(type);
    return list.firstWhere((c) => c.id == id, orElse: () => list.last);
  }
}
