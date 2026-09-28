import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../widgets/date_format_utils.dart';
import '../widgets/lead_time_picker.dart';

/// Reminder configuration shared by homework (attached to a lab/seminar) and
/// tasks (attached to an event). Supports two modes:
///  * "before each" — remind a chosen lead time before each weekly occurrence
///    of the parent lab/event (default).
///  * "daily until" — remind EVERY DAY at a chosen hour until the due date.
class ReminderConfig {
  final String description;
  final DateTime dueDate;
  final int leadMinutes;
  final bool dailyUntil;
  final SlotTime? dailyTime;

  const ReminderConfig({
    required this.description,
    required this.dueDate,
    required this.leadMinutes,
    required this.dailyUntil,
    required this.dailyTime,
  });
}

/// A dialog that edits a [ReminderConfig]. [parentLabel] is "lab" or "event"
/// so the wording matches the context.
class ReminderDialog extends StatefulWidget {
  final String title;
  final String parentLabel; // 'lab' or 'event'
  final String descriptionHint;
  final ReminderConfig? initial;

  const ReminderDialog({
    super.key,
    required this.title,
    required this.parentLabel,
    required this.descriptionHint,
    this.initial,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late TextEditingController _desc;
  late DateTime _due;
  late int _lead;
  late bool _daily;
  late TimeOfDay _dailyTime;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _desc = TextEditingController(text: init?.description ?? '');
    _due = init?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _lead = init?.leadMinutes ?? 24 * 60;
    _daily = init?.dailyUntil ?? false;
    final dt = init?.dailyTime;
    _dailyTime =
        dt != null ? TimeOfDay(hour: dt.hour, minute: dt.minute) : const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  String _leadLabel(int m) {
    if (m == 0) return 'At ${widget.parentLabel} time';
    return LeadTime.label(m, suffix: 'before ${widget.parentLabel}');
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: InputDecoration(labelText: widget.descriptionHint),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Due date'),
              subtitle: Text(DateFormatUtils.dueWithCountdown(_due)),
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
            const SizedBox(height: 8),
            // Reminder-mode switch.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alert me every day until then'),
              subtitle: Text(_daily
                  ? 'Daily at ${_fmtTime(_dailyTime)} until the ${widget.parentLabel}'
                  : 'Remind once before each ${widget.parentLabel}'),
              value: _daily,
              onChanged: (v) => setState(() => _daily = v),
            ),
            if (_daily)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Daily reminder time'),
                subtitle: Text(_fmtTime(_dailyTime)),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: _dailyTime);
                  if (picked != null) setState(() => _dailyTime = picked);
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Remind me'),
                subtitle: Text(_leadLabel(_lead)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final picked = await LeadTime.pick(context, _lead);
                  if (picked != null) setState(() => _lead = picked);
                },
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
            Navigator.of(context).pop(ReminderConfig(
              description: _desc.text.trim(),
              dueDate: _due,
              leadMinutes: _lead,
              dailyUntil: _daily,
              dailyTime: _daily
                  ? SlotTime(_dailyTime.hour, _dailyTime.minute)
                  : null,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
