import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Alle Aufgaben an einem Ort: heute faellig, spaeter, wiederkehrend und
/// abgehakt. Das Dashboard zeigt nur den Heute-Ausschnitt.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final t = today();
    final todayTasks = state.tasksToday();
    final upcoming = state.upcomingTasks();
    final recurring = state.recurringTasks();
    final done = state.doneTasks();

    return JoeScaffold(
      title: 'Aufgaben',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (state.tasks.isEmpty)
              PaperCard(
                child: Text(
                  'Noch keine Aufgaben. Tippe auf +, um eine anzulegen.',
                  style: TextStyle(color: theme.inkSoft, fontSize: 15),
                ),
              ),
            if (todayTasks.isNotEmpty) ...[
              const SectionTitle('Heute'),
              _TaskCard(
                children: [
                  for (final task in todayTasks)
                    TaskTile(task: task, day: t, showOverdue: true),
                ],
              ),
            ],
            if (upcoming.isNotEmpty) ...[
              const SectionTitle('Demnächst'),
              _TaskCard(
                children: [
                  for (final task in upcoming)
                    _DatedTaskRow(task: task, label: formatDate(task.startDate)),
                ],
              ),
            ],
            if (recurring.isNotEmpty) ...[
              const SectionTitle('Wiederkehrend'),
              _TaskCard(
                children: [
                  for (final task in recurring)
                    _DatedTaskRow(task: task, label: task.recurrenceLabel),
                ],
              ),
            ],
            if (done.isNotEmpty) ...[
              const SectionTitle('Erledigt'),
              _TaskCard(
                children: [
                  for (final task in done) TaskTile(task: task, day: t),
                ],
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        tooltip: 'Neue Aufgabe',
        onPressed: () => showTaskSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final List<Widget> children;
  const _TaskCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(children: children),
    );
  }
}

/// Aufgabe, die nicht heute dran ist: statt der Checkbox steht links der
/// Farbstrich und rechts, wann sie kommt. Abhaken geht erst am Tag selbst.
class _DatedTaskRow extends StatelessWidget {
  final Task task;
  final String label;

  const _DatedTaskRow({required this.task, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showTaskSheet(context, task: task),
      onLongPress: () => showTaskOptions(context, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 26,
              decoration: BoxDecoration(
                color: task.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(color: theme.ink, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PriorityMark(
              priority: task.priority,
              color:
                  task.priority == Priority.hoch ? theme.accent : theme.inkSoft,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: theme.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
