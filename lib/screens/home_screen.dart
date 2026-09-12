import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import 'day_list_screen.dart';
import 'event_editor_screen.dart';
import 'week_grid_screen.dart';

/// Main shell: switches between the weekly grid and the day list, hosts the
/// "add class" button and the settings sheet (with the "notify all" control).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _titles = ['Weekly grid', 'By day'];

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
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EventEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add class'),
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
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, ScheduleStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer<ScheduleStore>(
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
                  title: const Text('Notify me for all classes'),
                  subtitle: const Text(
                      'Turns weekly reminders on or off for every class'),
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
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Reset to sample schedule'),
                  subtitle:
                      const Text('Replace all classes with the built-in sample'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _confirmReset(context, store);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, ScheduleStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset schedule?'),
        content: const Text(
            'This replaces your current classes with the sample schedule. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.resetToSample();
    }
  }
}
