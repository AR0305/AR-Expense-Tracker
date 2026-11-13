import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticIntensity { off, light, medium, heavy }

class Haptics {
  static late SharedPreferences _prefs;
  static const String _hapticIntensityKey = 'haptic_intensity_level';

  static void init(SharedPreferences prefs) {
    _prefs = prefs;
  }

  static HapticIntensity get intensity {
    final val = _prefs.getInt(_hapticIntensityKey) ?? 2; // Default to medium
    return HapticIntensity.values[val];
  }

  static Future<void> setIntensity(HapticIntensity level) async {
    await _prefs.setInt(_hapticIntensityKey, level.index);
  }

  // Helper for boolean migration (if used anywhere)
  static bool get isEnabled => intensity != HapticIntensity.off;
  static Future<void> setEnabled(bool enabled) async {
    await setIntensity(enabled ? HapticIntensity.medium : HapticIntensity.off);
  }

  static void lightImpact() {
    if (intensity == HapticIntensity.off) return;
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (intensity == HapticIntensity.off) return;
    if (intensity == HapticIntensity.light) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (intensity == HapticIntensity.off) return;
    if (intensity == HapticIntensity.light) {
      HapticFeedback.lightImpact();
      return;
    }
    if (intensity == HapticIntensity.medium) {
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (intensity == HapticIntensity.off) return;
    HapticFeedback.selectionClick();
  }

  static void vibrate() {
    if (intensity == HapticIntensity.off) return;
    HapticFeedback.vibrate();
  }
}
