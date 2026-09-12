import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_event.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
import 'event_details_screen.dart';

/// Day-by-day view: a row of selectable weekday chips, then a chronological
/// list of that day's events. Tap an event to see full details.
class DayListScreen extends StatefulWidget {
  const DayListScreen({super.key});

  @override
  State<DayListScreen> createState() => _DayListScreenState();
}

class _DayListScreenState extends State<DayListScreen> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    // Default to today if it's a school day, otherwise Monday.
    _selectedDay = Weekday.schoolWeek.contains(today) ? today : Weekday.monday;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final events = store.eventsForDay(_selectedDay);

    return Column(
      children: [
        _buildDaySelector(context),
        const Divider(height: 1),
        Expanded(
          child: events.isEmpty
              ? _buildEmpty(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildEventCard(context, events[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildDaySelector(BuildContext context) {
    final today = DateTime.now().weekday;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final day in Weekday.schoolWeek)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(Weekday.short(day)),
                selected: _selectedDay == day,
                avatar: day == today
                    ? const Icon(Icons.today, size: 16)
                    : null,
                onSelected: (_) => setState(() => _selectedDay = day),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.free_breakfast_outlined,
              size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text('No classes on ${Weekday.long(_selectedDay)}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Enjoy your free day!',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, ScheduleEvent event) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(eventId: event.id),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: event.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (event.notificationsEnabled)
                            Icon(Icons.notifications_active,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 15),
                          const SizedBox(width: 4),
                          Text(event.intervalLabel),
                          const SizedBox(width: 10),
                          Text('(${event.durationLabel})',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      if (event.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 15),
                            const SizedBox(width: 4),
                            Text(event.location),
                          ],
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
}
