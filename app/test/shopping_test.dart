import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/theme.dart';
import 'package:joe_todo/toast.dart';

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
      ..shoppingLists = [
        ShoppingList(
          id: 'l1',
          name: defaultShoppingListName,
          items: [...items],
        ),
      ]
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

  List<String> titles(AppState state) =>
      [for (final i in state.shoppingItems) i.title];

  group('Modus eigener Reiter', () {
    testWidgets('der Reiter steht zwischen Notizen und Historie',
        (tester) async {
      await pump(tester);
      // Im Reiter-Modus heisst der Notizen-Reiter schlicht "Notizen".
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
      expect(find.text('Milch'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);

      // Enter auf leerem Feld: nichts.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state.currentShoppingList.items, hasLength(1));

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
      expect(state.currentShoppingList.items.first.done, isTrue);
      expect(titles(state), ['Brot', 'Milch']);
      expect(
        tester.getTopLeft(find.text('Brot')).dy,
        lessThan(tester.getTopLeft(find.text('Milch')).dy),
      );
      final style = tester.widget<Text>(find.text('Milch')).style!;
      expect(style.decoration, TextDecoration.lineThrough);

      // Zweiter Tipp nimmt den Haken zurueck.
      await tap(tester, find.text('Milch'));
      expect(state.currentShoppingList.items.first.done, isFalse);
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

      expect(state.currentShoppingList.items.single.title, 'Hafermilch');
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
      expect(state.currentShoppingList.items.single.title, 'Milch');
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
      expect(state.currentShoppingList.items, hasLength(1));

      await tap(tester, find.text('Löschen'));
      expect(state.currentShoppingList.items, isEmpty);
      expect(find.text('Milch'), findsNothing);
    });
  });

  group('Modus in den Notizen', () {
    Future<AppState> pumpInNotes(
      WidgetTester tester, {
      List<ShoppingItem> items = const [],
    }) async {
      final state = await pump(tester, items: items);
      state.setShoppingMode(ShoppingListMode.notes);
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('kein Reiter, dafuer der Umschalter in den Notizen',
        (tester) async {
      await pumpInNotes(tester);
      expect(find.text('Einkaufsliste'), findsNothing);
      // Der Reiter nennt die Einkaufsliste mit: sonst suchte man sie
      // hinter einem Namen, der sie nicht nennt.
      expect(find.text('Notizen'), findsNothing);

      await tap(tester, find.text('Notizen/Einkaufsliste'));
      // Die Notizen oeffnen mit "Notizen": Liste und Stift wie gewohnt.
      expect(find.text('Einkaufsliste'), findsOneWidget);
      expect(find.textContaining('Noch keine Notizen'), findsOneWidget);
      expect(find.byTooltip('Neue Notiz'), findsOneWidget);

      await tap(tester, find.text('Einkaufsliste'));
      expect(find.textContaining('Noch nichts auf der Liste'), findsOneWidget);
      // Auf der Einkaufsseite kein Stift – das Eingabefeld ist der Weg.
      expect(find.byTooltip('Neue Notiz'), findsNothing);
    });

    testWidgets('es ist dieselbe Liste wie im Reiter, ohne Datumszeile',
        (tester) async {
      // Der Eintrag aus dem Reiter-Modus steht hier genauso.
      final state = await pumpInNotes(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Notizen/Einkaufsliste'));
      await tap(tester, find.text('Einkaufsliste'));
      expect(find.text('Milch'), findsOneWidget);
      // Kein Datumsumschalter mehr: die Liste haengt an keinem Tag.
      expect(find.byTooltip('Nächster Tag'), findsNothing);
      expect(find.byTooltip('Voriger Tag'), findsNothing);

      await type(tester, 'Brot');
      expect(titles(state), ['Milch', 'Brot']);
      expect(find.text('Brot'), findsOneWidget);
    });

    testWidgets('die Notizen oeffnen wieder mit "Notizen"', (tester) async {
      await pumpInNotes(tester);
      await tap(tester, find.text('Notizen/Einkaufsliste'));
      await tap(tester, find.text('Einkaufsliste'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tap(tester, find.text('Notizen/Einkaufsliste'));
      expect(find.textContaining('Noch keine Notizen'), findsOneWidget);
    });

    testWidgets('Umschalten loescht nichts', (tester) async {
      final state = await pumpInNotes(
        tester,
        items: [item('1', 'Milch')],
      );
      await tap(tester, find.text('Notizen/Einkaufsliste'));
      await tap(tester, find.text('Einkaufsliste'));
      expect(find.text('Milch'), findsOneWidget);
      expect(state.currentShoppingList.items, hasLength(1));
    });
  });

  group('Mehrere Listen', () {
    Finder chip(String name) => find.widgetWithText(ChoiceChip, name);

    bool isChosen(WidgetTester tester, String name) =>
        tester.widget<ChoiceChip>(chip(name)).selected;

    /// Legt ueber "Neue Liste" eine Liste namens [name] an.
    Future<void> addList(WidgetTester tester, String name) async {
      await tap(tester, find.text('Neue Liste'));
      expect(find.text('Name – oder geteilten Link einfügen'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, name);
      await tap(tester, find.text('Speichern'));
    }

    testWidgets('anlegen, gleich zeigen, und jede Liste hat ihre Eintraege',
        (tester) async {
      final state = await pump(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Einkaufsliste'));
      expect(isChosen(tester, 'Einkaufsliste'), isTrue);

      await addList(tester, 'Baumarkt');
      expect(state.shoppingLists, hasLength(2));
      expect(isChosen(tester, 'Baumarkt'), isTrue);
      expect(isChosen(tester, 'Einkaufsliste'), isFalse);
      expect(find.text('Milch'), findsNothing);
      expect(find.textContaining('Noch nichts auf der Liste'), findsOneWidget);

      await type(tester, 'Schrauben');
      expect(find.text('Schrauben'), findsOneWidget);

      await tap(tester, chip('Einkaufsliste'));
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Schrauben'), findsNothing);
      expect(titles(state), ['Milch']);
    });

    testWidgets('langer Druck auf eine Liste: umbenennen', (tester) async {
      final state = await pump(tester);
      await tap(tester, find.text('Einkaufsliste'));

      await tester.longPress(chip('Einkaufsliste'));
      await tester.pumpAndSettle();
      // Die letzte Liste laesst sich nicht loeschen.
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Löschen'), findsNothing);

      await tap(tester, find.text('Bearbeiten'));
      expect(find.text('Liste umbenennen'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Wocheneinkauf');
      await tap(tester, find.text('Speichern'));

      expect(state.currentShoppingList.name, 'Wocheneinkauf');
      expect(chip('Wocheneinkauf'), findsOneWidget);
    });

    testWidgets('Liste loeschen fragt nach und nennt, was mitgeht',
        (tester) async {
      final state = await pump(tester, items: [item('1', 'Milch')]);
      await tap(tester, find.text('Einkaufsliste'));
      await addList(tester, 'Baumarkt');
      await type(tester, 'Schrauben');
      await type(tester, 'Dübel');

      await tester.longPress(chip('Baumarkt'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Löschen'));
      expect(find.text('Liste löschen?'), findsOneWidget);
      expect(find.textContaining('2 Einträge gehen mit'), findsOneWidget);

      await tap(tester, find.text('Löschen'));
      expect(state.shoppingLists, hasLength(1));
      expect(chip('Baumarkt'), findsNothing);
      // Gezeigt wird wieder die erste Liste.
      expect(isChosen(tester, 'Einkaufsliste'), isTrue);
      expect(find.text('Milch'), findsOneWidget);
    });

    testWidgets('in den Notizen dieselben Listen', (tester) async {
      final state = await pump(tester, items: [item('1', 'Milch')]);
      state.addShoppingList('Baumarkt');
      state.setShoppingMode(ShoppingListMode.notes);
      await tester.pumpAndSettle();

      await tap(tester, find.text('Notizen/Einkaufsliste'));
      await tap(tester, find.text('Einkaufsliste'));
      expect(isChosen(tester, 'Baumarkt'), isTrue);
      await tap(tester, chip('Einkaufsliste'));
      expect(find.text('Milch'), findsOneWidget);
    });
  });

  group('Teilen', () {
    // Der Kanal, ueber den share_plus das Teilen-Blatt des Systems ruft.
    const channel = MethodChannel('dev.fluttercommunity.plus/share');

    /// Faengt ab, was geteilt wuerde, statt ein Blatt zu oeffnen.
    List<Map<Object?, Object?>> captureShares(WidgetTester tester) {
      final shared = <Map<Object?, Object?>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        shared.add(call.arguments as Map<Object?, Object?>);
        return 'dev.fluttercommunity.plus/share/success';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return shared;
    }

    testWidgets('teilt die gezeigte Liste als Text, nur das Offene',
        (tester) async {
      final shared = captureShares(tester);
      await pump(
        tester,
        items: [
          item('1', 'Milch'),
          item('2', 'Brot', minute: 1),
        ],
      );
      await tap(tester, find.text('Einkaufsliste'));
      await tap(tester, find.text('Brot'));

      // Erst die Wahl: als Text oder gemeinsam bearbeiten.
      await tap(tester, find.byTooltip('Liste teilen'));
      expect(find.text('Gemeinsam bearbeiten'), findsOneWidget);
      await tap(tester, find.text('Als Text senden'));
      expect(shared, hasLength(1));
      expect(shared.single['text'], 'Einkaufsliste\n- Milch');
      expect(shared.single['subject'], 'Einkaufsliste');
    });

    testWidgets('eine Liste ohne Offenes: Hinweis statt Teilen-Blatt',
        (tester) async {
      final shared = captureShares(tester);
      await pump(tester);
      await tap(tester, find.text('Einkaufsliste'));

      await tap(tester, find.byTooltip('Liste teilen'));
      await tester.tap(find.text('Als Text senden'));
      await tester.pump();
      expect(shared, isEmpty);
      expect(find.text('Auf der Liste fehlt gerade nichts.'), findsOneWidget);
      await tester.pump(JoeToast.showDuration);
      await tester.pumpAndSettle();
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
