import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Die Wiederholungslogik: Wochenskala, jaehrlich, alle X Tage, die Dauer
/// von Aufgaben und Terminen und das Umschreiben alter Bestaende.
void main() {
  // toggleTask speichert nebenbei; ohne Attrappe liefe das ins Leere.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Task weekly(Set<int> days, DateTime start) => Task(
        id: 'w',
        title: 'x',
        recurrence: RecurrenceType.weekly,
        weekdays: days,
        startDate: start,
      );

  group('Wochenskala', () {
    test('Mo+Mi+Fr trifft genau diese Tage', () {
      // 2.7.2026 ist ein Donnerstag – der Start selbst ist kein gewaehlter Tag.
      final t = weekly({1, 3, 5}, DateTime(2026, 7, 2));
      // Vor dem Start nie, auch nicht an einem passenden Wochentag.
      expect(t.occursOn(DateTime(2026, 6, 29)), isFalse); // Mo
      expect(t.occursOn(DateTime(2026, 7, 1)), isFalse); // Mi
      // Der Starttag zaehlt nur, wenn er einer der Tage ist.
      expect(t.occursOn(DateTime(2026, 7, 2)), isFalse); // Do
      expect(t.occursOn(DateTime(2026, 7, 3)), isTrue); // Fr
      expect(t.occursOn(DateTime(2026, 7, 4)), isFalse); // Sa
      expect(t.occursOn(DateTime(2026, 7, 5)), isFalse); // So
      expect(t.occursOn(DateTime(2026, 7, 6)), isTrue); // Mo
      expect(t.occursOn(DateTime(2026, 7, 7)), isFalse); // Di
      expect(t.occursOn(DateTime(2026, 7, 8)), isTrue); // Mi
    });

    test('alle sieben = jeden Tag ab Start, nicht davor', () {
      final t = weekly(allWeekdays, DateTime(2026, 7, 1));
      expect(t.occursOn(DateTime(2026, 6, 30)), isFalse);
      for (var i = 0; i < 14; i++) {
        final day = addCalendarDays(DateTime(2026, 7, 1), i);
        expect(t.occursOn(day), isTrue, reason: dateKey(day));
      }
    });

    test('ungueltige Tage fallen weg, ohne Tag gilt der des Starts', () {
      expect(weekly({0, 3, 9}, DateTime(2026, 7, 1)).weekdays, {3});
      // 1.7.2026 ist ein Mittwoch.
      expect(weekly({}, DateTime(2026, 7, 1)).weekdays, {3});
    });
  });

  group('Jaehrlich', () {
    Task yearly(DateTime start) => Task(
          id: 'j',
          title: 'x',
          recurrence: RecurrenceType.yearly,
          startDate: start,
        );

    test('am selben Tag im naechsten Jahr', () {
      final t = yearly(DateTime(2026, 3, 14));
      expect(t.occursOn(DateTime(2026, 3, 14)), isTrue);
      expect(t.occursOn(DateTime(2027, 3, 14)), isTrue);
      expect(t.occursOn(DateTime(2027, 3, 15)), isFalse);
      expect(t.occursOn(DateTime(2027, 4, 14)), isFalse);
      expect(t.occursOn(DateTime(2025, 3, 14)), isFalse);
    });

    test('am 29.2. begonnen: ohne Schalttag am 28.2.', () {
      final t = yearly(DateTime(2028, 2, 29));
      expect(t.occursOn(DateTime(2029, 2, 28)), isTrue);
      expect(t.occursOn(DateTime(2029, 3, 1)), isFalse);
      expect(t.occursOn(DateTime(2032, 2, 29)), isTrue);
      // Im Schaltjahr gilt der echte Tag, nicht zusaetzlich der 28.
      expect(t.occursOn(DateTime(2032, 2, 28)), isFalse);
    });
  });

  group('Alle X Tage', () {
    test('Sommerzeit verschiebt die Reihe nicht', () {
      // Am 29.3.2026 wird die Uhr vorgestellt. Mit dem alten
      // Duration.inDays lagen zwischen 28.3. und 30.3. nur 47 Stunden, also
      // "1 Tag" – die Reihe fiel dann auf den 31.3. statt auf den 30.3.
      // Das faellt nur auf, wenn der Rechner in einer Zeitzone mit
      // Umstellung laeuft; in UTC (CI) waere es nie aufgefallen.
      final t = Task(
        id: 'x',
        title: 'x',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 2,
        startDate: DateTime(2026, 3, 28),
      );
      expect(t.occursOn(DateTime(2026, 3, 30)), isTrue);
      expect(t.occursOn(DateTime(2026, 3, 31)), isFalse);
      expect(t.occursOn(DateTime(2026, 4, 1)), isTrue);
    });

    test('Kalendertage zaehlen ueber die Umstellung hinweg richtig', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(calendarDaysBetween(DateTime(2026, 3, 30), DateTime(2026, 3, 28)), -2);
      // Die Uhrzeit spielt keine Rolle, nur das Datum.
      expect(
        calendarDaysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 29, 1)),
        1,
      );
      expect(addCalendarDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
      expect(addCalendarDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });

  group('Beschriftung', () {
    final start = DateTime(2026, 7, 1);

    test('je Art', () {
      expect(Task(id: '1', title: 'x', startDate: start).recurrenceLabel,
          'Einmalig');
      expect(
        Task(
          id: '1',
          title: 'x',
          recurrence: RecurrenceType.monthly,
          startDate: start,
        ).recurrenceLabel,
        'Monatlich',
      );
      expect(
        Task(
          id: '1',
          title: 'x',
          recurrence: RecurrenceType.yearly,
          startDate: start,
        ).recurrenceLabel,
        'Jährlich',
      );
      expect(
        Task(
          id: '1',
          title: 'x',
          recurrence: RecurrenceType.everyXDays,
          intervalDays: 3,
          startDate: start,
        ).recurrenceLabel,
        'Alle 3 Tage',
      );
    });

    test('Wochenskala', () {
      expect(weekly(allWeekdays, start).recurrenceLabel, 'Täglich');
      expect(weekly({1, 2, 3, 4, 5}, start).recurrenceLabel, 'Werktags');
      expect(weekly({6, 7}, start).recurrenceLabel, 'Am Wochenende');
      expect(weekly({1}, start).recurrenceLabel, 'Jeden Montag');
      expect(weekly({7}, start).recurrenceLabel, 'Jeden Sonntag');
      // In Wochenfolge, egal in welcher Reihenfolge gewaehlt wurde.
      expect(weekly({5, 1, 3}, start).recurrenceLabel, 'Mo, Mi, Fr');
      expect(weekly({1, 2, 3, 4}, start).recurrenceLabel, 'Mo, Di, Mi, Do');
      expect(weekly({5, 6, 7}, start).recurrenceLabel, 'Fr, Sa, So');
    });
  });

  group('Dauer', () {
    // 14.9.2026 ist ein Montag.
    final montag = DateTime(2026, 9, 14);

    test('einmalig Mo bis Do: an jedem Tag faellig, einmal abgehakt', () {
      final t = Task(
        id: 'd',
        title: 'x',
        startDate: montag,
        spanDays: 3,
        startMinute: 12 * 60,
        endMinute: 18 * 60,
      );
      expect(t.hasDuration, isTrue);
      expect(t.occursOn(DateTime(2026, 9, 13)), isFalse); // So
      for (var i = 0; i <= 3; i++) {
        expect(t.occursOn(addCalendarDays(montag, i)), isTrue, reason: '+$i');
        expect(t.occurrenceStartFor(addCalendarDays(montag, i)), montag);
      }
      expect(t.occursOn(DateTime(2026, 9, 18)), isFalse); // Fr
      expect(t.lastDay, DateTime(2026, 9, 17));
      // Nur am ersten Tag beginnt sie.
      expect(t.startsOn(montag), isTrue);
      expect(t.startsOn(DateTime(2026, 9, 15)), isFalse);

      final state = AppState()..tasks = [t];
      state.toggleTask(t, DateTime(2026, 9, 16)); // am Mittwoch abgehakt
      for (var i = 0; i <= 3; i++) {
        expect(t.isCompletedOn(addCalendarDays(montag, i)), isTrue);
      }
    });

    test('Beginn und Ende einer Wiederholung', () {
      final t = Task(
        id: 'd',
        title: 'x',
        startDate: montag,
        spanDays: 3,
        startMinute: 12 * 60,
        endMinute: 18 * 60,
      );
      final span = t.spanOf(montag);
      expect(span.start, DateTime(2026, 9, 14, 12));
      expect(span.end, DateTime(2026, 9, 17, 18));

      // Ohne Uhrzeit: Mitternacht bis Mitternacht nach dem letzten Tag.
      final ohne = Task(id: 'o', title: 'x', startDate: montag, spanDays: 1);
      expect(ohne.hasDuration, isTrue);
      expect(ohne.spanOf(montag).start, montag);
      expect(ohne.spanOf(montag).end, DateTime(2026, 9, 16));
      expect(Task(id: 'k', title: 'x', startDate: montag).hasDuration, isFalse);
    });

    test('woechentlich Mo mit drei Tagen Dauer: Haken gilt je Woche', () {
      final t = Task(
        id: 'w',
        title: 'x',
        recurrence: RecurrenceType.weekly,
        weekdays: {1},
        startDate: montag,
        spanDays: 3,
      );
      final naechsterMo = DateTime(2026, 9, 21);
      final naechsterMi = DateTime(2026, 9, 23);
      expect(t.occurrenceStartFor(naechsterMi), naechsterMo);
      expect(t.occurrenceStartFor(DateTime(2026, 9, 25)), isNull); // Fr

      final state = AppState()..tasks = [t];
      state.toggleTask(t, naechsterMi);
      expect(t.completedDates, {dateKey(naechsterMo)});
      for (var i = 0; i <= 3; i++) {
        expect(t.isCompletedOn(addCalendarDays(naechsterMo, i)), isTrue);
        // Die Woche davor und die danach bleiben offen.
        expect(t.isCompletedOn(addCalendarDays(montag, i)), isFalse);
        expect(t.isCompletedOn(addCalendarDays(naechsterMo, 7 + i)), isFalse);
      }
      // Zuruecknehmen geht an jedem Tag der Spanne.
      state.toggleTask(t, DateTime(2026, 9, 24));
      expect(t.completedDates, isEmpty);
    });

    test('laengste Dauer ohne Ueberlappung', () {
      int max(RecurrenceType r, {Set<int> days = const {}, int every = 2}) =>
          Task.maxSpanDays(r, days, every);
      expect(max(RecurrenceType.weekly, days: {1, 3}), 1);
      expect(max(RecurrenceType.weekly, days: {1}), 6);
      expect(max(RecurrenceType.weekly, days: {1, 7}), 0);
      expect(max(RecurrenceType.weekly, days: allWeekdays), 0);
      expect(max(RecurrenceType.everyXDays, every: 3), 2);
      expect(max(RecurrenceType.monthly), 27);
      expect(max(RecurrenceType.yearly), 364);
      expect(max(RecurrenceType.none), 365);
    });

    test('ueber die Sommerzeit bleibt jeder Tag richtig', () {
      // 29.3.2026: Umstellung. Alle 4 Tage ab 28.3., zwei Tage Dauer.
      final t = Task(
        id: 's',
        title: 'x',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 4,
        startDate: DateTime(2026, 3, 28),
        spanDays: 1,
      );
      expect(t.occursOn(DateTime(2026, 3, 28)), isTrue);
      expect(t.occursOn(DateTime(2026, 3, 29)), isTrue);
      expect(t.occursOn(DateTime(2026, 3, 30)), isFalse);
      expect(t.occursOn(DateTime(2026, 3, 31)), isFalse);
      expect(t.occursOn(DateTime(2026, 4, 1)), isTrue);
      expect(t.occurrenceStartFor(DateTime(2026, 4, 2)), DateTime(2026, 4, 1));
    });

    group('Termin', () {
      Appointment termin({DateTime? end}) => Appointment(
            id: 'a',
            title: 'x',
            when: DateTime(2026, 9, 14, 12),
            end: end,
          );

      test('14.9. 12:00 bis 17.9. 18:00 steht an allen vier Tagen', () {
        final a = termin(end: DateTime(2026, 9, 17, 18));
        expect(a.coversDay(DateTime(2026, 9, 13)), isFalse);
        for (var i = 0; i <= 3; i++) {
          expect(a.coversDay(addCalendarDays(montag, i)), isTrue);
        }
        expect(a.coversDay(DateTime(2026, 9, 18)), isFalse);
        expect(a.lastDay, DateTime(2026, 9, 17));
      });

      test('ein Ende um Mitternacht gehoert nicht auf den Folgetag', () {
        final a = termin(end: DateTime(2026, 9, 17));
        expect(a.lastDay, DateTime(2026, 9, 16));
        expect(a.coversDay(DateTime(2026, 9, 16)), isTrue);
        expect(a.coversDay(DateTime(2026, 9, 17)), isFalse);
      });

      test('ein Ende vor oder am Start zaehlt nicht', () {
        for (final end in [
          DateTime(2026, 9, 14, 12),
          DateTime(2026, 9, 13, 18),
          null,
        ]) {
          final a = termin(end: end);
          expect(a.lastDay, montag, reason: '$end');
          expect(a.coversDay(montag), isTrue);
          expect(a.coversDay(DateTime(2026, 9, 15)), isFalse);
        }
      });
    });

    test('JSON-Rundreise beider Klassen', () {
      final t = Task(
        id: 'd',
        title: 'x',
        recurrence: RecurrenceType.weekly,
        weekdays: {1},
        startDate: montag,
        spanDays: 3,
        startMinute: 12 * 60,
        endMinute: 18 * 60,
      );
      final back = Task.fromJson(t.toJson());
      expect(back.spanDays, 3);
      expect(back.startMinute, 720);
      expect(back.endMinute, 1080);

      final a = Appointment(
        id: 'a',
        title: 'x',
        when: DateTime(2026, 9, 14, 12),
        end: DateTime(2026, 9, 17, 18),
      );
      expect(Appointment.fromJson(a.toJson()).end, DateTime(2026, 9, 17, 18));
    });

    test('ohne die neuen Schluessel laedt alles wie vorher', () {
      final t = Task.fromJson({
        'id': 'alt',
        'title': 'Alt',
        'recurrence': 'none',
        'startDate': '2026-09-14',
      });
      expect(t.spanDays, 0);
      expect(t.startMinute, isNull);
      expect(t.endMinute, isNull);
      expect(t.hasDuration, isFalse);
      // Ohne Dauer schreibt eine Aufgabe auch keine Schluessel dafuer.
      expect(t.toJson().keys,
          isNot(anyElement(isIn(['spanDays', 'startMinute', 'endMinute']))));

      final a = Appointment.fromJson({
        'id': 'alt',
        'title': 'Alt',
        'when': '2026-09-14T12:00:00.000',
      });
      expect(a.end, isNull);
      expect(a.toJson().containsKey('end'), isFalse);
    });

    test('unbrauchbare Werte heissen "keine Dauer"', () {
      Task load(Map<String, dynamic> extra) => Task.fromJson({
            'id': 'k',
            'title': 'x',
            'recurrence': 'none',
            'startDate': '2026-09-14',
            ...extra,
          });
      expect(load({'spanDays': -2}).spanDays, 0);
      expect(load({'spanDays': 'drei'}).spanDays, 0);
      // Eine Riesenzahl wird gedeckelt statt zur Endlosschleife.
      expect(load({'spanDays': 1 << 40}).spanDays, Task.maxStoredSpanDays);
      // Eine Uhrzeit allein sagt nichts – beide fallen weg.
      final halb = load({'startMinute': 720});
      expect(halb.startMinute, isNull);
      expect(halb.endMinute, isNull);
      final kaputt = load({'startMinute': 720, 'endMinute': 5000});
      expect(kaputt.startMinute, isNull);
      expect(kaputt.endMinute, isNull);

      Appointment termin(Object? end) => Appointment.fromJson({
            'id': 'a',
            'title': 'x',
            'when': '2026-09-14T12:00:00.000',
            'end': end,
          });
      expect(termin('2026-09-13T12:00:00.000').end, isNull);
      expect(termin('morgen').end, isNull);
      expect(termin(42).end, isNull);
    });
  });

  group('Formatierung', () {
    test('Spannen', () {
      expect(formatHm(DateTime(2026, 9, 14, 9, 5)), '09:05');
      expect(
        formatSpan(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 18)),
        '12:00 – 18:00 Uhr',
      );
      expect(
        formatSpan(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 17, 18)),
        'Mo, 14. Sep 12:00 – Do, 17. Sep 18:00',
      );
    });
  });

  group('JSON', () {
    Map<String, dynamic> stored(String recurrence, {Object? weekdays}) => {
          'id': 'alt',
          'title': 'Alt',
          'recurrence': recurrence,
          'startDate': '2026-07-01', // ein Mittwoch
          'weekdays': ?weekdays,
        };

    test('Rundreise mit Wochentagen', () {
      final t = weekly({5, 1, 3}, DateTime(2026, 7, 1));
      final json = t.toJson();
      expect(json['weekdays'], [1, 3, 5]);
      final back = Task.fromJson(json);
      expect(back.recurrence, RecurrenceType.weekly);
      expect(back.weekdays, {1, 3, 5});
    });

    test('nur woechentliche Aufgaben schreiben Wochentage', () {
      final t = Task(
        id: '1',
        title: 'x',
        recurrence: RecurrenceType.yearly,
        startDate: DateTime(2026, 7, 1),
      );
      expect(t.toJson().containsKey('weekdays'), isFalse);
      expect(Task.fromJson(t.toJson()).recurrence, RecurrenceType.yearly);
    });

    test('Altbestand "daily" wird woechentlich an allen Tagen', () {
      final back = Task.fromJson(stored('daily'));
      expect(back.recurrence, RecurrenceType.weekly);
      expect(back.weekdays, allWeekdays);
      expect(back.recurrenceLabel, 'Täglich');
    });

    test('Altbestand "weekly" ohne Tage behaelt den Wochentag des Starts', () {
      final back = Task.fromJson(stored('weekly'));
      expect(back.recurrence, RecurrenceType.weekly);
      expect(back.weekdays, {3});
      expect(back.occursOn(DateTime(2026, 7, 8)), isTrue);
      expect(back.occursOn(DateTime(2026, 7, 9)), isFalse);
    });

    test('Fremdkoerper in den Wochentagen fallen still weg', () {
      final back = Task.fromJson(stored('weekly', weekdays: [0, 3, 'x', 9]));
      expect(back.weekdays, {3});
      // Kein Listentyp: wie ohne Angabe.
      expect(Task.fromJson(stored('weekly', weekdays: 'Mo')).weekdays, {3});
    });

    test('unbekannte Art heisst einmalig', () {
      expect(Task.fromJson(stored('stuendlich')).recurrence,
          RecurrenceType.none);
    });
  });
}
