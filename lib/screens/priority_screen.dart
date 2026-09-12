import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_item.dart';
import '../state/schedule_store.dart';
import 'item_details_screen.dart';

/// Priority view — split screen:
///  * TOP: Homeworks sorted by due date (soonest = highest priority).
///  * BOTTOM: Exams sorted by date (soonest first).
class PriorityScreen extends StatelessWidget {
  const PriorityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _HomeworkHalf()),
        const Divider(height: 1, thickness: 1),
        Expanded(child: _ExamHalf()),
      ],
    );
  }
}

class _HomeworkHalf extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final homeworks = store.homeworksByDueDate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, Icons.assignment_outlined, 'Homework',
            'Soonest due = highest priority'),
        Expanded(
          child: homeworks.isEmpty
              ? const Center(child: Text('No homework. Nice.'))
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
                          '${lab?.title ?? 'Lab'} • due ${_fmt(hw.dueDate)}'
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

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _ExamHalf extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScheduleStore>();
    final now = DateTime.now();
    final exams =
        store.examsByDate().where((e) => (e.date ?? now).isAfter(now)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, Icons.emoji_events_outlined, 'Exams',
            'Soonest first — top priority'),
        Expanded(
          child: exams.isEmpty
              ? const Center(child: Text('No upcoming exams.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: exams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ex = exams[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ex.color,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.emoji_events_outlined),
                        ),
                        title: Text(ex.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(ex.whenLabel),
                        trailing: Text(_countdown(now, ex.date),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailsScreen(itemId: ex.id))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _countdown(DateTime now, DateTime? when) {
    if (when == null) return '';
    final days = DateTime(when.year, when.month, when.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in ${days}d';
  }
}

Widget _header(
    BuildContext context, IconData icon, String title, String subtitle) {
  return Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
