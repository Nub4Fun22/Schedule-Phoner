import '../models/schedule_item.dart';

/// Shared date/countdown formatting used across screens.
class DateFormatUtils {
  /// "12/03/2026"
  static String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// "12/03" (no year)
  static String fmtDayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// A human "time until [target]" string:
  ///  * past       -> "overdue"
  ///  * same day   -> "in 2h 15m" / "in 45m" / "now" (uses hours/minutes)
  ///  * future day -> "in 3 days" / "tomorrow" / "today"
  ///
  /// When [target] has no meaningful time-of-day (e.g. a due DATE with time set
  /// to 00:00), pass [dateOnly] = true so same-day shows "today" rather than a
  /// possibly-negative hour count.
  static String untilLabel(DateTime target, {DateTime? from, bool dateOnly = false}) {
    final now = from ?? DateTime.now();
    if (target.isBefore(now) && !dateOnly) return 'overdue';

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    final dayDiff = targetDay.difference(today).inDays;

    if (dayDiff < 0) return 'overdue';

    if (dayDiff == 0) {
      // Same calendar day.
      if (dateOnly) return 'today';
      final diff = target.difference(now);
      if (diff.isNegative) return 'now';
      final mins = diff.inMinutes;
      if (mins < 60) return 'in ${mins}m';
      final h = diff.inHours;
      final m = mins % 60;
      return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
    }

    if (dayDiff == 1) return 'tomorrow';
    return 'in $dayDiff days';
  }

  /// A due-date badge combining the date and a countdown, e.g.
  /// "12/03/2026 • in 3 days" or "12/03/2026 • in 2h 15m".
  /// [atTime] optionally supplies the event's start time for same-day precision.
  static String dueWithCountdown(DateTime due, {SlotTime? atTime}) {
    final target = atTime == null
        ? due
        : DateTime(due.year, due.month, due.day, atTime.hour, atTime.minute);
    // A bare due date carries no time, so treat same-day as "today" unless a
    // time was supplied.
    final label = untilLabel(target, dateOnly: atTime == null);
    return '${fmtDate(due)} • $label';
  }
}
