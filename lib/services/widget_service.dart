import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/schedule_item.dart';

/// Pushes "next item" data to the Android home-screen widget (4x2).
///
/// The native [NextItemWidgetProvider] reads these keys. The day label
/// ("Today"/"Tomorrow"/weekday) AND the countdown are computed NATIVELY from
/// the *_epoch values on every widget update, so both stay correct across
/// midnight without opening the app. We push the raw pieces (time, location)
/// plus the epoch; the fallback *_subtitle/_sub strings are only used if the
/// epoch is missing.
///   next_type        e.g. "Course"
///   next_title       e.g. "Mathematics"
///   next_time        e.g. "08:00"
///   next_location    e.g. "Room A1" (may be empty)
///   next_epoch       occurrence time in millis (day label + countdown source)
///   next_subtitle    fallback "Tomorrow • 08:00 • Room A1"
///   next_countdown   fallback "in 2h 15m"
///   following_label  e.g. "UP NEXT"  (empty when there's no second item)
///   following_title  e.g. "Physics Lab"
///   following_time   e.g. "10:00"
///   following_epoch  occurrence time in millis
///   following_sub    fallback "Wed • 10:00 • in 1d 2h"
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
        await HomeWidget.saveWidgetData<String>('next_time', '');
        await HomeWidget.saveWidgetData<String>('next_location', '');
        await HomeWidget.saveWidgetData<String>('next_countdown', '');
        await HomeWidget.saveWidgetData<String>('next_epoch', '');
        await HomeWidget.saveWidgetData<String>('following_label', '');
        await HomeWidget.saveWidgetData<String>('following_title', '');
        await HomeWidget.saveWidgetData<String>('following_sub', '');
        await HomeWidget.saveWidgetData<String>('following_time', '');
        await HomeWidget.saveWidgetData<String>('following_epoch', '');
      } else {
        await HomeWidget.saveWidgetData<String>('next_type', item.type.label);
        await HomeWidget.saveWidgetData<String>('next_title', item.title);
        // Raw pieces so the native widget can build "day • time • loc" with a
        // LIVE day label (Today/Tomorrow/weekday) computed from next_epoch —
        // otherwise the label would freeze and read "Tomorrow" after midnight.
        await HomeWidget.saveWidgetData<String>(
            'next_time', item.start.format());
        await HomeWidget.saveWidgetData<String>(
            'next_location', item.location);
        await HomeWidget.saveWidgetData<String>(
            'next_epoch', occurrenceWhen.millisecondsSinceEpoch.toString());
        // Fallbacks used only if epoch is missing.
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', _subtitle(item, occurrenceWhen));
        await HomeWidget.saveWidgetData<String>(
            'next_countdown', _countdown(occurrenceWhen));

        if (following != null && followingWhen != null) {
          await HomeWidget.saveWidgetData<String>('following_label', 'UP NEXT');
          await HomeWidget.saveWidgetData<String>(
              'following_title', '${following.type.label}: ${following.title}');
          await HomeWidget.saveWidgetData<String>(
              'following_time', following.start.format());
          await HomeWidget.saveWidgetData<String>('following_epoch',
              followingWhen.millisecondsSinceEpoch.toString());
          await HomeWidget.saveWidgetData<String>(
              'following_sub', _followingSub(following, followingWhen));
        } else {
          await HomeWidget.saveWidgetData<String>('following_label', '');
          await HomeWidget.saveWidgetData<String>('following_title', '');
          await HomeWidget.saveWidgetData<String>('following_sub', '');
          await HomeWidget.saveWidgetData<String>('following_time', '');
          await HomeWidget.saveWidgetData<String>('following_epoch', '');
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

  /// "Wed • 10:00 • in 1d 2h" for the second (following) item (fallback only).
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
