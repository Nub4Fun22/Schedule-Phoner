import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sample_schedule.dart';
import '../models/schedule_item.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

/// A homework paired with a computed next-due-lab occurrence, for list views.
class HomeworkWithLab {
  final Homework homework;
  final ScheduleItem? lab;
  const HomeworkWithLab(this.homework, this.lab);
}

/// A task paired with its parent Event, for list views.
class TaskWithEvent {
  final Task task;
  final ScheduleItem? event;
  const TaskWithEvent(this.task, this.event);
}

/// An upcoming occurrence of an item (for the "What's next" screen).
class UpcomingOccurrence {
  final ScheduleItem item;
  final DateTime when;
  const UpcomingOccurrence(this.item, this.when);
}

/// Central state: items + homeworks, persistence, and notification sync.
class ScheduleStore extends ChangeNotifier {
  static const String _itemsKey = 'items_v2';
  static const String _homeworkKey = 'homework_v2';
  static const String _taskKey = 'tasks_v1';

  final NotificationService _notifications;

  List<ScheduleItem> _items = [];
  List<Homework> _homeworks = [];
  List<Task> _tasks = [];
  bool _loading = true;

  // Notification sound/vibration preferences, mirrored from SettingsStore.
  // The schedule store owns the (re)scheduling, so it needs these to pick the
  // right notification channel set.
  bool _notificationSound = false;
  bool _notificationVibrate = true;

  ScheduleStore({NotificationService? notifications})
      : _notifications = notifications ?? NotificationService.instance;

  bool get isLoading => _loading;

  /// Sync notification sound/vibrate preferences and reschedule so the change
  /// takes effect immediately. Called by the UI when settings change.
  Future<void> applyNotificationPreferences({
    required bool sound,
    required bool vibrate,
  }) async {
    _notificationSound = sound;
    _notificationVibrate = vibrate;
    await _rescheduleAll();
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// All items sorted by weekday/date then start time.
  List<ScheduleItem> get items {
    final list = [..._items];
    list.sort(_byWhenThenPriority);
    return list;
  }

  List<Homework> get homeworks => [..._homeworks];

  /// Weekly items that fall on a given weekday, sorted by start time.
  List<ScheduleItem> weeklyItemsForDay(int weekday) {
    final list =
        _items.where((e) => !e.oneTime && e.weekday == weekday).toList();
    list.sort((a, b) => a.start.inMinutes.compareTo(b.start.inMinutes));
    return list;
  }

  /// Items to show on the weekly grid for [weekday]: all recurring weekly items
  /// on that day, PLUS any one-time items whose date falls in the CURRENT week
  /// (Mon–Sun) on that weekday. Sorted by start time. This is why a one-time
  /// test added for "this Saturday" now appears in Saturday's grid column.
  List<ScheduleItem> gridItemsForDay(int weekday) {
    final now = DateTime.now();
    // Monday 00:00 of the current week.
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7)); // exclusive

