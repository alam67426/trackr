import 'package:flutter/material.dart';

import '../models/category_model.dart';

class AppColors {
  static const teal = Color(0xFF00CEC9);
  static const purple = Color(0xFF6C5CE7);
  static const ink = Color(0xFF0C101B);
  static const panel = Color(0xFF171D2B);
  static const panelElevated = Color(0xFF202838);
  static const line = Color(0xFF303B50);
  static const muted = Color(0xFF96A2B8);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFDCB6E);
  static const success = Color(0xFF00B894);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: Brightness.dark,
          primary: AppColors.teal,
          secondary: AppColors.purple,
          surface: AppColors.panel,
        ),
        scaffoldBackgroundColor: AppColors.ink,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF111724),
          indicatorColor: Color(0x2630E7D8),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.panel,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.panelElevated,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
          labelLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: Color(0xFFD7DEEA)),
          bodySmall: TextStyle(color: AppColors.muted),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.teal, secondary: AppColors.purple),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          filled: true,
        ),
      );
}

class AppCategories {
  static const all = <ExpenseCategory>[
    ExpenseCategory(
        id: 'food',
        name: 'Food & Meals',
        icon: Icons.restaurant,
        color: Color(0xFFFF6B6B),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'groceries',
        name: 'Groceries',
        icon: Icons.shopping_cart,
        color: Color(0xFF00B894),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'rent',
        name: 'Rent',
        icon: Icons.home,
        color: Color(0xFFE17055),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'bills',
        name: 'Bills & Utilities',
        icon: Icons.lightbulb,
        color: Color(0xFFFDCB6E),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'commute',
        name: 'Transportation & Commute',
        icon: Icons.directions_transit,
        color: Color(0xFF0984E3),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'fuel',
        name: 'Fuel/Petrol',
        icon: Icons.local_gas_station,
        color: Color(0xFFE17055),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'healthcare',
        name: 'Healthcare',
        icon: Icons.local_hospital,
        color: Color(0xFF00CEC9),
        group: CategoryGroup.essentials),
    ExpenseCategory(
        id: 'shopping',
        name: 'Shopping',
        icon: Icons.shopping_bag,
        color: Color(0xFF6C5CE7),
        group: CategoryGroup.lifestyle),
    ExpenseCategory(
        id: 'entertainment',
        name: 'Entertainment',
        icon: Icons.movie,
        color: Color(0xFFFD79A8),
        group: CategoryGroup.lifestyle),
    ExpenseCategory(
        id: 'dining',
        name: 'Dining Out',
        icon: Icons.ramen_dining,
        color: Color(0xFFE17055),
        group: CategoryGroup.lifestyle),
    ExpenseCategory(
        id: 'subscriptions',
        name: 'Subscriptions',
        icon: Icons.subscriptions,
        color: Color(0xFFA29BFE),
        group: CategoryGroup.lifestyle),
    ExpenseCategory(
        id: 'fitness',
        name: 'Fitness',
        icon: Icons.fitness_center,
        color: Color(0xFF00B894),
        group: CategoryGroup.lifestyle),
    ExpenseCategory(
        id: 'friends',
        name: 'To Friends',
        icon: Icons.groups,
        color: Color(0xFF0984E3),
        group: CategoryGroup.transfers),
    ExpenseCategory(
        id: 'family',
        name: 'To Family',
        icon: Icons.family_restroom,
        color: Color(0xFFE17055),
        group: CategoryGroup.transfers),
    ExpenseCategory(
        id: 'sip',
        name: 'SIP/Investment',
        icon: Icons.trending_up,
        color: Color(0xFF00B894),
        group: CategoryGroup.transfers),
    ExpenseCategory(
        id: 'mutual_funds',
        name: 'Mutual Funds',
        icon: Icons.bar_chart,
        color: Color(0xFF6C5CE7),
        group: CategoryGroup.transfers),
    ExpenseCategory(
        id: 'insurance',
        name: 'Insurance',
        icon: Icons.shield,
        color: Color(0xFFFDCB6E),
        group: CategoryGroup.transfers),
    ExpenseCategory(
        id: 'travel',
        name: 'Travel',
        icon: Icons.flight,
        color: Color(0xFF00CEC9),
        group: CategoryGroup.transport),
    ExpenseCategory(
        id: 'parking',
        name: 'Parking',
        icon: Icons.local_parking,
        color: Color(0xFF636E72),
        group: CategoryGroup.transport),
    ExpenseCategory(
        id: 'salary',
        name: 'Salary',
        icon: Icons.payments,
        color: Color(0xFF00B894),
        group: CategoryGroup.income),
    ExpenseCategory(
        id: 'freelance',
        name: 'Freelance',
        icon: Icons.laptop_mac,
        color: Color(0xFF6C5CE7),
        group: CategoryGroup.income),
    ExpenseCategory(
        id: 'returns',
        name: 'Investment Returns',
        icon: Icons.show_chart,
        color: Color(0xFF00CEC9),
        group: CategoryGroup.income),
    ExpenseCategory(
        id: 'gift',
        name: 'Gift Received',
        icon: Icons.card_giftcard,
        color: Color(0xFFFD79A8),
        group: CategoryGroup.income),
    ExpenseCategory(
        id: 'education',
        name: 'Education',
        icon: Icons.menu_book,
        color: Color(0xFF6C5CE7),
        group: CategoryGroup.other),
    ExpenseCategory(
        id: 'emergency',
        name: 'Emergency',
        icon: Icons.emergency,
        color: Color(0xFFFF6B6B),
        group: CategoryGroup.other),
    ExpenseCategory(
        id: 'uncategorized',
        name: 'Uncategorized',
        icon: Icons.push_pin,
        color: Color(0xFF636E72),
        group: CategoryGroup.other),
  ];

  static ExpenseCategory byId(String id) => all.firstWhere(
        (category) => category.id == id,
        orElse: () => all.last,
      );
}

const savingTips = [
  'Move savings first, spend what remains.',
  'Keep UPI spends visible by reviewing pending items daily.',
  'A weekly food cap usually saves more than one big month-end cut.',
  'Use transfers for lending so repayments are easy to spot.',
  'Subscriptions deserve a monthly audit before they become background noise.',
];
