import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_event.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
import 'event_details_screen.dart';

/// Excel-like weekly grid: weekdays across the top, hours down the left,
/// event blocks positioned and sized by their time interval.
class WeekGridScreen extends StatelessWidget {
  const WeekGridScreen({super.key});

  // Layout constants.
  static const double _hourHeight = 64.0; // pixels per hour
  static const double _timeColWidth = 52.0;
  static const double _headerHeight = 40.0;
  static const double _minColWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final days = Weekday.schoolWeek;
    final events = store.events;

    // Determine the visible time range from the data (fallback 8:00–18:00).
    int minMinutes = 8 * 60;
    int maxMinutes = 18 * 60;
    if (events.isNotEmpty) {
      minMinutes = events.map((e) => e.start.inMinutes).reduce((a, b) => a < b ? a : b);
      maxMinutes = events.map((e) => e.end.inMinutes).reduce((a, b) => a > b ? a : b);
    }
    final startHour = (minMinutes ~/ 60);
    final endHour = ((maxMinutes + 59) ~/ 60);
    final totalHours = (endHour - startHour).clamp(1, 24);
    final gridHeight = totalHours * _hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _timeColWidth;
        final colWidth = (available / days.length).clamp(_minColWidth, 400.0);
        final bodyWidth = _timeColWidth + colWidth * days.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: bodyWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(context, days, colWidth),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: gridHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTimeColumn(context, startHour, endHour),
                          for (final day in days)
                            _buildDayColumn(
                              context,
                              store,
                              day,
                              colWidth,
                              startHour,
                              gridHeight,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(
      BuildContext context, List<int> days, double colWidth) {
    final today = DateTime.now().weekday;
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          const SizedBox(width: _timeColWidth),
          for (final day in days)
            Container(
              width: colWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
                ),
              ),
              child: Text(
                Weekday.short(day),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: day == today
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(BuildContext context, int startHour, int endHour) {
    return SizedBox(
      width: _timeColWidth,
      child: Column(
        children: [
          for (int h = startHour; h < endHour; h++)
            SizedBox(
              height: _hourHeight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 6),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    ScheduleStore store,
    int day,
    double colWidth,
    int startHour,
    double gridHeight,
  ) {
    final dayEvents = store.eventsForDay(day);
    final dividerColor = Theme.of(context).dividerColor.withOpacity(0.25);

    return Container(
      width: colWidth,
      height: gridHeight,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
        ),
      ),
      child: Stack(
        children: [
          // Hour gridlines.
          Column(
            children: [
              for (int i = 0; i * 60 < gridHeight / _hourHeight * 60; i++)
                Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: dividerColor)),
                  ),
                ),
            ],
          ),
          // Event blocks.
          for (final event in dayEvents)
            _buildEventBlock(context, event, startHour, colWidth),
        ],
      ),
    );
  }

  Widget _buildEventBlock(
    BuildContext context,
    ScheduleEvent event,
    int startHour,
    double colWidth,
  ) {
    final top = (event.start.inMinutes - startHour * 60) / 60 * _hourHeight;
    final height =
        (event.durationMinutes / 60 * _hourHeight).clamp(24.0, double.infinity);
    final fg = contrastOn(event.color);

    return Positioned(
      top: top,
      left: 2,
      width: colWidth - 4,
      height: height - 2,
      child: Material(
        color: event.color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: event.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (event.notificationsEnabled)
                      Icon(Icons.notifications_active,
                          size: 12, color: fg),
                  ],
                ),
                if (height > 40)
                  Text(
                    event.start.format(),
                    style: TextStyle(color: fg.withOpacity(0.9), fontSize: 10),
                  ),
                if (height > 58 && event.location.isNotEmpty)
                  Text(
                    event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg.withOpacity(0.9), fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
