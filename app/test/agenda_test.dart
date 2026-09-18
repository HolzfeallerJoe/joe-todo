import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/agenda.dart';
import 'package:joe_todo/device_calendar.dart' show deviceEventTimeLabel;
import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Die Terminliste des Dashboards mischt zwei Quellen, die nichts
/// voneinander wissen: die eigenen Termine und die aus den Kalendern des
/// Geraets. Was dabei in welcher Reihenfolge herauskommt, ist reine Logik –
/// und laeuft hier ohne Plugin und ohne Bildschirm.
void main() {
  const fallback = Color(0xFF4E937A);
  final t = DateTime(2026, 8, 23);

  Appointment own(String id, DateTime when, {int colorIndex = 4}) =>
      Appointment(id: id, title: id, when: when, colorIndex: colorIndex);

  Event device(
    String title, {
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? colorHex,
  }) =>
      Event(
        eventId: title,
        instanceId: title,
        calendarId: 'c1',
        title: title,
        startDate: start,
        endDate: end,
        isAllDay: allDay,
        colorHex: colorHex,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

  group('Ein Tag', () {
    test('eigene und Geraete-Termine stehen nach der Uhrzeit', () {
      final entries = agendaForDay(
        t,
        appointments: [
          own('eigen-14', t.add(const Duration(hours: 14))),
          own('eigen-9', t.add(const Duration(hours: 9))),
        ],
        deviceEvents: [
          device('geraet-11',
              start: t.add(const Duration(hours: 11)),
              end: t.add(const Duration(hours: 12))),
        ],
        deviceColor: fallback,
      );

      expect(
        entries.map((e) => e.title),
        ['eigen-9', 'geraet-11', 'eigen-14'],
      );
      expect(entries[1].fromDevice, isTrue);
      expect(entries[0].fromDevice, isFalse);
    });

    test('ganztaegige stehen vorn und tragen keine Uhrzeit', () {
      final entries = agendaForDay(
        t,
        appointments: [own('eigen-9', t.add(const Duration(hours: 9)))],
        deviceEvents: [
          // Lokale Mitternacht, nicht UTC: so liefert das Plugin ganztaegige
          // Termine (utcToLocalMidnight in device_calendar_plus_android,
          // siehe eventCoversDay).
          device('feiertag',
              start: t,
              end: DateTime(2026, 8, 24),
              allDay: true),
        ],
        deviceColor: fallback,
      );

      expect(entries.first.title, 'feiertag');
      expect(entries.first.allDay, isTrue);
      expect(agendaTimeLabel(entries.first), 'ganztägig');
      expect(agendaTimeLabel(entries.last), '09:00 Uhr');
    });

    test('ein mehrtaegiger Termin faengt am Folgetag nicht neu an', () {
      // Sonst stuende am 24. "18:00 Uhr" – die Uhrzeit von gestern.
      final entries = agendaForDay(
        t.add(const Duration(days: 1)),
        appointments: const [],
        deviceEvents: [
          device('umzug',
              start: t.add(const Duration(hours: 18)),
              end: t.add(const Duration(days: 2))),
        ],
        deviceColor: fallback,
      );

      expect(entries.single.allDay, isTrue);
      expect(agendaTimeLabel(entries.single), 'ganztägig');
    });

    test('bei gleicher Zeit steht der eigene Termin vorn', () {
      final entries = agendaForDay(
        t,
        appointments: [own('eigen', t.add(const Duration(hours: 10)))],
        deviceEvents: [
          device('geraet',
              start: t.add(const Duration(hours: 10)),
              end: t.add(const Duration(hours: 11))),
        ],
        deviceColor: fallback,
      );

      expect(entries.map((e) => e.title), ['eigen', 'geraet']);
    });

    test('ein Geraete-Termin ohne eigene Farbe bekommt die des Designs', () {
      final entries = agendaForDay(
        t,
        appointments: const [],
        deviceEvents: [
          device('ohne-farbe',
              start: t.add(const Duration(hours: 8)),
              end: t.add(const Duration(hours: 9))),
          device('mit-farbe',
              start: t.add(const Duration(hours: 10)),
              end: t.add(const Duration(hours: 11)),
              colorHex: '#B23A5E'),
        ],
        deviceColor: fallback,
      );

      expect(entries.first.color, fallback);
      expect(entries.last.color, const Color(0xFFB23A5E));
    });

    test('Termine anderer Tage bleiben draussen', () {
      final entries = agendaForDay(
        t,
        appointments: [
          own('gestern', t.subtract(const Duration(hours: 2))),
          own('morgen', t.add(const Duration(days: 1, hours: 9))),
          own('heute', t.add(const Duration(hours: 9))),
        ],
        deviceColor: fallback,
      );

      expect(entries.map((e) => e.title), ['heute']);
    });
  });

  group('Termine mit Dauer', () {
    // Mo 14.9. 12:00 bis Do 17.9. 18:00 – das Beispiel aus der Anforderung.
    final start = DateTime(2026, 9, 14, 12);
    final ende = DateTime(2026, 9, 17, 18);
    Appointment lang() => Appointment(
          id: 'lang',
          title: 'Messe',
          when: start,
          end: ende,
        );

    List<AgendaEntry> amTag(int day, {List<Appointment>? appointments}) =>
        agendaForDay(
          DateTime(2026, 9, day),
          appointments: appointments ?? [lang()],
          deviceColor: fallback,
        );

    test('steht an jedem Tag: Uhrzeit, ganztaegig, "bis …"', () {
      expect(amTag(13), isEmpty);
      expect(agendaTimeLabel(amTag(14).single), '12:00 Uhr');
      expect(agendaTimeLabel(amTag(15).single), 'ganztägig');
      expect(agendaTimeLabel(amTag(16).single), 'ganztägig');
      expect(agendaTimeLabel(amTag(17).single), 'bis 18:00');
      expect(amTag(18), isEmpty);
    });

    test('der Endtag steht vorn, weil er vor dem Tag begonnen hat', () {
      final entries = amTag(17, appointments: [
        Appointment(id: 'frueh', title: 'Frueh', when: DateTime(2026, 9, 17, 8)),
        lang(),
      ]);
      expect(entries.map((e) => e.title), ['Messe', 'Frueh']);
      expect(entries.first.continued, isTrue);
      expect(entries.first.until, ende);
      expect(entries.first.allDay, isFalse);
    });

    test('ein Ende um Mitternacht gehoert nicht mehr auf den Folgetag', () {
      final bisMitternacht = Appointment(
        id: 'm',
        title: 'Nachtschicht',
        when: DateTime(2026, 9, 14, 20),
        end: DateTime(2026, 9, 16),
      );
      // Der 15. ist sein letzter Tag – und den hat er ganz.
      expect(
        agendaTimeLabel(amTag(15, appointments: [bisMitternacht]).single),
        'ganztägig',
      );
      expect(amTag(16, appointments: [bisMitternacht]), isEmpty);
    });

    test('am selben Tag: kurz im Dashboard, ganz in der Spanne', () {
      final kurz = Appointment(
        id: 'k',
        title: 'Mittag',
        when: DateTime(2026, 9, 14, 12),
        end: DateTime(2026, 9, 14, 14),
      );
      expect(agendaTimeLabel(amTag(14, appointments: [kurz]).single),
          '12:00 Uhr');
      expect(appointmentRangeLabel(kurz), '12:00 – 14:00 Uhr');
    });

    test('die Spanne nennt ueber mehrere Tage beide Tage', () {
      expect(
        appointmentRangeLabel(lang()),
        'Mo, 14. Sep 12:00 – Do, 17. Sep 18:00',
      );
      expect(
        appointmentRangeLabel(
          Appointment(id: 'p', title: 'Punkt', when: DateTime(2026, 9, 14, 9)),
        ),
        '09:00 Uhr',
      );
    });

    test('appointmentDayLabel redet wie das Dashboard', () {
      for (final day in [14, 15, 16, 17]) {
        expect(
          appointmentDayLabel(lang(), DateTime(2026, 9, day, 10, 30)),
          agendaTimeLabel(amTag(day).single),
          reason: 'Tag $day',
        );
      }
    });

    test('Terminliste: relativer Tag nur ohne mehrere Tage', () {
      final heute = today();
      final kurz = Appointment(
        id: 'k',
        title: 'Mittag',
        when: heute.add(const Duration(hours: 12)),
        end: heute.add(const Duration(hours: 14)),
      );
      expect(appointmentListLabel(kurz), 'Heute · 12:00 – 14:00 Uhr');
      final punkt = Appointment(
        id: 'p',
        title: 'Punkt',
        when: heute.add(const Duration(hours: 9)),
      );
      expect(appointmentListLabel(punkt), 'Heute · 09:00 Uhr');
      expect(appointmentListLabel(lang()), appointmentRangeLabel(lang()));
    });

    test('Geraete-Termine: Dashboard und Kalender sagen dasselbe', () {
      // 13.8. 18:00 bis 15.8. 09:00. Die beiden Beschriftungen stehen in
      // zwei Dateien; auseinanderlaufen duerfen sie nicht.
      final e = device('umzug',
          start: DateTime(2026, 8, 13, 18), end: DateTime(2026, 8, 15, 9));
      for (final day in [13, 14, 15]) {
        final d = DateTime(2026, 8, day);
        final entry = agendaForDay(
          d,
          appointments: const [],
          deviceEvents: [e],
          deviceColor: fallback,
        ).single;
        expect(agendaTimeLabel(entry), deviceEventTimeLabel(e, d),
            reason: 'Tag $day');
      }
    });
  });
}
