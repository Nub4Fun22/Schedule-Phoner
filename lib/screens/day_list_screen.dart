import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import 'item_details_screen.dart';

/// Day-by-day view: weekday chips, then that day's weekly items in order.
/// Labs show a homework badge. Tap an item to open its details.
class DayListScreen extends StatefulWidget {
  const DayListScreen({super.key});

  @override
  State<DayListScreen> createState() => DayListScreenState();
}

class DayListScreenState extends State<DayListScreen> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayOrMonday();
  }

  int _todayOrMonday() {
    final today = DateTime.now().weekday;
    return Weekday.fullWeek.contains(today) ? today : Weekday.monday;
  }

  /// Jump the view back to the current weekday. Called by the home shell each
  /// time the "Day" tab is selected, so opening it always lands on today.
  void showToday() {
    setState(() => _selectedDay = _todayOrMonday());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final items = store.weeklyItemsForDay(_selectedDay);

    return Column(
      children: [
        _daySelector(context),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _itemCard(context, store, items[i]),
                ),
        ),
      ],
    );
  }

  Widget _daySelector(BuildContext context) {
    final today = DateTime.now().weekday;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final day in Weekday.fullWeek)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(Weekday.short(day)),
                selected: _selectedDay == day,
                avatar:
                    day == today ? const Icon(Icons.today, size: 16) : null,
                onSelected: (_) => setState(() => _selectedDay = day),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.free_breakfast_outlined,
              size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text('Nothing on ${Weekday.long(_selectedDay)}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Tap "Add" to create a course, lab, test and more.'),
        ],
      ),
    );
  }

  Widget _itemCard(
      BuildContext context, ScheduleStore store, ScheduleItem item) {
    final activeHw =
        item.type == ItemType.lab ? store.activeHomeworksForLab(item.id) : const [];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(itemId: item.id))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: item.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.type.icon,
                              size: 18, color: item.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (item.notificationsEnabled)
                            Icon(Icons.notifications_active,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _typeBadge(context, item),
                          const SizedBox(width: 8),
                          const Icon(Icons.schedule, size: 15),
                          const SizedBox(width: 4),
                          Text(item.intervalLabel),
                        ],
                      ),
                      if (item.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 15),
                            const SizedBox(width: 4),
                            Text(item.location),
                          ],
                        ),
                      ],
                      if (activeHw.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_late_outlined,
                                  size: 14),
                              const SizedBox(width: 4),
                              Text('${activeHw.length} homework due',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(BuildContext context, ScheduleItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(item.type.label,
          style: TextStyle(
              color: item.color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
