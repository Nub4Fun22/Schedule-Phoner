import '../models/schedule_item.dart';

/// A tiny demo dataset the user can optionally load from Settings to see how
/// the different item types look. NOT loaded on a fresh install.
class SampleData {
  final List<ScheduleItem> items;
  final List<Homework> homeworks;
  const SampleData({required this.items, required this.homeworks});
}

class SampleSchedule {
  static const int _blue = 0xFF3F51B5;
  static const int _teal = 0xFF00897B;
  static const int _orange = 0xFFEF6C00;
  static const int _purple = 0xFF8E24AA;
  static const int _red = 0xFFE53935;

  static SampleData build() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    final inTenDays = now.add(const Duration(days: 10));

    final items = <ScheduleItem>[
      // Course (weekly, permanent)
      const ScheduleItem(
        id: 'demo-math-course',
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
      // Lab (weekly, permanent, can carry homework)
      const ScheduleItem(
        id: 'demo-cs-lab',
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
      // Weekly test
      const ScheduleItem(
        id: 'demo-eng-test',
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
      // One-time project presentation
      ScheduleItem(
        id: 'demo-presentation',
        type: ItemType.projectPresentation,
        title: 'CS Project',
        description: 'Final presentation',
        location: 'Room C1',
        oneTime: true,
        date: nextWeek,
        start: const SlotTime(14, 0),
        end: const SlotTime(15, 0),
        colorValue: _purple,
      ),
      // One-time exam (highest priority)
      ScheduleItem(
        id: 'demo-exam',
        type: ItemType.exam,
        title: 'Mathematics',
        description: 'Final exam',
        location: 'Hall 1',
        oneTime: true,
        date: inTenDays,
        start: const SlotTime(9, 0),
        end: const SlotTime(11, 0),
        colorValue: _red,
      ),
    ];

    final homeworks = <Homework>[
      // Homework attached to the CS lab, due in 5 days.
      Homework(
        id: 'demo-hw-1',
        labId: 'demo-cs-lab',
        description: 'Finish exercises 1–5',
        dueDate: now.add(const Duration(days: 5)),
      ),
    ];

    return SampleData(items: items, homeworks: homeworks);
  }
}
