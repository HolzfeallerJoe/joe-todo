import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/tasks.dart';
import 'package:joe_todo/toast.dart';
import 'package:joe_todo/util.dart';
import 'package:joe_todo/widgets.dart';

/// Das Aufgabenblatt, geoeffnet ueber dem Aufgaben-Reiter – so sieht der
/// Test nach dem Speichern auch, wie die Aufgabe in der Liste steht.
/// Ohne Persistenz und ohne Begleiter.
Future<AppState> pumpTasksScreen(
  WidgetTester tester, {
  List<Task> tasks = const [],
}) async {
  // Die Testschrift setzt jedes Zeichen auf ein volles Quadrat, deshalb ist
  // das Fenster breiter und hoeher als ein echtes Telefon – das Blatt soll
  // ohne Scrollen ganz zu sehen sein.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(560, 1600);
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

/// Oeffnet das Blatt fuer eine neue Aufgabe (ueber den Plus-Knopf) oder
/// zum Bearbeiten von [task].
Future<void> openTaskSheet(WidgetTester tester, {Task? task}) async {
  if (task == null) {
    await tester.tap(find.byTooltip('Neue Aufgabe'));
  } else {
    showTaskSheet(tester.element(find.byType(TasksScreen)), task: task);
  }
  await tester.pumpAndSettle();
}

/// Ein Tag der Wochenskala, ueber seinen Kurznamen.
Finder weekday(String short) => find.descendant(
      of: find.byType(WeekdayPicker),
      matching: find.text(short),
    );

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> saveAs(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.tap(find.text('Speichern'));
  await tester.pumpAndSettle();
}

/// Ob der Tag [day] (1 = Montag) auf der Skala als gewaehlt gemeldet wird.
bool weekdaySelected(WidgetTester tester, int day) => tester
    .getSemantics(find.bySemanticsLabel(weekdayNames[day - 1]))
    .getSemanticsData()
    .flagsCollection
    .isSelected ==
    ui.Tristate.isTrue;

void main() {
  setUp(JoeToast.instance.reset);
  tearDown(JoeToast.instance.reset);

  group('Wochenskala', () {
    testWidgets('Mo und Mi gewaehlt heisst woechentlich an genau diesen Tagen',
        (tester) async {
      final state = await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      await tapAndSettle(tester, weekday('Mo'));
      await tapAndSettle(tester, weekday('Mi'));
      await saveAs(tester, 'Sport');

      final task = state.tasks.single;
      expect(task.recurrence, RecurrenceType.weekly);
      expect(task.weekdays, {1, 3});
    });

    testWidgets('ein Chip nimmt der Skala ihre Tage', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      await tapAndSettle(tester, weekday('Mo'));
      await tapAndSettle(tester, find.text('Monatlich'));
      // Die Skala zeigt nichts mehr markiert, der Chip gilt.
      expect(weekdaySelected(tester, 1), isFalse);
      await saveAs(tester, 'Miete');

      final task = state.tasks.single;
      expect(task.recurrence, RecurrenceType.monthly);
      expect(task.weekdays, isEmpty);
    });

    testWidgets('den letzten Tag abwaehlen heisst wieder einmalig',
        (tester) async {
      final state = await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      await tapAndSettle(tester, weekday('Mo'));
      expect(weekdaySelected(tester, 1), isTrue);
      await tapAndSettle(tester, weekday('Mo'));
      expect(weekdaySelected(tester, 1), isFalse);
      await saveAs(tester, 'Einmal');

      expect(state.tasks.single.recurrence, RecurrenceType.none);
    });

    testWidgets('alle sieben Tage heisst "Täglich"', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      for (final short in weekdayNamesShort) {
        await tapAndSettle(tester, weekday(short));
      }
      await saveAs(tester, 'Blumen');

      expect(state.tasks.single.weekdays, allWeekdays);
      // Taeglich ist auch heute dran und steht mit seiner Wiederholung da.
      expect(find.text('🔁 Täglich'), findsOneWidget);
    });

    testWidgets('eine woechentliche Aufgabe oeffnet mit ihren Tagen',
        (tester) async {
      final task = Task(
        id: '1',
        title: 'Markt',
        startDate: today(),
        recurrence: RecurrenceType.weekly,
        weekdays: {5},
      );
      await pumpTasksScreen(tester, tasks: [task]);
      await openTaskSheet(tester, task: task);

      expect(weekdaySelected(tester, 5), isTrue);
      expect(weekdaySelected(tester, 1), isFalse);
      // Kein Chip ist gewaehlt – die Skala traegt die Wiederholung.
      final einmalig =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Einmalig'));
      expect(einmalig.selected, isFalse);
    });

    testWidgets('Monatlich und Jaehrlich sagen, an welchem Tag',
        (tester) async {
      final task = Task(id: '1', title: 'Miete', startDate: DateTime(2026, 3, 14));
      await pumpTasksScreen(tester, tasks: [task]);
      await openTaskSheet(tester, task: task);

      await tapAndSettle(tester, find.text('Monatlich'));
      expect(find.text('am 14. jedes Monats'), findsOneWidget);
      await tapAndSettle(tester, find.text('Jährlich'));
      expect(find.text('jedes Jahr am 14. März'), findsOneWidget);
    });
  });
}
