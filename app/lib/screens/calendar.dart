import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first day of shown month
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final t = today();
    _month = DateTime(t.year, t.month);
    _selected = t;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final t = today();

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday - 1;

    final dayTasks = state.tasksForDay(_selected);
    final dayAppointments = state.appointmentsForDay(_selected);

    return JoeScaffold(
      title: 'Kalender',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            PaperCard(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: theme.ink),
                        tooltip: 'Voriger Monat',
                        onPressed: () => _shiftMonth(-1),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _month = DateTime(t.year, t.month);
                            _selected = t;
                          }),
                          child: Text(
                            '${monthNames[_month.month - 1]} ${_month.year}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: theme.ink),
                        tooltip: 'Nächster Monat',
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final w in weekdayNamesShort)
                        Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                color: theme.inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: leadingBlanks + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(
                          _month.year, _month.month, index - leadingBlanks + 1);
                      return _DayCell(
                        day: day,
                        isToday: day == t,
                        isSelected: day == _selected,
                        onTap: () => setState(() => _selected = day),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDateYear(_selected),
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add, size: 18, color: theme.accent),
                        label: Text('Aufgabe',
                            style: TextStyle(color: theme.accent)),
                        onPressed: () =>
                            showTaskSheet(context, initialDate: _selected),
                      ),
                    ],
                  ),
                  if (dayTasks.isEmpty && dayAppointments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Nichts eingetragen an diesem Tag.',
                        style: TextStyle(color: theme.inkSoft, fontSize: 14),
                      ),
                    ),
                  for (final a in dayAppointments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: a.color),
                          const SizedBox(width: 10),
                          Text(
                            formatTime(a.when),
                            style: TextStyle(
                              color: theme.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.title,
                              style:
                                  TextStyle(color: theme.ink, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final task in dayTasks)
                    TaskTile(task: task, day: _selected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final tasks = state.tasksForDay(day);
    final appointments = state.appointmentsForDay(day);

    final markers = <Widget>[];
    for (final a in appointments) {
      markers.add(_marker(a.color, done: false));
    }
    for (final task in tasks) {
      markers.add(_marker(task.color, done: task.isCompletedOn(day)));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? theme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: isToday
              ? Border.all(color: theme.accent, width: 1.6)
              : null,
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? theme.accent : theme.ink,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: markers.take(6).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Completed tasks stay visible: filled dot for open, ring for done.
  Widget _marker(Color color, {required bool done}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: done ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: done ? Border.all(color: color, width: 1.4) : null,
      ),
    );
  }
}
