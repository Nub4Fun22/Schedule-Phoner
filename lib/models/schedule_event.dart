import 'package:flutter/material.dart';

/// A simple time-of-day value we can serialize (hour + minute).
class SlotTime {
  final int hour;
  final int minute;

  const SlotTime(this.hour, this.minute);

  /// Minutes since midnight — handy for sorting and layout.
  int get inMinutes => hour * 60 + minute;

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  static SlotTime fromTimeOfDay(TimeOfDay t) => SlotTime(t.hour, t.minute);

  /// Formats as "08:00" (24h) — clean and unambiguous for a timetable.
  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory SlotTime.fromJson(Map<String, dynamic> json) =>
      SlotTime(json['hour'] as int, json['minute'] as int);
}

/// Weekday numbers follow DateTime: Monday = 1 ... Sunday = 7.
class Weekday {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;

  static const List<int> schoolWeek = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
  ];

  static const List<int> fullWeek = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
  ];

  static const Map<int, String> shortNames = {
    monday: 'Mon',
    tuesday: 'Tue',
    wednesday: 'Wed',
    thursday: 'Thu',
    friday: 'Fri',
    saturday: 'Sat',
    sunday: 'Sun',
  };

  static const Map<int, String> longNames = {
    monday: 'Monday',
    tuesday: 'Tuesday',
    wednesday: 'Wednesday',
    thursday: 'Thursday',
    friday: 'Friday',
    saturday: 'Saturday',
    sunday: 'Sunday',
  };

  static String short(int day) => shortNames[day] ?? '?';
  static String long(int day) => longNames[day] ?? '?';
}

/// A single class/event in the timetable.
class ScheduleEvent {
  final String id;
  final String title;
  final String description;
  final String location;

  /// DateTime weekday: 1 (Mon) .. 7 (Sun)
  final int weekday;
  final SlotTime start;
  final SlotTime end;

  /// Stored as an ARGB int so it survives serialization.
  final int colorValue;

  /// Whether a reminder is scheduled for this specific event.
  final bool notificationsEnabled;

  /// Minutes before the event start to fire the reminder.
  final int reminderMinutesBefore;

  const ScheduleEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    required this.weekday,
    required this.start,
    required this.end,
    this.colorValue = 0xFF3F51B5,
    this.notificationsEnabled = false,
    this.reminderMinutesBefore = 10,
  });

  Color get color => Color(colorValue);

  /// Duration of the event in minutes.
  int get durationMinutes => end.inMinutes - start.inMinutes;

  /// Human-friendly duration like "1h 30m" or "45m".
  String get durationLabel {
    final d = durationMinutes;
    final h = d ~/ 60;
    final m = d % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// "08:00 – 09:30"
  String get intervalLabel => '${start.format()} \u2013 ${end.format()}';

  ScheduleEvent copyWith({
    String? title,
    String? description,
    String? location,
    int? weekday,
    SlotTime? start,
    SlotTime? end,
    int? colorValue,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
  }) {
    return ScheduleEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      weekday: weekday ?? this.weekday,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'weekday': weekday,
        'start': start.toJson(),
        'end': end.toJson(),
        'colorValue': colorValue,
        'notificationsEnabled': notificationsEnabled,
        'reminderMinutesBefore': reminderMinutesBefore,
      };

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: (json['description'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        weekday: json['weekday'] as int,
        start: SlotTime.fromJson(json['start'] as Map<String, dynamic>),
        end: SlotTime.fromJson(json['end'] as Map<String, dynamic>),
        colorValue: (json['colorValue'] ?? 0xFF3F51B5) as int,
        notificationsEnabled: (json['notificationsEnabled'] ?? false) as bool,
        reminderMinutesBefore: (json['reminderMinutesBefore'] ?? 10) as int,
      );

  /// A stable integer id for notifications derived from the string id.
  int get notificationId => id.hashCode & 0x7FFFFFFF;
}
