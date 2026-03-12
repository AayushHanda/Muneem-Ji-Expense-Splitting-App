import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> predefined = [
    ExpenseCategory(name: 'General', icon: Icons.receipt_long, color: Colors.blueGrey),
    ExpenseCategory(name: 'Food', icon: Icons.restaurant, color: Colors.orange),
    ExpenseCategory(name: 'Rent', icon: Icons.home, color: Colors.indigo),
    ExpenseCategory(name: 'Travel', icon: Icons.flight, color: Colors.lightBlue),
    ExpenseCategory(name: 'Groceries', icon: Icons.shopping_cart, color: Colors.green),
    ExpenseCategory(name: 'Entertainment', icon: Icons.movie, color: Colors.purple),
    ExpenseCategory(name: 'Utilities', icon: Icons.bolt, color: Colors.amber),
  ];

  static ExpenseCategory fromName(String name) {
    return predefined.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => predefined.first,
    );
  }
}
