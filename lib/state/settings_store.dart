import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences, persisted with shared_preferences.
///
/// Kept separate from the schedule data so wiping items/homework never touches
/// the user's settings, and vice-versa.
class SettingsStore extends ChangeNotifier {
  static const String _kNotificationSound = 'settings_notification_sound';
  static const String _kVibrate = 'settings_notification_vibrate';
  static const String _kThemeMode = 'settings_theme_mode';
  static const String _kShowWeekend = 'settings_show_weekend_grid';
  static const String _kDefaultReminder = 'settings_default_reminder_minutes';

  bool _notificationSound = false; // silent by default (per the app spec)
  bool _vibrate = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _showWeekendInGrid = false;
  int _defaultReminderMinutes = 10;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // --- getters --------------------------------------------------------------
  /// Whether notifications play a sound. false = silent (default).
  bool get notificationSound => _notificationSound;
  bool get vibrate => _vibrate;
  ThemeMode get themeMode => _themeMode;
  bool get showWeekendInGrid => _showWeekendInGrid;
  int get defaultReminderMinutes => _defaultReminderMinutes;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationSound = prefs.getBool(_kNotificationSound) ?? false;
    _vibrate = prefs.getBool(_kVibrate) ?? true;
    _themeMode = _themeModeFromString(prefs.getString(_kThemeMode));
    _showWeekendInGrid = prefs.getBool(_kShowWeekend) ?? false;
    _defaultReminderMinutes = prefs.getInt(_kDefaultReminder) ?? 10;
    _loaded = true;
    notifyListeners();
  }

  // --- setters --------------------------------------------------------------
  Future<void> setNotificationSound(bool value) async {
    _notificationSound = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationSound, value);
  }

  Future<void> setVibrate(bool value) async {
    _vibrate = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrate, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setShowWeekendInGrid(bool value) async {
    _showWeekendInGrid = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowWeekend, value);
  }

  Future<void> setDefaultReminderMinutes(int minutes) async {
    _defaultReminderMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultReminder, minutes);
  }

  static ThemeMode _themeModeFromString(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
