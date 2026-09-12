import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_event.dart';
import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
import 'event_editor_screen.dart';

/// Shows full details of an event: duration, description, hour interval,
/// location — plus a per-event notification toggle and reminder lead time.
class EventDetailsScreen extends StatelessWidget {
  final String eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  static const List<int> _leadOptions = [0, 5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final event = store.byId(eventId);

    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: const Center(child: Text('This event was deleted.')),
      );
    }

    final fg = contrastOn(event.color);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            backgroundColor: event.color,
            foregroundColor: fg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
              title: Text(
                event.title,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventEditorScreen(existing: event),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, store, event),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _infoTile(
                context,
                icon: Icons.calendar_today,
                label: 'Day',
                value: Weekday.long(event.weekday),
              ),
              _infoTile(
                context,
                icon: Icons.schedule,
                label: 'Time',
                value: event.intervalLabel,
              ),
              _infoTile(
                context,
                icon: Icons.hourglass_bottom,
                label: 'Duration',
                value: event.durationLabel,
              ),
              if (event.location.isNotEmpty)
                _infoTile(
                  context,
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: event.location,
                ),
              if (event.description.isNotEmpty)
                _infoTile(
                  context,
                  icon: Icons.notes,
                  label: 'Description',
                  value: event.description,
                ),
              const Divider(height: 24),
              _buildNotificationSection(context, store, event),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context,
      {required IconData icon,
      required String label,
      required String value}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _buildNotificationSection(
      BuildContext context, ScheduleStore store, ScheduleEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Reminder',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Notify me for this class'),
          subtitle: Text(event.notificationsEnabled
              ? 'You\'ll get a weekly reminder'
              : 'No reminder set'),
          value: event.notificationsEnabled,
          onChanged: (val) async {
            if (val) {
              await NotificationService.instance.requestPermissions();
            }
            await store.setEventNotifications(event.id, val);
          },
        ),
        if (event.notificationsEnabled)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Remind me before'),
            trailing: DropdownButton<int>(
              value: _leadOptions.contains(event.reminderMinutesBefore)
                  ? event.reminderMinutesBefore
                  : 10,
              items: [
                for (final m in _leadOptions)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m == 0 ? 'At start' : '$m min'),
                  ),
              ],
              onChanged: (m) async {
                if (m == null) return;
                final updated = event.copyWith(reminderMinutesBefore: m);
                await store.addOrUpdate(updated);
              },
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ScheduleStore store, ScheduleEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text('Remove "${event.title}" from your schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await store.delete(event.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
