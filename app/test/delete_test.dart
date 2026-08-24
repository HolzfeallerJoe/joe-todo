import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Geloescht wird in Joe an drei Stellen – Aufgabe, Termin, Notiz – und seit
/// "Teil 2" ueberall gleich: langer Druck, dasselbe Blatt, dieselbe Karte von
/// unten. Diese Tests halten die drei Wege zusammen; auseinanderlaufen war
/// vorher genau das Problem.
void main() {
  const screenHeight = 800.0;

  Future<AppState> pump(
    WidgetTester tester, {
    List<Task> tasks = const [],
    List<Appointment> appointments = const [],
    List<Note> notes = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, screenHeight);
    addTearDown(tester.view.reset);

    final state = AppState()
      ..tasks = [...tasks]
      ..appointments = [...appointments]
      ..notes = [...notes]
      ..showPet = false;
    await tester.pumpWidget(JoeApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  /// Von der ersten Seite in einen Bereich wechseln.
  Future<void> open(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  Future<void> longPress(WidgetTester tester, String label) async {
    await tester.longPress(find.text(label));
    await tester.pumpAndSettle();
  }

  group('Der Weg zum Loeschen', () {
    testWidgets('Aufgabe: langer Druck, Blatt, Karte, weg', (tester) async {
      final state = await pump(
        tester,
        tasks: [Task(id: '1', title: 'Blumen gießen', startDate: today())],
      );

      await longPress(tester, 'Blumen gießen');
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(find.text('Aufgabe löschen?'), findsOneWidget);
      expect(find.text('Das lässt sich nicht rückgängig machen.'),
          findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(state.tasks, isEmpty);
    });

    testWidgets('Termin: derselbe Griff, dasselbe Blatt', (tester) async {
      final state = await pump(
        tester,
        appointments: [
          Appointment(
            id: 'a',
            title: 'Zahnarzt',
            when: today().add(const Duration(days: 1, hours: 9)),
          ),
        ],
      );
      await open(tester, 'Termine');

      await longPress(tester, 'Zahnarzt');
      expect(find.text('Bearbeiten'), findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Termin löschen?'), findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(state.appointments, isEmpty);
    });

    testWidgets('Notiz: auch aus der Liste heraus', (tester) async {
      // Vorher ging das nur ueber den Papierkorb im Editor.
      final state = await pump(
        tester,
        notes: [
          Note(
            id: 'n',
            title: 'Einkaufsliste',
            body: '',
            updatedAt: DateTime.now(),
          ),
        ],
      );
      await open(tester, 'Notizen');

      await longPress(tester, 'Einkaufsliste');
      expect(find.text('Bearbeiten'), findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Notiz löschen?'), findsOneWidget);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(state.notes, isEmpty);
    });
  });

  group('Die Karte selbst', () {
    testWidgets('kommt von unten und fuellt das untere Drittel',
        (tester) async {
      await pump(
        tester,
        tasks: [Task(id: '1', title: 'Blumen gießen', startDate: today())],
      );
      await longPress(tester, 'Blumen gießen');
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.text('Aufgabe löschen?'));
      // Die Frage steht in der unteren Haelfte, nicht mitten auf dem Bild.
      expect(card.top, greaterThan(screenHeight / 2));

      // Und die Karte selbst reicht ueber das untere Drittel.
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.height, greaterThanOrEqualTo(screenHeight / 3));
      expect(sheet.bottom, closeTo(screenHeight, 1));
    });

    testWidgets('Abbrechen laesst den Eintrag stehen', (tester) async {
      final state = await pump(
        tester,
        tasks: [Task(id: '1', title: 'Blumen gießen', startDate: today())],
      );

      await longPress(tester, 'Blumen gießen');
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(state.tasks, hasLength(1));
      expect(find.text('Blumen gießen'), findsOneWidget);
    });

    testWidgets('Wegtippen neben der Karte loescht nicht', (tester) async {
      // Ein Blatt geht auch zu, indem man daneben tippt – das darf nicht
      // als "ja, loeschen" durchgehen.
      final state = await pump(
        tester,
        tasks: [Task(id: '1', title: 'Blumen gießen', startDate: today())],
      );

      await longPress(tester, 'Blumen gießen');
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(280, 40));
      await tester.pumpAndSettle();

      expect(state.tasks, hasLength(1));
    });

    testWidgets('sie nennt den Eintrag beim Namen', (tester) async {
      await pump(
        tester,
        tasks: [Task(id: '1', title: 'Blumen gießen', startDate: today())],
      );

      await longPress(tester, 'Blumen gießen');
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      // Einmal in der Karte – die Liste dahinter ist vom Blatt verdeckt,
      // steht aber weiter im Baum.
      expect(find.text('Blumen gießen'), findsNWidgets(2));
    });
  });
}
