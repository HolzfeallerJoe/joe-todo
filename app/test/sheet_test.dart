import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';

/// Die Eingabeblaetter duerfen weder unter die Tastatur noch unter die
/// Statusleiste rutschen – beides war beim Anlegen einer Aufgabe der Fall,
/// weil die Hoehe an einem festen Anteil der Bildschirmhoehe hing.
void main() {
  const screenHeight = 800.0;
  const statusBar = 40.0;
  const navBar = 48.0;
  const keyboard = 380.0;

  Future<void> openTaskSheet(WidgetTester tester, {double bottomInset = 0}) async {
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
    await tester.pumpWidget(JoeApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Aufgabe'));
    await tester.pumpAndSettle();
  }

  testWidgets('Speichern bleibt bei offener Tastatur sichtbar', (tester) async {
    await openTaskSheet(tester, bottomInset: keyboard);

    final button = tester.getRect(find.text('Speichern'));
    expect(
      button.bottom,
      lessThanOrEqualTo(screenHeight - keyboard),
      reason: 'Speichern liegt unter der Tastatur',
    );
    expect(button.top, greaterThanOrEqualTo(0));
  });

  testWidgets('Blatt bleibt unter der Statusleiste', (tester) async {
    await openTaskSheet(tester, bottomInset: keyboard);

    // Der Titel ist das oberste Element des Blattes.
    expect(
      tester.getRect(find.text('Neue Aufgabe')).top,
      greaterThanOrEqualTo(statusBar),
      reason: 'Titel steckt hinter der Statusleiste',
    );
  });

  testWidgets('ohne Tastatur bleibt Speichern über der Tastenleiste',
      (tester) async {
    await openTaskSheet(tester);

    expect(
      tester.getRect(find.text('Speichern')).bottom,
      lessThanOrEqualTo(screenHeight - navBar),
      reason: 'Speichern liegt unter den Telefontasten',
    );
  });
}
