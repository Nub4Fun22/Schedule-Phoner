import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../state/settings_store.dart';
import '../widgets/color_utils.dart';
import '../widgets/date_format_utils.dart';
import '../widgets/lead_time_picker.dart';
import 'homework_task_dialog.dart';

/// Result returned when an item is saved, so callers can show confirmation.
class ItemSaveResult {
  final String title;
  final bool isNew;
  const ItemSaveResult({required this.title, required this.isNew});
}

/// Create or edit a schedule item. Pass [existing] to edit; null to create.
class ItemEditorScreen extends StatefulWidget {
  final ScheduleItem? existing;
  final ItemType? initialType;
  const ItemEditorScreen({super.key, this.existing, this.initialType});

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _title;
  late TextEditingController _description;
  late TextEditingController _location;

  late ItemType _type;
  late bool _oneTime;
  late int _weekday;
  DateTime? _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _colorValue;
  late int _reminderMinutes;

  bool get _isEditing => widget.existing != null;

  /// Homework/tasks the user adds inline while CREATING a new lab/seminar/event
  /// (before it has an id). Persisted on save. Only used for new items.
  final List<ReminderConfig> _pendingSubItems = [];

  /// Whether the current type carries inline sub-items (homework or tasks).
  bool get _carriesSubItems =>
      _type.carriesHomework || _type == ItemType.event;

