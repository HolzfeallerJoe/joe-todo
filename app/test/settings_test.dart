import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/pets.dart';
import 'package:joe_todo/screens/settings.dart';

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
}