    final list = _items.where((e) {
      if (!e.oneTime) return e.weekday == weekday;
      final d = e.date;
      if (d == null) return false;
      final dayOnly = DateTime(d.year, d.month, d.day);
      return d.weekday == weekday &&
          !dayOnly.isBefore(startOfWeek) &&
          dayOnly.isBefore(endOfWeek);
    }).toList();
    list.sort((a, b) => a.start.inMinutes.compareTo(b.start.inMinutes));
    return list;
  }

  /// All labs and seminars (for linking homework/projects). Labs and seminars
  /// behave 1:1, so both can carry homework.
  List<ScheduleItem> get labs =>
      _items.where((e) => e.type.carriesHomework).toList();

  /// All events (for attaching tasks).
  List<ScheduleItem> get events =>
      _items.where((e) => e.type == ItemType.event).toList();

  List<Task> get tasks => [..._tasks];

  /// Tasks attached to a given event.
  List<Task> tasksForEvent(String eventId) =>
      _tasks.where((t) => t.eventId == eventId).toList();

  /// Active (not done, not past due) tasks for an event.
  List<Task> activeTasksForEvent(String eventId) {
    final now = DateTime.now();
    return _tasks
        .where((t) => t.eventId == eventId && !t.done && t.dueDate.isAfter(now))
        .toList();
  }

  ScheduleItem? itemById(String id) {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Homeworks attached to a given lab.
  List<Homework> homeworksForLab(String labId) =>
      _homeworks.where((h) => h.labId == labId).toList();

  /// Active (not done, not past due) homeworks for a lab.
  List<Homework> activeHomeworksForLab(String labId) {
    final now = DateTime.now();
    return _homeworks
        .where((h) => h.labId == labId && !h.done && h.dueDate.isAfter(now))
        .toList();
  }

  bool get allNotificationsEnabled =>
      _items.isNotEmpty && _items.every((e) => e.notificationsEnabled);

  bool get anyNotificationsEnabled =>
      _items.any((e) => e.notificationsEnabled);

  // ---------------------------------------------------------------------------
  // Query: What's next (by time)
  // ---------------------------------------------------------------------------

  /// Upcoming occurrences of items, sorted by soonest. Excludes homework.
  /// [types] can restrict which item types to include.
  List<UpcomingOccurrence> upcoming({
    DateTime? from,
    Set<ItemType>? types,
    int limit = 50,
  }) {
    final now = from ?? DateTime.now();
    final result = <UpcomingOccurrence>[];
    for (final item in _items) {
      if (types != null && !types.contains(item.type)) continue;
      final next = item.nextOccurrence(now);
      if (next != null) result.add(UpcomingOccurrence(item, next));
    }
    result.sort((a, b) => a.when.compareTo(b.when));
    return result.take(limit).toList();
  }

  /// The single next item occurrence for the 3x1 widget: next Course/Lab/
  /// Test/Exam (per spec, no homework). Presentation/Project excluded too,
  /// matching the requested set exactly.
  UpcomingOccurrence? get nextForWidget {
    final list = widgetUpcoming(limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Upcoming Course/Lab/Test/Exam occurrences for the home-screen widget
  /// (the "next up" row shows the second entry).
  List<UpcomingOccurrence> widgetUpcoming({int limit = 2}) {
    return upcoming(types: {
      ItemType.course,
      ItemType.lab,
      ItemType.test,
      ItemType.exam,
    }, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Query: Priority screen data
  // ---------------------------------------------------------------------------

  /// Homeworks sorted by due date (soonest first). Done ones go last.
  List<HomeworkWithLab> homeworksByDueDate({bool includeDone = true}) {
    final list = _homeworks.where((h) => includeDone || !h.done).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list.map((h) => HomeworkWithLab(h, itemById(h.labId))).toList();
  }

  /// Tasks sorted by due date (soonest first). Done ones go last.
  List<TaskWithEvent> tasksByDueDate({bool includeDone = true}) {
    final list = _tasks.where((t) => includeDone || !t.done).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list.map((t) => TaskWithEvent(t, itemById(t.eventId))).toList();
  }

  /// Exams sorted by date (soonest first).
  List<ScheduleItem> examsByDate() => _itemsOfTypeByNextOccurrence(ItemType.exam);

  /// Tests sorted by their next occurrence (soonest first). Includes both
  /// weekly and one-time tests.
  List<ScheduleItem> testsByNext() =>
      _itemsOfTypeByNextOccurrence(ItemType.test);

  /// Project presentations sorted by date (soonest first).
  List<ScheduleItem> presentationsByDate() =>
      _itemsOfTypeByNextOccurrence(ItemType.projectPresentation);

  /// Items of [type] sorted by their next upcoming occurrence (soonest first).
  /// Weekly items use their next weekday occurrence; one-time items use their
  /// date. Items with no future occurrence sort to the end.
  List<ScheduleItem> _itemsOfTypeByNextOccurrence(ItemType type) {
    final now = DateTime.now();
    final list = _items.where((e) => e.type == type).toList();
    DateTime keyFor(ScheduleItem e) =>
        e.nextOccurrence(now) ?? DateTime.fromMillisecondsSinceEpoch(1 << 62);
    list.sort((a, b) => keyFor(a).compareTo(keyFor(b)));
    return list;
  }

  int _byWhenThenPriority(ScheduleItem a, ScheduleItem b) {
    // One-time items sorted by date; weekly by weekday. Group weekly first.
    if (a.oneTime != b.oneTime) return a.oneTime ? 1 : -1;
    if (!a.oneTime) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      if (a.start.inMinutes != b.start.inMinutes) {
        return a.start.inMinutes.compareTo(b.start.inMinutes);
      }
      return b.priority.compareTo(a.priority);
    } else {
      final da = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    }
  }

  // ---------------------------------------------------------------------------
  // Load / persist
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getString(_itemsKey);
    final rawHw = prefs.getString(_homeworkKey);
    final rawTasks = prefs.getString(_taskKey);

    if (rawItems == null) {
      // Fresh install: empty schedule.
      _items = [];
      _homeworks = [];
      _tasks = [];
      await _persist();
    } else {
      try {
        _items = (jsonDecode(rawItems) as List<dynamic>)
            .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to parse items, starting empty: $e');
        _items = [];
      }
      try {
        _homeworks = rawHw == null
            ? []
            : (jsonDecode(rawHw) as List<dynamic>)
                .map((e) => Homework.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (e) {
        debugPrint('Failed to parse homeworks: $e');
        _homeworks = [];
      }
      try {
        _tasks = rawTasks == null
            ? []
            : (jsonDecode(rawTasks) as List<dynamic>)
                .map((e) => Task.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (e) {
        debugPrint('Failed to parse tasks: $e');
        _tasks = [];
      }
    }

    _loading = false;
    notifyListeners();

    await _rescheduleAll();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _itemsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _homeworkKey, jsonEncode(_homeworks.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _taskKey, jsonEncode(_tasks.map((e) => e.toJson()).toList()));
  }

  Future<void> _rescheduleAll() async {
    // Notifications + widget updates are best-effort side effects. Never let a
    // platform exception here (e.g. exact-alarm permission, widget plugin)
    // propagate up and break the calling flow (like closing the editor).
    try {
      await _notifications.rescheduleAll(
        items: _items,
        homeworks: _homeworks,
        tasks: _tasks,
        sound: _notificationSound,
        vibrate: _notificationVibrate,
      );
    } catch (e) {
      debugPrint('rescheduleAll (notifications) failed: $e');
    }
    try {
      // Keep the home-screen widget in sync with the next two items.
      final upcomingForWidget = widgetUpcoming(limit: 2);
      await WidgetService.instance.updateNextItem(
        item: upcomingForWidget.isNotEmpty ? upcomingForWidget[0].item : null,
        occurrenceWhen:
            upcomingForWidget.isNotEmpty ? upcomingForWidget[0].when : null,
        following:
            upcomingForWidget.length > 1 ? upcomingForWidget[1].item : null,
        followingWhen:
            upcomingForWidget.length > 1 ? upcomingForWidget[1].when : null,
      );
    } catch (e) {
      debugPrint('rescheduleAll (widget) failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Item CRUD
  // ---------------------------------------------------------------------------

  Future<void> addOrUpdateItem(ScheduleItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item;
    } else {
      _items.add(item);
    }
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((e) => e.id == id);
    // Deleting a lab removes its homeworks; deleting an event removes its
    // tasks (they can't exist without their parent).
    _homeworks.removeWhere((h) => h.labId == id);
    _tasks.removeWhere((t) => t.eventId == id);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> setItemNotifications(String id, bool enabled) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(notificationsEnabled: enabled);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> setAllNotifications(bool enabled) async {
    _items = _items
        .map((e) => e.copyWith(notificationsEnabled: enabled))
        .toList();
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  // ---------------------------------------------------------------------------
  // Homework CRUD
  // ---------------------------------------------------------------------------

  Future<void> addOrUpdateHomework(Homework hw) async {
    final i = _homeworks.indexWhere((e) => e.id == hw.id);
    if (i >= 0) {
      _homeworks[i] = hw;
    } else {
      _homeworks.add(hw);
    }
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> deleteHomework(String id) async {
    _homeworks.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  /// Toggle "done" — done stops the recurring reminders.
  Future<void> setHomeworkDone(String id, bool done) async {
    final i = _homeworks.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _homeworks[i] = _homeworks[i].copyWith(done: done);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  // ---------------------------------------------------------------------------
  // Task CRUD (tasks attached to Events)
  // ---------------------------------------------------------------------------

  Future<void> addOrUpdateTask(Task task) async {
    final i = _tasks.indexWhere((e) => e.id == task.id);
    if (i >= 0) {
      _tasks[i] = task;
    } else {
      _tasks.add(task);
    }
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  /// Toggle "done" — done stops the recurring reminders.
  Future<void> setTaskDone(String id, bool done) async {
    final i = _tasks.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(done: done);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  // ---------------------------------------------------------------------------
  // Demo data (optional)
  // ---------------------------------------------------------------------------

  /// True if any demo item/homework/task is currently present.
  bool get hasDemoData =>
      _items.any((e) => e.id.startsWith(SampleSchedule.demoPrefix)) ||
      _homeworks.any((h) => h.id.startsWith(SampleSchedule.demoPrefix)) ||
      _tasks.any((t) => t.id.startsWith(SampleSchedule.demoPrefix));

  /// Import the demo dataset. Demo items are ADDED alongside the user's own
  /// items (their ids are demo-prefixed), so they can be removed later without
  /// touching the user's data. Existing demo items are refreshed.
  Future<void> loadSample() async {
    // Drop any previous demo data first so re-importing doesn't duplicate.
    _items.removeWhere((e) => e.id.startsWith(SampleSchedule.demoPrefix));
    _homeworks.removeWhere((h) => h.id.startsWith(SampleSchedule.demoPrefix));
    _tasks.removeWhere((t) => t.id.startsWith(SampleSchedule.demoPrefix));

    final sample = SampleSchedule.build();
    _items.addAll(sample.items);
    _homeworks.addAll(sample.homeworks);
    _tasks.addAll(sample.tasks);
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  /// Remove only the demo data, leaving the user's own items untouched.
  Future<void> deleteSample() async {
    _items.removeWhere((e) => e.id.startsWith(SampleSchedule.demoPrefix));
    _homeworks.removeWhere((h) => h.id.startsWith(SampleSchedule.demoPrefix));
    _tasks.removeWhere((t) => t.id.startsWith(SampleSchedule.demoPrefix));
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }

  /// Wipe EVERYTHING — all items, homework and tasks. Settings are unaffected.
  Future<void> deleteAll() async {
    _items = [];
    _homeworks = [];
    _tasks = [];
    await _persist();
    notifyListeners();
    await _rescheduleAll();
  }
}
