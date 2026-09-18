import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/tasks.dart';
import 'package:joe_todo/util.dart';

/// Aufgaben-Reiter mit festem Datenstand, ohne Persistenz.
Future<AppState> pumpTasks(WidgetTester tester, List<Task> tasks) async {
  // Die Testschrift setzt jedes Zeichen auf ein volles Quadrat, deshalb ist
  // das Fenster deutlich breiter und hoeher als ein echtes Telefon.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(560, 1000);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = [...tasks]
    ..appointments = []
    ..notes = []
    ..showPet = false;
  await tester.pumpWidget(AppScope(
    state: state,
    child: const MaterialApp(home: TasksScreen()),
  ));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('liegengebliebene Stufe 3 steht unter "Hat Zeit"',
      (tester) async {
    final t = today();
    await pumpTasks(tester, [
      Task(id: '1', title: 'Normal', startDate: t),
      Task(
        id: '2',
        title: 'Unwichtig',
        startDate: t.subtract(const Duration(days: 4)),
        priority: Priority.niedrig,
      ),
    ]);

    double y(String label) => tester.getTopLeft(find.text(label)).dy;

    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Hat Zeit'), findsOneWidget);
    // Reihenfolge auf dem Blatt: Heute > Normal > Hat Zeit > Unwichtig.
    expect(y('Heute'), lessThan(y('Normal')));
    expect(y('Normal'), lessThan(y('Hat Zeit')));
    expect(y('Hat Zeit'), lessThan(y('Unwichtig')));
    expect(
      find.text('offen seit ${formatDate(t.subtract(const Duration(days: 4)))}'),
      findsOneWidget,
    );
  });

  testWidgets('ohne Stufe-3-Aufgabe bleibt der Block weg', (tester) async {
    await pumpTasks(tester, [
      Task(id: '1', title: 'Normal', startDate: today()),
    ]);

    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Hat Zeit'), findsNothing);
  });

  testWidgets('an ihrem Faelligkeitstag steht Stufe 3 unter "Heute"',
      (tester) async {
    final t = today();
    await pumpTasks(tester, [
      Task(id: '1', title: 'Normal', startDate: t),
      Task(id: '2', title: 'Leise', startDate: t, priority: Priority.niedrig),
    ]);

    // Heute ist sie eine Aufgabe wie jede andere; der eigene Block kommt
    // erst, wenn sie liegengeblieben ist.
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Hat Zeit'), findsNothing);
    expect(find.text('Leise'), findsOneWidget);
  });

  testWidgets('eine Aufgabe von gestern bis morgen steht heute, nicht als '
      'ueberfaellig, mit ihrer Spanne', (tester) async {
    final t = today();
    final yesterday = addCalendarDays(t, -1);
    await pumpTasks(tester, [
      Task(
        id: '1',
        title: 'Umzug',
        startDate: yesterday,
        spanDays: 2,
        startMinute: 12 * 60,
        endMinute: 18 * 60,
      ),
    ]);

    double y(String label) => tester.getTopLeft(find.text(label)).dy;

    expect(find.text('Heute'), findsOneWidget);
    expect(y('Heute'), lessThan(y('Umzug')));
    // Gestern begonnen heisst nicht liegengeblieben: sie laeuft noch.
    expect(find.textContaining('offen seit'), findsNothing);
    expect(
      find.text(formatSpan(
        DateTime(yesterday.year, yesterday.month, yesterday.day, 12),
        DateTime(t.year, t.month, t.day + 1, 18),
      )),
      findsOneWidget,
    );
  });

  testWidgets('erst nach ihrem letzten Tag ist sie ueberfaellig',
      (tester) async {
    final t = today();
    await pumpTasks(tester, [
      Task(
        id: '1',
        title: 'Umzug',
        startDate: addCalendarDays(t, -3),
        spanDays: 2,
      ),
    ]);

    // Ohne Uhrzeit nur die Tage; "offen seit" nennt den letzten Tag.
    expect(
      find.text('${formatDate(addCalendarDays(t, -3))} – '
          '${formatDate(addCalendarDays(t, -1))}'),
      findsOneWidget,
    );
    expect(
      find.text('offen seit ${formatDate(addCalendarDays(t, -1))}'),
      findsOneWidget,
    );
  });

  testWidgets('Demnaechst und Wiederkehrend nennen die Dauer', (tester) async {
    final t = today();
    await pumpTasks(tester, [
      Task(
        id: '1',
        title: 'Urlaub',
        startDate: addCalendarDays(t, 5),
        spanDays: 3,
      ),
      Task(
        id: '2',
        title: 'Dienst',
        startDate: t,
        recurrence: RecurrenceType.weekly,
        weekdays: {1},
        spanDays: 2,
        startMinute: 8 * 60,
        endMinute: 16 * 60,
      ),
    ]);

    expect(
      find.text('${formatDate(addCalendarDays(t, 5))} – '
          '${formatDate(addCalendarDays(t, 8))}'),
      findsOneWidget,
    );
    expect(find.text('Jeden Montag · 3 Tage'), findsOneWidget);
  });
}
