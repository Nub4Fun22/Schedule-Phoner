import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../widgets/color_utils.dart';

/// Result of the subject wizard: how many items were created + the name.
class SubjectSaveResult {
  final String name;
  final int count;
  const SubjectSaveResult({required this.name, required this.count});
}

/// A fast way to add a whole subject at once: a Course, a Lab OR Seminar, and
/// optionally a Project — all sharing the subject's name + color, but created
/// as INDEPENDENT items (so you can later delete one, e.g. the course, and the
/// others remain).
class SubjectWizardScreen extends StatefulWidget {
  const SubjectWizardScreen({super.key});

  @override
  State<SubjectWizardScreen> createState() => _SubjectWizardScreenState();
}

/// Editable config for one part of a subject.
class _PartConfig {
  bool enabled;
  int weekday;
  TimeOfDay start;
  TimeOfDay end;
  // For the "practical" part: lab vs seminar.
  ItemType type;
  _PartConfig({
    required this.enabled,
    required this.weekday,
    required this.start,
    required this.end,
    required this.type,
  });
}

class _SubjectWizardScreenState extends State<SubjectWizardScreen> {
  final _nameController = TextEditingController();
  int _colorValue = kSubjectPalette.first;

  late final _PartConfig _course;
  late final _PartConfig _practical; // Lab or Seminar
  late final _PartConfig _project;

  @override
  void initState() {
    super.initState();
    _course = _PartConfig(
      enabled: true,
      weekday: Weekday.monday,
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 9, minute: 30),
      type: ItemType.course,
    );
    _practical = _PartConfig(
      enabled: true,
      weekday: Weekday.tuesday,
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 12, minute: 0),
      type: ItemType.lab,
    );
    _project = _PartConfig(
      enabled: false,
      weekday: Weekday.wednesday,
      start: const TimeOfDay(hour: 14, minute: 0),
      end: const TimeOfDay(hour: 15, minute: 0),
      type: ItemType.project,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickTime(_PartConfig p, {required bool isStart}) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? p.start : p.end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        p.start = picked;
        if (_min(p.end) <= _min(p.start)) {
          final endM = (_min(p.start) + 90).clamp(0, 23 * 60 + 59);
          p.end = TimeOfDay(hour: endM ~/ 60, minute: endM % 60);
        }
      } else {
        p.end = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a subject name.');
      return;
    }
    final parts = <_PartConfig>[
      if (_course.enabled) _course,
      if (_practical.enabled) _practical,
      if (_project.enabled) _project,
    ];
    if (parts.isEmpty) {
      _snack('Enable at least one part (course / lab / project).');
      return;
    }
    for (final p in parts) {
      if (_min(p.end) <= _min(p.start)) {
        _snack('Each part\'s end time must be after its start time.');
        return;
      }
    }

    final store = context.read<ScheduleStore>();
    final base = DateTime.now().microsecondsSinceEpoch;
    var i = 0;
    for (final p in parts) {
      await store.addOrUpdateItem(ScheduleItem(
        id: 'item-$base-${i++}',
        type: p.type,
        title: name,
        oneTime: false,
        weekday: p.weekday,
        start: SlotTime.fromTimeOfDay(p.start),
        end: SlotTime.fromTimeOfDay(p.end),
        colorValue: _colorValue,
      ));
    }

    if (mounted) {
      Navigator.of(context)
          .pop(SubjectSaveResult(name: name, count: parts.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New subject'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom + 48,
        ),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Subject name',
              prefixIcon: Icon(Icons.book_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _colorPicker(),
          const SizedBox(height: 8),
          const Divider(),

          _partCard(
            title: 'Course',
            icon: ItemType.course.icon,
            part: _course,
          ),
          _partCard(
            title: 'Practical',
            icon: _practical.type.icon,
            part: _practical,
            // Lab vs Seminar chooser.
            extra: SegmentedButton<ItemType>(
              segments: const [
                ButtonSegment(value: ItemType.lab, label: Text('Lab')),
                ButtonSegment(value: ItemType.seminar, label: Text('Seminar')),
              ],
              selected: {_practical.type},
              onSelectionChanged: (s) =>
                  setState(() => _practical.type = s.first),
            ),
          ),
          _partCard(
            title: 'Project (optional)',
            icon: ItemType.project.icon,
            part: _project,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Creates each enabled part as its own item (sharing this '
                    'name & color). You can edit or delete any of them later '
                    'independently.',
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _partCard({
    required String title,
    required IconData icon,
    required _PartConfig part,
    Widget? extra,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              value: part.enabled,
              onChanged: (v) => setState(() => part.enabled = v),
            ),
            if (part.enabled) ...[
              if (extra != null) ...[
                extra,
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<int>(
                value: part.weekday,
                decoration: const InputDecoration(
                  labelText: 'Day of week',
                  prefixIcon: Icon(Icons.calendar_today),
                  isDense: true,
                ),
                items: [
                  for (final d in Weekday.fullWeek)
                    DropdownMenuItem(value: d, child: Text(Weekday.long(d))),
                ],
                onChanged: (d) =>
                    setState(() => part.weekday = d ?? Weekday.monday),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _timeField(
                      label: 'Start',
                      value: _fmt(part.start),
                      onTap: () => _pickTime(part, isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeField(
                      label: 'End',
                      value: _fmt(part.end),
                      onTap: () => _pickTime(part, isStart: false),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeField(
      {required String label,
      required String value,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          isDense: true,
        ),
        child: Text(value),
      ),
    );
  }
}
