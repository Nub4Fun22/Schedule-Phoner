import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_event.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';

/// Form to create a new event or edit an existing one.
/// Pass [existing] to edit; leave null to create.
class EventEditorScreen extends StatefulWidget {
  final ScheduleEvent? existing;
  const EventEditorScreen({super.key, this.existing});

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _title;
  late TextEditingController _description;
  late TextEditingController _location;

  late int _weekday;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _colorValue;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _weekday = e?.weekday ?? Weekday.monday;
    _start = e?.start.toTimeOfDay() ?? const TimeOfDay(hour: 8, minute: 0);
    _end = e?.end.toTimeOfDay() ?? const TimeOfDay(hour: 9, minute: 30);
    _colorValue = e?.colorValue ?? kSubjectPalette.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep end after start; nudge if needed.
        if (_minutes(_end) <= _minutes(_start)) {
          final endM = (_minutes(_start) + 90).clamp(0, 23 * 60 + 59);
          _end = TimeOfDay(hour: endM ~/ 60, minute: endM % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_minutes(_end) <= _minutes(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    final store = context.read<ScheduleStore>();
    final id = widget.existing?.id ??
        'evt-${DateTime.now().microsecondsSinceEpoch}';

    final event = ScheduleEvent(
      id: id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      location: _location.text.trim(),
      weekday: _weekday,
      start: SlotTime.fromTimeOfDay(_start),
      end: SlotTime.fromTimeOfDay(_end),
      colorValue: _colorValue,
      notificationsEnabled: widget.existing?.notificationsEnabled ?? false,
      reminderMinutesBefore: widget.existing?.reminderMinutesBefore ?? 10,
    );

    await store.addOrUpdate(event);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit class' : 'New class'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            DropdownButtonFormField<int>(
              value: _weekday,
              decoration: const InputDecoration(
                labelText: 'Day',
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
                  child: _timeField(
                    label: 'Start',
                    value: _start,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeField(
                    label: 'End',
                    value: _end,
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
            const SizedBox(height: 20),
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _colorPicker(),
          ],
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}',
        ),
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
}
