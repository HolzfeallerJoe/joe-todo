import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/calendar.dart';

Future<void> pumpCalendar(WidgetTester tester, DateTime initialDay) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(560, 1000);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = []
    ..appointments = []
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
}
