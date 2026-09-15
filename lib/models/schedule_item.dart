import 'package:flutter/material.dart';

// ============================================================================
// Time + weekday primitives
// ============================================================================

/// A serializable time-of-day (hour + minute).
class SlotTime {
  final int hour;
  final int minute;

  const SlotTime(this.hour, this.minute);

  int get inMinutes => hour * 60 + minute;

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);
  static SlotTime fromTimeOfDay(TimeOfDay t) => SlotTime(t.hour, t.minute);

  /// "08:00"
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};
  factory SlotTime.fromJson(Map<String, dynamic> j) =>
      SlotTime(j['hour'] as int, j['minute'] as int);
}

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

  static const Map<int, String> _short = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };
  static const Map<int, String> _long = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  static String short(int d) => _short[d] ?? '?';
  static String long(int d) => _long[d] ?? '?';
}

// ============================================================================
// Item types + priority
// ============================================================================

/// The kind of academic item. Order of declaration is NOT the priority order —
/// priority is defined explicitly in [ItemTypeX.priority].
enum ItemType {
  course,
  lab,
  test,
  project,
  projectPresentation,
  exam,
  event,
  seminar,
}

extension ItemTypeX on ItemType {
  /// Priority (higher = more important). Requested order (low -> high):
  /// Course < Lab < (Homework = Project) < Test < Presentation < Exam.
  /// Homework is a separate entity but shares Project's priority (=30).
  int get priority {
    switch (this) {
      case ItemType.course:
        return 10;
      case ItemType.lab:
        return 20;
      case ItemType.project:
        return 30; // == homework
      case ItemType.test:
        return 40;
      case ItemType.projectPresentation:
        return 50;
      case ItemType.exam:
        return 60;
      case ItemType.event:
        return 5; // personal reminder — below academic items
      case ItemType.seminar:
        return 20; // 1:1 with Lab
    }
  }

  String get label {
    switch (this) {
      case ItemType.course:
        return 'Course';
      case ItemType.lab:
        return 'Lab';
      case ItemType.test:
        return 'Test';
      case ItemType.project:
        return 'Project';
      case ItemType.projectPresentation:
        return 'Project presentation';
      case ItemType.exam:
        return 'Exam';
      case ItemType.event:
        return 'Event';
      case ItemType.seminar:
        return 'Seminar';
    }
  }

  IconData get icon {
    switch (this) {
      case ItemType.course:
        return Icons.menu_book_outlined;
      case ItemType.lab:
        return Icons.science_outlined;
      case ItemType.test:
        return Icons.quiz_outlined;
      case ItemType.project:
        return Icons.build_outlined;
      case ItemType.projectPresentation:
        return Icons.co_present_outlined;
      case ItemType.exam:
        return Icons.emoji_events_outlined;
      case ItemType.event:
        return Icons.event_note_outlined;
      case ItemType.seminar:
        return Icons.groups_outlined;
    }
  }

  /// Whether this type is inherently a one-time event only (uses a date).
  bool get isOneTimeOnly =>
      this == ItemType.exam || this == ItemType.projectPresentation;

  /// Whether this type is always a recurring weekly event.
  bool get isWeeklyOnly =>
      this == ItemType.course ||
      this == ItemType.lab ||
      this == ItemType.seminar;

  /// Whether this type carries homework (Lab and Seminar are 1:1).
  bool get carriesHomework =>
      this == ItemType.lab || this == ItemType.seminar;

  /// Whether this type can be either one-time or weekly (user chooses).
  bool get supportsBothModes =>
      this == ItemType.test ||
      this == ItemType.project ||
      this == ItemType.event;

  /// Whether this type must be linked to a specific Lab.
  bool get requiresLabLink => this == ItemType.project;

  /// Whether this type can carry attached "tasks" (like a Lab carries homework,
  /// an Event carries tasks). Only weekly instances get recurring task
  /// reminders; the editor guides the user accordingly.
  bool get canCarryTasks => this == ItemType.event;

  String get storageKey => name;

  static ItemType fromKey(String key) =>
      ItemType.values.firstWhere((e) => e.name == key,
          orElse: () => ItemType.course);
}

/// Priority shared by Homework (mirrors Project's priority).
const int kHomeworkPriority = 30;

// ============================================================================
// Homework — a sub-entity that must be attached to a Lab item.
// ============================================================================

class Homework {
  final String id;

  /// The Lab item this homework belongs to. Homework can't exist without it.
  final String labId;

  /// Optional free text describing the assignment.
  final String description;

  /// When it's due.
  final DateTime dueDate;

  /// Whether the user has marked it done (stops the recurring nagging).
  final bool done;

  /// Minutes before each lab occurrence to remind. Default = 1 day (1440 min).
  final int reminderMinutesBeforeLab;

