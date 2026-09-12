import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_event.dart';

/// Wraps flutter_local_notifications to schedule weekly, repeating reminders
/// for schedule events (per-event and, via the store, "all events").
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'school_schedule_reminders',
    'Class reminders',
    description: 'Reminders before your scheduled classes',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    // Timezone setup — required for zonedSchedule.
    tzdata.initializeTimeZones();
    try {
      // flutter_timezone changed its return type across major versions:
      //   1.x  -> String (the IANA name, e.g. "Europe/Bucharest")
      //   3.x  -> TimezoneInfo (with an `identifier` field)
      // Read it as dynamic and support both shapes so we don't depend on a
      // specific version's type at compile time.
      final dynamic result = await FlutterTimezone.getLocalTimezone();
      final String localName =
          result is String ? result : (result.identifier as String);
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      // Fallback to UTC if the platform timezone can't be resolved.
      debugPrint('Could not resolve local timezone, defaulting to UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Create the Android channel up front.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _initialized = true;
  }

  /// Requests notification permission (Android 13+ and iOS).
  Future<bool> requestPermissions() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    return (androidGranted) || (iosGranted ?? false);
  }

  /// Computes the next occurrence of [weekday]/[time], then subtracts the
  /// reminder lead time. Returns a timezone-aware instant in the future.
  tz.TZDateTime _nextInstance(int weekday, SlotTime time, int minutesBefore) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    ).subtract(Duration(minutes: minutesBefore));

    // Advance to the correct weekday (DateTime.weekday: Mon=1..Sun=7).
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // If it already passed this week, push to next week.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  NotificationDetails _details() {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Schedules a weekly repeating reminder for a single event.
  Future<void> scheduleEvent(ScheduleEvent event) async {
    await init();
    // Always clear an existing schedule for this event first.
    await cancelEvent(event);

    if (!event.notificationsEnabled) return;

    final when = _nextInstance(
      event.weekday,
      event.start,
      event.reminderMinutesBefore,
    );

    final body = _buildBody(event);

    try {
      await _plugin.zonedSchedule(
        event.notificationId,
        event.title,
        body,
        when,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Repeat weekly at the same weekday/time.
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification for ${event.id}: $e');
    }
  }

  String _buildBody(ScheduleEvent event) {
    final parts = <String>[event.intervalLabel];
    if (event.location.isNotEmpty) parts.add(event.location);
    final lead = event.reminderMinutesBefore;
    final leadText = lead > 0 ? 'in $lead min' : 'now';
    return 'Starts $leadText \u2022 ${parts.join(" \u2022 ")}';
  }

  Future<void> cancelEvent(ScheduleEvent event) async {
    await init();
    await _plugin.cancel(event.notificationId);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Reschedules the full set — cancels everything then re-adds enabled events.
  Future<void> rescheduleAll(List<ScheduleEvent> events) async {
    await init();
    await cancelAll();
    for (final e in events) {
      if (e.notificationsEnabled) {
        await scheduleEvent(e);
      }
    }
  }
}
