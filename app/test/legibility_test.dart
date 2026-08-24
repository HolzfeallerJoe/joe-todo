import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/theme.dart';
import 'package:joe_todo/widgets.dart';

/// Lesbarkeit auf jedem Untergrund.
///
/// Joe malt seinen Hintergrund selbst – vier gemalte Texturen und elf Fotos.
/// Damit gibt es genau zwei Sorten Text: auf einer [PaperCard] (dort gilt
/// die Tintenfarbe des Designs) oder frei auf dem Hintergrund (dort gilt
/// `theme.onBg` samt Halo). Wer die Tintenfarbe frei auf den Hintergrund
/// setzt, bekommt auf einem Foto genau das, was uns aufgefallen ist: Text,
/// der praktisch verschwindet – auf dem Ozean-Design war der Leer-Hinweis
/// der Historie nicht mehr zu lesen.
void main() {
  Future<AppState> pump(WidgetTester tester, {AppState? state}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, 1200);
    addTearDown(tester.view.reset);

    final appState = state ??
        (AppState()
          ..tasks = []
          ..appointments = []
          ..notes = []
          ..showPet = false);
    await tester.pumpWidget(JoeApp(state: appState));
    await tester.pumpAndSettle();
    return appState;
  }

  Future<void> open(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  /// Ob [text] in einer PaperCard steht – also auf Papier und nicht auf dem
  /// Hintergrundbild.
  void expectOnPaper(WidgetTester tester, Finder text) {
    expect(text, findsOneWidget);
    expect(
      find.ancestor(of: text, matching: find.byType(PaperCard)),
      findsWidgets,
      reason: 'Text ohne Karte auf dem Hintergrund – auf einem Foto-Design '
          'waere er nicht zu lesen',
    );
  }

  group('Leere Zustaende stehen auf Papier', () {
    testWidgets('Aufgaben', (tester) async {
      await pump(tester);
      await open(tester, 'Aufgaben');
      expectOnPaper(tester, find.textContaining('Noch keine Aufgaben'));
    });

    testWidgets('Termine', (tester) async {
      await pump(tester);
      await open(tester, 'Termine');
      expectOnPaper(tester, find.textContaining('Noch keine Termine'));
    });

    testWidgets('Notizen', (tester) async {
      await pump(tester);
      await open(tester, 'Notizen');
      expectOnPaper(tester, find.textContaining('Noch keine Notizen'));
    });

    testWidgets('Historie', (tester) async {
      await pump(tester);
      await open(tester, 'Historie');
      expectOnPaper(tester, find.textContaining('Noch nichts erledigt'));
    });

    testWidgets('Dashboard: nichts zu tun, keine Termine', (tester) async {
      await pump(tester);
      expectOnPaper(tester, find.textContaining('Alles erledigt'));
      expectOnPaper(tester, find.textContaining('Heute keine Termine'));
    });

    testWidgets('Kalender: leerer Tag', (tester) async {
      await pump(tester);
      await open(tester, 'Kalender');
      expectOnPaper(tester, find.textContaining('Nichts eingetragen'));
    });
  });

  group('Die Farben der Designs', () {
    test('jedes Design trennt Papier, Tinte und Hintergrundtext', () {
      for (final theme in joeThemes) {
        // Auf dem Hintergrund gilt onBg – und die Foto-Designs bekommen
        // zusaetzlich einen Halo, weil ein Foto hell *und* dunkel ist.
        if (theme.backgroundAsset != null) {
          expect(
            theme.onBgShadows,
            isNotEmpty,
            reason: '${theme.name}: Text auf dem Foto braucht seinen Halo',
          );
        }
        // Tinte auf Papier muss sich von der Papierfarbe abheben.
        expect(
          _contrast(theme.ink, theme.paper),
          greaterThan(4.5),
          reason: '${theme.name}: Tinte auf Papier zu blass',
        );
        // Die leise Tinte darf blasser sein, aber nicht beliebig: sie
        // traegt Datumszeilen, "offen seit" und die Leer-Hinweise.
        expect(
          _contrast(theme.inkSoft, theme.paper),
          greaterThan(3.0),
          reason: '${theme.name}: leise Tinte auf Papier zu blass',
        );
      }
    });
  });
}

/// Kontrastverhaeltnis nach WCAG (1 = gleich, 21 = Schwarz auf Weiss).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hell = la > lb ? la : lb;
  final dunkel = la > lb ? lb : la;
  return (hell + 0.05) / (dunkel + 0.05);
}

double _luminance(Color c) => Color(c.toARGB32()).computeLuminance();
