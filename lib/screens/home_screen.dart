import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/schedule_store.dart';
import '../state/settings_store.dart';
import 'day_list_screen.dart';
import 'item_editor_screen.dart';
import 'priority_screen.dart';
import 'settings_screen.dart';
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
  bool _syncedPrefs = false;

  /// Key to the Day view so we can reset it to "today" when its tab is opened.
  final GlobalKey<DayListScreenState> _dayKey = GlobalKey<DayListScreenState>();

  static const _titles = ['Weekly grid', 'By day', "What's next", 'Priority'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once settings have loaded from disk, push the notification sound/vibrate
    // preferences into the schedule store so cold-start rescheduling uses the
    // right channel set. Runs once.
    final settings = context.watch<SettingsStore>();
    if (settings.isLoaded && !_syncedPrefs) {
      _syncedPrefs = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ScheduleStore>().applyNotificationPreferences(
              sound: settings.notificationSound,
              vibrate: settings.vibrate,
            );
      });
    }
  }

  void _onTabSelected(int i) {
    setState(() => _tab = i);
    // Whenever the "Day" tab (index 1) is opened, jump to the current weekday.
    // Deferred to after the frame so the Day view's State is attached (the
    // IndexedStack may build it lazily on first selection).
    if (i == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dayKey.currentState?.showToday();
      });
    }
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<ItemSaveResult>(
      MaterialPageRoute(builder: (_) => const ItemEditorScreen()),
    );
    if (result != null && mounted) {
      final name = result.title.trim().isEmpty ? 'Item' : result.title.trim();
      final msg = result.isNew
          ? '"$name" has been added successfully'
          : '"$name" has been updated';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                const WeekGridScreen(),
                DayListScreen(key: _dayKey),
                const WhatsNextScreen(),
                const PriorityScreen(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
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
}
