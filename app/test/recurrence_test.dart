import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Die Wiederholungslogik: Wochenskala, jaehrlich, alle X Tage und das
/// Umschreiben alter Bestaende.
void main() {
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
