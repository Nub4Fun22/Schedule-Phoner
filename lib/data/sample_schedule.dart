import '../models/schedule_item.dart';

/// A demo dataset the user can optionally load from Settings to see how the
/// different item types look and behave. NOT loaded on a fresh install, and
/// can be removed again with "Delete demo data".
///
/// Every item/homework id is prefixed with [demoPrefix] so the demo data can
/// be identified and removed without touching the user's own items.
class SampleData {
  final List<ScheduleItem> items;
  final List<Homework> homeworks;
  final List<Task> tasks;
  const SampleData({
    required this.items,
    required this.homeworks,
    this.tasks = const [],
  });
}

class SampleSchedule {
  /// Prefix that marks an item/homework as demo data.
  static const String demoPrefix = 'demo-';

  static const int _blue = 0xFF3F51B5;
  static const int _teal = 0xFF00897B;
  static const int _orange = 0xFFEF6C00;
  static const int _purple = 0xFF8E24AA;
  static const int _red = 0xFFE53935;
  static const int _green = 0xFF43A047;
  static const int _indigo = 0xFF5E35B1;
  static const int _brown = 0xFF6D4C41;

  static SampleData build() {
    final now = DateTime.now();
    DateTime inDays(int d) => now.add(Duration(days: d));

    final items = <ScheduleItem>[
      // --- Courses (weekly, permanent) -------------------------------------
      const ScheduleItem(
        id: '${demoPrefix}math-course',
        type: ItemType.course,
        title: 'Mathematics',
        description: 'Calculus lecture',
        location: 'Room A1',
        oneTime: false,
        weekday: Weekday.monday,
        start: SlotTime(8, 0),
        end: SlotTime(9, 30),
        colorValue: _blue,
      ),
      const ScheduleItem(
        id: '${demoPrefix}history-course',
        type: ItemType.course,
        title: 'History',
        description: 'Modern European history',
        location: 'Room A2',
        oneTime: false,
        weekday: Weekday.thursday,
        start: SlotTime(9, 0),
        end: SlotTime(10, 30),
        colorValue: _brown,
      ),

      // --- Labs (weekly, permanent, can carry homework) --------------------
      const ScheduleItem(
        id: '${demoPrefix}cs-lab',
        type: ItemType.lab,
        title: 'Computer Science',
        description: 'Programming lab',
        location: 'Lab 2',
        oneTime: false,
        weekday: Weekday.tuesday,
        start: SlotTime(10, 0),
        end: SlotTime(12, 0),
        colorValue: _teal,
      ),
      // Seminar (weekly, permanent, carries homework — 1:1 with Lab)
      const ScheduleItem(
        id: '${demoPrefix}lit-seminar',
        type: ItemType.seminar,
        title: 'Literature',
        description: 'Discussion seminar',
        location: 'Room D2',
        oneTime: false,
        weekday: Weekday.thursday,
        start: SlotTime(15, 0),
        end: SlotTime(16, 30),
        colorValue: _purple,
      ),
      const ScheduleItem(
        id: '${demoPrefix}physics-lab',
        type: ItemType.lab,
        title: 'Physics',
        description: 'Mechanics experiments',
        location: 'Lab 5',
        oneTime: false,
        weekday: Weekday.friday,
        start: SlotTime(13, 0),
        end: SlotTime(15, 0),
        colorValue: _indigo,
      ),

      // --- Tests: one weekly, one one-time ---------------------------------
      const ScheduleItem(
        id: '${demoPrefix}eng-test',
        type: ItemType.test,
        title: 'English',
        description: 'Weekly vocabulary test',
        location: 'Room B3',
        oneTime: false,
        weekday: Weekday.wednesday,
        start: SlotTime(11, 0),
        end: SlotTime(11, 30),
        colorValue: _orange,
      ),
      ScheduleItem(
        id: '${demoPrefix}chem-test',
        type: ItemType.test,
        title: 'Chemistry',
        description: 'Organic chemistry quiz',
        location: 'Room B1',
        oneTime: true,
        date: inDays(4),
        start: const SlotTime(10, 0),
        end: const SlotTime(11, 0),
        colorValue: _green,
      ),

      // --- Project (weekly, linked to the CS lab) --------------------------
      const ScheduleItem(
        id: '${demoPrefix}cs-project',
        type: ItemType.project,
        title: 'CS Group Project',
        description: 'Build a small app — linked to the CS lab',
        location: 'Lab 2',
        oneTime: false,
        weekday: Weekday.tuesday,
        start: SlotTime(12, 0),
        end: SlotTime(12, 30),
        colorValue: _teal,
      ),

      // --- One-time project presentation -----------------------------------
      ScheduleItem(
        id: '${demoPrefix}presentation',
        type: ItemType.projectPresentation,
        title: 'CS Project',
        description: 'Final presentation',
        location: 'Room C1',
        oneTime: true,
        date: inDays(7),
        start: const SlotTime(14, 0),
        end: const SlotTime(15, 0),
        colorValue: _purple,
      ),

      // --- One-time exams (highest priority) --------------------------------
      ScheduleItem(
        id: '${demoPrefix}math-exam',
        type: ItemType.exam,
        title: 'Mathematics',
        description: 'Final exam',
        location: 'Hall 1',
        oneTime: true,
        date: inDays(10),
        start: const SlotTime(9, 0),
        end: const SlotTime(11, 0),
        colorValue: _red,
      ),
      ScheduleItem(
        id: '${demoPrefix}physics-exam',
        type: ItemType.exam,
        title: 'Physics',
        description: 'Midterm exam',
        location: 'Hall 2',
        oneTime: true,
        date: inDays(15),
        start: const SlotTime(13, 0),
        end: const SlotTime(15, 0),
        colorValue: _indigo,
      ),

      // --- Event (personal reminder, weekly, can carry tasks) --------------
      const ScheduleItem(
        id: '${demoPrefix}chores-event',
        type: ItemType.event,
        title: 'Chores',
        description: 'Weekly personal reminders',
        location: 'Home',
        oneTime: false,
        weekday: Weekday.sunday,
        start: SlotTime(18, 0),
        end: SlotTime(18, 30),
        colorValue: _green,
      ),
      // --- Event (one-time personal reminder) ------------------------------
      ScheduleItem(
        id: '${demoPrefix}dentist-event',
        type: ItemType.event,
        title: 'Dentist appointment',
        description: 'Checkup',
        location: 'Clinic',
        oneTime: true,
        date: inDays(6),
        start: const SlotTime(16, 0),
        end: const SlotTime(16, 30),
        colorValue: _brown,
      ),
    ];

    final homeworks = <Homework>[
      // Homework attached to the CS lab, due soon (will nag before each lab).
      Homework(
        id: '${demoPrefix}hw-1',
        labId: '${demoPrefix}cs-lab',
        description: 'Finish exercises 1–5',
        dueDate: inDays(5),
      ),
      // A second CS-lab homework, due a bit later.
      Homework(
        id: '${demoPrefix}hw-2',
        labId: '${demoPrefix}cs-lab',
        description: 'Read chapter 4 and write a summary',
        dueDate: inDays(12),
      ),
      // Homework on the physics lab.
      Homework(
        id: '${demoPrefix}hw-3',
        labId: '${demoPrefix}physics-lab',
        description: 'Lab report on the pendulum experiment',
        dueDate: inDays(8),
      ),
      // An already-done homework, to show the checked state.
      Homework(
        id: '${demoPrefix}hw-4',
        labId: '${demoPrefix}physics-lab',
        description: 'Pre-lab reading',
        dueDate: inDays(3),
        done: true,
      ),
      // Homework on the Literature seminar (seminars carry homework 1:1 w/ labs)
      // with a daily-until-seminar reminder to showcase that option.
      Homework(
        id: '${demoPrefix}hw-5',
        labId: '${demoPrefix}lit-seminar',
        description: 'Read the assigned short story',
        dueDate: inDays(6),
        dailyUntil: true,
        dailyReminderTime: const SlotTime(20, 0),
      ),
    ];

    final tasks = <Task>[
      // Tasks attached to the weekly "Chores" event.
      Task(
        id: '${demoPrefix}task-1',
        eventId: '${demoPrefix}chores-event',
        description: 'Do the dishes',
        dueDate: inDays(2),
      ),
      Task(
        id: '${demoPrefix}task-2',
        eventId: '${demoPrefix}chores-event',
        description: 'Take out the trash',
        dueDate: inDays(4),
      ),
      // A done task to show the checked state.
      Task(
        id: '${demoPrefix}task-3',
        eventId: '${demoPrefix}chores-event',
        description: 'Water the plants',
        dueDate: inDays(1),
        done: true,
      ),
    ];

    return SampleData(items: items, homeworks: homeworks, tasks: tasks);
  }
}
