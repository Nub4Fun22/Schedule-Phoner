import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_item.dart';

/// Handles all local notifications.
///
/// Design points (per the app spec):
/// * ALL notifications are SILENT (no sound) — we create channels with
///   `playSound: false` and a null sound.
/// * Notification importance is derived from item priority (higher priority
///   => more prominent channel).
/// * Weekly items repeat weekly; one-time items fire once.
/// * Homework reminders fire before EACH weekly occurrence of their lab and
///   repeat weekly, but only while the homework is not done and not past due.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Four silent channels of increasing importance, chosen by item priority.
  // (Android bakes sound/importance into the channel at creation time.)
  static const AndroidNotificationChannel _chLow = AndroidNotificationChannel(
    'sp_silent_low',
    'Courses (silent)',
    description: 'Silent reminders for courses',
    importance: Importance.low,
    playSound: false,
  );
  static const AndroidNotificationChannel _chDefault =
      AndroidNotificationChannel(
    'sp_silent_default',
    'Labs & homework (silent)',
    description: 'Silent reminders for labs, homework and projects',
    importance: Importance.defaultImportance,
    playSound: false,
  );
  static const AndroidNotificationChannel _chHigh = AndroidNotificationChannel(
    'sp_silent_high',
    'Tests & presentations (silent)',
    description: 'Silent reminders for tests and presentations',
    importance: Importance.high,
    playSound: false,
  );
  static const AndroidNotificationChannel _chMax = AndroidNotificationChannel(
    'sp_silent_max',
    'Exams (silent)',
    description: 'Silent reminders for exams',
    importance: Importance.max,
    playSound: false,
  );

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      // flutter_timezone: 1.x returns String, 3.x returns TimezoneInfo.
      final dynamic result = await FlutterTimezone.getLocalTimezone();
      final String localName =
          result is String ? result : (result.identifier as String);
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
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

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final ch in [_chLow, _chDefault, _chHigh, _chMax]) {
      await android?.createNotificationChannel(ch);
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: false);
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    return androidGranted || (iosGranted ?? false);
  }

  // --- channel/details selection by priority -------------------------------

  AndroidNotificationChannel _channelForPriority(int priority) {
    if (priority >= ItemType.exam.priority) return _chMax;
    if (priority >= ItemType.test.priority) return _chHigh;
    if (priority >= ItemType.lab.priority) return _chDefault;
    return _chLow;
  }

  NotificationDetails _detailsForPriority(int priority) {
    final ch = _channelForPriority(priority);
    final androidDetails = AndroidNotificationDetails(
      ch.id,
      ch.name,
      channelDescription: ch.description,
      importance: ch.importance,
      priority: _androidPriority(priority),
      playSound: false, // silent
    );
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Priority _androidPriority(int priority) {
    if (priority >= ItemType.exam.priority) return Priority.max;
    if (priority >= ItemType.test.priority) return Priority.high;
    if (priority >= ItemType.lab.priority) return Priority.defaultPriority;
    return Priority.low;
  }

  // --- scheduling helpers ---------------------------------------------------

  tz.TZDateTime _tz(DateTime dt) => tz.TZDateTime.from(dt, tz.local);

  /// Next weekly instance of [weekday]/[time] minus [minutesBefore].
  tz.TZDateTime _nextWeekly(int weekday, SlotTime time, int minutesBefore) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    ).subtract(Duration(minutes: minutesBefore));
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  String _itemBody(ScheduleItem item) {
    final parts = <String>[item.intervalLabel];
    if (item.location.isNotEmpty) parts.add(item.location);
    final lead = item.reminderMinutesBefore;
    final leadText = lead > 0 ? 'in $lead min' : 'now';
    return '${item.type.label} \u2022 starts $leadText \u2022 ${parts.join(" \u2022 ")}';
  }

  // --- public API -----------------------------------------------------------

  /// Cancels everything and reschedules all enabled items + active homeworks.
  Future<void> rescheduleAll({
    required List<ScheduleItem> items,
    required List<Homework> homeworks,
  }) async {
    await init();
    await _plugin.cancelAll();

    for (final item in items) {
      if (item.notificationsEnabled) {
        await _scheduleItem(item);
      }
    }

    // Homework reminders are tied to their lab's weekly occurrences.
    final now = DateTime.now();
    for (final hw in homeworks) {
      if (hw.done) continue;
      if (hw.dueDate.isBefore(now)) continue; // past due -> stop nagging
      ScheduleItem? lab;
      for (final it in items) {
        if (it.id == hw.labId) {
          lab = it;
          break;
        }
      }
      if (lab == null || lab.oneTime) continue;
      await _scheduleHomework(hw, lab);
    }
  }

  Future<void> _scheduleItem(ScheduleItem item) async {
    final details = _detailsForPriority(item.priority);
    try {
      if (item.oneTime) {
        if (item.date == null) return;
        final when = _tz(DateTime(
          item.date!.year,
          item.date!.month,
          item.date!.day,
          item.start.hour,
          item.start.minute,
        ).subtract(Duration(minutes: item.reminderMinutesBefore)));
        if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
        await _plugin.zonedSchedule(
          item.notificationId,
          '${item.type.label}: ${item.title}',
          _itemBody(item),
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        final when = _nextWeekly(
            item.weekday, item.start, item.reminderMinutesBefore);
        await _plugin.zonedSchedule(
          item.notificationId,
          '${item.type.label}: ${item.title}',
          _itemBody(item),
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      debugPrint('Failed to schedule item ${item.id}: $e');
    }
  }

  /// Homework reminder: fires before each weekly occurrence of its lab and
  /// repeats weekly (matchDateTimeComponents), using the homework's own lead
  /// time (default 1 day). The store only passes not-done, not-past-due
  /// homeworks here, so marking done / passing the due date stops it after the
  /// next reschedule.
  Future<void> _scheduleHomework(Homework hw, ScheduleItem lab) async {
    // Homework shares Project priority (default channel).
    final details = _detailsForPriority(hw.priority);
    final when =
        _nextWeekly(lab.weekday, lab.start, hw.reminderMinutesBeforeLab);

    // If the next reminder would land after the due date, don't schedule.
    final due = tz.TZDateTime.from(hw.dueDate, tz.local);
    if (when.isAfter(due)) return;

    final desc = hw.description.isNotEmpty ? hw.description : 'Homework due';
    final body =
        '$desc \u2022 due ${_formatDate(hw.dueDate)} \u2022 for ${lab.title} lab';
    try {
      await _plugin.zonedSchedule(
        hw.notificationId(lab.weekday),
        'Homework: ${lab.title}',
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule homework ${hw.id}: $e');
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
