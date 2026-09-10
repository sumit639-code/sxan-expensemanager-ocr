import 'package:flutter/material.dart';

import '../enums/transaction_enums.dart';

/// Category model representing transaction categories (Food, Transport, Salary, etc.).
class Category {
  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;
  final Color color;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });
}
