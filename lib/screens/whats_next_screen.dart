import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import 'item_details_screen.dart';

/// "What's next" — upcoming item occurrences by time (soonest first).
/// Includes courses, labs, tests, projects, presentations and exams
/// (not homework). Shows a countdown to each.
class WhatsNextScreen extends StatelessWidget {
  const WhatsNextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final now = DateTime.now();
    final upcoming = store.upcoming(from: now, limit: 40);

    if (upcoming.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 56, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            const Text('Nothing coming up yet.'),
            const SizedBox(height: 4),
            const Text('Add courses, labs, tests or exams to see them here.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: upcoming.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final occ = upcoming[i];
        final item = occ.item;
        final countdown = _countdown(now, occ.when);
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.color,
              foregroundColor: Colors.white,
              child: Icon(item.type.icon, size: 20),
            ),
            title: Text(item.title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${item.type.label} • ${_whenLabel(occ.when)} • '
                '${item.start.format()}'),
            trailing: Text(countdown,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ItemDetailsScreen(itemId: item.id))),
          ),
        );
      },
    );
  }

  String _whenLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final diffDays = target.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    if (diffDays < 7) return Weekday.long(when.weekday);
    return '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}';
  }

  String _countdown(DateTime now, DateTime when) {
    final d = when.difference(now);
    if (d.inMinutes < 60) return 'in ${d.inMinutes}m';
    if (d.inHours < 24) return 'in ${d.inHours}h';
    return 'in ${d.inDays}d';
  }
}
