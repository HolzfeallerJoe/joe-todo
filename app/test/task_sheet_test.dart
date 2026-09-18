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
    // Wie in der App ueber dem Navigator, damit ein Toast auch ueber dem
    // offenen Blatt steht.
    child: MaterialApp(
      builder: (context, child) => ToastHost(child: child!),
      home: const TasksScreen(),
    ),
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

/// Oeffnet ein Blatt direkt an einem festen Tag – so haengt kein Test daran,
/// ob drei Tage spaeter noch im selben Monat liegen.
Future<void> openSheetOn(
  WidgetTester tester,
  DateTime day, {
  bool appointment = false,
}) async {
  final context = tester.element(find.byType(TasksScreen));
  if (appointment) {
    showAppointmentSheet(context, initialDate: day);
  } else {
    showTaskSheet(context, initialDate: day);
  }
  await tester.pumpAndSettle();
}

/// Waehlt im offenen Datumswaehler den Tag [day] des angezeigten Monats.
Future<void> pickDay(WidgetTester tester, int day) async {
  await tester.tap(find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.text('$day'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
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

  group('Prioritaetsfarbe', () {
    setUp(PriorityColors.reset);
    tearDown(PriorityColors.reset);

    Finder notice() =>
        find.textContaining('Wird in der Farbe der Priorität');

    double pickerOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find
            .ancestor(
              of: find.byType(ColorDotPicker),
              matching: find.byType(Opacity),
            )
            .first)
        .opacity;

    testWidgets('Hoch mit Vorgabe: Hinweis, eigene Farbe blass',
        (tester) async {
      PriorityColors.use({Priority.hoch: 20});
      await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      // Neu ist Mittel – ohne Vorgabe, also kein Hinweis.
      expect(notice(), findsNothing);
      expect(pickerOpacity(tester), 1);

      await tapAndSettle(tester, find.text('Hoch'));
      expect(notice(), findsOneWidget);
      expect(find.textContaining('Priorität Hoch angezeigt'), findsOneWidget);
      expect(pickerOpacity(tester), 0.45);

      // Wechselt man die Stufe, verschwindet er sofort wieder.
      await tapAndSettle(tester, find.text('Mittel'));
      expect(notice(), findsNothing);
    });

    testWidgets('die eigene Farbe bleibt waehlbar', (tester) async {
      PriorityColors.use({Priority.hoch: 20});
      final state = await pumpTasksScreen(tester);
      await openTaskSheet(tester);

      await tapAndSettle(tester, find.text('Hoch'));
      await tapAndSettle(tester, find.bySemanticsLabel('Farbe Himmel'));
      await saveAs(tester, 'Steuer');

      final task = state.tasks.single;
      expect(task.colorIndex, 21);
      expect(task.color, taskPalette[20]);
    });
  });

  group('Dauer', () {
    final monday = DateTime(2026, 9, 14);

    testWidgets('Mo bis Do: drei Tage, Uhrzeiten gesetzt', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, find.byType(Switch));
      // Die Von-Zeile ersetzt das Datum; Standard 12:00 bis 18:00.
      expect(find.textContaining('Datum:'), findsNothing);
      expect(find.text('Mo, 14. Sep'), findsNWidgets(2));
      await tapAndSettle(tester, find.byKey(const ValueKey('task-end-date')));
      await pickDay(tester, 17);
      expect(find.text('Do, 17. Sep'), findsOneWidget);
      await saveAs(tester, 'Umzug');

      final task = state.tasks.single;
      expect(task.startDate, monday);
      expect(task.spanDays, 3);
      expect(task.startMinute, 12 * 60);
      expect(task.endMinute, 18 * 60);
    });

    testWidgets('das Enddatum wandert mit dem Anfang', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, find.byType(Switch));
      await tapAndSettle(tester, find.byKey(const ValueKey('task-end-date')));
      await pickDay(tester, 15);
      await tapAndSettle(
          tester, find.byKey(const ValueKey('task-start-date')));
      await pickDay(tester, 16);
      // Einen Tag Dauer behaelt die Aufgabe: jetzt Mi bis Do.
      expect(find.text('Do, 17. Sep'), findsOneWidget);
      await saveAs(tester, 'Besuch');

      expect(state.tasks.single.startDate, DateTime(2026, 9, 16));
      expect(state.tasks.single.spanDays, 1);
    });

    testWidgets('Ende vor Anfang: Hinweis, Blatt bleibt offen',
        (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, find.byType(Switch));
      await tapAndSettle(tester, find.byKey(const ValueKey('task-end-date')));
      await pickDay(tester, 12);
      await tester.enterText(find.byType(TextField).first, 'Rueckwaerts');
      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(find.text('Das Ende liegt vor dem Anfang.'), findsOneWidget);
      expect(find.text('Neue Aufgabe'), findsOneWidget);
      expect(state.tasks, isEmpty);
      await tester.pump(JoeToast.showDuration);
    });

    testWidgets('ohne Dauer bleibt alles wie bisher', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, find.byType(Switch));
      await tapAndSettle(tester, find.byType(Switch));
      expect(find.textContaining('Datum:'), findsOneWidget);
      await saveAs(tester, 'Kurz');

      final task = state.tasks.single;
      expect(task.hasDuration, isFalse);
      expect(task.startMinute, isNull);
      expect(task.endMinute, isNull);
    });

    testWidgets('Mo+Mi: das Plus bleibt bei "+1 Tag" stehen', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, weekday('Mo'));
      await tapAndSettle(tester, weekday('Mi'));
      await tapAndSettle(tester, find.byType(Switch));
      expect(find.text('am selben Tag'), findsOneWidget);

      final plus = find.byTooltip('Einen Tag länger');
      await tapAndSettle(tester, plus);
      await tapAndSettle(tester, plus);
      await tapAndSettle(tester, plus);

      expect(find.text('+1 Tag'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
                find.ancestor(of: plus, matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Länger würde die nächste Wiederholung überlappen.'),
        findsOneWidget,
      );
      await saveAs(tester, 'Training');
      expect(state.tasks.single.spanDays, 1);
    });

    testWidgets('Wiederholung nach der Dauer verkuerzt: Hinweis beim Speichern',
        (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday);

      await tapAndSettle(tester, weekday('Mo'));
      await tapAndSettle(tester, find.byType(Switch));
      final plus = find.byTooltip('Einen Tag länger');
      await tapAndSettle(tester, plus);
      await tapAndSettle(tester, plus);
      // Mo+Di laesst keinen Tag Dauer mehr zu.
      await tapAndSettle(tester, weekday('Di'));
      await tester.enterText(find.byType(TextField).first, 'Zu lang');
      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(
        find.text(
            'Die Dauer ist länger als der Abstand zwischen zwei Wiederholungen.'),
        findsOneWidget,
      );
      expect(state.tasks, isEmpty);
      await tester.pump(JoeToast.showDuration);
    });

    testWidgets('eine Aufgabe mit Dauer oeffnet mit Schalter an',
        (tester) async {
      final task = Task(
        id: '1',
        title: 'Umzug',
        startDate: monday,
        spanDays: 3,
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      );
      await pumpTasksScreen(tester, tasks: [task]);
      await openTaskSheet(tester, task: task);

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Do, 17. Sep'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
    });

    testWidgets('Terminblatt: eingeschaltet eine Stunde', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday, appointment: true);

      await tapAndSettle(tester, find.byType(Switch));
      expect(find.text('13:00'), findsOneWidget);
      await saveAs(tester, 'Arzt');

      final a = state.appointments.single;
      expect(a.when, DateTime(2026, 9, 14, 12));
      expect(a.end, DateTime(2026, 9, 14, 13));
    });

    testWidgets('Terminblatt: das Ende wandert mit dem Start', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday, appointment: true);

      await tapAndSettle(tester, find.byType(Switch));
      // Start um zwei Tage verschieben (ueber das Datum; der Uhrzeiger-
      // Waehler laesst sich im Test nur umstaendlich bedienen).
      await tapAndSettle(tester, find.text('14. September'));
      await pickDay(tester, 16);
      expect(find.text('Mi, 16. Sep'), findsOneWidget);
      await saveAs(tester, 'Seminar');

      final a = state.appointments.single;
      expect(a.when, DateTime(2026, 9, 16, 12));
      expect(a.end, DateTime(2026, 9, 16, 13));
    });

    testWidgets('Terminblatt: Ende vor Anfang wird abgelehnt', (tester) async {
      final state = await pumpTasksScreen(tester);
      await openSheetOn(tester, monday, appointment: true);

      await tapAndSettle(tester, find.byType(Switch));
      await tapAndSettle(
          tester, find.byKey(const ValueKey('appointment-end-date')));
      await pickDay(tester, 13);
      await tester.enterText(find.byType(TextField).first, 'Falsch');
      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(find.text('Das Ende liegt vor dem Anfang.'), findsOneWidget);
      expect(state.appointments, isEmpty);
      await tester.pump(JoeToast.showDuration);
    });

    testWidgets('Terminblatt: ein Termin mit Ende oeffnet mit Schalter an',
        (tester) async {
      final a = Appointment(
        id: 'a',
        title: 'Messe',
        when: DateTime(2026, 9, 14, 12),
        end: DateTime(2026, 9, 17, 18),
      );
      final state = await pumpTasksScreen(tester);
      state.appointments = [a];
      showAppointmentSheet(tester.element(find.byType(TasksScreen)),
          appointment: a);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Do, 17. Sep'), findsOneWidget);
      // Ausschalten und speichern macht ihn wieder zum Zeitpunkt.
      await tapAndSettle(tester, find.byType(Switch));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(a.end, isNull);
    });
  });
}
