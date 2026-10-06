import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../state/settings_store.dart';
import '../widgets/color_utils.dart';
import '../widgets/date_format_utils.dart';
import '../widgets/lead_time_picker.dart';
import 'homework_task_dialog.dart';

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
///
/// Each part exposes the SAME per-item options as the single-item editor:
/// day, start/end time, odd/even week restriction, location, description and
/// reminder lead time.
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
  WeekParity weekParity;
  int reminderMinutes;
  final TextEditingController location;
  final TextEditingController description;
  // Inline homework/deadlines added on the spot (persisted on save).
  final List<ReminderConfig> pending;
  _PartConfig({
    required this.enabled,
    required this.weekday,
    required this.start,
    required this.end,
    required this.type,
    this.weekParity = WeekParity.any,
    this.reminderMinutes = 10,
  })  : location = TextEditingController(),
        description = TextEditingController(),
        pending = [];

  /// Whether this part carries inline homework/deadlines.
  bool get carriesSubItems => type.carriesHomework;

  /// Word for the sub-item for this part.
  String get subItemNoun => type == ItemType.project ? 'deadline' : 'homework';

  /// Section title for this part's sub-items.
  String get subItemTitle => type == ItemType.project ? 'Deadlines' : 'Homework';

  void dispose() {
    location.dispose();
    description.dispose();
  }
}

class _SubjectWizardScreenState extends State<SubjectWizardScreen> {
  final _nameController = TextEditingController();
  int _colorValue = kSubjectPalette.first;

  late final _PartConfig _course;
  late final _PartConfig _practical; // Lab or Seminar
  late final _PartConfig _project;
  late final List<_PartConfig> _allParts;

  bool _seededReminders = false;

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
    _allParts = [_course, _practical, _project];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed each part's reminder lead time from the user's default (once).
    if (!_seededReminders) {
      _seededReminders = true;
      final def = context.read<SettingsStore>().defaultReminderMinutes;
      if (def >= 0) {
        setState(() {
          for (final p in _allParts) {
            p.reminderMinutes = def;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final p in _allParts) {
      p.dispose();
    }
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
      final id = 'item-$base-${i++}';
      await store.addOrUpdateItem(ScheduleItem(
        id: id,
        type: p.type,
        title: name,
        description: p.description.text.trim(),
        location: p.location.text.trim(),
        oneTime: false,
        weekday: p.weekday,
        start: SlotTime.fromTimeOfDay(p.start),
        end: SlotTime.fromTimeOfDay(p.end),
        colorValue: _colorValue,
        reminderMinutesBefore: p.reminderMinutes,
        weekParity: p.weekParity,
      ));
      // Persist any inline homework/deadlines against the new item's id.
      var j = 0;
      for (final cfg in p.pending) {
        await store.addOrUpdateHomework(Homework(
          id: 'hw-$base-$id-${j++}',
          labId: id,
          description: cfg.description,
          dueDate: cfg.dueDate,
          reminderMinutesBeforeLab: cfg.leadMinutes,
          dailyUntil: cfg.dailyUntil,
          dailyReminderTime: cfg.dailyTime,
        ));
      }
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
              const SizedBox(height: 4),

              // Odd/even week restriction.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.repeat_on_outlined),
                title: const Text('Only on some weeks'),
                subtitle: Text(part.weekParity == WeekParity.any
                    ? 'Shows every week'
                    : part.weekParity == WeekParity.odd
                        ? 'Odd weeks only'
                        : 'Even weeks only'),
                value: part.weekParity != WeekParity.any,
                onChanged: (on) => setState(() {
                  part.weekParity = on ? WeekParity.odd : WeekParity.any;
                }),
              ),
              if (part.weekParity != WeekParity.any)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SegmentedButton<WeekParity>(
                    segments: const [
                      ButtonSegment(
                          value: WeekParity.odd, label: Text('Odd weeks')),
                      ButtonSegment(
                          value: WeekParity.even, label: Text('Even weeks')),
                    ],
                    selected: {part.weekParity},
                    onSelectionChanged: (s) =>
                        setState(() => part.weekParity = s.first),
                  ),
                ),
              const SizedBox(height: 12),

              TextField(
                controller: part.location,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  prefixIcon: Icon(Icons.place_outlined),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: part.description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Reminder lead time.
              InkWell(
                onTap: () async {
                  final picked =
                      await LeadTime.pick(context, part.reminderMinutes);
                  if (picked != null) {
                    setState(() => part.reminderMinutes = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Remind me before',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                    suffixIcon: Icon(Icons.edit_outlined),
                    isDense: true,
                  ),
                  child: Text(LeadTime.label(part.reminderMinutes)),
                ),
              ),

              // Inline homework / deadlines for lab, seminar and project parts.
              if (part.carriesSubItems) ...[
                const SizedBox(height: 8),
                const Divider(),
                _subItemsSection(part),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _subItemsSection(_PartConfig part) {
    final noun = part.subItemNoun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(part.subItemTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add $noun'),
              onPressed: () => _addSubItem(part),
            ),
          ],
        ),
        if (part.pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Optionally add $noun now. You can also add more later from the '
              '${part.type.label.toLowerCase()}\'s details screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (int i = 0; i < part.pending.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_box_outline_blank),
            title: Text(part.pending[i].description.isEmpty
                ? (part.type == ItemType.project ? 'Deadline' : 'Homework')
                : part.pending[i].description),
            subtitle: Text(_subItemSubtitle(part.pending[i])),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => part.pending.removeAt(i)),
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

  Future<void> _addSubItem(_PartConfig part) async {
    final noun = part.subItemNoun;
    final cfg = await showDialog<ReminderConfig>(
      context: context,
      builder: (_) => ReminderDialog(
        title: 'Add $noun',
        parentLabel: part.type.label.toLowerCase(),
        descriptionHint: part.type == ItemType.project
            ? 'What is the deadline? (optional)'
            : 'What is the homework? (optional)',
      ),
    );
    if (cfg != null) setState(() => part.pending.add(cfg));
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
