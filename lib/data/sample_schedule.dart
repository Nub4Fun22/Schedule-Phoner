import '../models/schedule_event.dart';

/// Sample timetable used on first launch. The user can edit/add/delete these,
/// or replace them with their real school schedule via the in-app editor.
///
/// Colors are chosen to be visually distinct per subject.
class SampleSchedule {
  // A small palette of pleasant, distinct colors (ARGB ints).
  static const int _blue = 0xFF3F51B5;
  static const int _teal = 0xFF00897B;
  static const int _orange = 0xFFEF6C00;
  static const int _purple = 0xFF8E24AA;
  static const int _green = 0xFF43A047;
  static const int _red = 0xFFE53935;
  static const int _brown = 0xFF6D4C41;

  static List<ScheduleEvent> build() {
    return [
      // ---- Monday ----
      const ScheduleEvent(
        id: 'mon-math',
        title: 'Mathematics',
        description: 'Calculus — lecture hall A1',
        location: 'Room A1',
        weekday: Weekday.monday,
        start: SlotTime(8, 0),
        end: SlotTime(9, 30),
        colorValue: _blue,
      ),
      const ScheduleEvent(
        id: 'mon-cs',
        title: 'Computer Science',
        description: 'Programming fundamentals — lab',
        location: 'Lab 2',
        weekday: Weekday.monday,
        start: SlotTime(9, 45),
        end: SlotTime(11, 15),
        colorValue: _teal,
      ),
      const ScheduleEvent(
        id: 'mon-eng',
        title: 'English',
        description: 'Academic writing',
        location: 'Room B3',
        weekday: Weekday.monday,
        start: SlotTime(11, 30),
        end: SlotTime(13, 0),
        colorValue: _orange,
      ),

      // ---- Tuesday ----
      const ScheduleEvent(
        id: 'tue-phys',
        title: 'Physics',
        description: 'Mechanics — lecture',
        location: 'Room A2',
        weekday: Weekday.tuesday,
        start: SlotTime(10, 0),
        end: SlotTime(11, 30),
        colorValue: _purple,
      ),
      const ScheduleEvent(
        id: 'tue-cs-sem',
        title: 'CS Seminar',
        description: 'Algorithms problem session',
        location: 'Room C1',
        weekday: Weekday.tuesday,
        start: SlotTime(11, 45),
        end: SlotTime(13, 15),
        colorValue: _teal,
      ),

      // ---- Wednesday ----
      const ScheduleEvent(
        id: 'wed-math-sem',
        title: 'Math Seminar',
        description: 'Exercises and Q&A',
        location: 'Room A1',
        weekday: Weekday.wednesday,
        start: SlotTime(8, 0),
        end: SlotTime(9, 30),
        colorValue: _blue,
      ),
      const ScheduleEvent(
        id: 'wed-chem',
        title: 'Chemistry',
        description: 'Organic chemistry lab',
        location: 'Lab 4',
        weekday: Weekday.wednesday,
        start: SlotTime(9, 45),
        end: SlotTime(12, 0),
        colorValue: _green,
      ),

      // ---- Thursday ----
      const ScheduleEvent(
        id: 'thu-db',
        title: 'Databases',
        description: 'SQL and relational modeling',
        location: 'Lab 2',
        weekday: Weekday.thursday,
        start: SlotTime(10, 0),
        end: SlotTime(11, 30),
        colorValue: _brown,
      ),
      const ScheduleEvent(
        id: 'thu-eng',
        title: 'English',
        description: 'Presentations workshop',
        location: 'Room B3',
        weekday: Weekday.thursday,
        start: SlotTime(11, 45),
        end: SlotTime(13, 15),
        colorValue: _orange,
      ),

      // ---- Friday ----
      const ScheduleEvent(
        id: 'fri-phys-lab',
        title: 'Physics Lab',
        description: 'Measurement experiments',
        location: 'Lab 1',
        weekday: Weekday.friday,
        start: SlotTime(8, 0),
        end: SlotTime(10, 15),
        colorValue: _purple,
      ),
      const ScheduleEvent(
        id: 'fri-sport',
        title: 'Sports',
        description: 'Physical education',
        location: 'Gym',
        weekday: Weekday.friday,
        start: SlotTime(10, 30),
        end: SlotTime(12, 0),
        colorValue: _red,
      ),
    ];
  }
}
