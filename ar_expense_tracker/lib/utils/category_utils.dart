import 'package:flutter/material.dart';
import '../database/expense_database.dart';

class CategoryUtils {
  static final List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Food & Dining', 'icon': Icons.restaurant_rounded, 'color': Colors.orange.shade700},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_rounded, 'color': Colors.purple.shade600},
    {'name': 'Transportation', 'icon': Icons.directions_car_rounded, 'color': Colors.blue.shade600},
    {'name': 'Bills & Utilities', 'icon': Icons.receipt_rounded, 'color': Colors.red.shade600},
    {'name': 'Entertainment', 'icon': Icons.movie_creation_rounded, 'color': Colors.pink.shade600},
    {'name': 'Health & Medical', 'icon': Icons.local_hospital_rounded, 'color': Colors.teal.shade600},
    {'name': 'Travel', 'icon': Icons.flight_rounded, 'color': Colors.indigo.shade600},
  ];

  static Widget getIconWidget(String categoryName, List<CustomCategory> customCats, {double size = 20, Color? color}) {
    // Check defaults
    final def = defaultCategories.firstWhere((c) => c['name'] == categoryName, orElse: () => {});
    if (def.isNotEmpty) {
      return Icon(
        def['icon'] as IconData,
        size: size,
        color: color ?? def['color'] as Color,
      );
    }

    // Check customs (use emoji text)
    final custom = customCats.where((c) => c.name == categoryName).firstOrNull;
    if (custom != null) {
      final customColor = custom.colorValue == 0 ? Colors.blueGrey.shade600 : Color(custom.colorValue);
      return Text(
        custom.iconName, // this now stores the emoji string
        style: TextStyle(
          fontSize: size * 0.8, // Slightly adjust size to align well with standard icons
          color: color ?? customColor,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Icon(
      Icons.category_rounded,
      size: size,
      color: color ?? Colors.blueGrey,
    );
  }

  static Color getColor(String categoryName, List<CustomCategory> customCats) {
    // Check defaults
    final def = defaultCategories.firstWhere((c) => c['name'] == categoryName, orElse: () => {});
    if (def.isNotEmpty) return def['color'] as Color;

    // Check customs
    final custom = customCats.where((c) => c.name == categoryName).firstOrNull;
    if (custom != null) {
      return custom.colorValue == 0 ? Colors.blueGrey.shade600 : Color(custom.colorValue);
    }

    return Colors.blueGrey.shade600;
  }
}
