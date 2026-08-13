import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/reminders.dart';
import 'package:joe_todo/util.dart';

/// Was wann erinnert wird, ist reine Rechnung und laeuft ohne Plugin:
/// [pendingReminders] stellt den Plan, [JoeReminders] traegt ihn nur zum
/// System.
void main() {
  // Ein fester Bezugspunkt, damit die Erwartungen nicht mit der Uhr wandern.
  final now = DateTime(2026, 8, 13, 10, 0);
  final heute = dateOnly(now);

  Appointment appointment({
    String id = 'a1',
    required DateTime when,
    int? lead,
  }) =>
      Appointment(id: id, title: 'Zahnarzt', when: when,
          reminderLeadMinutes: lead);

  Task task({
    String id = 't1',
    String title = 'Blumen gießen',
    required DateTime start,
    RecurrenceType recurrence = RecurrenceType.none,
    int? reminder,
    Set<String>? done,
  }) =>
      Task(
        id: id,
        title: title,
        startDate: start,
        recurrence: recurrence,
        reminderMinuteOfDay: reminder,
        completedDates: done,
      );

  List<Reminder> plan({
    List<Task> tasks = const [],
    List<Appointment> appointments = const [],
  }) =>
      pendingReminders(tasks: tasks, appointments: appointments, from: now);

  group('Benachrichtigungs-Nummern', () {
    test('sind stabil, unterscheidbar und passen in einen 32-Bit-Int', () {
      expect(reminderNotificationId('abc', 0), reminderNotificationId('abc', 0));
      expect(reminderNotificationId('abc', 0),
          isNot(reminderNotificationId('abc', 1)));
      expect(reminderNotificationId('abc', 0),
          isNot(reminderNotificationId('abd', 0)));
      for (final id in ['1723561234567_0', 'kurz', '', 'ü-mläut']) {
        for (final slot in [0, 7, 255]) {
          final value = reminderNotificationId(id, slot);
          expect(value, greaterThanOrEqualTo(0));
          expect(value, lessThanOrEqualTo(0x7fffffff));
        }
      }
    });
  });

  group('Termine', () {
    test('Vorlauf zaehlt rueckwaerts von der Terminzeit', () {
      final reminders = plan(appointments: [
        appointment(when: heute.add(const Duration(hours: 15)), lead: 30),
      ]);
      expect(reminders, hasLength(1));
      expect(reminders.single.when, heute.add(const Duration(hours: 14, minutes: 30)));
      expect(reminders.single.title, 'Zahnarzt');
      expect(reminders.single.body, 'Heute um 15:00 Uhr');
    });

    test('ohne Vorlauf keine Erinnerung', () {
      expect(
        plan(appointments: [
          appointment(when: heute.add(const Duration(hours: 15))),
        ]),
        isEmpty,
      );
    });

    test('"Zur Terminzeit" erinnert genau dann', () {
      final when = heute.add(const Duration(hours: 15));
      final reminders = plan(appointments: [appointment(when: when, lead: 0)]);
      expect(reminders.single.when, when);
    });

    test('was vorbei ist, wird nicht mehr gestellt', () {
      // Termin heute um 10:15, Vorlauf 30 Minuten: der Moment (09:45) liegt
      // vor "jetzt" (10:00).
      expect(
        plan(appointments: [
          appointment(
              when: heute.add(const Duration(hours: 10, minutes: 15)),
              lead: 30),
        ]),
        isEmpty,
      );
    });

    test('jenseits des Horizonts wird noch nicht gestellt', () {
      expect(
        plan(appointments: [
          appointment(when: now.add(const Duration(days: 90)), lead: 30),
        ]),
        isEmpty,
      );
    });
  });

  group('Aufgaben', () {
    test('einmalige Aufgabe erinnert an ihrem Tag zur gewaehlten Zeit', () {
      final reminders = plan(tasks: [
        task(start: heute.add(const Duration(days: 1)), reminder: 9 * 60),
      ]);
      expect(reminders, hasLength(1));
      expect(reminders.single.when,
          heute.add(const Duration(days: 1, hours: 9)));
      expect(reminders.single.body, 'Aufgabe für heute');
    });

    test('ohne Uhrzeit keine Erinnerung', () {
      expect(plan(tasks: [task(start: heute.add(const Duration(days: 1)))]),
          isEmpty);
    });

    test('erledigte Aufgaben erinnern nicht mehr', () {
      final morgen = heute.add(const Duration(days: 1));
      expect(
        plan(tasks: [
          task(start: morgen, reminder: 9 * 60, done: {dateKey(morgen)}),
        ]),
        isEmpty,
      );
    });

    test('wiederkehrend: mehrere Termine, aber gedeckelt', () {
      final reminders = plan(tasks: [
        task(
          start: heute,
          recurrence: RecurrenceType.daily,
          reminder: 18 * 60,
        ),
      ]);
      expect(reminders, hasLength(remindersPerTask));
      // Taeglich ab heute 18:00, jeder Tag einer – und jede Nummer nur
      // einmal, sonst ueberschriebe eine Erinnerung die naechste.
      expect(reminders.first.when, heute.add(const Duration(hours: 18)));
      expect(reminders.last.when,
          heute.add(Duration(days: remindersPerTask - 1, hours: 18)));
      expect(reminders.map((r) => r.id).toSet(), hasLength(remindersPerTask));
    });

    test('wiederkehrend: ein erledigter Tag faellt aus der Reihe', () {
      final reminders = plan(tasks: [
        task(
          start: heute,
          recurrence: RecurrenceType.daily,
          reminder: 18 * 60,
          done: {dateKey(heute.add(const Duration(days: 1)))},
        ),
      ]);
      final tage = reminders.map((r) => dateOnly(r.when)).toList();
      expect(tage, isNot(contains(heute.add(const Duration(days: 1)))));
      expect(tage, contains(heute));
      expect(tage, contains(heute.add(const Duration(days: 2))));
    });

    test('heute schon vorbei: erst der naechste Tag zaehlt', () {
      // Taegliche Aufgabe mit Erinnerung um 08:00; "jetzt" ist 10:00.
      final reminders = plan(tasks: [
        task(start: heute, recurrence: RecurrenceType.daily, reminder: 8 * 60),
      ]);
      expect(reminders.first.when,
          heute.add(const Duration(days: 1, hours: 8)));
    });
  });

  test('der Plan steht nach Zeit sortiert', () {
    final reminders = plan(
      appointments: [
        appointment(
            id: 'a1', when: heute.add(const Duration(days: 2)), lead: 0),
      ],
      tasks: [
        task(id: 't1', start: heute.add(const Duration(days: 1)),
            reminder: 9 * 60),
      ],
    );
    expect(reminders, hasLength(2));
    expect(reminders.first.when.isBefore(reminders.last.when), isTrue);
  });

  group('Beschriftungen', () {
    test('Vorlauf', () {
      expect(reminderLeadLabel(null), 'Keine');
      expect(reminderLeadLabel(0), 'Zur Terminzeit');
      expect(reminderLeadLabel(30), '30 Minuten vorher');
      expect(reminderLeadLabel(60), '1 Stunde vorher');
      expect(reminderLeadLabel(120), '2 Stunden vorher');
      expect(reminderLeadLabel(1440), '1 Tag vorher');
    });

    test('Uhrzeit', () {
      expect(reminderTimeLabel(null), 'Keine');
      expect(reminderTimeLabel(9 * 60), '09:00 Uhr');
      expect(reminderTimeLabel(18 * 60 + 30), '18:30 Uhr');
    });
  });

  group('Bestand', () {
    test('Erinnerungen ueberleben Speichern und Laden', () {
      final a = Appointment(
        id: 'a1',
        title: 'Zahnarzt',
        when: DateTime(2026, 8, 20, 15),
        reminderLeadMinutes: 30,
      );
      expect(Appointment.fromJson(a.toJson()).reminderLeadMinutes, 30);

      final t = Task(
          id: 't1', title: 'Gießen', startDate: heute, reminderMinuteOfDay: 540);
      expect(Task.fromJson(t.toJson()).reminderMinuteOfDay, 540);
    });

    test('unsinnige Werte heissen "keine Erinnerung"', () {
      // Eine kaputte Zahl darf nicht zu einem Alarm zu unmoeglicher Zeit
      // werden – lieber gar keine Erinnerung.
      for (final broken in <Object?>['neun', -5, 1440, 99999, 3.5, null]) {
        expect(minuteOfDayFromJson(broken), isNull, reason: '$broken');
      }
      expect(minuteOfDayFromJson(0), 0);
      expect(minuteOfDayFromJson(1439), 1439);

      for (final broken in <Object?>['dreissig', -1, maxReminderLead + 1]) {
        expect(leadMinutesFromJson(broken), isNull, reason: '$broken');
      }
      expect(leadMinutesFromJson(0), 0);
      expect(leadMinutesFromJson(1440), 1440);
    });
  });
}
