import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('daily occurs every day from start', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.daily, startDate: start);
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
          id: '2', title: 'y', recurrence: RecurrenceType.daily, startDate: start);
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

    test('Stufe 3 zählt in "offene Aufgaben heute" mit', () {
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
      // Die Zahl nennt alles, was heute faellig und offen ist; die Trennung
      // in zwei Bloecke ist nur eine der Anzeige.
      expect(state.openTodayCount(), 3);
      expect(state.tasksDueToday().map((x) => x.id), ['1', '2']);
      expect(state.openLowTasks().map((x) => x.id), ['3']);
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

    test('offene Stufe-3-Aufgaben kommen neuste zuerst', () {
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
      expect(state.openLowTasks().map((x) => x.id), ['neu', 'mittig', 'alt']);
    });

    test('Aufgaben-Reiter haelt Stufe 3 aus "Heute" heraus', () {
      final t = today();
      final done = Task(
        id: 'erledigt',
        title: 'Schon abgehakt',
        recurrence: RecurrenceType.daily,
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
      expect(state.tasksDueToday().map((x) => x.id), ['normal']);
      // Offen zuerst und darin neuste zuerst, Abgehaktes bleibt am Ende
      // stehen – nur hier laesst sich ein Haken zurueckziehen.
      expect(
        state.lowTasksToday().map((x) => x.id),
        ['neu', 'alt', 'erledigt'],
      );
    });

    test('abgehakte Stufe-3-Aufgaben verschwinden aus der Liste', () {
      final t = today();
      final task = Task(
          id: '1', title: 'Unwichtig', startDate: t, priority: Priority.niedrig);
      final state = stateWith(tasks: [task]);
      expect(state.openLowTasks(), hasLength(1));
      task.completedDates.add(dateKey(t));
      expect(state.openLowTasks(), isEmpty);
      expect(state.openTodayCount(), 0);
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
    test('20 Farben, die ersten acht behalten ihren Index', () {
      expect(taskPalette, hasLength(20));
      expect(taskPaletteNames, hasLength(20));
      expect(taskPalette[0], const Color(0xFFC0563B));
      expect(taskPalette[7], const Color(0xFFC9A227));
      expect(taskPalette.toSet(), hasLength(20));
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
