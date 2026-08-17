import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/toast.dart';

/// Die Eingabeblaetter duerfen weder unter die Tastatur noch unter die
/// Statusleiste rutschen – beides war beim Anlegen einer Aufgabe der Fall,
/// weil die Hoehe an einem festen Anteil der Bildschirmhoehe hing.
void main() {
  const screenHeight = 800.0;
  const statusBar = 40.0;
  const navBar = 48.0;
  const keyboard = 380.0;

  setUp(JoeToast.instance.reset);
  tearDown(JoeToast.instance.reset);

  late AppState openedState;

  Future<void> openSheet(
    WidgetTester tester, {
    String entry = 'Neue Aufgabe',
    double bottomInset = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, screenHeight);
    tester.view.padding = const FakeViewPadding(top: statusBar, bottom: navBar);
    tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);

    final state = AppState()
      ..tasks = []
      ..appointments = []
      ..notes = []
      ..showPet = false;
    openedState = state;
    await tester.pumpWidget(JoeApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  testWidgets('Speichern bleibt bei offener Tastatur sichtbar', (tester) async {
    await openSheet(tester, bottomInset: keyboard);

    final button = tester.getRect(find.text('Speichern'));
    expect(
      button.bottom,
      lessThanOrEqualTo(screenHeight - keyboard),
      reason: 'Speichern liegt unter der Tastatur',
    );
    expect(button.top, greaterThanOrEqualTo(0));
  });

  testWidgets('Blatt bleibt unter der Statusleiste', (tester) async {
    await openSheet(tester, bottomInset: keyboard);

    // Der Titel ist das oberste Element des Blattes.
    expect(
      tester.getRect(find.text('Neue Aufgabe')).top,
      greaterThanOrEqualTo(statusBar),
      reason: 'Titel steckt hinter der Statusleiste',
    );
  });

  testWidgets('ohne Tastatur bleibt Speichern über der Tastenleiste', (
    tester,
  ) async {
    await openSheet(tester);

    expect(
      tester.getRect(find.text('Speichern')).bottom,
      lessThanOrEqualTo(screenHeight - navBar),
      reason: 'Speichern liegt unter den Telefontasten',
    );
  });

  for (final entry in ['Neue Aufgabe', 'Neuer Termin']) {
    testWidgets('$entry zeigt bei leerem Titel einen Fehler', (tester) async {
      await openSheet(tester, entry: entry);

      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(find.text('Bitte gib einen Titel ein.'), findsOneWidget);
      expect(find.text(entry), findsOneWidget);
      await tester.pump(JoeToast.showDuration);
    });
  }

  // Der Titel-Controller haing frueher am Future der Route und wurde damit
  // schon bei Navigator.pop weggeraeumt – das Blatt animierte danach aber noch
  // heraus, das Textfeld griff auf den toten Controller zu und die App landete
  // auf dem roten Bildschirm. Darum wird hier bis zum Ende der Animation
  // gepumpt und nicht nur ein Frame.
  for (final entry in ['Neue Aufgabe', 'Neuer Termin']) {
    testWidgets('$entry laesst sich ohne Fehler speichern', (tester) async {
      await openSheet(tester, entry: entry);

      await tester.enterText(find.byType(TextField).first, 'Mit Joe reden');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(entry), findsNothing, reason: 'Blatt blieb offen');
      final saved = entry == 'Neue Aufgabe'
          ? openedState.tasks.map((t) => t.title)
          : openedState.appointments.map((a) => a.title);
      expect(saved, contains('Mit Joe reden'));
    });
  }
}
