import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/wellbeing.dart';
import 'package:joe_todo/util.dart';

/// Das Befinden steht als Kategorie im Notiz-Editor und gehoert der Notiz,
/// in der es eingetragen wurde – zwei Notizen desselben Tages fuehren also
/// getrennte Listen. Jeder Eintrag traegt seine Uhrzeit: wie es einem geht,
/// ist keine Tagesnote, morgens Kopfschmerzen und abends nicht mehr sind
/// zwei Angaben und kein Widerspruch.
void main() {
  final t = today();

  AppState stateWith({
    List<WellbeingEntry> wellbeing = const [],
    List<Symptom> customSymptoms = const [],
    List<Note> notes = const [],
  }) {
    return AppState()
      ..tasks = []
      ..appointments = []
      ..notes = [...notes]
      ..wellbeing = [...wellbeing]
      ..customSymptoms = [...customSymptoms]
      ..showPet = false;
  }

  /// Die Notiz, an der die Eintraege der meisten Tests haengen.
  const noteId = 'n1';

  WellbeingEntry entry(
    DateTime at, {
    String? id,
    String? note = noteId,
    Mood? mood,
    Map<String, int> symptoms = const {},
  }) =>
      WellbeingEntry(
        id: id ?? at.toIso8601String(),
        noteId: note,
        at: at,
        mood: mood,
        symptoms: {...symptoms},
        updatedAt: DateTime.now(),
      );

  Note note(
    DateTime day, {
    String id = noteId,
    String title = 'Montag',
  }) =>
      Note(
        id: id,
        title: title,
        body: '',
        date: day,
        updatedAt: DateTime.now(),
      );

  group('Der Eintrag', () {
    test('haelt Staerken nur innerhalb der Skala', () {
      final e = entry(t);
      e.setStrength('kopfschmerzen', 3);
      expect(e.strengthOf('kopfschmerzen'), 3);

      // 0 heisst "nicht angegeben" und nimmt das Symptom heraus – ohne den
      // Rueckweg muesste man den Tag schlimmer lassen, als er war.
      e.setStrength('kopfschmerzen', 0);
      expect(e.symptoms, isEmpty);

      e.setStrength('kopfschmerzen', 9);
      expect(e.symptoms, isEmpty);
    });

    test('ist leer, solange nichts angegeben ist', () {
      final e = entry(t);
      expect(e.isEmpty, isTrue);
      e.mood = Mood.gut;
      expect(e.isEmpty, isFalse);
    });

    test('kennt Tag und Tageszeit', () {
      expect(entry(t.add(const Duration(hours: 8))).day, t);
      expect(entry(t.add(const Duration(hours: 8))).dayPart, 'Morgens');
      expect(entry(t.add(const Duration(hours: 12))).dayPart, 'Mittags');
      expect(entry(t.add(const Duration(hours: 15))).dayPart, 'Nachmittags');
      expect(entry(t.add(const Duration(hours: 20))).dayPart, 'Abends');
      expect(entry(t.add(const Duration(hours: 2))).dayPart, 'Nachts');
    });

    test('ueberlebt Speichern und Laden', () {
      final e = entry(
        t.add(const Duration(hours: 20, minutes: 15)),
        mood: Mood.naja,
        symptoms: {'uebelkeit': 2},
      );
      final back = WellbeingEntry.fromJson(e.toJson());
      expect(back.at, e.at);
      expect(back.mood, Mood.naja);
      expect(back.symptoms, {'uebelkeit': 2});
    });

    test('wirft kaputte Werte aus dem Bestand weg', () {
      final back = WellbeingEntry.fromJson({
        'id': 'x',
        'at': t.toIso8601String(),
        'mood': 'gibtsnicht',
        'symptoms': {'kopfschmerzen': 99, 'uebelkeit': 'viel', 'koliken': 2},
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(back.mood, isNull);
      expect(back.symptoms, {'koliken': 2});
    });
  });

  group('Mehrere Eintraege je Notiz', () {
    test('stehen nach der Uhrzeit, morgens zuerst', () {
      final state = stateWith(wellbeing: [
        entry(t.add(const Duration(hours: 20)), id: 'abends', mood: Mood.gut),
        entry(t.add(const Duration(hours: 7)), id: 'morgens', mood: Mood.naja),
        entry(t.add(const Duration(hours: 13)), id: 'mittags'),
      ]);
      expect(
        state.wellbeingOfNote(noteId).map((e) => e.id),
        ['morgens', 'mittags', 'abends'],
      );
    });

    test('zwei Notizen desselben Tages fuehren getrennte Listen', () {
      // Der Punkt der Zuordnung: was in der einen Notiz steht, steht nicht
      // in der anderen.
      final state = stateWith(
        notes: [note(t), note(t, id: 'n2', title: 'Zweite')],
        wellbeing: [
          entry(t.add(const Duration(hours: 7)), id: 'erste', mood: Mood.gut),
          entry(t.add(const Duration(hours: 9)),
              id: 'zweite', note: 'n2', mood: Mood.naja),
        ],
      );

      expect(state.wellbeingOfNote(noteId).map((e) => e.id), ['erste']);
      expect(state.wellbeingOfNote('n2').map((e) => e.id), ['zweite']);
    });

    test('Speichern ersetzt nur den einen Eintrag', () {
      final morgens =
          entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.schlecht);
      final state = stateWith(wellbeing: [
        morgens,
        entry(t.add(const Duration(hours: 20)), id: 'b', mood: Mood.gut),
      ]);

      morgens.mood = Mood.okay;
      state.saveWellbeing(morgens);

      expect(state.wellbeingOfNote(noteId), hasLength(2));
      expect(state.wellbeingOfNote(noteId).first.mood, Mood.okay);
      expect(state.wellbeingOfNote(noteId).last.mood, Mood.gut);
    });

    test('ein leer gemachter Eintrag wird nicht aufbewahrt', () {
      final e = entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.gut);
      final state = stateWith(wellbeing: [e]);

      e.mood = null;
      state.saveWellbeing(e);

      // Sonst saehe ein Zeitpunkt, an dem man den Editor nur aufgemacht hat,
      // aus wie ein eingetragenes Befinden.
      expect(state.wellbeingOfNote(noteId), isEmpty);
    });

    test('der Entwurf legt noch nichts an und kennt Notiz und Tag', () {
      final state = stateWith();
      final gestern = t.subtract(const Duration(days: 1));
      final draft = state.newWellbeingDraft(gestern, noteId: noteId);

      expect(state.wellbeing, isEmpty);
      expect(draft.day, gestern);
      expect(draft.noteId, noteId);
    });

    test('mit der Notiz geht ihr Befinden', () {
      final state = stateWith(
        notes: [note(t), note(t, id: 'n2', title: 'Zweite')],
        wellbeing: [
          entry(t.add(const Duration(hours: 7)), id: 'erste'),
          entry(t.add(const Duration(hours: 9)), id: 'zweite', note: 'n2'),
        ],
      );

      state.deleteNote(state.notes.firstWhere((n) => n.id == noteId));

      expect(state.wellbeing.map((e) => e.id), ['zweite']);
    });

    test('heimatlose Eintraege bekommen die aelteste Notiz ihres Tages', () {
      // Aus der Fassung, in der das Befinden noch am Tag hing.
      final aeltere = note(t, id: 'alt')..updatedAt = DateTime(2026, 1, 1);
      final state = stateWith(
        notes: [note(t, id: 'neu'), aeltere],
        wellbeing: [
          entry(t.add(const Duration(hours: 7)), id: 'a', note: null),
          // Ein Tag ohne Notiz: der Eintrag bleibt liegen, statt
          // weggeworfen zu werden.
          entry(t.subtract(const Duration(days: 3)), id: 'b', note: null),
        ],
      );

      state.adoptOrphanWellbeing();

      expect(state.wellbeingOfNote('alt').map((e) => e.id), ['a']);
      expect(state.wellbeingOfNote('neu'), isEmpty);
      expect(state.wellbeing.firstWhere((e) => e.id == 'b').noteId, isNull);
    });
  });

  group('Eigene Symptome', () {
    test('kommen hinter die zehn festen', () {
      final state = stateWith();
      final own = state.addCustomSymptom('Migräne');

      expect(state.symptomCatalog.length, fixedSymptoms.length + 1);
      expect(state.symptomCatalog.last.id, own.id);
      expect(state.symptomCatalog.first.name, 'Kopfschmerzen');
      expect(own.custom, isTrue);
    });

    test('ein Name, den es schon gibt, legt nichts Neues an', () {
      final state = stateWith();
      final first = state.addCustomSymptom('Migräne');
      final again = state.addCustomSymptom('  migräne ');

      expect(again.id, first.id);
      expect(state.customSymptoms, hasLength(1));
      // Auch gegen die festen: zwei Zeilen "Übelkeit" waeren Unsinn.
      expect(state.addCustomSymptom('Übelkeit').id, 'uebelkeit');
      expect(state.customSymptoms, hasLength(1));
    });

    test('Loeschen nimmt die Werte aus allen Eintraegen mit', () {
      final state = stateWith();
      final own = state.addCustomSymptom('Migräne');
      state.saveWellbeing(entry(
        t.add(const Duration(hours: 9)),
        id: 'a',
        symptoms: {own.id: 4, 'koliken': 2},
      ));
      state.saveWellbeing(entry(
        t.add(const Duration(hours: 21)),
        id: 'b',
        symptoms: {own.id: 1},
      ));
      expect(state.wellbeingUsageOf(own.id), 2);

      state.deleteCustomSymptom(own.id);

      expect(state.symptomById(own.id), isNull);
      expect(state.wellbeingOfNote(noteId).single.symptoms, {'koliken': 2});
    });
  });

  group('Auf dem Bildschirm', () {
    Future<AppState> pump(WidgetTester tester, AppState state) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(560, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(JoeApp(state: state));
      await tester.pumpAndSettle();
      return state;
    }

    /// Von der ersten Seite in die Notiz [title] und dort die Kategorie
    /// "Befinden" aufklappen.
    Future<void> openCategory(WidgetTester tester, String title) async {
      await tester.tap(find.text('Notizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Befinden'));
      await tester.pumpAndSettle();
    }

    testWidgets('die Kategorie steht in der Notiz und ist zuerst leer',
        (tester) async {
      await pump(tester, stateWith(notes: [note(t)]));
      await tester.tap(find.text('Notizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();

      expect(find.text('Befinden'), findsOneWidget);
      expect(find.text('nichts eingetragen'), findsOneWidget);
    });

    testWidgets('ein Eintrag entsteht mit Uhrzeit', (tester) async {
      final state = await pump(tester, stateWith(notes: [note(t)]));
      await openCategory(tester, 'Montag');

      await tester.tap(find.text('Befinden eintragen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gut'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final entries = state.wellbeingOfNote(noteId);
      expect(entries, hasLength(1));
      expect(entries.single.mood, Mood.gut);
      expect(entries.single.day, t);
      // Die Zeile in der Kategorie nennt die Tageszeit.
      expect(find.text(entries.single.dayPart), findsOneWidget);
    });

    testWidgets('eine neue Notiz entsteht mit ihrem ersten Eintrag',
        (tester) async {
      // Ein Befinden braucht eine Notiz, an der es haengt – in einer noch
      // leeren gibt es die noch nicht.
      final state = await pump(tester, stateWith());
      await tester.tap(find.text('Notizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Neue Notiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Befinden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Befinden eintragen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(state.notes, hasLength(1));
      expect(state.wellbeingOfNote(state.notes.single.id), hasLength(1));
    });

    testWidgets('der Knopf steht unter der Liste, nicht auf ihr',
        (tester) async {
      // Am Geraet fiel auf: der Tipp auf "Weiterer Eintrag" landete auf der
      // Zeile darueber. Die Kategorie hatte eine eigene Scroll-Liste, und
      // deren Kinder meldeten ihre Tippflaechen an der alten Stelle, sobald
      // die Liste wuchs. Seitdem scrollt die Seite als Ganzes – hier steht,
      // dass es dabei bleibt.
      await pump(
        tester,
        stateWith(
          notes: [note(t)],
          wellbeing: [
            entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.gut),
          ],
        ),
      );
      await openCategory(tester, 'Montag');

      expect(
        find.descendant(
          of: find.byType(NoteWellbeingSection),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: 'keine Liste in der Liste',
      );
      expect(
        tester.getRect(find.text('Weiterer Eintrag')).top,
        greaterThan(tester.getRect(find.text('Morgens')).bottom),
      );
    });

    testWidgets('mehrere Eintraege in einer Notiz stehen nebeneinander',
        (tester) async {
      final state = await pump(
        tester,
        stateWith(
          notes: [note(t)],
          wellbeing: [
            entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.schlecht),
            entry(t.add(const Duration(hours: 20)), id: 'b', mood: Mood.gut),
          ],
        ),
      );
      await openCategory(tester, 'Montag');

      expect(find.text('2 Einträge'), findsOneWidget);
      expect(find.text('Morgens'), findsOneWidget);
      expect(find.text('Abends'), findsOneWidget);
      expect(find.text('Schlecht'), findsOneWidget);
      expect(find.text('Gut'), findsOneWidget);

      // Und ein dritter kommt dazu, statt einen der beiden zu ersetzen.
      await tester.tap(find.text('Weiterer Eintrag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(state.wellbeingOfNote(noteId), hasLength(3));
    });

    testWidgets('die zweite Notiz desselben Tages bleibt leer',
        (tester) async {
      // Eingetragen wurde es in der ersten – dort steht es auch nur.
      await pump(
        tester,
        stateWith(
          notes: [note(t), note(t, id: 'n2', title: 'Zweite')],
          wellbeing: [
            entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.naja),
          ],
        ),
      );

      await openCategory(tester, 'Zweite');
      expect(find.text('Naja'), findsNothing);
      expect(find.text('nichts eingetragen'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openCategory(tester, 'Montag');
      expect(find.text('Naja'), findsOneWidget);
    });

    testWidgets('die Loeschkarte sagt an, dass das Befinden mitgeht',
        (tester) async {
      final state = await pump(
        tester,
        stateWith(
          notes: [note(t), note(t, id: 'n2', title: 'Zweite')],
          wellbeing: [
            entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.naja),
            entry(t.add(const Duration(hours: 9)), id: 'b', mood: Mood.gut),
          ],
        ),
      );
      await tester.tap(find.text('Notizen'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('2 Befinden-Einträge gehen mit'),
        findsOneWidget,
      );

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(state.notes.map((n) => n.id), ['n2']);
      expect(state.wellbeing, isEmpty);
    });

    testWidgets('die Notizliste zeigt, an welchem Tag etwas haengt',
        (tester) async {
      await pump(
        tester,
        stateWith(
          notes: [note(t)],
          wellbeing: [
            entry(t.add(const Duration(hours: 7)), id: 'a', mood: Mood.gut),
            entry(t.add(const Duration(hours: 20)), id: 'b', mood: Mood.naja),
          ],
        ),
      );
      await tester.tap(find.text('Notizen'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('die Skala laesst sich auch wieder zuruecknehmen',
        (tester) async {
      final state = await pump(tester, stateWith(notes: [note(t)]));
      await openCategory(tester, 'Montag');
      await tester.tap(find.text('Befinden eintragen'));
      await tester.pumpAndSettle();

      Finder dot(int index) => find.descendant(
            of: find.ancestor(
              of: find.text('Kopfschmerzen'),
              matching: find.byType(Row),
            ).first,
            matching: find.byType(GestureDetector),
          ).at(index);

      await tester.tap(dot(2));
      await tester.pumpAndSettle();
      expect(find.text('deutlich'), findsOneWidget);

      // Noch einmal auf denselben Punkt: das Symptom ist wieder weg.
      await tester.tap(dot(2));
      await tester.pumpAndSettle();
      expect(find.text('deutlich'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(state.wellbeing, isEmpty);
    });

    testWidgets('ein eigenes Symptom anlegen und wieder loeschen',
        (tester) async {
      final state = await pump(tester, stateWith(notes: [note(t)]));
      await openCategory(tester, 'Montag');
      await tester.tap(find.text('Befinden eintragen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eigenes Symptom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Migraene');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Migraene'), findsOneWidget);
      expect(state.customSymptoms, hasLength(1));

      // Langer Druck auf den Namen fuehrt auf dieselbe Loeschkarte wie
      // ueberall sonst.
      await tester.longPress(find.text('Migraene'));
      await tester.pumpAndSettle();
      expect(find.text('Symptom löschen?'), findsOneWidget);
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(state.customSymptoms, isEmpty);
      expect(find.text('Migraene'), findsNothing);
    });
  });
}
