import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/agenda.dart';
import 'package:joe_todo/models.dart';

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
          device('feiertag',
              start: t.toUtc(),
              end: t.add(const Duration(days: 1)).toUtc(),
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
}
