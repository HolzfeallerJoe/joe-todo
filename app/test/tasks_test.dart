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
  testWidgets('Stufe 3 steht unter "Kann warten", nicht unter "Heute"',
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
    expect(find.text('Kann warten'), findsOneWidget);
    // Reihenfolge auf dem Blatt: Heute > Normal > Kann warten > Unwichtig.
    expect(y('Heute'), lessThan(y('Normal')));
    expect(y('Normal'), lessThan(y('Kann warten')));
    expect(y('Kann warten'), lessThan(y('Unwichtig')));
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
    expect(find.text('Kann warten'), findsNothing);
  });
}
