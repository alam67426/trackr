import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.group,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final CategoryGroup group;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'codePoint': icon.codePoint,
        'fontFamily': icon.fontFamily,
        'color': color.value,
        'group': group.name,
      };
}

enum CategoryGroup {
  essentials,
  lifestyle,
  transfers,
  transport,
  income,
  other
}
