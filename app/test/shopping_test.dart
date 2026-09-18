import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/theme.dart';
import 'package:joe_todo/toast.dart';
import 'package:joe_todo/util.dart';

/// Die Einkaufsliste auf dem Bildschirm: der Reiter, das Eingabefeld unten,
/// Abhaken per Tipp, Bearbeiten und Loeschen per langem Druck.
void main() {
  Future<AppState> pump(
    WidgetTester tester, {
    List<ShoppingItem> items = const [],
  }) async {
    // Hoch genug, dass die ganze Reiterleiste ohne Scrollen zu sehen ist.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, 1200);
    addTearDown(tester.view.reset);

    final state = AppState()
      ..tasks = []
      ..appointments = []
      ..notes = []
      ..shopping = [...items]
      ..showPet = false;
    await tester.pumpWidget(JoeApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tippt [text] ins Eingabefeld unten und drueckt "Fertig" (Enter).
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  ShoppingItem item(String id, String title, {int minute = 0}) =>
      ShoppingItem(
        id: id,
        title: title,
        createdAt: DateTime(2026, 9, 18, 10, minute),
      );

  List<String> titles(AppState state, [DateTime? day]) =>
      [for (final i in state.shoppingItemsFor(day)) i.title];

  group('Modus eigener Reiter', () {
    testWidgets('der Reiter steht zwischen Notizen und Historie',
        (tester) async {
      await pump(tester);
      final notes = tester.getTopLeft(find.text('Notizen')).dy;
      final shopping = tester.getTopLeft(find.text('Einkaufsliste')).dy;
      final history = tester.getTopLeft(find.text('Historie')).dy;
      expect(notes, lessThan(shopping));
      expect(shopping, lessThan(history));

      await tap(tester, find.text('Einkaufsliste'));
      expect(find.textContaining('Noch nichts auf der Liste'), findsOneWidget);
      // Kein Plus-Knopf: das Eingabefeld ist der Weg zum Hinzufuegen.
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Enter legt an, leert das Feld und behaelt den Fokus',
        (tester) async {
      final state = await pump(tester);
      await tap(tester, find.text('Einkaufsliste'));

      await type(tester, 'Milch');
      expect(titles(state), ['Milch']);
      expect(state.shopping.single.day, isNull);
      expect(find.text('Milch'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);

      // Enter auf leerem Feld: nichts.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state.shopping, hasLength(1));

      // Der Knopf daneben tut dasselbe; neue Eintraege landen unten.
      await tester.enterText(find.byType(TextField), 'Brot');
      await tap(tester, find.byTooltip('Hinzufügen'));
      expect(titles(state), ['Milch', 'Brot']);
      expect(
        tester.getTopLeft(find.text('Milch')).dy,
        lessThan(tester.getTopLeft(find.text('Brot')).dy),
      );
    });

    testWidgets('Tipp hakt ab: durchgestrichen, unter den offenen',
        (tester) async {
      final state = await pump(
        tester,
        items: [item('1', 'Milch'), item('2', 'Brot', minute: 1)],
      );
      await tap(tester, find.text('Einkaufsliste'));

      await tap(tester, find.text('Milch'));
      expect(state.shopping.first.done, isTrue);
      expect(titles(state), ['Brot', 'Milch']);
      expect(
        tester.getTopLeft(find.text('Brot')).dy,
        lessThan(tester.getTopLeft(find.text('Milch')).dy),
      );
      final style = tester.widget<Text>(find.text('Milch')).style!;
      expect(style.decoration, TextDecoration.lineThrough);

      // Zweiter Tipp nimmt den Haken zurueck.
      await tap(tester, find.text('Milch'));
      expect(state.shopping.first.done, isFalse);
    });

    testWidgets('langer Druck: Bearbeiten aendert den Titel', (tester) async {
      final state = await pump(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Einkaufsliste'));

      await tester.longPress(find.text('Milch'));
      await tester.pumpAndSettle();
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);

      await tap(tester, find.text('Bearbeiten'));
      expect(find.text('Eintrag bearbeiten'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Hafermilch');
      await tap(tester, find.text('Speichern'));

      expect(state.shopping.single.title, 'Hafermilch');
      expect(find.text('Hafermilch'), findsOneWidget);
    });

    testWidgets('Bearbeiten mit leerem Feld: Hinweis ohne "Namen"',
        (tester) async {
      // Ein Einkaufs-Eintrag ist kein Name; das Blatt teilt es sich aber mit
      // den eigenen Symptomen, die weiter nach einem Namen fragen.
      final state = await pump(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Einkaufsliste'));

      await tester.longPress(find.text('Milch'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Bearbeiten'));
      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(find.text('Bitte gib etwas ein.'), findsOneWidget);
      expect(find.text('Bitte gib einen Namen ein.'), findsNothing);
      expect(find.text('Eintrag bearbeiten'), findsOneWidget);
      expect(state.shopping.single.title, 'Milch');
      await tester.pump(JoeToast.showDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('langer Druck: Loeschen fragt nach, dann ist er weg',
        (tester) async {
      final state = await pump(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Einkaufsliste'));

      await tester.longPress(find.text('Milch'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Löschen'));
      expect(find.text('Eintrag löschen?'), findsOneWidget);
      expect(state.shopping, hasLength(1));

      await tap(tester, find.text('Löschen'));
      expect(state.shopping, isEmpty);
      expect(find.text('Milch'), findsNothing);
    });
  });

  group('Modus je Tag in den Notizen', () {
    Future<AppState> pumpPerDay(
      WidgetTester tester, {
      List<ShoppingItem> items = const [],
    }) async {
      final state = await pump(tester, items: items);
      state.setShoppingMode(ShoppingListMode.perDay);
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('kein Reiter, dafuer der Umschalter in den Notizen',
        (tester) async {
      await pumpPerDay(tester);
      expect(find.text('Einkaufsliste'), findsNothing);

      await tap(tester, find.text('Notizen'));
      // Die Notizen oeffnen mit "Notizen": Liste und Stift wie gewohnt.
      expect(find.text('Einkaufsliste'), findsOneWidget);
      expect(find.textContaining('Noch keine Notizen'), findsOneWidget);
      expect(find.byTooltip('Neue Notiz'), findsOneWidget);

      await tap(tester, find.text('Einkaufsliste'));
      expect(find.text(formatDateFull(today())), findsOneWidget);
      expect(find.textContaining('Noch nichts auf der Liste'), findsOneWidget);
      // Auf der Einkaufsseite kein Stift – das Eingabefeld ist der Weg.
      expect(find.byTooltip('Neue Notiz'), findsNothing);
    });

    testWidgets('der Eintrag gehoert zu heute, ein anderer Tag ist leer',
        (tester) async {
      final state = await pumpPerDay(tester);
      await tap(tester, find.text('Notizen'));
      await tap(tester, find.text('Einkaufsliste'));

      await type(tester, 'Milch');
      expect(dateKey(state.shopping.single.day!), dateKey(today()));
      expect(titles(state), isEmpty, reason: 'nicht in der Reiter-Liste');
      expect(find.text('Milch'), findsOneWidget);

      await tap(tester, find.byTooltip('Nächster Tag'));
      final tomorrow = addCalendarDays(today(), 1);
      expect(find.text(formatDateFull(tomorrow)), findsOneWidget);
      expect(find.text('Milch'), findsNothing);
      expect(find.textContaining('Noch nichts auf der Liste'), findsOneWidget);

      await type(tester, 'Brot');
      expect(titles(state, tomorrow), ['Brot']);
      expect(titles(state, today()), ['Milch']);

      await tap(tester, find.byTooltip('Voriger Tag'));
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Brot'), findsNothing);
    });

    testWidgets('die Notizen oeffnen wieder mit "Notizen"', (tester) async {
      await pumpPerDay(tester);
      await tap(tester, find.text('Notizen'));
      await tap(tester, find.text('Einkaufsliste'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tap(tester, find.text('Notizen'));
      expect(find.textContaining('Noch keine Notizen'), findsOneWidget);
    });

    testWidgets('Umschalten loescht nichts', (tester) async {
      final state = await pumpPerDay(
        tester,
        items: [item('1', 'Milch')],
      );
      // Der Reiter-Eintrag ist unsichtbar, aber noch da.
      await tap(tester, find.text('Notizen'));
      await tap(tester, find.text('Einkaufsliste'));
      expect(find.text('Milch'), findsNothing);
      expect(state.shopping, hasLength(1));
    });
  });

  test('Reiterbeschriftung erreicht 3:1 auf der Einkaufslisten-Farbe', () {
    for (final theme in joeThemes) {
      final color = theme.shoppingTabColor;
      expect(
        contrastRatio(theme.onTab(color), color),
        greaterThanOrEqualTo(3.0),
        reason: '${theme.name} / $color',
      );
    }
  });
}
