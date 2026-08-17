import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/home_widget.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Was die Widgets zeigen, rechnet die App aus – das Android-Widget sucht
/// sich aus dem Schnappschuss nur den Tag heraus. Also gehoert alles
/// Interessante hierher und laeuft ohne Telefon.
void main() {
  // Ein fester Bezugspunkt, damit die Erwartungen nicht mit der Uhr wandern.
  final now = DateTime(2026, 8, 13, 10, 0);
  final heute = dateOnly(now);

  AppState stateWith({
    List<Task> tasks = const [],
    List<Appointment> appointments = const [],
    List<Note> notes = const [],
  }) {
    final state = AppState();
    state.tasks = [...tasks];
    state.appointments = [...appointments];
    state.notes = [...notes];
    return state;
  }

  Map<String, dynamic> snapshotOf(AppState state) =>
      buildWidgetSnapshot(state, now: now);

  Map<String, dynamic>? dayOf(Map<String, dynamic> snapshot, DateTime day) =>
      (snapshot['days'] as Map<String, dynamic>)[dateKey(day)]
          as Map<String, dynamic>?;

  group('Zeitraum', () {
    test('reicht vom Monatsersten bis über den Horizont', () {
      final snapshot = snapshotOf(stateWith());
      expect(snapshot['from'], dateKey(DateTime(2026, 8, 1)));
      expect(
        snapshot['to'],
        dateKey(heute.add(const Duration(days: widgetHorizonDays))),
      );
    });

    test('laesst leere Tage weg', () {
      final snapshot = snapshotOf(
        stateWith(
          appointments: [
            Appointment(
              id: 'a1',
              title: 'Zahnarzt',
              when: heute.add(const Duration(days: 2, hours: 9)),
            ),
          ],
        ),
      );
      final days = snapshot['days'] as Map<String, dynamic>;
      expect(days.keys, [dateKey(heute.add(const Duration(days: 2)))]);
    });

    test('ist als JSON verschickbar', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [Task(id: 't1', title: 'Blumen gießen', startDate: heute)],
          appointments: [
            Appointment(
              id: 'a1',
              title: 'Zahnarzt',
              when: heute.add(const Duration(hours: 9)),
            ),
          ],
        ),
      );
      final again = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      expect(again['version'], widgetSnapshotVersion);
      expect((again['theme'] as Map)['paper'], matches(r'^#[0-9a-f]{8}$'));
    });

    test('ist bei unverändertem Stand bytegleich für die Deduplizierung', () {
      final state = stateWith(
        tasks: [Task(id: 't1', title: 'Blumen gießen', startDate: heute)],
      );
      final first = jsonEncode(buildWidgetSnapshot(state, now: now));
      final second = jsonEncode(buildWidgetSnapshot(state, now: now));

      expect(second, first);
      expect(first, isNot(contains('pushedAt')));
    });
  });

  group('Ein Tag', () {
    test('traegt Aufgaben mit Farbe und Haken', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            Task(
              id: 't1',
              title: 'Blumen gießen',
              startDate: heute,
              recurrence: RecurrenceType.daily,
              completedDates: {dateKey(heute)},
            ),
            Task(id: 't2', title: 'Wochenputz', startDate: heute),
          ],
        ),
      );
      final day = dayOf(snapshot, heute)!;
      final tasks = day['tasks'] as List<dynamic>;
      // Offenes zuerst, Abgehaktes danach.
      expect(tasks.map((t) => t['title']), ['Wochenputz', 'Blumen gießen']);
      expect(tasks.last['done'], isTrue);
      expect(tasks.first['color'], matches(r'^#[0-9a-f]{8}$'));
    });

    test('zaehlt offene Aufgaben wie das Dashboard, Stufe 3 eingeschlossen', () {
      final state = stateWith(
        tasks: [
          Task(
            id: 't1',
            title: 'Wichtig',
            startDate: heute,
            priority: Priority.hoch,
          ),
          Task(
            id: 't2',
            title: 'Leise',
            startDate: heute,
            priority: Priority.niedrig,
          ),
        ],
      );
      final day = dayOf(snapshotOf(state), heute)!;
      expect(day['open'], 2);
      expect(day['taskCount'], 2);
      // Die leise Aufgabe zaehlt mit, steht in der Liste aber ganz unten.
      expect((day['tasks'] as List).last['title'], 'Leise');
      expect(day['open'], state.openTodayCount());
    });

    test('nimmt Termine mit Uhrzeit als Minute im Tag', () {
      final snapshot = snapshotOf(
        stateWith(
          appointments: [
            Appointment(
              id: 'a1',
              title: 'Kaffee mit Anna',
              when: heute.add(const Duration(days: 1, hours: 15, minutes: 30)),
            ),
          ],
        ),
      );
      final day = dayOf(snapshot, heute.add(const Duration(days: 1)))!;
      expect((day['appointments'] as List).single['minute'], 15 * 60 + 30);
    });

    test('merkt sich Notizen', () {
      final snapshot = snapshotOf(
        stateWith(
          notes: [
            Note(
              id: 'n1',
              title: 'Gedanke',
              body: '',
              updatedAt: now,
              date: heute,
            ),
          ],
        ),
      );
      expect(dayOf(snapshot, heute)!['note'], isTrue);
    });

    test('merkt sich Feiertage – die rechnet das Widget nicht selbst', () {
      final tag = DateTime(2026, 10, 3); // Tag der Deutschen Einheit
      final snapshot = buildWidgetSnapshot(
        stateWith(),
        now: DateTime(2026, 9, 20, 10, 0),
      );
      final day =
          (snapshot['days'] as Map<String, dynamic>)[dateKey(tag)] as Map;
      expect(day['holiday'], 'Tag der Deutschen Einheit');
    });

    test('deckelt lange Listen und sagt die volle Zahl daneben', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            for (var i = 0; i < widgetEntriesPerDay + 5; i++)
              Task(id: 't$i', title: 'Aufgabe $i', startDate: heute),
          ],
        ),
      );
      final day = dayOf(snapshot, heute)!;
      expect((day['tasks'] as List), hasLength(widgetEntriesPerDay));
      expect(day['taskCount'], widgetEntriesPerDay + 5);
    });
  });

  group('Vorausgerechnete Tage', () {
    test('kennen die Wiederholung, damit das Widget sie nicht kennen muss', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            Task(
              id: 't1',
              title: 'Blumen gießen',
              startDate: heute,
              recurrence: RecurrenceType.everyXDays,
              intervalDays: 3,
            ),
          ],
        ),
      );
      for (final offset in [0, 3, 6, 9]) {
        expect(
          dayOf(snapshot, heute.add(Duration(days: offset))),
          isNotNull,
          reason: 'Tag +$offset gehoert zur Reihe',
        );
      }
      for (final offset in [1, 2, 4]) {
        expect(dayOf(snapshot, heute.add(Duration(days: offset))), isNull);
      }
    });

    test('tragen eine ueberfaellige Aufgabe weiter, bis sie erledigt ist', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            Task(
              id: 't1',
              title: 'Liegengeblieben',
              startDate: heute.subtract(const Duration(days: 5)),
            ),
          ],
        ),
      );
      expect((dayOf(snapshot, heute)!['tasks'] as List), hasLength(1));
      expect(
        (dayOf(snapshot, heute.add(const Duration(days: 7)))!['tasks'] as List),
        hasLength(1),
      );
    });

    test('sagen dazu, was nur mitgeschleppt ist', () {
      // Ohne diese Angabe stuende eine heute offene Aufgabe im Widget auch
      // unter "Demnaechst" – an jedem einzelnen kommenden Tag.
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            Task(
              id: 't1',
              title: 'Liegengeblieben',
              startDate: heute.subtract(const Duration(days: 5)),
            ),
            Task(
              id: 't2',
              title: 'Wöchentlich',
              startDate: heute,
              recurrence: RecurrenceType.weekly,
            ),
          ],
        ),
      );
      final morgen = dayOf(snapshot, heute.add(const Duration(days: 1)))!;
      expect(
        {for (final t in morgen['tasks'] as List) t['title']: t['over']},
        {'Liegengeblieben': true},
      );
      // An ihrem eigenen Tag ist keine der beiden mitgeschleppt.
      final inEinerWoche = dayOf(snapshot, heute.add(const Duration(days: 7)))!;
      expect(
        (inEinerWoche['tasks'] as List).firstWhere(
          (t) => t['title'] == 'Wöchentlich',
        )['over'],
        isFalse,
      );
    });

    test(
      'markieren im Raster trotzdem nur den Tag, an dem etwas faellig ist',
      () {
        // Sonst waere jeder kommende Tag im Monatsraster gepunktet, nur weil
        // heute etwas offen ist.
        final snapshot = snapshotOf(
          stateWith(
            tasks: [
              Task(
                id: 't1',
                title: 'Liegengeblieben',
                startDate: heute.subtract(const Duration(days: 5)),
              ),
            ],
          ),
        );
        expect(dayOf(snapshot, heute)!['mark'], isNull);
        expect(
          dayOf(snapshot, heute.add(const Duration(days: 7)))!['mark'],
          isNull,
        );
        // Der Tag, an dem sie faellig war, liegt vor dem Monatsersten des
        // Schnappschusses – also die Probe mit einer Aufgabe von heute.
        final heutig = snapshotOf(
          stateWith(
            tasks: [Task(id: 't2', title: 'Heute faellig', startDate: heute)],
          ),
        );
        expect((dayOf(heutig, heute)!['mark'] as Map)['done'], isFalse);
        expect(
          dayOf(heutig, heute.add(const Duration(days: 3)))!['mark'],
          isNull,
        );
      },
    );

    test('setzen den Ring, wenn an dem Tag alles abgehakt ist', () {
      final snapshot = snapshotOf(
        stateWith(
          tasks: [
            Task(
              id: 't1',
              title: 'Blumen gießen',
              startDate: heute,
              recurrence: RecurrenceType.daily,
              completedDates: {dateKey(heute)},
            ),
          ],
        ),
      );
      expect((dayOf(snapshot, heute)!['mark'] as Map)['done'], isTrue);
      expect(
        (dayOf(snapshot, heute.add(const Duration(days: 1)))!['mark']
            as Map)['done'],
        isFalse,
      );
    });

    test(
      'lassen eine erledigte einmalige Aufgabe am Tag stehen, nicht spaeter',
      () {
        final snapshot = snapshotOf(
          stateWith(
            tasks: [
              Task(
                id: 't1',
                title: 'Erledigt',
                startDate: heute,
                completedDates: {dateKey(heute)},
              ),
            ],
          ),
        );
        expect(
          (dayOf(snapshot, heute)!['tasks'] as List).single['done'],
          isTrue,
        );
        expect(dayOf(snapshot, heute.add(const Duration(days: 1))), isNull);
      },
    );

    test('rechnen ueber die Zeitumstellung hinweg Tag fuer Tag', () {
      // Am 25.10.2026 hat der Tag 25 Stunden; wer mit Duration(days: 1)
      // weiterzaehlt, landet um 23 Uhr am selben Tag und traete auf der
      // Stelle. Der Schnappschuss muss die Tage trotzdem lueckenlos kennen.
      final oktober = DateTime(2026, 10, 20, 10, 0);
      final state = stateWith(
        tasks: [
          Task(
            id: 't1',
            title: 'Täglich',
            startDate: dateOnly(oktober),
            recurrence: RecurrenceType.daily,
          ),
        ],
      );
      final days = (buildWidgetSnapshot(state, now: oktober)['days']
          as Map<String, dynamic>);
      for (final tag in [
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
      ]) {
        expect(
          days.containsKey(dateKey(tag)),
          isTrue,
          reason: '${dateKey(tag)} fehlt',
        );
      }
    });
  });

  group('Das Ziel eines Antippers', () {
    test('kommt nur aus den bekannten Namen', () {
      expect(WidgetTarget.fromName('tasks'), WidgetTarget.tasks);
      expect(WidgetTarget.fromName('calendar'), WidgetTarget.calendar);
      expect(WidgetTarget.fromName('quatsch'), isNull);
      expect(WidgetTarget.fromName(null), isNull);
    });
  });
}
