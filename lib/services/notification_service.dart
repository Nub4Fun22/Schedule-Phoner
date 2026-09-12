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

  /// Whether the current run should play a sound. Android bakes sound into the
  /// channel at creation time, so we keep two parallel channel sets (silent and
  /// sound) and pick the right one per notification based on this flag.
  bool _soundEnabled = false;
  bool _vibrateEnabled = true;

  // --- Silent channels (no sound), increasing importance by priority --------
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

  // --- Sound channels (default system sound), same importance ladder --------
  static const AndroidNotificationChannel _chLowSound =
      AndroidNotificationChannel(
    'sp_sound_low',
    'Courses',
    description: 'Reminders for courses',
    importance: Importance.low,
  );
  static const AndroidNotificationChannel _chDefaultSound =
      AndroidNotificationChannel(
    'sp_sound_default',
    'Labs & homework',
    description: 'Reminders for labs, homework and projects',
    importance: Importance.defaultImportance,
  );
  static const AndroidNotificationChannel _chHighSound =
      AndroidNotificationChannel(
    'sp_sound_high',
    'Tests & presentations',
    description: 'Reminders for tests and presentations',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _chMaxSound =
      AndroidNotificationChannel(
    'sp_sound_max',
    'Exams',
    description: 'Reminders for exams',
    importance: Importance.max,
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
    for (final ch in [
      _chLow, _chDefault, _chHigh, _chMax, // silent set
      _chLowSound, _chDefaultSound, _chHighSound, _chMaxSound, // sound set
    ]) {
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
    // Android 13+ also gates *exact* alarms behind a separate permission.
    // Request it so scheduled reminders fire at the right time; if it's not
    // granted we fall back to inexact scheduling (see _scheduleItem).
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('requestExactAlarmsPermission not available: $e');
    }
    return androidGranted || (iosGranted ?? false);
  }

  /// Fire an immediate test notification so the user can confirm reminders
  /// work on their device. Honors the current sound/vibrate preferences.
  Future<void> showTestNotification({
    required bool sound,
    required bool vibrate,
  }) async {
    await init();
    _soundEnabled = sound;
    _vibrateEnabled = vibrate;
    // Use the "test" priority (default channel) so it's clearly visible.
    final details = _detailsForPriority(ItemType.test.priority);
    await _plugin.show(
      0x5A5A,
      'Test notification',
      sound
          ? 'Notifications are working (with sound).'
          : 'Notifications are working (silent).',
      details,
    );
  }

  /// Schedule a test notification [seconds] from now, so the user can verify
  /// that *scheduled* (not just instant) delivery works on their device.
  /// Returns null on success, or an error message string on failure — so the
  /// UI can SHOW the real error instead of the app crashing.
  Future<String?> scheduleTestNotification({
    required bool sound,
    required bool vibrate,
    int seconds = 10,
  }) async {
    try {
      await init();
      _soundEnabled = sound;
      _vibrateEnabled = vibrate;
      final details = _detailsForPriority(ItemType.test.priority);
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
      await _zonedScheduleWithFallback(
        id: 0x5A5B,
        title: 'Scheduled test',
        body: 'This was scheduled ${seconds}s ago and fired on time.',
        when: when,
        details: details,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Whether the app can post notifications (best-effort; true if unknown).
  Future<bool> areNotificationsEnabled() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  /// Whether the app is allowed to schedule EXACT alarms (Android 12+).
  /// Returns true when unknown/not applicable.
  Future<bool> canScheduleExactAlarms() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  // --- channel/details selection by priority -------------------------------

  AndroidNotificationChannel _channelForPriority(int priority) {
    if (_soundEnabled) {
      if (priority >= ItemType.exam.priority) return _chMaxSound;
      if (priority >= ItemType.test.priority) return _chHighSound;
      if (priority >= ItemType.lab.priority) return _chDefaultSound;
      return _chLowSound;
    }
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
      playSound: _soundEnabled,
      enableVibration: _vibrateEnabled,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: _soundEnabled);
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
  /// [sound]/[vibrate] come from user settings and pick the sound vs silent
  /// channel set for every scheduled notification.
  Future<void> rescheduleAll({
    required List<ScheduleItem> items,
    required List<Homework> homeworks,
    bool sound = false,
    bool vibrate = true,
  }) async {
    await init();
    _soundEnabled = sound;
    _vibrateEnabled = vibrate;
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

  /// Schedules a notification, trying exact mode first and transparently
  /// falling back to inexact if exact alarms aren't permitted (Android 13+).
  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    DateTimeComponents? matchComponents,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );

    // IMPORTANT: on Android 14+, calling exact scheduling when the
    // SCHEDULE_EXACT_ALARM permission is NOT granted throws a native
    // SecurityException that can crash the app (a Dart try/catch can't always
    // catch a native crash). So decide the mode UP FRONT by asking the OS
    // whether exact alarms are allowed, and only use exact when they are.
    AndroidScheduleMode mode;
    try {
      final exactAllowed = await canScheduleExactAlarms();
      mode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      mode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      await schedule(mode);
    } catch (e) {
      debugPrint('Schedule failed ($id) in $mode: $e');
      // Last-ditch: if we somehow tried exact and it failed, retry inexact.
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        } catch (e2) {
          debugPrint('Inexact retry also failed ($id): $e2');
        }
      }
    }
  }

  Future<void> _scheduleItem(ScheduleItem item) async {
    final details = _detailsForPriority(item.priority);
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
      await _zonedScheduleWithFallback(
        id: item.notificationId,
        title: '${item.type.label}: ${item.title}',
        body: _itemBody(item),
        when: when,
        details: details,
      );
    } else {
      final when =
          _nextWeekly(item.weekday, item.start, item.reminderMinutesBefore);
      await _zonedScheduleWithFallback(
        id: item.notificationId,
        title: '${item.type.label}: ${item.title}',
        body: _itemBody(item),
        when: when,
        details: details,
        matchComponents: DateTimeComponents.dayOfWeekAndTime,
      );
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
    await _zonedScheduleWithFallback(
      id: hw.notificationId(lab.weekday),
      title: 'Homework: ${lab.title}',
      body: body,
      when: when,
      details: details,
      matchComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
