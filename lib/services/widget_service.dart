import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/schedule_item.dart';

/// Pushes "next item" data to the Android home-screen widget (4x2).
///
/// The native [NextItemWidgetProvider] reads these keys:
///   next_type        e.g. "Course"
///   next_title       e.g. "Mathematics"
///   next_subtitle    e.g. "Tomorrow • 08:00 • Room A1"
///   next_countdown   e.g. "in 2h 15m" / "in 3d"
///   following_label  e.g. "UP NEXT"  (empty when there's no second item)
///   following_title  e.g. "Physics Lab"
///   following_sub    e.g. "Wed • 10:00 • in 1d 2h"
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _androidProvider = 'NextItemWidgetProvider';

  /// Update the 4x2 widget with the next Course/Lab/Test/Exam occurrence and
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
        await HomeWidget.saveWidgetData<String>('following_label', '');
        await HomeWidget.saveWidgetData<String>('following_title', '');
        await HomeWidget.saveWidgetData<String>('following_sub', '');
      } else {
        await HomeWidget.saveWidgetData<String>('next_type', item.type.label);
        await HomeWidget.saveWidgetData<String>('next_title', item.title);
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', _subtitle(item, occurrenceWhen));
        await HomeWidget.saveWidgetData<String>(
            'next_countdown', _countdown(occurrenceWhen));

        if (following != null && followingWhen != null) {
          await HomeWidget.saveWidgetData<String>('following_label', 'UP NEXT');
          await HomeWidget.saveWidgetData<String>(
              'following_title', '${following.type.label}: ${following.title}');
          await HomeWidget.saveWidgetData<String>(
              'following_sub', _followingSub(following, followingWhen));
        } else {
          await HomeWidget.saveWidgetData<String>('following_label', '');
          await HomeWidget.saveWidgetData<String>('following_title', '');
          await HomeWidget.saveWidgetData<String>('following_sub', '');
        }
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

  /// "Wed • 10:00 • in 1d 2h" for the second (following) item.
  String _followingSub(ScheduleItem item, DateTime when) {
    return '${_dayLabel(when)} • ${item.start.format()} • ${_countdown(when)}';
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
