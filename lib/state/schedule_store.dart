import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sample_schedule.dart';
import '../models/schedule_event.dart';
import '../services/notification_service.dart';

/// Central state: holds the list of events, persists them, and keeps
/// notifications in sync. Exposed to the UI via provider (ChangeNotifier).
class ScheduleStore extends ChangeNotifier {
  static const String _eventsKey = 'events_v1';
  static const String _seededKey = 'seeded_v1';

  final NotificationService _notifications;

  List<ScheduleEvent> _events = [];
  bool _loading = true;

  ScheduleStore({NotificationService? notifications})
      : _notifications = notifications ?? NotificationService.instance;

  bool get isLoading => _loading;

  /// All events, sorted by weekday then start time.
  List<ScheduleEvent> get events {
    final list = [..._events];
    list.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      return a.start.inMinutes.compareTo(b.start.inMinutes);
    });
    return list;
  }

  /// Events for a specific weekday (Mon=1..Sun=7), sorted by start time.
  List<ScheduleEvent> eventsForDay(int weekday) {
    final list = _events.where((e) => e.weekday == weekday).toList();
    list.sort((a, b) => a.start.inMinutes.compareTo(b.start.inMinutes));
    return list;
  }

  /// True if every event currently has notifications enabled (and there is
  /// at least one event).
  bool get allNotificationsEnabled =>
      _events.isNotEmpty && _events.every((e) => e.notificationsEnabled);

  /// True if at least one event has notifications enabled.
  bool get anyNotificationsEnabled =>
      _events.any((e) => e.notificationsEnabled);

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(_seededKey) ?? false;
    final raw = prefs.getString(_eventsKey);

    if (!seeded || raw == null) {
      _events = SampleSchedule.build();
      await _persist();
      await prefs.setBool(_seededKey, true);
    } else {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _events = decoded
            .map((e) => ScheduleEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to parse stored events, reseeding: $e');
        _events = SampleSchedule.build();
        await _persist();
      }
    }

    _loading = false;
    notifyListeners();

    // Make sure scheduled notifications match persisted state.
    await _notifications.rescheduleAll(_events);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, raw);
  }

  ScheduleEvent? byId(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> addOrUpdate(ScheduleEvent event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      _events[index] = event;
    } else {
      _events.add(event);
    }
    await _persist();
    notifyListeners();
    await _notifications.scheduleEvent(event);
  }

  Future<void> delete(String id) async {
    final event = byId(id);
    _events.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
    if (event != null) {
      await _notifications.cancelEvent(event);
    }
  }

  /// Toggle notifications for a single event.
  Future<void> setEventNotifications(String id, bool enabled) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index < 0) return;
    _events[index] =
        _events[index].copyWith(notificationsEnabled: enabled);
    await _persist();
    notifyListeners();
    await _notifications.scheduleEvent(_events[index]);
  }

  /// Toggle notifications for ALL events at once.
  Future<void> setAllNotifications(bool enabled) async {
    _events = _events
        .map((e) => e.copyWith(notificationsEnabled: enabled))
        .toList();
    await _persist();
    notifyListeners();
    await _notifications.rescheduleAll(_events);
  }

  /// Reset back to the bundled sample schedule.
  Future<void> resetToSample() async {
    _events = SampleSchedule.build();
    await _persist();
    notifyListeners();
    await _notifications.rescheduleAll(_events);
  }
}
