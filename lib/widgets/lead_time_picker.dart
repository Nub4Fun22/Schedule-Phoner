import 'package:flutter/material.dart';

/// Shared helpers for choosing a reminder lead time (how long before an event
/// to remind), supporting ANY hours + minutes combination — e.g. "1h 30m" —
/// not just fixed presets.
class LeadTime {
  /// Human label for a lead time in minutes. [suffix] e.g. "before" or
  /// "before lab"; omit for a bare label.
  static String label(int minutes, {String suffix = ''}) {
    final tail = suffix.isEmpty ? '' : ' $suffix';
    if (minutes <= 0) return 'At start$tail';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final String core;
    if (h > 0 && m > 0) {
      core = '${h}h ${m}m';
    } else if (h > 0) {
      core = '${h}h';
    } else {
      core = '${m}m';
    }
    return '$core$tail';
  }

  /// Show a picker dialog to choose hours + minutes. Returns the total minutes,
  /// or null if cancelled. [current] pre-fills the fields.
  static Future<int?> pick(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (_) => _LeadTimePickerDialog(initialMinutes: current),
    );
  }
}

class _LeadTimePickerDialog extends StatefulWidget {
  final int initialMinutes;
  const _LeadTimePickerDialog({required this.initialMinutes});

  @override
  State<_LeadTimePickerDialog> createState() => _LeadTimePickerDialogState();
}

class _LeadTimePickerDialogState extends State<_LeadTimePickerDialog> {
  late int _hours;
  late int _minutes;

  // Quick presets in minutes.
  static const List<int> _presets = [0, 10, 30, 60, 90, 120, 24 * 60];

  @override
  void initState() {
    super.initState();
    _hours = widget.initialMinutes ~/ 60;
    _minutes = widget.initialMinutes % 60;
  }

  int get _total => _hours * 60 + _minutes;

  void _applyPreset(int m) {
    setState(() {
      _hours = m ~/ 60;
      _minutes = m % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remind me before'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepperRow(
                label: 'Hours',
                value: _hours,
                max: 168, // up to a week
                onChanged: (v) => setState(() => _hours = v),
              ),
              const SizedBox(height: 4),
              _stepperRow(
                label: 'Minutes',
                value: _minutes,
                max: 59,
                step: 5,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              const SizedBox(height: 12),
              Text(
                _total <= 0 ? 'At start time' : LeadTime.label(_total),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in _presets)
                    ActionChip(
                      label: Text(LeadTime.label(p)),
                      onPressed: () => _applyPreset(p),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_total),
          child: const Text('OK'),
        ),
      ],
    );
  }

  /// A full-width row: label on the left, [-] value [+] controls on the right.
  Widget _stepperRow({
    required String label,
    required int value,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed:
              value <= 0 ? null : () => onChanged((value - step).clamp(0, max)),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value >= max
              ? null
              : () => onChanged((value + step).clamp(0, max)),
        ),
      ],
    );
  }
}