  /// If true, instead of reminding once before each lab occurrence, remind
  /// EVERY DAY at [dailyReminderTime] until the lab (i.e. until the due date /
  /// next lab passes).
  final bool dailyUntil;

  /// The time-of-day for the daily reminder (used only when [dailyUntil]).
  final SlotTime? dailyReminderTime;

  const Homework({
    required this.id,
    required this.labId,
    this.description = '',
    required this.dueDate,
    this.done = false,
    this.reminderMinutesBeforeLab = 24 * 60,
    this.dailyUntil = false,
    this.dailyReminderTime,
  });

  int get priority => kHomeworkPriority;

  bool get isOverdue => !done && dueDate.isBefore(DateTime.now());

  Homework copyWith({
    String? description,
    DateTime? dueDate,
    bool? done,
    int? reminderMinutesBeforeLab,
    bool? dailyUntil,
    SlotTime? dailyReminderTime,
  }) =>
      Homework(
        id: id,
        labId: labId,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        done: done ?? this.done,
        reminderMinutesBeforeLab:
            reminderMinutesBeforeLab ?? this.reminderMinutesBeforeLab,
        dailyUntil: dailyUntil ?? this.dailyUntil,
        dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'labId': labId,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'done': done,
        'reminderMinutesBeforeLab': reminderMinutesBeforeLab,
        'dailyUntil': dailyUntil,
        'dailyReminderTime': dailyReminderTime?.toJson(),
      };

  factory Homework.fromJson(Map<String, dynamic> j) => Homework(
        id: j['id'] as String,
        labId: j['labId'] as String,
        description: (j['description'] ?? '') as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        done: (j['done'] ?? false) as bool,
        reminderMinutesBeforeLab:
            (j['reminderMinutesBeforeLab'] ?? 24 * 60) as int,
        dailyUntil: (j['dailyUntil'] ?? false) as bool,
        dailyReminderTime: j['dailyReminderTime'] != null
            ? SlotTime.fromJson(j['dailyReminderTime'] as Map<String, dynamic>)
            : null,
      );

  /// Stable notification id namespace for homework-before-lab reminders.
  int notificationId(int weekdayOccurrence) =>
      ('hw_$id\_$weekdayOccurrence').hashCode & 0x7FFFFFFF;

  /// Notification id namespace for the daily "until lab" reminder.
  int get dailyNotificationId => ('hw_daily_$id').hashCode & 0x7FFFFFFF;
}

// ============================================================================
// Task — a sub-entity attached to an Event (the personal-reminder analogue of
// Homework attached to a Lab). E.g. Event "Chores" with a Task "do dishes".
// ============================================================================

/// Priority shared by Tasks (mirrors the Event's low personal priority).
const int kTaskPriority = 5;

class Task {
  final String id;

  /// The Event item this task belongs to. A task can't exist without it.
  final String eventId;

  /// Optional free text describing the task.
  final String description;

  /// When it's due.
  final DateTime dueDate;

  /// Whether the user has marked it done (stops recurring reminders).
  final bool done;

  /// Minutes before each event occurrence to remind. Default = 1 day.
  final int reminderMinutesBeforeEvent;

  /// If true, remind EVERY DAY at [dailyReminderTime] until the event.
  final bool dailyUntil;

  /// The time-of-day for the daily reminder (used only when [dailyUntil]).
  final SlotTime? dailyReminderTime;

  const Task({
    required this.id,
    required this.eventId,
    this.description = '',
    required this.dueDate,
    this.done = false,
    this.reminderMinutesBeforeEvent = 24 * 60,
    this.dailyUntil = false,
    this.dailyReminderTime,
  });

  int get priority => kTaskPriority;

  bool get isOverdue => !done && dueDate.isBefore(DateTime.now());

  Task copyWith({
    String? description,
    DateTime? dueDate,
    bool? done,
    int? reminderMinutesBeforeEvent,
    bool? dailyUntil,
    SlotTime? dailyReminderTime,
  }) =>
      Task(
        id: id,
        eventId: eventId,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        done: done ?? this.done,
        reminderMinutesBeforeEvent:
            reminderMinutesBeforeEvent ?? this.reminderMinutesBeforeEvent,
        dailyUntil: dailyUntil ?? this.dailyUntil,
        dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'done': done,
        'reminderMinutesBeforeEvent': reminderMinutesBeforeEvent,
        'dailyUntil': dailyUntil,
        'dailyReminderTime': dailyReminderTime?.toJson(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        description: (j['description'] ?? '') as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        done: (j['done'] ?? false) as bool,
        reminderMinutesBeforeEvent:
            (j['reminderMinutesBeforeEvent'] ?? 24 * 60) as int,
        dailyUntil: (j['dailyUntil'] ?? false) as bool,
        dailyReminderTime: j['dailyReminderTime'] != null
            ? SlotTime.fromJson(j['dailyReminderTime'] as Map<String, dynamic>)
            : null,
      );

  /// Stable notification id namespace for task-before-event reminders.
  int notificationId(int weekdayOccurrence) =>
      ('task_$id\_$weekdayOccurrence').hashCode & 0x7FFFFFFF;

  /// Notification id namespace for the daily "until event" reminder.
  int get dailyNotificationId => ('task_daily_$id').hashCode & 0x7FFFFFFF;
}

// ============================================================================
// ScheduleItem — the main academic item (course/lab/test/project/etc.)
// ============================================================================

class ScheduleItem {
  final String id;
  final ItemType type;

