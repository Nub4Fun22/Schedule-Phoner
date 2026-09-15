import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
import '../widgets/date_format_utils.dart';
import 'homework_task_dialog.dart';
import 'item_editor_screen.dart';

/// Details of a schedule item: type, when, duration, description, location,
/// per-item notification toggle. For Labs, manage attached homework. For
/// Projects, link to a lab.
class ItemDetailsScreen extends StatelessWidget {
  final String itemId;
  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final item = store.itemById(itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: const Center(child: Text('This item was deleted.')),
      );
    }
    final fg = contrastOn(item.color);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            backgroundColor: item.color,
            foregroundColor: fg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.type.icon, color: fg, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(item.title,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ItemEditorScreen(existing: item))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, store, item),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _tile(context, Icons.label_outline, 'Type', item.type.label),
              _tile(context, Icons.event, 'When', item.whenLabel),
              _tile(context, Icons.hourglass_bottom, 'Duration',
                  item.durationLabel),
              if (item.location.isNotEmpty)
                _tile(context, Icons.place_outlined, 'Location', item.location),
              if (item.description.isNotEmpty)
                _tile(context, Icons.notes, 'Description', item.description),
              const Divider(height: 24),
              _notificationSwitch(context, store, item),
              if (item.type.carriesHomework) ...[
                const Divider(height: 24),
                _homeworkSection(context, store, item),
              ],
              if (item.type == ItemType.event) ...[
                const Divider(height: 24),
                _taskSection(context, store, item),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _notificationSwitch(
      BuildContext context, ScheduleStore store, ScheduleItem item) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: const Text('Reminder for this item'),
      subtitle: Text(item.notificationsEnabled
          ? 'Silent reminder is scheduled'
          : 'No reminder'),
      value: item.notificationsEnabled,
      onChanged: (v) async {
        if (v) await NotificationService.instance.requestPermissions();
        await store.setItemNotifications(item.id, v);
      },
    );
  }

  // ---- Homework management (labs only) ------------------------------------

  Widget _homeworkSection(
      BuildContext context, ScheduleStore store, ScheduleItem lab) {
    final homeworks = store.homeworksForLab(lab.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('Homework',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () => _editHomework(context, store, lab, null),
              ),
            ],
          ),
        ),
        if (homeworks.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('No homework yet. Homework reminds you before each '
                'occurrence of this lab, until you mark it done.'),
          ),
        for (final hw in homeworks)
          ListTile(
            leading: Checkbox(
              value: hw.done,
              onChanged: (v) => store.setHomeworkDone(hw.id, v ?? false),
            ),
            title: Text(
              hw.description.isEmpty ? 'Homework' : hw.description,
              style: TextStyle(
                decoration: hw.done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text('Due ${DateFormatUtils.dueWithCountdown(hw.dueDate)}'
                '${hw.isOverdue ? ' • OVERDUE' : ''}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editHomework(context, store, lab, hw);
                if (v == 'delete') store.deleteHomework(hw.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editHomework(BuildContext context, ScheduleStore store,
      ScheduleItem lab, Homework? existing) async {
    final result = await showDialog<ReminderConfig>(
      context: context,
      builder: (_) => ReminderDialog(
        title: existing == null ? 'Add homework' : 'Edit homework',
        parentLabel: 'lab',
        descriptionHint: 'What is the homework? (optional)',
        initial: existing == null
            ? null
            : ReminderConfig(
                description: existing.description,
                dueDate: existing.dueDate,
                leadMinutes: existing.reminderMinutesBeforeLab,
                dailyUntil: existing.dailyUntil,
                dailyTime: existing.dailyReminderTime,
              ),
      ),
    );
    if (result != null) {
      await NotificationService.instance.requestPermissions();
      await store.addOrUpdateHomework(Homework(
        id: existing?.id ?? 'hw-${DateTime.now().microsecondsSinceEpoch}',
        labId: lab.id,
        description: result.description,
        dueDate: result.dueDate,
        done: existing?.done ?? false,
        reminderMinutesBeforeLab: result.leadMinutes,
        dailyUntil: result.dailyUntil,
        dailyReminderTime: result.dailyTime,
      ));
    }
  }

  // ---- Task management (events only) --------------------------------------

  Widget _taskSection(
      BuildContext context, ScheduleStore store, ScheduleItem event) {
    final tasks = store.tasksForEvent(event.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('Tasks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () => _editTask(context, store, event, null),
              ),
            ],
          ),
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(event.oneTime
                ? 'No tasks yet. (Recurring task reminders only work for '
                    'weekly events; add a task to keep a checklist.)'
                : 'No tasks yet. A task reminds you before each occurrence of '
                    'this event, until you mark it done.'),
          ),
        for (final t in tasks)
          ListTile(
            leading: Checkbox(
              value: t.done,
              onChanged: (v) => store.setTaskDone(t.id, v ?? false),
            ),
            title: Text(
              t.description.isEmpty ? 'Task' : t.description,
              style: TextStyle(
                decoration: t.done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text('Due ${DateFormatUtils.dueWithCountdown(t.dueDate)}'
                '${t.isOverdue ? ' • OVERDUE' : ''}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editTask(context, store, event, t);
                if (v == 'delete') store.deleteTask(t.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editTask(BuildContext context, ScheduleStore store,
      ScheduleItem event, Task? existing) async {
    final result = await showDialog<ReminderConfig>(
      context: context,
      builder: (_) => ReminderDialog(
        title: existing == null ? 'Add task' : 'Edit task',
        parentLabel: 'event',
        descriptionHint: 'What is the task? (e.g. do dishes)',
        initial: existing == null
            ? null
            : ReminderConfig(
                description: existing.description,
                dueDate: existing.dueDate,
                leadMinutes: existing.reminderMinutesBeforeEvent,
                dailyUntil: existing.dailyUntil,
                dailyTime: existing.dailyReminderTime,
              ),
      ),
    );
    if (result != null) {
      await NotificationService.instance.requestPermissions();
      await store.addOrUpdateTask(Task(
        id: existing?.id ?? 'task-${DateTime.now().microsecondsSinceEpoch}',
        eventId: event.id,
        description: result.description,
        dueDate: result.dueDate,
        done: existing?.done ?? false,
        reminderMinutesBeforeEvent: result.leadMinutes,
        dailyUntil: result.dailyUntil,
        dailyReminderTime: result.dailyTime,
      ));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ScheduleStore store, ScheduleItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.type.label.toLowerCase()}?'),
        content: Text('Remove "${item.title}"?'
            '${item.type.carriesHomework ? ' Its homework will also be removed.' : ''}'
            '${item.type == ItemType.event ? ' Its tasks will also be removed.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await store.deleteItem(item.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
