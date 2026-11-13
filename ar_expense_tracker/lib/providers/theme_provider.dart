import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

// Provide SharedPreferences synchronously after initializing it in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider was not initialized');
});

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeIndex = prefs.getInt('theme_mode');
    if (themeIndex == null) return ThemeMode.system;
    
    return ThemeMode.values[themeIndex];
  }

  void toggleTheme() {
    final prefs = ref.read(sharedPreferencesProvider);
    final nextMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = nextMode;
    prefs.setInt('theme_mode', state.index);
  }

  void setTheme(ThemeMode mode) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = mode;
    prefs.setInt('theme_mode', mode.index);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

// App Color Provider
class AppColorNotifier extends Notifier<Color> {
  static const defaultColor = Color(0xFF10B981); // Emerald Green

  @override
  Color build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final colorValue = prefs.getInt('app_seed_color');
    return colorValue != null ? Color(colorValue) : defaultColor;
  }

  void setColor(Color color) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = color;
    // ignore: deprecated_member_use
    await prefs.setInt('app_seed_color', color.value);

    // Update native home widget color theme
    // ignore: deprecated_member_use
    await HomeWidget.saveWidgetData<int>('primary_color', color.value);
    await HomeWidget.updateWidget(androidName: 'AddExpenseWidgetProvider');
  }
}

final appColorProvider = NotifierProvider<AppColorNotifier, Color>(() {
  return AppColorNotifier();
});

// Icon Shape Provider
enum AppIconShape {
  circle,
  square,
  rounded,
  squircle,
  hexagon,
  octagon,
  pentagon,
  diamond,
  star,
  beveled,
  teardrop,
  flower,
  flower2,
  flower3,
  wavy,
  shield,
  ticket,
  pill,
  triangle,
  cross,
  polygon10,
  polygon12,
  burst,
  badge,
}

class IconShapeNotifier extends Notifier<AppIconShape> {
  @override
  AppIconShape build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final val = prefs.getInt('app_icon_shape') ?? 0;
    return AppIconShape.values[val];
  }

  void setShape(AppIconShape shape) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = shape;
    prefs.setInt('app_icon_shape', shape.index);
  }
}

final isAmoledProvider = NotifierProvider<AmoledNotifier, bool>(() => AmoledNotifier());

class AmoledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('app_is_amoled') ?? false;
  }

  void setAmoled(bool value) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = value;
    prefs.setBool('app_is_amoled', value);
  }
}

final iconShapeProvider = NotifierProvider<IconShapeNotifier, AppIconShape>(() {
  return IconShapeNotifier();
});

// Title Font Provider
class TitleFontNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('title_font_family') ?? 'Mea Culpa';
  }

  void setFont(String fontName) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = fontName;
    prefs.setString('title_font_family', fontName);
  }
}

final titleFontProvider = NotifierProvider<TitleFontNotifier, String>(() {
  return TitleFontNotifier();
});

// Body Font Provider
class BodyFontNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('body_font_family') ?? 'Elms Sans';
  }

  void setFont(String fontName) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = fontName;
    prefs.setString('body_font_family', fontName);
  }
}

final bodyFontProvider = NotifierProvider<BodyFontNotifier, String>(() {
  return BodyFontNotifier();
});

