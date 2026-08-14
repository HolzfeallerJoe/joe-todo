import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/reminders.dart';
import 'package:joe_todo/util.dart';

/// Was wann erinnert wird, ist reine Rechnung und laeuft ohne Plugin:
/// [pendingReminders] stellt den Plan, [JoeReminders] traegt ihn nur zum
/// System.
void main() {
  // Ein fester Bezugspunkt, damit die Erwartungen nicht mit der Uhr wandern:
  // heute um 10 Uhr. Bewusst der *echte* heutige Tag und kein eingetragenes
  // Datum – der Text einer Erinnerung sagt "Heute um 15:00 Uhr"
  // (formatRelativeDay rechnet gegen die Uhr des Geraets), und mit einem
  // festen Datum lief der Test um Mitternacht auf.
  final heute = today();
  final now = heute.add(const Duration(hours: 10));

  Appointment appointment({
    String id = 'a1',
    required DateTime when,
    int? lead,
  }) =>
      Appointment(
        id: id,
        title: 'Zahnarzt',
        when: when,
        reminderLeadMinutes: lead,
      );

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
      expect(
        reminderNotificationId('abc', 0),
        reminderNotificationId('abc', 0),
      );
      expect(
        reminderNotificationId('abc', 0),
        isNot(reminderNotificationId('abc', 1)),
      );
      expect(
        reminderNotificationId('abc', 0),
        isNot(reminderNotificationId('abd', 0)),
      );
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
      final reminders = plan(
        appointments: [
          appointment(when: heute.add(const Duration(hours: 15)), lead: 30),
        ],
      );
      expect(reminders, hasLength(1));
      expect(
        reminders.single.when,
        heute.add(const Duration(hours: 14, minutes: 30)),
      );
      expect(reminders.single.title, 'Zahnarzt');
      expect(reminders.single.body, 'Heute um 15:00 Uhr');
    });

    test('ohne Vorlauf keine Erinnerung', () {
      expect(
        plan(
          appointments: [
            appointment(when: heute.add(const Duration(hours: 15))),
          ],
        ),
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
        plan(
          appointments: [
            appointment(
              when: heute.add(const Duration(hours: 10, minutes: 15)),
              lead: 30,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('jenseits des Horizonts wird noch nicht gestellt', () {
      expect(
        plan(
          appointments: [
            appointment(when: now.add(const Duration(days: 90)), lead: 30),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('Aufgaben', () {
    test('Kalendertage und Uhrzeit bleiben an Zeitumstellungen stabil', () {
      final sonntag = DateTime(2026, 3, 29);
      final montag = nextCalendarDay(sonntag);
      final neunUhr = timeOnCalendarDay(montag, 9 * 60);

      expect(montag, DateTime(2026, 3, 30));
      expect(
        [
          neunUhr.year,
          neunUhr.month,
          neunUhr.day,
          neunUhr.hour,
          neunUhr.minute,
        ],
        [2026, 3, 30, 9, 0],
      );

      final reminders = pendingReminders(
        tasks: [
          task(
            start: DateTime(2026, 3, 28),
            recurrence: RecurrenceType.daily,
            reminder: 9 * 60,
          ),
        ],
        appointments: const [],
        from: DateTime(2026, 3, 28, 10),
      );
      expect(reminders.first.when, DateTime(2026, 3, 29, 9));
      expect(reminders[1].when, DateTime(2026, 3, 30, 9));
    });

    test('einmalige Aufgabe erinnert an ihrem Tag zur gewaehlten Zeit', () {
      final reminders = plan(
        tasks: [
          task(start: heute.add(const Duration(days: 1)), reminder: 9 * 60),
        ],
      );
      expect(reminders, hasLength(1));
      expect(
        reminders.single.when,
        heute.add(const Duration(days: 1, hours: 9)),
      );
      expect(reminders.single.body, 'Aufgabe für heute');
    });

    test('ohne Uhrzeit keine Erinnerung', () {
      expect(
        plan(tasks: [task(start: heute.add(const Duration(days: 1)))]),
        isEmpty,
      );
    });

    test('erledigte Aufgaben erinnern nicht mehr', () {
      final morgen = heute.add(const Duration(days: 1));
      expect(
        plan(
          tasks: [
            task(start: morgen, reminder: 9 * 60, done: {dateKey(morgen)}),
          ],
        ),
        isEmpty,
      );
    });

    test('wiederkehrend: mehrere Termine, aber gedeckelt', () {
      final reminders = plan(
        tasks: [
          task(
            start: heute,
            recurrence: RecurrenceType.daily,
            reminder: 18 * 60,
          ),
        ],
      );
      expect(reminders, hasLength(remindersPerTask));
      // Taeglich ab heute 18:00, jeder Tag einer – und jede Nummer nur
      // einmal, sonst ueberschriebe eine Erinnerung die naechste.
      expect(reminders.first.when, heute.add(const Duration(hours: 18)));
      expect(
        reminders.last.when,
        heute.add(Duration(days: remindersPerTask - 1, hours: 18)),
      );
      expect(reminders.map((r) => r.id).toSet(), hasLength(remindersPerTask));
    });

    test('wiederkehrend: ein erledigter Tag faellt aus der Reihe', () {
      final reminders = plan(
        tasks: [
          task(
            start: heute,
            recurrence: RecurrenceType.daily,
            reminder: 18 * 60,
            done: {dateKey(heute.add(const Duration(days: 1)))},
          ),
        ],
      );
      final tage = reminders.map((r) => dateOnly(r.when)).toList();
      expect(tage, isNot(contains(heute.add(const Duration(days: 1)))));
      expect(tage, contains(heute));
      expect(tage, contains(heute.add(const Duration(days: 2))));
    });

    test('heute schon vorbei: erst der naechste Tag zaehlt', () {
      // Taegliche Aufgabe mit Erinnerung um 08:00; "jetzt" ist 10:00.
      final reminders = plan(
        tasks: [
          task(
            start: heute,
            recurrence: RecurrenceType.daily,
            reminder: 8 * 60,
          ),
        ],
      );
      expect(
        reminders.first.when,
        heute.add(const Duration(days: 1, hours: 8)),
      );
    });
  });

  test('der Plan steht nach Zeit sortiert', () {
    final reminders = plan(
      appointments: [
        appointment(
          id: 'a1',
          when: heute.add(const Duration(days: 2)),
          lead: 0,
        ),
      ],
      tasks: [
        task(
          id: 't1',
          start: heute.add(const Duration(days: 1)),
          reminder: 9 * 60,
        ),
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
        id: 't1',
        title: 'Gießen',
        startDate: heute,
        reminderMinuteOfDay: 540,
      );
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

  group('Deckel', () {
    test('eine taegliche Aufgabe reicht einen Monat weit', () {
      final geplant = plan(
        tasks: [
          task(
            start: heute,
            recurrence: RecurrenceType.daily,
            reminder: 9 * 60,
          ),
        ],
      );
      // Der eigentliche Zweck: wer die App eine Woche nicht oeffnet, soll
      // trotzdem noch erinnert werden.
      expect(geplant.length, remindersPerTask);
      expect(geplant.last.when.difference(now).inDays, greaterThan(25));
    });

    test('viele Aufgaben reissen die Android-Grenze nicht', () {
      // Androids Grenze liegt bei 500 offenen Alarmen pro App. 30 Slots mal
      // 40 taegliche Aufgaben waeren 1200 – ohne globalen Deckel wuerde das
      // System werfen.
      final geplant = plan(
        tasks: [
          for (var i = 0; i < 40; i++)
            task(
              id: 't$i',
              start: heute,
              recurrence: RecurrenceType.daily,
              reminder: 9 * 60,
            ),
        ],
      );
      expect(geplant.length, maxScheduledReminders);
      expect(maxScheduledReminders, lessThan(500));
    });

    test('gedeckelt wird am Ende, die naechsten Erinnerungen gewinnen', () {
      final geplant = pendingReminders(
        tasks: [
          task(start: heute, recurrence: RecurrenceType.daily, reminder: 540),
        ],
        appointments: const [],
        from: now,
        maxTotal: 3,
      );
      expect(geplant.length, 3);
      // Immer noch nach Zeit sortiert, und es sind die drei fruehesten.
      // Die 9 Uhr von heute ist um 10 Uhr schon vorbei, es geht also
      // morgen los.
      expect(geplant.first.when, heute.add(const Duration(days: 1, hours: 9)));
      expect(geplant.last.when, heute.add(const Duration(days: 3, hours: 9)));
    });
  });

  group('Antippen', () {
    test('Payload haelt Art, Eintrag und Tag', () {
      final target = parseReminderPayload(
        reminderPayload(isTask: true, id: 't7', day: DateTime(2026, 8, 13)),
      );
      expect(target, isNotNull);
      expect(target!.isTask, isTrue);
      expect(target.id, 't7');
      expect(target.day, DateTime(2026, 8, 13));

      final termin = parseReminderPayload(
        reminderPayload(
          isTask: false,
          id: 'a3',
          day: DateTime(2026, 12, 24, 18, 30),
        ),
      );
      // Die Uhrzeit faellt weg, der Kalender oeffnet auf den Tag.
      expect(termin!.isTask, isFalse);
      expect(termin.id, 'a3');
      expect(termin.day, DateTime(2026, 12, 24));
    });

    test('unbrauchbare Payloads fuehren nirgendwohin', () {
      // Unter anderem der Fall "Benachrichtigung aus einer aelteren Version,
      // die noch keinen Payload gesetzt hat" – die darf nicht abstuerzen.
      for (final broken in <String?>[
        null,
        '',
        'aufgabe',
        'aufgabe|t1',
        'aufgabe|t1|2026-08-13|zuviel',
        'irgendwas|t1|2026-08-13',
        'aufgabe||2026-08-13',
        'aufgabe|t1|kein-datum',
        'aufgabe|t1|2026-13-45',
      ]) {
        expect(parseReminderPayload(broken), isNull, reason: '$broken');
      }
    });

    test('jede geplante Erinnerung weiss, wohin sie fuehrt', () {
      final geplant = plan(
        tasks: [
          task(
            id: 'taeglich',
            start: heute,
            recurrence: RecurrenceType.daily,
            reminder: 9 * 60,
          ),
        ],
        appointments: [
          appointment(
            when: heute.add(const Duration(days: 1, hours: 9)),
            lead: 1440,
          ),
        ],
      );
      expect(geplant, isNotEmpty);
      for (final reminder in geplant) {
        final target = parseReminderPayload(reminder.payload);
        expect(target, isNotNull, reason: reminder.title);
        // Der Tag im Payload ist der Tag, um den es geht – bei der Aufgabe
        // ihr Faelligkeitstag, beim Termin der Tag des Termins. Nicht der
        // Tag, an dem die Erinnerung losgeht: ein Vorlauf von einem Tag
        // wuerde sonst auf den falschen Tag zeigen.
        expect(target!.day, dateOnly(target.day));
      }
    });
  });
}
