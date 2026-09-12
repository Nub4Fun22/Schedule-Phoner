import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import 'day_list_screen.dart';
import 'item_editor_screen.dart';
import 'priority_screen.dart';
import 'week_grid_screen.dart';
import 'whats_next_screen.dart';

/// Main shell. Four views selectable from the bottom bar:
///   Grid | Day | What's next | Priority
/// The first two are the timetable; the last two are the requested extra
/// buttons "below where you choose between week or day".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _titles = ['Weekly grid', 'By day', "What's next", 'Priority'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Notifications & settings',
            icon: Icon(store.anyNotificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_none),
            onPressed: () => _openSettings(context, store),
          ),
        ],
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: const [
                WeekGridScreen(),
                DayListScreen(),
                WhatsNextScreen(),
                PriorityScreen(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ItemEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Grid',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_day_outlined),
            selectedIcon: Icon(Icons.view_day),
            label: 'Day',
          ),
          NavigationDestination(
            icon: Icon(Icons.upcoming_outlined),
            selectedIcon: Icon(Icons.upcoming),
            label: 'Next',
          ),
          NavigationDestination(
            icon: Icon(Icons.priority_high_outlined),
            selectedIcon: Icon(Icons.priority_high),
            label: 'Priority',
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, ScheduleStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<ScheduleStore>(
        builder: (ctx, store, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text('Notifications',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ],
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Reminders for all items'),
                subtitle:
                    const Text('Turn silent reminders on/off for everything'),
                value: store.allNotificationsEnabled,
                onChanged: (val) async {
                  if (val) {
                    await NotificationService.instance.requestPermissions();
                  }
                  await store.setAllNotifications(val);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dataset_outlined),
                title: const Text('Load sample data (demo)'),
                subtitle: const Text(
                    'Fills the app with example items of each type. '
                    'Replaces your current items.'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _confirmSample(context, store);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSample(BuildContext context, ScheduleStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load sample data?'),
        content: const Text(
            'This replaces your current items with demo examples. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Load sample')),
        ],
      ),
    );
    if (confirmed == true) await store.loadSample();
  }
}
