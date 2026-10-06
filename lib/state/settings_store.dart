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
  static const String _kWeekAnchor = 'settings_week_anchor'; // ISO date (Monday)

  bool _notificationSound = false; // silent by default (per the app spec)
  bool _vibrate = false; // vibration OFF by default
  ThemeMode _themeMode = ThemeMode.system;
  bool _showWeekendInGrid = true; // show weekend columns by default
  int _defaultReminderMinutes = 10;

  /// Monday 00:00 of "Week 1". The current week number counts Monday-boundaries
  /// from here. Defaults to the Monday of the current week (so it reads Week 1
  /// until the user sets/resets it).
  DateTime _weekAnchor = _mondayOf(DateTime.now());

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // --- getters --------------------------------------------------------------
  /// Whether notifications play a sound. false = silent (default).
  bool get notificationSound => _notificationSound;
  bool get vibrate => _vibrate;
  ThemeMode get themeMode => _themeMode;
  bool get showWeekendInGrid => _showWeekendInGrid;
  int get defaultReminderMinutes => _defaultReminderMinutes;

  /// Monday 00:00 of Week 1.
  DateTime get weekAnchor => _weekAnchor;

  /// The current week number (1-based), counting whole weeks since the anchor's
  /// Monday. Weeks before the anchor read as 1 (clamped).
  int get currentWeekNumber => weekNumberFor(DateTime.now());

  /// Week number for an arbitrary [when], 1-based, Monday-boundaried.
  int weekNumberFor(DateTime when) {
    final startThisWeek = _mondayOf(when);
    final diffDays = startThisWeek.difference(_weekAnchor).inDays;
    final weeks = (diffDays / 7).floor();
    return weeks < 0 ? 1 : weeks + 1;
  }

  /// Monday 00:00 of the week containing [d] (local time).
  static DateTime _mondayOf(DateTime d) {
    final dayOnly = DateTime(d.year, d.month, d.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationSound = prefs.getBool(_kNotificationSound) ?? false;
    _vibrate = prefs.getBool(_kVibrate) ?? false; // OFF by default
    _themeMode = _themeModeFromString(prefs.getString(_kThemeMode));
    _showWeekendInGrid = prefs.getBool(_kShowWeekend) ?? true; // ON by default
    _defaultReminderMinutes = prefs.getInt(_kDefaultReminder) ?? 10;
    final anchorStr = prefs.getString(_kWeekAnchor);
    if (anchorStr != null) {
      try {
        _weekAnchor = _mondayOf(DateTime.parse(anchorStr));
      } catch (_) {
        _weekAnchor = _mondayOf(DateTime.now());
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Set which week is "Week 1" by picking any date in that week (snapped to
  /// its Monday).
  Future<void> setWeekAnchor(DateTime date) async {
    _weekAnchor = _mondayOf(date);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWeekAnchor, _weekAnchor.toIso8601String());
  }

  /// Reset the counter so THIS week becomes Week 1 again.
  Future<void> resetWeekCounter() async {
    await setWeekAnchor(DateTime.now());
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
