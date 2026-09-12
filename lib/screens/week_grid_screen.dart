import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
import 'item_details_screen.dart';

/// Excel-like weekly grid of the recurring items (courses, labs, weekly
/// tests/projects). One-time items (exams, presentations) live in the
/// "What's next" / "Priority" screens.
class WeekGridScreen extends StatelessWidget {
  const WeekGridScreen({super.key});

  static const double _hourHeight = 64.0;
  static const double _timeColWidth = 52.0;
  static const double _headerHeight = 40.0;
  static const double _minColWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final days = Weekday.schoolWeek;

    // Always show a full standard day (7:00–22:00) so the grid has all its
    // hour rows even when the schedule is empty. If any weekly item falls
    // outside that window, expand the range to include it.
    const int defaultStartHour = 7;
    const int defaultEndHour = 22;
    final weekly = store.items.where((e) => !e.oneTime).toList();
    int startHour = defaultStartHour;
    int endHour = defaultEndHour;
    if (weekly.isNotEmpty) {
      final minMinutes =
          weekly.map((e) => e.start.inMinutes).reduce((a, b) => a < b ? a : b);
      final maxMinutes =
          weekly.map((e) => e.end.inMinutes).reduce((a, b) => a > b ? a : b);
      startHour = (minMinutes ~/ 60).clamp(0, defaultStartHour);
      endHour = ((maxMinutes + 59) ~/ 60).clamp(defaultEndHour, 24);
    }
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
                _headerRow(context, days, colWidth),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: gridHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _timeColumn(context, startHour, endHour),
                          for (final day in days)
                            _dayColumn(context, store, day, colWidth,
                                startHour, gridHeight),
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

  Widget _headerRow(BuildContext context, List<int> days, double colWidth) {
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
                  left: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.4)),
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

  Widget _timeColumn(BuildContext context, int startHour, int endHour) {
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
                  child: Text('${h.toString().padLeft(2, '0')}:00',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayColumn(BuildContext context, ScheduleStore store, int day,
      double colWidth, int startHour, double gridHeight) {
    final items = store.weeklyItemsForDay(day);
    final dividerColor = Theme.of(context).dividerColor.withOpacity(0.25);
    final rows = (gridHeight / _hourHeight).ceil();

    return Container(
      width: colWidth,
      height: gridHeight,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.4)),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              for (int i = 0; i < rows; i++)
                Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: dividerColor)),
                  ),
                ),
            ],
          ),
          for (final item in items)
            _block(context, store, item, startHour, colWidth),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, ScheduleStore store, ScheduleItem item,
      int startHour, double colWidth) {
    final top = (item.start.inMinutes - startHour * 60) / 60 * _hourHeight;
    final height =
        (item.durationMinutes / 60 * _hourHeight).clamp(26.0, double.infinity);
    final fg = contrastOn(item.color);
    final hasHw = item.type == ItemType.lab &&
        store.activeHomeworksForLab(item.id).isNotEmpty;

    return Positioned(
      top: top,
      left: 2,
      width: colWidth - 4,
      height: height - 2,
      child: Material(
        color: item.color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(itemId: item.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(item.type.icon, size: 12, color: fg),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    if (hasHw) Icon(Icons.assignment_late, size: 12, color: fg),
                    if (item.notificationsEnabled)
                      Icon(Icons.notifications_active, size: 11, color: fg),
                  ],
                ),
                if (height > 42)
                  Text(item.start.format(),
                      style: TextStyle(color: fg.withOpacity(0.9), fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
