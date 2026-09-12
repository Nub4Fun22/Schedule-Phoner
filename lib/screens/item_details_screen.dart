import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../services/notification_service.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';
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
              if (item.type == ItemType.lab) ...[
                const Divider(height: 24),
                _homeworkSection(context, store, item),
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
            subtitle: Text('Due ${_fmtDate(hw.dueDate)}'
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
    final result = await showDialog<Homework>(
      context: context,
      builder: (_) => _HomeworkDialog(lab: lab, existing: existing),
    );
    if (result != null) {
      await NotificationService.instance.requestPermissions();
      await store.addOrUpdateHomework(result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ScheduleStore store, ScheduleItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.type.label.toLowerCase()}?'),
        content: Text('Remove "${item.title}"?'
            '${item.type == ItemType.lab ? ' Its homework will also be removed.' : ''}'),
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Dialog to add/edit a homework attached to [lab].
class _HomeworkDialog extends StatefulWidget {
  final ScheduleItem lab;
  final Homework? existing;
  const _HomeworkDialog({required this.lab, this.existing});

  @override
  State<_HomeworkDialog> createState() => _HomeworkDialogState();
}

class _HomeworkDialogState extends State<_HomeworkDialog> {
  late TextEditingController _desc;
  late DateTime _due;
  late int _lead;

  static const List<int> _leadOptions = [0, 60, 2 * 60, 12 * 60, 24 * 60, 48 * 60];

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: widget.existing?.description ?? '');
    _due = widget.existing?.dueDate ??
        DateTime.now().add(const Duration(days: 7));
    _lead = widget.existing?.reminderMinutesBeforeLab ?? 24 * 60;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  String _leadLabel(int m) {
    if (m == 0) return 'At lab time';
    if (m == 24 * 60) return '1 day before lab';
    if (m == 48 * 60) return '2 days before lab';
    if (m >= 60) return '${m ~/ 60}h before lab';
    return '$m min before lab';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add homework' : 'Edit homework'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What is the homework? (optional)',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Due date'),
              subtitle: Text(
                  '${_due.day.toString().padLeft(2, '0')}/${_due.month.toString().padLeft(2, '0')}/${_due.year}'),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => _due = picked);
              },
            ),
            DropdownButtonFormField<int>(
              value: _leadOptions.contains(_lead) ? _lead : 24 * 60,
              decoration: const InputDecoration(labelText: 'Remind me'),
              items: [
                for (final m in _leadOptions)
                  DropdownMenuItem(value: m, child: Text(_leadLabel(m))),
              ],
              onChanged: (m) => setState(() => _lead = m ?? 24 * 60),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final hw = Homework(
              id: widget.existing?.id ??
                  'hw-${DateTime.now().microsecondsSinceEpoch}',
              labId: widget.lab.id,
              description: _desc.text.trim(),
              dueDate: _due,
              done: widget.existing?.done ?? false,
              reminderMinutesBeforeLab: _lead,
            );
            Navigator.of(context).pop(hw);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
