import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/schedule_store.dart';
import '../state/settings_store.dart';
import 'day_list_screen.dart';
import 'item_editor_screen.dart';
import 'priority_screen.dart';
import 'settings_screen.dart';
import 'subject_wizard_screen.dart';
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
        final store = context.read<ScheduleStore>();
        store.applyWeekAnchor(settings.weekAnchor);
        store.applyNotificationPreferences(
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

  /// The Add button first asks what to add: a whole subject or a single item.
  Future<void> _onAddPressed() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Subject'),
              subtitle: const Text(
                  'Add a course + lab/seminar (+ optional project) at once'),
              onTap: () => Navigator.of(ctx).pop('subject'),
            ),
            ListTile(
              leading: const Icon(Icons.add_task_outlined),
              title: const Text('Single item'),
              subtitle: const Text(
                  'Add one course, lab, test, exam, event, …'),
              onTap: () => Navigator.of(ctx).pop('item'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'subject') {
      await _openSubjectWizard();
    } else {
      await _openEditor();
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
      _showSnack(msg);
    }
  }

  Future<void> _openSubjectWizard() async {
    final result = await Navigator.of(context).push<SubjectSaveResult>(
      MaterialPageRoute(builder: (_) => const SubjectWizardScreen()),
    );
    if (result != null && mounted) {
      _showSnack('"${result.name}" added '
          '(${result.count} item${result.count == 1 ? '' : 's'})');
    }
  }

  void _showSnack(String msg) {
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
      // Add button only on the Grid tab.
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
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
