import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/theme.dart';
import 'package:joe_todo/util.dart';

/// Zustand ohne Persistenz – die Tests fassen nur die Abfragen an.
AppState stateWith({List<Task> tasks = const [], List<Note> notes = const []}) {
  return AppState()
    ..tasks = [...tasks]
    ..notes = [...notes];
}

void main() {
  group('Recurrence', () {
    final start = DateTime(2026, 7, 1); // a Wednesday

    test('alle sieben Wochentage = jeden Tag', () {
      final t = Task(
          id: '1',
          title: 'x',
          recurrence: RecurrenceType.weekly,
          weekdays: allWeekdays,
          startDate: start);
      expect(t.occursOn(DateTime(2026, 6, 30)), isFalse);
      expect(t.occursOn(DateTime(2026, 7, 1)), isTrue);
      expect(t.occursOn(DateTime(2026, 8, 15)), isTrue);
    });

    test('weekly occurs on same weekday', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.weekly, startDate: start);
      expect(t.occursOn(DateTime(2026, 7, 8)), isTrue);
      expect(t.occursOn(DateTime(2026, 7, 9)), isFalse);
    });

    test('monthly occurs on same day of month', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.monthly, startDate: start);
      expect(t.occursOn(DateTime(2026, 8, 1)), isTrue);
      expect(t.occursOn(DateTime(2026, 8, 2)), isFalse);
    });

    test('everyXDays respects interval', () {
      final t = Task(
        id: '1',
        title: 'x',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 3,
        startDate: start,
      );
      expect(t.occursOn(DateTime(2026, 7, 4)), isTrue);
      expect(t.occursOn(DateTime(2026, 7, 5)), isFalse);
      expect(t.occursOn(DateTime(2026, 7, 7)), isTrue);
    });

    test('one-off completion is permanent, recurring is per-day', () {
      final oneOff = Task(id: '1', title: 'x', startDate: start);
      oneOff.completedDates.add(dateKey(DateTime(2026, 7, 2)));
      expect(oneOff.isCompletedOn(DateTime(2026, 7, 5)), isTrue);

      final daily = Task(
          id: '2',
          title: 'y',
          recurrence: RecurrenceType.weekly,
          weekdays: allWeekdays,
          startDate: start);
      daily.completedDates.add(dateKey(DateTime(2026, 7, 2)));
      expect(daily.isCompletedOn(DateTime(2026, 7, 2)), isTrue);
      expect(daily.isCompletedOn(DateTime(2026, 7, 3)), isFalse);
    });

    test('task json roundtrip', () {
      final t = Task(
        id: '1',
        title: 'Blumen gießen',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 4,
        startDate: start,
        colorIndex: 3,
        priority: Priority.hoch,
        completedDates: {dateKey(DateTime(2026, 7, 5))},
      );
      final back = Task.fromJson(t.toJson());
      expect(back.title, t.title);
      expect(back.recurrence, t.recurrence);
      expect(back.intervalDays, t.intervalDays);
      expect(back.priority, Priority.hoch);
      expect(back.completedDates, t.completedDates);
    });
  });

  group('Priorität', () {
    test('drei Stufen, Standard ist Stufe 2', () {
      expect(Priority.values.map((p) => p.level), [1, 2, 3]);
      expect(Task(id: '1', title: 'x', startDate: today()).priority,
          Priority.mittel);
      expect(
        Appointment(id: '1', title: 'x', when: DateTime.now()).priority,
        Priority.mittel,
      );
    });

    test('Aufgaben ohne gespeicherte Priorität landen auf Stufe 2', () {
      final back = Task.fromJson({
        'id': '1',
        'title': 'Alt',
        'recurrence': 'none',
        'startDate': dateKey(today()),
      });
      expect(back.priority, Priority.mittel);
      final appointment = Appointment.fromJson({
        'id': '1',
        'title': 'Alt',
        'when': DateTime.now().toIso8601String(),
      });
      expect(appointment.priority, Priority.mittel);
    });

    test('Stufe 3 zählt an ihrem Faelligkeitstag mit', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(id: '1', title: 'Wichtig', startDate: t, priority: Priority.hoch),
        Task(id: '2', title: 'Normal', startDate: t),
        Task(
            id: '3',
            title: 'Unwichtig',
            startDate: t,
            priority: Priority.niedrig),
      ]);
      // Heute ist sie faellig wie jede andere: sie zaehlt mit und steht in
      // derselben Liste, nur hinter den wichtigeren.
      expect(state.openTodayCount(), 3);
      expect(state.tasksDueToday().map((x) => x.id), ['1', '2', '3']);
      expect(state.lowLeftoverTasks(), isEmpty);
    });

    test('danach faellt sie aus der Zahl und wandert in "Hat Zeit"', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(id: '2', title: 'Normal', startDate: t),
        Task(
          id: '3',
          title: 'Unwichtig',
          startDate: t.subtract(const Duration(days: 1)),
          priority: Priority.niedrig,
        ),
      ]);
      // Gestern hat sie noch gezaehlt, heute nicht mehr – sonst waechst die
      // Zahl von etwas weiter, das ausdruecklich Zeit hat.
      expect(state.openTodayCount(), 1);
      expect(state.tasksDueToday().map((x) => x.id), ['2']);
      expect(state.lowLeftoverTasks().map((x) => x.id), ['3']);
    });

    test('eine ueberfaellige Aufgabe anderer Stufen zaehlt weiter mit', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(
          id: 'gestern',
          title: 'Liegengeblieben',
          startDate: t.subtract(const Duration(days: 1)),
        ),
      ]);
      expect(state.openTodayCount(), 1);
      expect(state.tasksDueToday().map((x) => x.id), ['gestern']);
    });

    test('eine wiederkehrende Stufe 3 zaehlt an jedem ihrer Tage', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(
          id: 'taeglich',
          title: 'Leise, aber taeglich',
          recurrence: RecurrenceType.weekly,
          weekdays: allWeekdays,
          startDate: t.subtract(const Duration(days: 10)),
          priority: Priority.niedrig,
        ),
      ]);
      // Eine wiederkehrende Aufgabe bleibt nie liegen: heute ist sie faellig
      // oder gar nicht dabei.
      expect(state.openTodayCount(), 1);
      expect(state.lowLeftoverTasks(), isEmpty);
    });

    test('Stufe 3 faellt aus der Zahl, sobald sie abgehakt ist', () {
      final t = today();
      final low = Task(
          id: '3', title: 'Unwichtig', startDate: t, priority: Priority.niedrig);
      final state = stateWith(tasks: [
        Task(id: '2', title: 'Normal', startDate: t),
        low,
      ]);
      expect(state.openTodayCount(), 2);
      low.completedDates.add(dateKey(t));
      expect(state.openTodayCount(), 1);
    });

    test('liegengebliebene Stufe-3-Aufgaben kommen neuste zuerst', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(
          id: 'alt',
          title: 'Alt',
          startDate: t.subtract(const Duration(days: 9)),
          priority: Priority.niedrig,
        ),
        Task(
          id: 'neu',
          title: 'Neu',
          startDate: t.subtract(const Duration(days: 1)),
          priority: Priority.niedrig,
        ),
        Task(
          id: 'mittig',
          title: 'Mittig',
          startDate: t.subtract(const Duration(days: 4)),
          priority: Priority.niedrig,
        ),
      ]);
      expect(
        state.lowLeftoverTasks().map((x) => x.id),
        ['neu', 'mittig', 'alt'],
      );
    });

    test('nur das Liegengebliebene trennt sich von "Heute"', () {
      final t = today();
      final done = Task(
        id: 'erledigt',
        title: 'Schon abgehakt',
        recurrence: RecurrenceType.weekly,
        weekdays: allWeekdays,
        startDate: t.subtract(const Duration(days: 3)),
        priority: Priority.niedrig,
        completedDates: {dateKey(t)},
      );
      final state = stateWith(tasks: [
        Task(id: 'normal', title: 'Normal', startDate: t),
        Task(
          id: 'alt',
          title: 'Alt',
          startDate: t.subtract(const Duration(days: 5)),
          priority: Priority.niedrig,
        ),
        Task(
          id: 'neu',
          title: 'Neu',
          startDate: t,
          priority: Priority.niedrig,
        ),
        done,
      ]);
      // Heute faellig – die leise von heute und die abgehakte wiederkehrende
      // stehen mit unter "Heute", die abgehakte am Ende: nur dort laesst
      // sich ein Haken zurueckziehen.
      expect(
        state.tasksDueToday().map((x) => x.id),
        ['normal', 'neu', 'erledigt'],
      );
      expect(state.lowLeftoverTasks().map((x) => x.id), ['alt']);
    });

    test('abgehakte Stufe-3-Aufgaben fallen aus der Zahl', () {
      final t = today();
      final task = Task(
          id: '1', title: 'Unwichtig', startDate: t, priority: Priority.niedrig);
      final state = stateWith(tasks: [task]);
      expect(state.openTodayCount(), 1);
      task.completedDates.add(dateKey(t));
      expect(state.openTodayCount(), 0);
      // Abgehakt bleibt sie stehen, damit der Haken zurueckgenommen werden
      // kann – sie zaehlt nur nicht mehr.
      expect(state.tasksDueToday(), hasLength(1));
    });
  });

  group('Dauer', () {
    test('eine laufende Aufgabe zaehlt heute und ist nicht ueberfaellig', () {
      final t = today();
      final state = stateWith(tasks: [
        Task(
          id: 'laeuft',
          title: 'Von vorgestern bis morgen',
          startDate: addCalendarDays(t, -2),
          spanDays: 3,
        ),
        Task(
          id: 'vorbei',
          title: 'Bis gestern',
          startDate: addCalendarDays(t, -3),
          spanDays: 2,
        ),
      ]);
      expect(state.openTodayCount(), 2);
      expect(state.tasksDueToday().map((x) => x.id),
          containsAll(['laeuft', 'vorbei']));
      // Heute ist sie faellig, nicht liegengeblieben: occursOn stimmt.
      expect(state.tasks.first.occursOn(t), isTrue);
      expect(state.tasks.first.lastDay.isBefore(t), isFalse);
      // Die andere ist nur noch ueberfaellig: gestern war ihr letzter Tag.
      expect(state.tasks.last.occursOn(t), isFalse);
      expect(state.tasks.last.lastDay.isBefore(t), isTrue);
      expect(state.tasksForDay(t).map((x) => x.id), ['laeuft']);
    });

    test('eine leise Aufgabe mit Dauer bleibt erst nach dem letzten Tag liegen',
        () {
      final t = today();
      final state = stateWith(tasks: [
        Task(
          id: 'laeuft',
          title: 'Laeuft noch',
          startDate: addCalendarDays(t, -1),
          spanDays: 1,
          priority: Priority.niedrig,
        ),
        Task(
          id: 'vorbei',
          title: 'Vorbei',
          startDate: addCalendarDays(t, -2),
          spanDays: 1,
          priority: Priority.niedrig,
        ),
      ]);
      expect(state.tasksDueToday().map((x) => x.id), ['laeuft']);
      expect(state.lowLeftoverTasks().map((x) => x.id), ['vorbei']);
      expect(state.openTodayCount(), 1);
    });

    test('ein Drei-Tages-Termin steht an jedem seiner Tage', () {
      final start = DateTime(2026, 9, 14, 12);
      final state = AppState()
        ..appointments = [
          Appointment(
            id: 'lang',
            title: 'Messe',
            when: start,
            end: DateTime(2026, 9, 16, 18),
          ),
          Appointment(id: 'kurz', title: 'Kaffee', when: DateTime(2026, 9, 15, 9)),
        ];
      expect(state.appointmentsForDay(DateTime(2026, 9, 13)), isEmpty);
      expect(state.appointmentsForDay(DateTime(2026, 9, 14)).map((a) => a.id),
          ['lang']);
      // Sortiert nach Beginn: der lange hat am 14. begonnen.
      expect(state.appointmentsForDay(DateTime(2026, 9, 15)).map((a) => a.id),
          ['lang', 'kurz']);
      expect(state.appointmentsForDay(DateTime(2026, 9, 16)).map((a) => a.id),
          ['lang']);
      expect(state.appointmentsForDay(DateTime(2026, 9, 17)), isEmpty);
    });

    test('ein laufender Termin ist nicht vergangen', () {
      final t = today();
      final state = AppState()
        ..appointments = [
          Appointment(
            id: 'laeuft',
            title: 'Seit gestern',
            when: addCalendarDays(t, -1).add(const Duration(hours: 10)),
            end: addCalendarDays(t, 1).add(const Duration(hours: 10)),
          ),
          Appointment(
            id: 'vorbei',
            title: 'Gestern',
            when: addCalendarDays(t, -1).add(const Duration(hours: 10)),
          ),
        ];
      expect(state.upcomingAppointments().map((a) => a.id), ['laeuft']);
      expect(state.pastAppointments().map((a) => a.id), ['vorbei']);
    });
  });

  group('Prioritätsfarben', () {
    setUp(() {
      PriorityColors.reset();
      // setPriorityColor speichert nebenbei.
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(PriorityColors.reset);

    Task task(Priority p) => Task(
          id: p.name,
          title: p.label,
          startDate: today(),
          colorIndex: 3,
          priority: p,
        );

    test('ohne Einstellung zeigt eine Aufgabe ihre eigene Farbe', () {
      final t = task(Priority.hoch);
      expect(t.color, t.ownColor);
      expect(t.ownColor, taskPalette[3]);
    });

    test('die Stufe gibt die Farbe vor, die eigene bleibt stehen', () {
      final hoch = task(Priority.hoch);
      final mittel = task(Priority.mittel);
      final state = AppState()..tasks = [hoch, mittel];
      state.setPriorityColor(Priority.hoch, 20);

      expect(state.priorityColors, {Priority.hoch: 20});
      expect(PriorityColors.of(Priority.hoch), 20);
      expect(hoch.color, taskPalette[20]);
      expect(hoch.ownColor, taskPalette[3]);
      expect(hoch.colorIndex, 3);
      expect(mittel.color, taskPalette[3]);

      // "Keine Farbe": wieder die eigene.
      state.setPriorityColor(Priority.hoch, null);
      expect(state.priorityColors, isEmpty);
      expect(hoch.color, taskPalette[3]);
    });

    test('Termine behalten ihre Farbe', () {
      PriorityColors.use({Priority.hoch: 20});
      final a = Appointment(
        id: 'a',
        title: 'x',
        when: DateTime(2026, 9, 14, 12),
        colorIndex: 6,
        priority: Priority.hoch,
      );
      expect(a.color, taskPalette[6]);
    });
  });

  group('Notizen', () {
    test('Notiz haengt an ihrem Tag, nicht an der letzten Änderung', () {
      final day = DateTime(2026, 8, 3);
      final note = Note(
        id: '1',
        title: 'Einkauf',
        body: '',
        date: day,
        updatedAt: DateTime(2026, 8, 20, 14, 30),
      );
      final state = stateWith(notes: [note]);
      expect(state.notesForDay(day), hasLength(1));
      expect(state.notesForDay(DateTime(2026, 8, 20)), isEmpty);
    });

    test('alte Notizen ohne Datum erben den Tag der letzten Änderung', () {
      final back = Note.fromJson({
        'id': '1',
        'title': 'Alt',
        'body': '',
        'updatedAt': DateTime(2026, 7, 30, 18, 5).toIso8601String(),
      });
      expect(back.date, DateTime(2026, 7, 30));
    });

    test('note json roundtrip', () {
      final note = Note(
        id: '1',
        title: 'Einkauf',
        body: 'Brot',
        date: DateTime(2026, 8, 3),
        updatedAt: DateTime(2026, 8, 20, 14, 30),
      );
      final back = Note.fromJson(note.toJson());
      expect(back.date, note.date);
      expect(back.updatedAt, note.updatedAt);
      expect(back.body, note.body);
    });
  });

  group('Farben und Reiter', () {
    test('25 Farben, die ersten zwanzig behalten Index und Wert', () {
      // Gespeichert ist der Index – eine Farbe, die ihren Platz wechselt,
      // faerbte jede alte Aufgabe um.
      const frueher = [
        Color(0xFFC0563B), Color(0xFFD98E32), Color(0xFF8A9A5B),
        Color(0xFF4E937A), Color(0xFFB23A5E), Color(0xFF7A5C3E),
        Color(0xFF5B7C99), Color(0xFFC9A227), Color(0xFFA34A22),
        Color(0xFFE08A6A), Color(0xFFE07B39), Color(0xFFD9B382),
        Color(0xFF6E7A3A), Color(0xFF5A8F4C), Color(0xFF7FBFA5),
        Color(0xFF3A6E78), Color(0xFF3B4E70), Color(0xFF7B4B6E),
        Color(0xFFC77F92), Color(0xFF8E7BB0),
      ];
      expect(taskPalette, hasLength(25));
      expect(taskPaletteNames, hasLength(taskPalette.length));
      expect(taskPalette.sublist(0, 20), frueher);
      expect(taskPalette.toSet(), hasLength(25));
      expect(taskPaletteNames.toSet(), hasLength(25));
      expect(taskPaletteNames, contains('Mint'));
      expect(taskPaletteNames[14], 'Jade');
      expect(taskPalette[taskPaletteNames.indexOf('Mint')],
          const Color(0xFF9FDFC4));
    });

    test('jedes Design hat eine Farbe je Reiter', () {
      for (final theme in joeThemes) {
        expect(theme.tabColors, hasLength(6), reason: theme.name);
      }
    });

    test('Reiterbeschriftung erreicht 3:1 auf jeder Reiterfarbe', () {
      for (final theme in joeThemes) {
        for (final color in theme.tabColors) {
          expect(
            contrastRatio(theme.onTab(color), color),
            greaterThanOrEqualTo(3.0),
            reason: '${theme.name} / $color',
          );
        }
      }
    });
  });
}
