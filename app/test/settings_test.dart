import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/pets.dart';
import 'package:joe_todo/screens/settings.dart';
import 'package:joe_todo/widgets.dart' show PaperCard;

/// Die Einstellungen mit leerem Bestand. Das Fenster ist breit (die
/// Testschrift setzt jedes Zeichen auf ein volles Quadrat) und hoch, damit
/// die lange Liste nicht staendig gescrollt werden muss; wo doch, holt
/// [ensureVisible] die Zeile ins Bild.
Future<AppState> pumpSettings(
  WidgetTester tester, {
  bool showPet = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(560, 1600);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = []
    ..appointments = []
    ..notes = []
    ..showPet = showPet;
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

/// Zieht die Zeile [finder] ins Bild und laesst die Liste zur Ruhe kommen.
Future<void> ensureVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  // Jede Aenderung speichert; ohne Attrappe liefe das ins Leere.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Begleiter-Groesse', () {
    testWidgets('der Regler steht auf 100 % und nennt den Begleiter '
        'fuer jede Seite', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Kleine Deko auf jeder Seite'), findsOneWidget);
      await ensureVisible(tester, find.byType(Slider));
      expect(find.text('100 %'), findsOneWidget);
    });

    testWidgets('ganz nach rechts gezogen sind es 160 %', (tester) async {
      final state = await pumpSettings(tester);
      await ensureVisible(tester, find.byType(Slider));

      await tester.drag(find.byType(Slider), const Offset(2000, 0));
      await tester.pumpAndSettle();

      expect(state.petScale, maxPetScale);
      expect(find.text('160 %'), findsOneWidget);
    });

    testWidgets('ganz nach links gezogen sind es 60 %', (tester) async {
      final state = await pumpSettings(tester);
      await ensureVisible(tester, find.byType(Slider));

      await tester.drag(find.byType(Slider), const Offset(-2000, 0));
      await tester.pumpAndSettle();

      expect(state.petScale, minPetScale);
      expect(find.text('60 %'), findsOneWidget);
    });

    testWidgets('ohne Begleiter reagiert der Regler nicht', (tester) async {
      final state = await pumpSettings(tester, showPet: false);
      await ensureVisible(tester, find.byType(Slider));

      // Dass der Zug nicht ankommt, ist hier gerade die Erwartung.
      await tester.drag(find.byType(Slider), const Offset(2000, 0),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.petScale, 1.0);
      expect(find.text('100 %'), findsOneWidget);
    });

    testWidgets('die Vorlesehilfe hoert die Groesse, nicht den Regelweg',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester);
      await ensureVisible(tester, find.byType(Slider));

      // Bei 100 % steht der Regler bei 40 % seines Weges; vorgelesen werden
      // soll aber, was auch daneben steht.
      expect(find.semantics.byValue('100 %'), findsOne);
      expect(find.semantics.byValue(RegExp('40')), findsNothing);
      semantics.dispose();
    });
  });

  group('Prioritaetsfarben', () {
    // Die Tabelle ist statisch; ein Test darf dem naechsten keine Farbe
    // hinterlassen.
    tearDown(PriorityColors.reset);

    /// Die Zeile der Stufe [p] in der Karte "Prioritaeten".
    Finder row(Priority p) => find.ancestor(
          of: find.text('Stufe ${p.level} · ${p.label}'),
          matching: find.byType(ListTile),
        );

    /// Was die Zeile der Stufe [p] rechts nennt.
    Finder rowShows(Priority p, String text) =>
        find.descendant(of: row(p), matching: find.text(text));

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);

    testWidgets('drei Stufen, anfangs ohne Farbe', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Prioritäten'), findsOneWidget);
      for (final p in Priority.values) {
        expect(rowShows(p, 'Keine Farbe'), findsOneWidget);
      }
    });

    testWidgets('Hoch bekommt Mint und gibt es wieder ab', (tester) async {
      final state = await pumpSettings(tester);

      await tester.tap(row(Priority.hoch));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Farbe für Hoch')), findsOneWidget);
      expect(
        tester.getSemantics(inSheet(find.text('Keine Farbe'))),
        isSemantics(isSelected: true, isButton: true),
      );
      // Alle 25 Farben stehen zur Wahl, und bei "Keine Farbe" ist keine
      // davon markiert.
      for (final name in taskPaletteNames) {
        expect(inSheet(find.bySemanticsLabel('Farbe $name')), findsOneWidget);
        expect(
          tester.getSemantics(inSheet(find.bySemanticsLabel('Farbe $name'))),
          isSemantics(isSelected: false),
          reason: name,
        );
      }

      await tester.tap(inSheet(find.bySemanticsLabel('Farbe Mint')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(state.priorityColors[Priority.hoch], 20);
      expect(PriorityColors.of(Priority.hoch), 20);
      expect(rowShows(Priority.hoch, 'Mint'), findsOneWidget);
      expect(rowShows(Priority.mittel, 'Keine Farbe'), findsOneWidget);

      // Wieder oeffnen: jetzt ist Mint markiert, "Keine Farbe" nimmt sie weg.
      await tester.tap(row(Priority.hoch));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(inSheet(find.bySemanticsLabel('Farbe Mint'))),
        isSemantics(isSelected: true),
      );

      await tester.tap(inSheet(find.text('Keine Farbe')));
      await tester.pumpAndSettle();

      expect(state.priorityColors.containsKey(Priority.hoch), isFalse);
      expect(PriorityColors.of(Priority.hoch), isNull);
      expect(rowShows(Priority.hoch, 'Keine Farbe'), findsOneWidget);
    });

    testWidgets('die Punkte im Blatt sind gross genug fuer den Finger',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(row(Priority.niedrig));
      await tester.pumpAndSettle();

      Rect dot(int i) => tester.getRect(
          inSheet(find.bySemanticsLabel('Farbe ${taskPaletteNames[i]}')));
      final first = dot(0);
      final fifth = dot(4);
      final sixth = dot(5);
      expect(first.width, moreOrLessEquals(44));
      // Fuenf je Reihe: der fuenfte steht noch in der ersten, der sechste
      // beginnt die zweite.
      expect(fifth.top, moreOrLessEquals(first.top));
      expect(sixth.left, moreOrLessEquals(first.left, epsilon: 0.5));
      expect(sixth.top, greaterThan(first.bottom));
    });
  });

  group('Einkaufsliste', () {
    Finder option(ShoppingListMode mode) => find.ancestor(
          of: find.text(mode.label),
          matching: find.byType(RadioListTile<ShoppingListMode>),
        );

    /// Ob die Vorlesehilfe [mode] als gewaehlt meldet – und damit auch, ob
    /// der Punkt gefuellt ist.
    bool isChosen(WidgetTester tester, ShoppingListMode mode) =>
        isSemantics(isChecked: true)
            .matches(tester.getSemantics(option(mode)), {});

    testWidgets('Standard ist der eigene Reiter, umgeschaltet wird per Tipp',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final state = await pumpSettings(tester);
      await ensureVisible(tester, option(ShoppingListMode.notes));

      expect(find.text('Die Liste hat einen eigenen Reiter'), findsOneWidget);
      expect(find.text('Die Liste steht in den Notizen'), findsOneWidget);
      expect(isChosen(tester, ShoppingListMode.tab), isTrue);
      expect(isChosen(tester, ShoppingListMode.notes), isFalse);

      await tester.tap(option(ShoppingListMode.notes));
      await tester.pumpAndSettle();

      expect(state.shoppingMode, ShoppingListMode.notes);
      expect(isChosen(tester, ShoppingListMode.notes), isTrue);
      expect(isChosen(tester, ShoppingListMode.tab), isFalse);

      // Und zurueck – nichts daran ist eine Einbahnstrasse.
      await tester.tap(option(ShoppingListMode.tab));
      await tester.pumpAndSettle();
      expect(state.shoppingMode, ShoppingListMode.tab);
      semantics.dispose();
    });
  });

  testWidgets('Tippzeilen malen ihre Tintenwelle auf der Karte',
      (tester) async {
    // Eine ListTile malt auf das naechste Material darueber. Laege das
    // ausserhalb der PaperCard (das Scaffold), malte sie unter die
    // Papierfarbe – die Welle bliebe unsichtbar. PaperCard bringt deshalb
    // selbst eine durchsichtige Materialschicht mit.
    await pumpSettings(tester);

    final tiles = find.byType(ListTile);
    expect(tiles, findsWidgets);
    for (final tile in tiles.evaluate()) {
      // Die Vorfahren kommen vom naechsten an: .first ist das Material,
      // auf das die Zeile malt.
      final material = find
          .ancestor(
            of: find.byWidget(tile.widget),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.widget<Material>(material).type,
        MaterialType.transparency,
      );
      expect(
        find.ancestor(of: material, matching: find.byType(PaperCard)),
        findsOneWidget,
      );
    }
  });
}
