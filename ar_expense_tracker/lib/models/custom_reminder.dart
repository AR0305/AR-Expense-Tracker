import 'dart:convert';
import 'package:flutter/material.dart';

class CustomReminder {
  final String id;
  final String title;
  final int hour;
  final int minute;
  final bool isEnabled;

  const CustomReminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
  });

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String formatTime(BuildContext context) {
    return timeOfDay.format(context);
  }

  CustomReminder copyWith({
    String? id,
    String? title,
    int? hour,
    int? minute,
    bool? isEnabled,
  }) {
    return CustomReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hour': hour,
        'minute': minute,
        'isEnabled': isEnabled,
      };

  factory CustomReminder.fromJson(Map<String, dynamic> json) => CustomReminder(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Expense Reminder',
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  static String encodeList(List<CustomReminder> list) {
    return jsonEncode(list.map((item) => item.toJson()).toList());
  }

  static List<CustomReminder> decodeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((item) => CustomReminder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
