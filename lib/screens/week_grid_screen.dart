import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../state/settings_store.dart';
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
    final settings = context.watch<SettingsStore>();
    final showWeekend = settings.showWeekendInGrid;
    final showAll = settings.showAllWeeks;
    final days = showWeekend ? Weekday.fullWeek : Weekday.schoolWeek;
    final weekNumber = store.currentWeekNumber;

    // Always show a full standard day (7:00–22:00) so the grid has all its
    // hour rows even when the schedule is empty. If any displayed item falls
    // outside that window, expand the range to include it. "Displayed" = the
    // items each visible day column will actually render (weekly + this week's
    // one-time items).
    const int defaultStartHour = 7;
    const int defaultEndHour = 22;
    final displayed = [
      for (final d in days)
        ...store.gridItemsForDay(d, includeAllParities: showAll)
    ];
    int startHour = defaultStartHour;
    int endHour = defaultEndHour;
    if (displayed.isNotEmpty) {
      final minMinutes = displayed
          .map((e) => e.start.inMinutes)
          .reduce((a, b) => a < b ? a : b);
      final maxMinutes =
          displayed.map((e) => e.end.inMinutes).reduce((a, b) => a > b ? a : b);
      startHour = (minMinutes ~/ 60).clamp(0, defaultStartHour);
      endHour = ((maxMinutes + 59) ~/ 60).clamp(defaultEndHour, 24);
    }
    final totalHours = (endHour - startHour).clamp(1, 24);
    final gridHeight = totalHours * _hourHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _weekBanner(context, weekNumber, showAll, settings),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth - _timeColWidth;
              final colWidth =
                  (available / days.length).clamp(_minColWidth, 400.0);
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
                                      startHour, gridHeight, showAll),
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
          ),
        ),
      ],
    );
  }

  Widget _weekBanner(BuildContext context, int weekNumber, bool showAll,
      SettingsStore settings) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text('Week $weekNumber',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('(${weekNumber.isEven ? 'even' : 'odd'})',
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          // Toggle: show every item regardless of odd/even parity.
          Text('All weeks', style: Theme.of(context).textTheme.bodySmall),
          Switch(
            value: showAll,
            onChanged: (v) => settings.setShowAllWeeks(v),
          ),
        ],
      ),
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
      double colWidth, int startHour, double gridHeight, bool showAll) {
    final items = store.gridItemsForDay(day, includeAllParities: showAll);
    final dividerColor = Theme.of(context).dividerColor.withOpacity(0.25);
    final rows = (gridHeight / _hourHeight).ceil();

    // Group items that overlap in time so they can be laid out side-by-side
    // (e.g. an odd-week lab and an even-week project in the same slot when
    // "show all weeks" is on). Non-overlapping items each form their own group.
    final groups = _overlapGroups(items);
    final blocks = <Widget>[];
    for (final group in groups) {
      final n = group.length;
      for (var i = 0; i < n; i++) {
        blocks.add(_block(context, store, group[i], startHour, colWidth,
            slotIndex: i, slotCount: n, showAll: showAll));
      }
    }

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
          ...blocks,
        ],
      ),
    );
  }

  /// Partition [items] (sorted by start) into groups of mutually time-
  /// overlapping items. Each group is rendered as side-by-side sub-columns.
  List<List<ScheduleItem>> _overlapGroups(List<ScheduleItem> items) {
    final groups = <List<ScheduleItem>>[];
    for (final item in items) {
      var placed = false;
      for (final group in groups) {
        // Overlaps if it intersects any item already in the group.
        final overlaps = group.any((g) =>
            item.start.inMinutes < g.end.inMinutes &&
            g.start.inMinutes < item.end.inMinutes);
        if (overlaps) {
          group.add(item);
          placed = true;
          break;
        }
      }
      if (!placed) groups.add([item]);
    }
    return groups;
  }

  Widget _block(BuildContext context, ScheduleStore store, ScheduleItem item,
      int startHour, double colWidth,
      {int slotIndex = 0, int slotCount = 1, bool showAll = false}) {
    final top = (item.start.inMinutes - startHour * 60) / 60 * _hourHeight;
    final height =
        (item.durationMinutes / 60 * _hourHeight).clamp(26.0, double.infinity);
    final fg = contrastOn(item.color);
    final hasHw = item.type.carriesHomework &&
        store.activeHomeworksForLab(item.id).isNotEmpty;

    // Side-by-side layout within a group of overlapping items.
    const outerPad = 2.0;
    const gap = 2.0;
    final usable = colWidth - outerPad * 2;
    final slotWidth = (usable - gap * (slotCount - 1)) / slotCount;
    final left = outerPad + slotIndex * (slotWidth + gap);

    // Show a parity badge only when "all weeks" is on and the item is
    // restricted (so you can tell which belongs to odd vs even).
    final parityBadge = showAll && item.weekParity != WeekParity.any
        ? (item.weekParity == WeekParity.odd ? 'Odd' : 'Even')
        : null;
    final narrow = slotWidth < 90;

    return Positioned(
      top: top,
      left: left,
      width: slotWidth,
      height: height - 2,
      child: Material(
        color: item.color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(itemId: item.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(item.type.icon, size: 12, color: fg),
                    if (!narrow) const SizedBox(width: 3),
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
                    if (item.notificationsEnabled && !narrow)
                      Icon(Icons.notifications_active, size: 11, color: fg),
                  ],
                ),
                if (parityBadge != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: fg.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(parityBadge,
                        style: TextStyle(
                            color: fg,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                if (height > 42 && parityBadge == null)
                  Text(item.start.format(),
                      style:
                          TextStyle(color: fg.withOpacity(0.9), fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