  /// Subject / title, e.g. "Math".
  final String title;
  final String description;
  final String location;

  /// If true, this is a one-time dated event and [date] is used.
  /// If false, it recurs weekly and [weekday] is used.
  final bool oneTime;

  /// For weekly items (Mon=1..Sun=7). Ignored when [oneTime] is true.
  final int weekday;

  /// For one-time items — the specific calendar day. Null for weekly items.
  final DateTime? date;

  final SlotTime start;
  final SlotTime end;

  final int colorValue;

  /// Whether reminders are scheduled for this item.
  final bool notificationsEnabled;

  /// Minutes before start to remind (for the item's own reminder).
  final int reminderMinutesBefore;

  const ScheduleItem({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.location = '',
    required this.oneTime,
    this.weekday = Weekday.monday,
    this.date,
    required this.start,
    required this.end,
    this.colorValue = 0xFF3F51B5,
    this.notificationsEnabled = true,
    this.reminderMinutesBefore = 10,
  });

  int get priority => type.priority;

  Color get color => Color(colorValue);

  int get durationMinutes => end.inMinutes - start.inMinutes;

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

  /// A short human description of when this happens.
  String get whenLabel {
    if (oneTime && date != null) {
      final d = date!;
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year} \u2022 ${start.format()}';
    }
    return '${Weekday.long(weekday)} \u2022 ${intervalLabel}';
  }

  ScheduleItem copyWith({
    ItemType? type,
    String? title,
    String? description,
    String? location,
    bool? oneTime,
    int? weekday,
    DateTime? date,
    bool clearDate = false,
    SlotTime? start,
    SlotTime? end,
    int? colorValue,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
  }) =>
      ScheduleItem(
        id: id,
        type: type ?? this.type,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        oneTime: oneTime ?? this.oneTime,
        weekday: weekday ?? this.weekday,
        date: clearDate ? null : (date ?? this.date),
        start: start ?? this.start,
        end: end ?? this.end,
        colorValue: colorValue ?? this.colorValue,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        reminderMinutesBefore:
            reminderMinutesBefore ?? this.reminderMinutesBefore,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.storageKey,
        'title': title,
        'description': description,
        'location': location,
        'oneTime': oneTime,
        'weekday': weekday,
        'date': date?.toIso8601String(),
        'start': start.toJson(),
        'end': end.toJson(),
        'colorValue': colorValue,
        'notificationsEnabled': notificationsEnabled,
        'reminderMinutesBefore': reminderMinutesBefore,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'] as String,
        type: ItemTypeX.fromKey((j['type'] ?? 'course') as String),
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        location: (j['location'] ?? '') as String,
        oneTime: (j['oneTime'] ?? false) as bool,
        weekday: (j['weekday'] ?? Weekday.monday) as int,
        date: j['date'] != null ? DateTime.parse(j['date'] as String) : null,
        start: SlotTime.fromJson(j['start'] as Map<String, dynamic>),
        end: SlotTime.fromJson(j['end'] as Map<String, dynamic>),
        colorValue: (j['colorValue'] ?? 0xFF3F51B5) as int,
        notificationsEnabled: (j['notificationsEnabled'] ?? true) as bool,
        reminderMinutesBefore: (j['reminderMinutesBefore'] ?? 10) as int,
      );

  int get notificationId => id.hashCode & 0x7FFFFFFF;

  /// Next occurrence datetime from [from]. For one-time items returns [date]
  /// at [start]; for weekly items returns the next matching weekday/time.
  DateTime? nextOccurrence(DateTime from) {
    if (oneTime) {
      if (date == null) return null;
      final dt = DateTime(
          date!.year, date!.month, date!.day, start.hour, start.minute);
      return dt.isBefore(from) ? null : dt;
    }
    var candidate =
        DateTime(from.year, from.month, from.day, start.hour, start.minute);
    while (candidate.weekday != weekday || candidate.isBefore(from)) {
      candidate = candidate.add(const Duration(days: 1));
      candidate = DateTime(candidate.year, candidate.month, candidate.day,
          start.hour, start.minute);
    }
    return candidate;
  }
}
