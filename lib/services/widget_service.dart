import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes upcoming-item data to the Android home-screen widget (4x2).
///
/// We push an ORDERED LIST of the next several occurrences as JSON under
/// `occurrences`. The native [NextItemWidgetProvider] then, on every widget
/// refresh, drops any occurrence whose start time has already passed and shows
/// the first two that remain — computing the day label ("Today"/"Tomorrow"/…)
/// and countdown live from each occurrence's epoch. This means:
///   * the day label never freezes across midnight, and
///   * once an event passes, the widget rolls over to the next one NATIVELY,
///     without needing the app to run (until the pushed list is exhausted,
///     which the app/periodic refresh replenishes).
///
/// Each occurrence map: { epoch:int, type, title, time, location }.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _androidProvider = 'NextItemWidgetProvider';

  /// Save the next [occurrences] (already sorted soonest-first) for the widget.
  /// Each entry must contain: epoch (int millis), type, title, time, location.
  /// [weekNumber] is the current week counter value, shown at the top.
  Future<void> updateOccurrences(
    List<Map<String, dynamic>> occurrences, {
    int weekNumber = 1,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'occurrences', jsonEncode(occurrences));
      await HomeWidget.saveWidgetData<String>(
          'week_number', weekNumber.toString());
      await HomeWidget.updateWidget(name: _androidProvider);
    } catch (e) {
      // Widgets are best-effort; never let this crash the app.
      debugPrint('Widget update failed: $e');
    }
  }
}
