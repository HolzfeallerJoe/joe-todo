import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/pets.dart';
import 'package:joe_todo/widgets.dart';

/// Der Begleiter sitzt seit "Teil 2" auf jeder Seite, an einem Platz, den der
/// App-Start auswuerfelt. Damit muss er zwei Dinge koennen, die vorher niemand
/// pruefen musste: jedes der 53 Motive muss an jedem Platz gleich gross
/// wirken (die Bilder sind voellig verschieden geschnitten), und er darf an
/// keinem Platz etwas verdecken oder schlucken.
void main() {
  setUp(PetPlacement.reset);
  tearDown(PetPlacement.reset);

  group('Katalog', () {
    test('jedes Motiv bringt sein Seitenverhaeltnis mit', () {
      for (final pet in joePets) {
        expect(
          pet.aspect,
          inInclusiveRange(0.3, 2.0),
          reason: '${pet.id} hat ein unglaubwuerdiges Seitenverhaeltnis',
        );
      }
    });

    test('die Schluessel sind eindeutig', () {
      final ids = joePets.map((p) => p.id).toSet();
      expect(ids, hasLength(joePets.length));
    });
  });

  group('Groesse', () {
    test('alle Motive wirken an einem Platz gleich gross', () {
      for (final spot in PetSpot.values) {
        // Das geometrische Mittel ist das Mass: gleiche Hoehe hiesse, der
        // quer liegende Hai wuerde bildschirmbreit, gleiche Breite hiesse,
        // das hochkant stehende Lama verschwaende zu einem Strich.
        final gauges = [
          for (final pet in joePets)
            math.sqrt(petBox(pet, spot).width * petBox(pet, spot).height),
        ];
        final smallest = gauges.reduce(math.min);
        final largest = gauges.reduce(math.max);
        expect(
          largest / smallest,
          // Nicht ganz exakt: die Deckel in [petBox] druecken die extremen
          // Schnitte (Lama, Hai) noch einmal herunter. Ein groesserer
          // Abstand hiesse, dass die Normierung selbst nicht mehr greift –
          // ohne sie liegen zwischen Lama und Hai gut zwei Laengen.
          lessThan(1.3),
          reason: 'an $spot faellt die gefuehlte Groesse zu weit auseinander',
        );
      }
    });

    test('die Deckel halten die Extreme im Rahmen', () {
      final lama = petById('lama'); // 130x320, das hoechste Motiv
      final hai = petById('hai'); // 320x196, das breiteste
      for (final spot in PetSpot.values) {
        expect(petBox(lama, spot).height, lessThanOrEqualTo(132));
        expect(petBox(hai, spot).width, lessThanOrEqualTo(168));
      }
      // Oben ist weniger Platz als unten: da muss das Lama kleiner ausfallen.
      expect(
        petBox(lama, PetSpot.contentTopLeft).height,
        lessThan(petBox(lama, PetSpot.bottomLeft).height),
      );
    });

    test('der Begleiter ragt nur teilweise in die Seite', () {
      for (final pet in joePets) {
        for (final spot in PetSpot.values) {
          final box = petBox(pet, spot);
          final overlap = petOverlap(pet, spot, PetPage.dashboard);
          expect(overlap, greaterThan(0));
          expect(
            overlap,
            lessThan(box.height),
            reason: '${pet.id} an $spot verschwaende ganz im Inhalt',
          );
        }
      }
    });
  });

  group('Platz', () {
    test('jede Seite bietet nur Plaetze an, die zu ihr passen', () {
      for (final page in PetPage.values) {
        expect(page.spots, isNotEmpty, reason: '$page bietet nichts an');
        expect(
          page.spots.toSet(),
          hasLength(page.spots.length),
          reason: '$page nennt einen Platz doppelt',
        );
      }
      // Neben dem Plus sitzt nur, wo es ein Plus gibt.
      for (final page in [PetPage.calendar, PetPage.noteEdit, PetPage.history]) {
        expect(page.spots, isNot(contains(PetSpot.besideFab)), reason: '$page');
      }
      // Und auf dem Dashboard, wo die Reiter bis unten reichen, darf er
      // auch unten stehen.
      expect(PetPage.dashboard.spots, contains(PetSpot.bottomLeft));
      expect(PetPage.dashboard.spots, contains(PetSpot.besideFab));
    });

    test('derselbe Startwert ergibt immer denselben Platz', () {
      PetPlacement.use(4711);
      final first = {
        for (final page in PetPage.values) page: PetPlacement.spotOn(page),
      };
      PetPlacement.use(99);
      PetPlacement.use(4711);
      for (final page in PetPage.values) {
        expect(PetPlacement.spotOn(page), first[page], reason: '$page');
      }
    });

    test('der Platz kommt immer aus dem Vorrat der Seite', () {
      final random = math.Random(3);
      for (var i = 0; i < 100; i++) {
        PetPlacement.roll(random);
        for (final page in PetPage.values) {
          expect(page.spots, contains(PetPlacement.spotOn(page)));
        }
      }
    });

    test('ueber die Startwerte verteilt sich jede Seite auf ihre Plaetze', () {
      // Wichtig ist, dass nicht eine Ecke gewinnt: sonst waere der Wurf
      // umsonst.
      for (final page in PetPage.values) {
        final seen = <PetSpot>{};
        for (var seed = 0; seed < 200; seed++) {
          PetPlacement.use(seed);
          seen.add(PetPlacement.spotOn(page));
        }
        expect(seen, containsAll(page.spots), reason: '$page');
      }
    });

    test('die Seiten sitzen nicht alle gleich', () {
      // Der Sinn der ganzen Uebung: beim Blaettern taucht das Tierchen
      // woanders auf. Bei mindestens einem der Startwerte muessen sich
      // Dashboard und Notizen unterscheiden.
      var differing = 0;
      for (var seed = 0; seed < 20; seed++) {
        PetPlacement.use(seed);
        if (PetPlacement.spotOn(PetPage.dashboard) !=
            PetPlacement.spotOn(PetPage.notes)) {
          differing++;
        }
      }
      expect(differing, greaterThan(10));
    });

    test('oben und unten sind sauber getrennt', () {
      expect(
        PetSpot.values.where((s) => s.isTop),
        [
          PetSpot.contentTopLeft,
          PetSpot.contentTopCenter,
          PetSpot.contentTopRight,
        ],
      );
      expect(PetSpot.contentTopLeft.side, -1);
      expect(PetSpot.contentTopCenter.side, 0);
      expect(PetSpot.besideFab.side, 1);
    });
  });

  group('Auf der Seite', () {
    /// Einen Startwert suchen, mit dem [page] auf [spot] faellt: ein Test
    /// will einen bestimmten Platz pruefen und nicht auf einen Wurf hoffen.
    int seedFor(PetPage page, PetSpot spot) {
      for (var seed = 0; seed < 2000; seed++) {
        PetPlacement.use(seed);
        if (PetPlacement.spotOn(page) == spot) return seed;
      }
      fail('kein Startwert bringt $page auf $spot');
    }

    Future<AppState> pump(
      WidgetTester tester,
      PetPage page,
      PetSpot spot,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(560, 900);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);

      PetPlacement.use(seedFor(page, spot));
      final state = AppState()
        ..tasks = []
        ..appointments = []
        ..notes = []
        ..showPet = true
        ..petId = 'lama'; // das hoechste Motiv, der schwierigste Fall
      await tester.pumpWidget(JoeApp(state: state));
      await tester.pumpAndSettle();
      return state;
    }

    Rect petRect(WidgetTester tester) => tester.getRect(
          find.image(const AssetImage('assets/pets/aquarell/lama.webp')),
        );

    Future<void> open(WidgetTester tester, String tab) async {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    testWidgets('er sitzt auf jeder Seite, nicht nur auf dem Dashboard',
        (tester) async {
      await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final onDashboard = petRect(tester);

      await open(tester, 'Notizen');
      expect(find.textContaining('Noch keine Notizen'), findsOneWidget);
      expect(petRect(tester), isNotNull);

      // Zurueck: auf derselben Seite sitzt er wieder genauso. Ein Platz, der
      // beim Blaettern wandert, waere kein Platz.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(petRect(tester), onDashboard);
    });

    testWidgets('er verdeckt den Seitentitel nicht', (tester) async {
      // Mittig oben ist der schlimmste Fall: genau dort steht der Titel.
      // Die Historie ist die Seite, die diesen Platz anbietet.
      await pump(tester, PetPage.history, PetSpot.contentTopCenter);
      await open(tester, 'Historie');

      final title = tester.getRect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Historie')),
      );
      expect(
        petRect(tester).top,
        greaterThanOrEqualTo(title.bottom),
        reason: 'der Begleiter liegt ueber dem Seitentitel',
      );
    });

    testWidgets('die Karte darunter rueckt weg, bleibt aber angelehnt',
        (tester) async {
      await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final pet = petRect(tester);
      final card = tester.getRect(find.byType(PaperCard).first);
      expect(card.top, greaterThan(pet.top), reason: 'die Karte steht zu hoch');
      // Hoechstens so tief, wie petOverlap es zusagt – die Seite legt
      // ihren eigenen Rand noch darauf. Der Rest des Tierchens steht
      // ueber der Karte, sonst waere von ihm kaum etwas zu sehen.
      expect(
        pet.bottom - card.top,
        lessThanOrEqualTo(
          petOverlap(petById('lama'), PetSpot.contentTopLeft, PetPage.dashboard),
        ),
      );
      expect(
        card.top,
        lessThan(pet.bottom),
        reason: 'der Begleiter sitzt nicht mehr auf der Karte auf',
      );
    });

    testWidgets('neben dem Plus sitzt er daneben, nicht darauf',
        (tester) async {
      await pump(tester, PetPage.dashboard, PetSpot.besideFab);
      final pet = petRect(tester);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(pet.bottom, closeTo(900 - 16, 1), reason: 'nicht am unteren Rand');
      expect(
        pet.right,
        lessThanOrEqualTo(fab.left),
        reason: 'der Begleiter sitzt auf dem Plus-Knopf',
      );
    });

    testWidgets('er scrollt mit dem weg, worauf er sitzt', (tester) async {
      await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final before = petRect(tester);
      final cardBefore = tester.getRect(find.byType(PaperCard).first);

      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();

      final after = petRect(tester);
      final cardAfter = tester.getRect(find.byType(PaperCard).first);
      // Genau so weit wie die Karte, auf der er sitzt: er klebt an ihr,
      // nicht am Bildschirm.
      expect(before.top - after.top, closeTo(cardBefore.top - cardAfter.top, 1));
      expect(after.top, lessThan(before.top));
    });

    testWidgets('unten bleibt er stehen – die Leiste scrollt ja auch nicht',
        (tester) async {
      await pump(tester, PetPage.dashboard, PetSpot.besideFab);
      final before = petRect(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(petRect(tester), before);
    });

    testWidgets('Inhalt und Begleiter verschwinden an derselben Kante',
        (tester) async {
      // Der Platz fuer den Begleiter gehoert *in* die Liste. Liegt er
      // ausserhalb, endet der Inhalt an einer Kante weiter unten als das
      // Tierchen – dann sieht das Scrollen aus wie zwei Kaesten, die
      // aneinander vorbeilaufen.
      await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final clip = tester.getRect(
        find
            .ancestor(
              of: find.image(const AssetImage('assets/pets/aquarell/lama.webp')),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      final viewport = tester.getRect(find.byType(Viewport));
      expect(viewport.top, closeTo(clip.top, 1));
    });

    testWidgets('beim Wegscrollen wird er oben abgeschnitten', (tester) async {
      // Sonst schoebe er sich beim Hochscrollen ueber Titel- und
      // Statusleiste, statt unter ihnen zu verschwinden.
      await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final clip = tester.getRect(
        find
            .ancestor(
              of: find.image(const AssetImage('assets/pets/aquarell/lama.webp')),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      // Der Ausschnitt faengt an der Oberkante des Inhalts an – auf dem
      // Dashboard also direkt unter der Statusleiste (hier 24).
      expect(clip.top, closeTo(24, 1));
      expect(clip.bottom, closeTo(900, 1));
    });

    testWidgets('er schluckt keine Tipps', (tester) async {
      // Mitten auf der Heute-Karte: ohne IgnorePointer laege er ueber dem
      // Ausklappmenue und der Tipp ginge ins Leere.
      final state =
          await pump(tester, PetPage.dashboard, PetSpot.contentTopLeft);
      final before = state.todayExpanded;
      await tester.tap(find.text('Heute abhaken'));
      await tester.pumpAndSettle();
      expect(state.todayExpanded, !before);
    });
  });
}
