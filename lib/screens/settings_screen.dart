import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import '../state/settings_store.dart';

/// A full settings screen: notification behavior, appearance, demo data and
/// destructive data actions (delete demo / delete everything).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<int> _reminderOptions = [0, 5, 10, 15, 30, 60, 120, 24 * 60];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final store = context.watch<ScheduleStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Notifications'),

          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Reminders for all items'),
            subtitle: const Text('Turn reminders on/off for everything'),
            value: store.allNotificationsEnabled,
            onChanged: (val) async {
              if (val) {
                await NotificationService.instance.requestPermissions();
              }
              await store.setAllNotifications(val);
            },
          ),
          SwitchListTile(
            secondary: Icon(settings.notificationSound
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined),
            title: const Text('Notification sound'),
            subtitle: Text(settings.notificationSound
                ? 'Notifications play a sound (loud)'
                : 'Silent — no sound (default)'),
            value: settings.notificationSound,
            onChanged: (val) async {
              await settings.setNotificationSound(val);
              // Reschedule so the sound/silent channel change applies now.
              await store.applyNotificationPreferences(
                sound: val,
                vibrate: settings.vibrate,
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibrate'),
            subtitle: const Text('Vibrate on reminders'),
            value: settings.vibrate,
            onChanged: (val) async {
              await settings.setVibrate(val);
              await store.applyNotificationPreferences(
                sound: settings.notificationSound,
                vibrate: val,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Default reminder time'),
            subtitle: Text('New items remind '
                '${_reminderLabel(settings.defaultReminderMinutes)} by default'),
            trailing: DropdownButton<int>(
              value: _reminderOptions.contains(settings.defaultReminderMinutes)
                  ? settings.defaultReminderMinutes
                  : 10,
              underline: const SizedBox.shrink(),
              items: [
                for (final m in _reminderOptions)
                  DropdownMenuItem(value: m, child: Text(_reminderLabel(m))),
              ],
              onChanged: (m) =>
                  settings.setDefaultReminderMinutes(m ?? 10),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: const Text('Send a test notification'),
            subtitle: const Text('Check that reminders work on this device'),
            onTap: () async {
              await NotificationService.instance.requestPermissions();
              final enabled =
                  await NotificationService.instance.areNotificationsEnabled();
              await NotificationService.instance.showTestNotification(
                sound: settings.notificationSound,
                vibrate: settings.vibrate,
              );
              if (!context.mounted) return;
              _snack(
                  context,
                  enabled
                      ? 'Test notification sent — check your notification shade'
                      : 'Notifications are blocked for this app — enable them '
                          'in Android settings');
            },
          ),

          const Divider(),
          _sectionHeader(context, 'Appearance'),

          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) => settings.setThemeMode(m ?? ThemeMode.system),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.weekend_outlined),
            title: const Text('Show weekend in grid'),
            subtitle: const Text('Include Saturday & Sunday columns'),
            value: settings.showWeekendInGrid,
            onChanged: (val) => settings.setShowWeekendInGrid(val),
          ),

          const Divider(),
          _sectionHeader(context, 'Demo data'),

          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('Import demo data'),
            subtitle: const Text(
                'Adds example items of every type so you can try the app. '
                'Your own items are kept.'),
            onTap: () async {
              await store.loadSample();
              _snack(context, 'Demo data imported');
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined,
                color: store.hasDemoData
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).disabledColor),
            title: const Text('Delete demo data'),
            subtitle: Text(store.hasDemoData
                ? 'Removes only the demo items, keeps yours'
                : 'No demo data to remove'),
            enabled: store.hasDemoData,
            onTap: store.hasDemoData
                ? () async {
                    await store.deleteSample();
                    _snack(context, 'Demo data removed');
                  }
                : null,
          ),

          const Divider(),
          _sectionHeader(context, 'Danger zone'),

          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text('Delete everything',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text(
                'Permanently removes all items and homework'),
            onTap: () => _confirmDeleteAll(context, store),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(
      BuildContext context, ScheduleStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error),
        title: const Text('Delete everything?'),
        content: const Text(
            'This permanently removes ALL your items and homework. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await store.deleteAll();
      if (context.mounted) _snack(context, 'Everything deleted');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  static String _reminderLabel(int m) {
    if (m == 0) return 'at start';
    if (m == 24 * 60) return '1 day before';
    if (m >= 60) return '${m ~/ 60}h before';
    return '$m min before';
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Follow system';
    }
  }
}
