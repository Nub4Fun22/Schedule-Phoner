import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/schedule_item.dart';

/// Pushes "next item" data to the Android home-screen widget.
///
/// The native [NextItemWidgetProvider] reads these keys:
///   next_type, next_title, next_subtitle
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _androidProvider = 'NextItemWidgetProvider';

  /// Update the 3x1 widget with the next Course/Lab/Test/Exam occurrence.
  /// [occurrenceWhen] is the next datetime; [item] may be null if nothing.
  Future<void> updateNextItem({
    ScheduleItem? item,
    DateTime? occurrenceWhen,
  }) async {
    try {
      if (item == null || occurrenceWhen == null) {
        await HomeWidget.saveWidgetData<String>('next_type', 'Schedule Phoner');
        await HomeWidget.saveWidgetData<String>(
            'next_title', 'No upcoming items');
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', 'Open the app to add some');
      } else {
        await HomeWidget.saveWidgetData<String>('next_type', item.type.label);
        await HomeWidget.saveWidgetData<String>('next_title', item.title);
        await HomeWidget.saveWidgetData<String>(
            'next_subtitle', _subtitle(item, occurrenceWhen));
      }
      await HomeWidget.updateWidget(name: _androidProvider);
    } catch (e) {
      // Widgets are best-effort; never let this crash the app.
      debugPrint('Widget update failed: $e');
    }
  }

  String _subtitle(ScheduleItem item, DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final diffDays = target.difference(today).inDays;
    final dayLabel = diffDays == 0
        ? 'Today'
        : diffDays == 1
            ? 'Tomorrow'
            : (diffDays < 7
                ? Weekday.long(when.weekday)
                : '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}');
    final loc = item.location.isNotEmpty ? ' • ${item.location}' : '';
    return '$dayLabel • ${item.start.format()}$loc';
  }
}
