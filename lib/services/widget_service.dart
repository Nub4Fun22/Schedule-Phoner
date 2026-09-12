import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/schedule_item.dart';

/// Pushes "next item" data to the Android home-screen widget.
///
/// The native [NextItemWidgetProvider] reads these keys:
///   next_type      e.g. "Course"
///   next_title     e.g. "Mathematics"
///   next_subtitle  e.g. "Tomorrow • 08:00 • Room A1"
///   next_countdown e.g. "in 2h 15m" / "in 3d"
///   following      e.g. "Next: Physics Lab • Wed 10:00"  (may be empty)
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _androidProvider = 'NextItemWidgetProvider';

  /// Update the 3x1 widget with the next Course/Lab/Test/Exam occurrence and
  /// the one after it. [item]/[occurrenceWhen] may be null if nothing is
  /// scheduled; [following]/[followingWhen] is the item after the next one.
  Future<void> updateNextItem({
    ScheduleItem? item,
    DateTime? occurrenceWhen,
    ScheduleItem? following,
    DateTime? followingWhen,
  }) async {
    try {
      if (item == null || occurrenceWhen == null) {
        await HomeWidget.saveWidgetData<String>('next_type', 'Schedule Phoner');
        await HomeWidget.saveWidgetData<String>(
            'next_title', 'No upcoming items');
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', 'Open the app to add some');
        await HomeWidget.saveWidgetData<String>('next_countdown', '');
        await HomeWidget.saveWidgetData<String>('following', '');
      } else {
        await HomeWidget.saveWidgetData<String>('next_type', item.type.label);
        await HomeWidget.saveWidgetData<String>('next_title', item.title);
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', _subtitle(item, occurrenceWhen));
        await HomeWidget.saveWidgetData<String>(
            'next_countdown', _countdown(occurrenceWhen));
        await HomeWidget.saveWidgetData<String>(
            'following',
            following != null && followingWhen != null
                ? 'Next: ${following.title} • ${_shortWhen(following, followingWhen)}'
                : '');
      }
      await HomeWidget.updateWidget(name: _androidProvider);
    } catch (e) {
      // Widgets are best-effort; never let this crash the app.
      debugPrint('Widget update failed: $e');
    }
  }

  /// "Tomorrow • 08:00 • Room A1"
  String _subtitle(ScheduleItem item, DateTime when) {
    final loc = item.location.isNotEmpty ? ' • ${item.location}' : '';
    return '${_dayLabel(when)} • ${item.start.format()}$loc';
  }

  /// "Physics Lab • Wed 10:00" style used for the "Next:" second line.
  String _shortWhen(ScheduleItem item, DateTime when) {
    return '${_dayLabel(when)} ${item.start.format()}';
  }

  String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final diffDays = target.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    if (diffDays < 7) return Weekday.long(when.weekday);
    return '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}';
  }

  /// A human "time until" string: "in 45m", "in 2h 15m", "in 3d".
  String _countdown(DateTime when) {
    final diff = when.difference(DateTime.now());
    if (diff.isNegative) return 'now';
    final totalMinutes = diff.inMinutes;
    if (totalMinutes < 60) return 'in ${totalMinutes}m';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = totalMinutes % 60;
      return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    return hours > 0 ? 'in ${days}d ${hours}h' : 'in ${days}d';
  }
}
