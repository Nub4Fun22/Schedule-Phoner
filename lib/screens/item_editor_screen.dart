import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';

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

  static const List<int> _leadOptions = [0, 5, 10, 15, 30, 60, 120, 24 * 60];

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

    await store.addOrUpdateItem(item);
    // Return a result so the caller can confirm the save (e.g. show a
    // snackbar). isNew=false when editing an existing item.
    if (mounted) {
      Navigator.of(context).pop(
        ItemSaveResult(title: item.title, isNew: !_isEditing),
      );
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _leadLabel(int m) {
    if (m == 0) return 'At start';
    if (m == 24 * 60) return '1 day';
    if (m >= 60) return '${m ~/ 60}h';
    return '$m min';
  }

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
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ItemType.values)
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

            // Reminder lead time
            DropdownButtonFormField<int>(
              value: _leadOptions.contains(_reminderMinutes)
                  ? _reminderMinutes
                  : 10,
              decoration: const InputDecoration(
                labelText: 'Remind me before',
                prefixIcon: Icon(Icons.notifications_active_outlined),
              ),
              items: [
                for (final m in _leadOptions)
                  DropdownMenuItem(value: m, child: Text(_leadLabel(m))),
              ],
              onChanged: (m) => setState(() => _reminderMinutes = m ?? 10),
            ),
            const SizedBox(height: 20),

            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _colorPicker(),

            if (_type == ItemType.lab && _isEditing) ...[
              const SizedBox(height: 8),
              const Divider(),
              _labHomeworkHint(),
            ],
            if (_type == ItemType.project) ...[
              const SizedBox(height: 8),
              const Divider(),
              _projectLabHint(),
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

  Widget _labHomeworkHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Save this lab, then open it from the schedule to add homework '
              'that reminds you before each lab.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectLabHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Projects should be linked to a lab. You can pick the lab from '
              'the project\'s details screen after saving.',
            ),
          ),
        ],
      ),
    );
  }
}
