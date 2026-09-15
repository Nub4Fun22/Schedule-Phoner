import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import '../widgets/date_format_utils.dart';
import 'item_details_screen.dart';

/// Priority view — a vertical, priority-ordered split screen. From top to
/// bottom (lowest → highest priority reading downward, most urgent per section
/// sorted soonest-first):
///   1. Homework  (soonest due = highest)
///   2. Tests
///   3. Project presentations
///   4. Exams     (top priority)
class PriorityScreen extends StatelessWidget {
  const PriorityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(child: _HomeworkHalf()),
        Divider(height: 1, thickness: 1),
        Expanded(child: _TestHalf()),
        Divider(height: 1, thickness: 1),
        Expanded(child: _PresentationHalf()),
        Divider(height: 1, thickness: 1),
        Expanded(child: _ExamHalf()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Homework
// ---------------------------------------------------------------------------

class _HomeworkHalf extends StatelessWidget {
  const _HomeworkHalf();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final homeworks = store.homeworksByDueDate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, Icons.assignment_outlined, 'Homework',
            'Soonest due = highest'),
        Expanded(
          child: homeworks.isEmpty
              ? const _EmptyNote('No homework. Nice.')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: homeworks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final hw = homeworks[i].homework;
                    final lab = homeworks[i].lab;
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Checkbox(
                          value: hw.done,
                          onChanged: (v) =>
                              store.setHomeworkDone(hw.id, v ?? false),
                        ),
                        title: Text(
                          hw.description.isEmpty ? 'Homework' : hw.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration:
                                hw.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${lab?.title ?? 'Lab'} • due '
                          '${DateFormatUtils.dueWithCountdown(hw.dueDate)}'
                          '${hw.isOverdue ? ' • OVERDUE' : ''}',
                          style: TextStyle(
                            color: hw.isOverdue
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        trailing: _dueBadge(context, hw.dueDate, hw.done),
                        onTap: lab == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ItemDetailsScreen(itemId: lab.id))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dueBadge(BuildContext context, DateTime due, bool done) {
    if (done) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day))
        .inDays;
    final label = days < 0
        ? '${-days}d late'
        : days == 0
            ? 'today'
            : 'in ${days}d';
    return Text(label,
        style: TextStyle(
            color: days <= 1
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

class _TestHalf extends StatelessWidget {
  const _TestHalf();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final tests = store.testsByNext();
    return _ItemSection(
      icon: Icons.quiz_outlined,
      title: 'Tests',
      subtitle: 'Soonest first',
      emptyNote: 'No upcoming tests.',
      items: tests,
      fallbackIcon: Icons.quiz_outlined,
    );
  }
}

// ---------------------------------------------------------------------------
// Project presentations
// ---------------------------------------------------------------------------

class _PresentationHalf extends StatelessWidget {
  const _PresentationHalf();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final now = DateTime.now();
    final presentations = store
        .presentationsByDate()
        .where((e) => (e.date ?? now).isAfter(now))
        .toList();
    return _ItemSection(
      icon: Icons.co_present_outlined,
      title: 'Project presentations',
      subtitle: 'Soonest first',
      emptyNote: 'No upcoming presentations.',
      items: presentations,
      fallbackIcon: Icons.co_present_outlined,
    );
  }
}

// ---------------------------------------------------------------------------
// Exams
// ---------------------------------------------------------------------------

class _ExamHalf extends StatelessWidget {
  const _ExamHalf();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final now = DateTime.now();
    final exams =
        store.examsByDate().where((e) => (e.date ?? now).isAfter(now)).toList();
    return _ItemSection(
      icon: Icons.emoji_events_outlined,
      title: 'Exams',
      subtitle: 'Soonest first — top priority',
      emptyNote: 'No upcoming exams.',
      items: exams,
      fallbackIcon: Icons.emoji_events_outlined,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section widget for Tests / Presentations / Exams
// ---------------------------------------------------------------------------

class _ItemSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String emptyNote;
  final List<ScheduleItem> items;
  final IconData fallbackIcon;

  const _ItemSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emptyNote,
    required this.items,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, icon, title, subtitle),
        Expanded(
          child: items.isEmpty
              ? _EmptyNote(emptyNote)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: it.color,
                          foregroundColor: Colors.white,
                          child: Icon(it.type.icon),
                        ),
                        title: Text(it.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(it.whenLabel),
                        trailing: Text(_countdown(it),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailsScreen(itemId: it.id))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _countdown(ScheduleItem item) {
    final now = DateTime.now();
    final when = item.nextOccurrence(now);
    if (when == null) return '';
    // when includes the item's start time, so same-day shows hours/minutes.
    return DateFormatUtils.untilLabel(when, from: now);
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            style: TextStyle(color: Theme.of(context).disabledColor)),
      );
}

Widget _header(
    BuildContext context, IconData icon, String title, String subtitle) {
  return Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        Flexible(
          child: Text(subtitle,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
