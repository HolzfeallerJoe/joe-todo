import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/calendar.dart';

Future<void> pumpCalendar(
  WidgetTester tester,
  DateTime initialDay, {
  List<Task> tasks = const [],
  List<Appointment> appointments = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(560, 1000);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = [...tasks]
    ..appointments = [...appointments]
    ..notes = []
    ..showHolidays = false
    ..showMoon = false
    ..showDeviceCalendar = false
    ..showPet = false;
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(home: CalendarScreen(initialDay: initialDay)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Monatswechsel hält Auswahl und Tagesdetail synchron', (
    tester,
  ) async {
    await pumpCalendar(tester, DateTime(2026, 1, 31));

    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pumpAndSettle();

    expect(find.text('Februar 2026'), findsOneWidget);
    expect(find.text('28. Februar 2026'), findsOneWidget);
  });

  testWidgets('Kalendertag meldet Datum und Auswahlzustand', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCalendar(tester, DateTime(2026, 1, 31));

    final data = tester
        .getSemantics(find.bySemanticsLabel('Samstag, 31. Januar 2026'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('Termine stehen als eigene Uhrenreihe unter den Aufgaben',
      (tester) async {
    // Vorher waren Termine und Aufgaben dieselben Punkte und nicht
    // auseinanderzuhalten.
    await pumpCalendar(
      tester,
      DateTime(2026, 1, 31),
      tasks: [Task(id: 't', title: 'Aufgabe', startDate: DateTime(2026, 1, 22))],
      appointments: [
        Appointment(id: 'a', title: 'Zahnarzt', when: DateTime(2026, 1, 22, 9)),
        Appointment(id: 'b', title: 'Kaffee', when: DateTime(2026, 1, 22, 15)),
      ],
    );

    final grid = find.byType(GridView);
    // Zwei Termine, zwei Uhren – und nur an ihrem Tag.
    expect(
      find.descendant(of: grid, matching: find.byIcon(Icons.schedule)),
      findsNWidgets(2),
    );

    final cell = find
        .ancestor(
          of: find.descendant(of: grid, matching: find.text('22')),
          matching: find.byType(Column),
        )
        .first;
    final clock = tester.getRect(
      find.descendant(of: cell, matching: find.byIcon(Icons.schedule)).first,
    );
    final dayNumber = tester.getRect(
      find.descendant(of: cell, matching: find.text('22')),
    );
    // Die Uhrenreihe liegt zwischen der Punktreihe (direkt unter der Zahl)
    // und dem unteren Rand der Zelle.
    expect(clock.top, greaterThan(dayNumber.bottom));
  });

  testWidgets('die Uhr steht zwischen Punktreihe und Zeichenzeile',
      (tester) async {
    await pumpCalendar(
      tester,
      DateTime(2026, 1, 31),
      appointments: [
        Appointment(id: 'a', title: 'Zahnarzt', when: DateTime(2026, 1, 22, 9)),
      ],
    );
    // Notiz an demselben Tag: dann steht die Zeichenzeile mit dem "N"
    // darunter.
    final state = AppScope.of(
      tester.element(find.byType(CalendarScreen)),
    );
    state.addNote(Note(
      id: 'n',
      title: 'Notiz',
      body: '',
      date: DateTime(2026, 1, 22),
      updatedAt: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    final grid = find.byType(GridView);
    final cell = find
        .ancestor(
          of: find.descendant(of: grid, matching: find.text('22')),
          matching: find.byType(Column),
        )
        .first;
    final clock = tester.getRect(
      find.descendant(of: cell, matching: find.byIcon(Icons.schedule)).first,
    );
    final noteBadge = tester.getRect(
      find.descendant(of: cell, matching: find.text('N')).first,
    );
    expect(clock.bottom, lessThanOrEqualTo(noteBadge.top + 1));
  });

  testWidgets('ohne Termin bleibt die Uhr weg', (tester) async {
    await pumpCalendar(
      tester,
      DateTime(2026, 1, 31),
      tasks: [Task(id: 't', title: 'Aufgabe', startDate: DateTime(2026, 1, 20))],
    );

    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byIcon(Icons.schedule),
      ),
      findsNothing,
    );
  });
}