  /// Word for the sub-item given the current type.
  String get _subItemNoun => _type == ItemType.event
      ? 'task'
      : _type == ItemType.project
          ? 'deadline'
          : 'homework';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? ItemType.course;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _weekday = e?.weekday ?? Weekday.monday;
    _date = e?.date;
    _start = e?.start.toTimeOfDay() ?? const TimeOfDay(hour: 8, minute: 0);
    _end = e?.end.toTimeOfDay() ?? const TimeOfDay(hour: 9, minute: 30);
    _colorValue = e?.colorValue ?? kSubjectPalette.first;
    _reminderMinutes = e?.reminderMinutesBefore ?? 10;
    _oneTime = e?.oneTime ?? _defaultOneTimeFor(_type);
    _applyTypeConstraints();
  }

  bool _appliedDefaultReminder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // For NEW items, seed the reminder lead time from the user's default
    // (once). Editing keeps the item's own value.
    if (!_isEditing && !_appliedDefaultReminder) {
      _appliedDefaultReminder = true;
      final def = context.read<SettingsStore>().defaultReminderMinutes;
      if (def >= 0) {
        setState(() => _reminderMinutes = def);
      }
    }
  }

  bool _defaultOneTimeFor(ItemType t) {
    if (t.isOneTimeOnly) return true;
    if (t.isWeeklyOnly) return false;
    return false; // both-mode types default to weekly
  }

  /// Force _oneTime to a valid value for the current type.
  void _applyTypeConstraints() {
    if (_type.isOneTimeOnly) {
      _oneTime = true;
    } else if (_type.isWeeklyOnly) {
      _oneTime = false;
    }
    if (_oneTime && _date == null) {
      _date = DateTime.now().add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked =
        await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_min(_end) <= _min(_start)) {
          final endM = (_min(_start) + 90).clamp(0, 23 * 60 + 59);
          _end = TimeOfDay(hour: endM ~/ 60, minute: endM % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_min(_end) <= _min(_start)) {
      _snack('End time must be after start time.');
      return;
    }
    if (_oneTime && _date == null) {
      _snack('Please pick a date.');
      return;
    }

    final store = context.read<ScheduleStore>();
    final id = widget.existing?.id ??
        'item-${DateTime.now().microsecondsSinceEpoch}';

    final item = ScheduleItem(
      id: id,
      type: _type,
      title: _title.text.trim(),
      description: _description.text.trim(),
      location: _location.text.trim(),
      oneTime: _oneTime,
      weekday: _weekday,
      date: _oneTime ? _date : null,
      start: SlotTime.fromTimeOfDay(_start),
      end: SlotTime.fromTimeOfDay(_end),
      colorValue: _colorValue,
      notificationsEnabled: widget.existing?.notificationsEnabled ?? true,
      reminderMinutesBefore: _reminderMinutes,
    );

    final result = ItemSaveResult(title: item.title, isNew: !_isEditing);
    try {
      await store.addOrUpdateItem(item);
      // Persist any inline-added homework/tasks now that the item has an id.
      for (final cfg in _pendingSubItems) {
        if (_type == ItemType.event) {
          await store.addOrUpdateTask(Task(
            id: 'task-${DateTime.now().microsecondsSinceEpoch}-${cfg.hashCode & 0xFFFF}',
            eventId: item.id,
            description: cfg.description,
            dueDate: cfg.dueDate,
            reminderMinutesBeforeEvent: cfg.leadMinutes,
            dailyUntil: cfg.dailyUntil,
            dailyReminderTime: cfg.dailyTime,
          ));
        } else {
          await store.addOrUpdateHomework(Homework(
            id: 'hw-${DateTime.now().microsecondsSinceEpoch}-${cfg.hashCode & 0xFFFF}',
            labId: item.id,
            description: cfg.description,
            dueDate: cfg.dueDate,
            reminderMinutesBeforeLab: cfg.leadMinutes,
            dailyUntil: cfg.dailyUntil,
            dailyReminderTime: cfg.dailyTime,
          ));
        }
      }
    } catch (e) {
      // Persisting/scheduling should never block closing the editor. The item
      // is saved in memory + prefs regardless; log and continue.
      debugPrint('addOrUpdateItem error (continuing to close): $e');
    }
    // Always return a result so the caller can confirm the save and the editor
    // closes, even if a side-effect (e.g. notification scheduling) failed.
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _leadLabel(int m) => LeadTime.label(m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit ${_type.label}' : 'New item'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Extra bottom padding (+ the system nav-bar inset) so the last
          // fields scroll clear of the on-screen navigation buttons.
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewPadding.bottom + 48,
          ),
          children: [
            // Type selector
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ItemTypeX.displayOrder)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 18),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() {
                      _type = t;
                      _applyTypeConstraints();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Subject / Title',
                prefixIcon: Icon(Icons.book_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Color — placed near the top so it's easy to reach.
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _colorPicker(),
            const SizedBox(height: 16),

            // One-time vs weekly (only for types that support both)
            if (_type.supportsBothModes) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Weekly'), icon: Icon(Icons.repeat)),
                  ButtonSegment(value: true, label: Text('One-time'), icon: Icon(Icons.event)),
                ],
                selected: {_oneTime},
                onSelectionChanged: (s) => setState(() {
                  _oneTime = s.first;
                  _applyTypeConstraints();
                }),
              ),
              const SizedBox(height: 16),
            ],

            // When: weekday (weekly) or date (one-time)
            if (_oneTime)
              _tappableField(
                label: 'Date',
                icon: Icons.calendar_today,
                value: _date == null
                    ? 'Pick a date'
                    : '${_date!.day.toString().padLeft(2, '0')}/'
                        '${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                onTap: _pickDate,
              )
            else
              DropdownButtonFormField<int>(
                value: _weekday,
                decoration: const InputDecoration(
                  labelText: 'Day of week',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: [
                  for (final d in Weekday.fullWeek)
                    DropdownMenuItem(value: d, child: Text(Weekday.long(d))),
                ],
                onChanged: (d) => setState(() => _weekday = d ?? Weekday.monday),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _tappableField(
                    label: 'Start',
                    icon: Icons.schedule,
                    value: _fmt(_start),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tappableField(
                    label: 'End',
                    icon: Icons.schedule,
                    value: _fmt(_end),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Reminder lead time (any hours + minutes, e.g. 1h 30m)
            InkWell(
              onTap: () async {
                final picked =
                    await LeadTime.pick(context, _reminderMinutes);
                if (picked != null) {
                  setState(() => _reminderMinutes = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Remind me before',
                  prefixIcon: Icon(Icons.notifications_active_outlined),
                  suffixIcon: Icon(Icons.edit_outlined),
                ),
                child: Text(_leadLabel(_reminderMinutes)),
              ),
            ),
            const SizedBox(height: 8),

            // Inline homework/tasks when CREATING a lab/seminar/project/event.
            if (_carriesSubItems && !_isEditing) ...[
              const SizedBox(height: 8),
              const Divider(),
              _inlineSubItemsSection(),
            ],
            // When editing, sub-items are managed from the details screen.
            if (_carriesSubItems && _isEditing) ...[
              const SizedBox(height: 8),
              const Divider(),
              _editHintForSubItems(),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _tappableField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration:
            InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kSubjectPalette)
          GestureDetector(
            onTap: () => setState(() => _colorValue = c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _colorValue == c
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: _colorValue == c
                  ? Icon(Icons.check, color: contrastOn(Color(c)), size: 20)
                  : null,
            ),
          ),
      ],
    );
  }

  /// Inline homework/task list shown while creating a lab/seminar/event, so the
  /// user can add them "on the spot".
  Widget _inlineSubItemsSection() {
    final noun = _subItemNoun;
    final title = _type == ItemType.event
        ? 'Tasks'
        : _type == ItemType.project
            ? 'Deadlines'
            : 'Homework';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add $noun'),
              onPressed: _addInlineSubItem,
            ),
          ],
        ),
        if (_pendingSubItems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Optionally add $noun now. You can also add more later from the '
              '${_type.label.toLowerCase()}\'s details screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (int i = 0; i < _pendingSubItems.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_box_outline_blank),
            title: Text(_pendingSubItems[i].description.isEmpty
                ? (_type == ItemType.event ? 'Task' : 'Homework')
                : _pendingSubItems[i].description),
            subtitle: Text(_subItemSubtitle(_pendingSubItems[i])),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  setState(() => _pendingSubItems.removeAt(i)),
            ),
          ),
      ],
    );
  }

  String _subItemSubtitle(ReminderConfig c) {
    final due = DateFormatUtils.dueWithCountdown(c.dueDate);
    if (c.dailyUntil && c.dailyTime != null) {
      return 'Due $due • daily at ${c.dailyTime!.format()}';
    }
    return 'Due $due';
  }

  Future<void> _addInlineSubItem() async {
    final noun = _subItemNoun;
    final cfg = await showDialog<ReminderConfig>(
      context: context,
      builder: (_) => ReminderDialog(
        title: 'Add $noun',
        parentLabel: _type.label.toLowerCase(),
        descriptionHint: _type == ItemType.event
            ? 'What is the task? (e.g. do dishes)'
            : _type == ItemType.project
                ? 'What is the deadline? (optional)'
                : 'What is the homework? (optional)',
      ),
    );
    if (cfg != null) setState(() => _pendingSubItems.add(cfg));
  }

  Widget _editHintForSubItems() {
    final noun = _subItemNoun;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Manage $noun from this ${_type.label.toLowerCase()}\'s details '
              'screen (open it from the schedule).',
            ),
          ),
        ],
      ),
    );
  }

}
