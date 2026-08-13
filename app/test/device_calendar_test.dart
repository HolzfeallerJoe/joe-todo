import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/device_calendar.dart';

/// Die Tag-Zuordnung der Geraete-Termine ist reine Logik und laeuft ohne
/// Plugin: [eventCoversDay] entscheidet, auf welchen Kalendertagen ein
/// Termin erscheint.
void main() {
  Event event({
    required DateTime start,
    required DateTime end,
    bool allDay = false,
  }) =>
      Event(
        eventId: 'e1',
        instanceId: 'i1',
        calendarId: 'c1',
        title: 'Termin',
        startDate: start,
        endDate: end,
        isAllDay: allDay,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

  test('Termin mit Uhrzeit gehoert nur auf seinen Tag', () {
    final e = event(
      start: DateTime(2026, 8, 13, 10),
      end: DateTime(2026, 8, 13, 11),
    );
    expect(eventCoversDay(e, DateTime(2026, 8, 13)), isTrue);
    expect(eventCoversDay(e, DateTime(2026, 8, 12)), isFalse);
    expect(eventCoversDay(e, DateTime(2026, 8, 14)), isFalse);
  });

  test('Ende um Mitternacht zaehlt nicht auf den Folgetag', () {
    final e = event(
      start: DateTime(2026, 8, 13, 22),
      end: DateTime(2026, 8, 14),
    );
    expect(eventCoversDay(e, DateTime(2026, 8, 13)), isTrue);
    expect(eventCoversDay(e, DateTime(2026, 8, 14)), isFalse);
  });

  test('mehrtaegiger Termin erscheint auf jedem beruehrten Tag', () {
    final e = event(
      start: DateTime(2026, 8, 13, 18),
      end: DateTime(2026, 8, 15, 9),
    );
    for (final day in [13, 14, 15]) {
      expect(eventCoversDay(e, DateTime(2026, 8, day)), isTrue,
          reason: 'Tag $day');
    }
    expect(eventCoversDay(e, DateTime(2026, 8, 16)), isFalse);
  });

  test('ganztaegig: UTC-Mitternacht bis exklusive UTC-Mitternacht', () {
    // So legt der Android Calendar Provider ganztaegige Termine ab. Die
    // Zuordnung darf nicht durch die lokale Zeitzone verrutschen.
    final e = event(
      start: DateTime.utc(2026, 8, 13),
      end: DateTime.utc(2026, 8, 14),
      allDay: true,
    );
    expect(eventCoversDay(e, DateTime(2026, 8, 13)), isTrue);
    expect(eventCoversDay(e, DateTime(2026, 8, 12)), isFalse);
    expect(eventCoversDay(e, DateTime(2026, 8, 14)), isFalse);
  });

  test('ganztaegig ueber mehrere Tage', () {
    final e = event(
      start: DateTime.utc(2026, 12, 24),
      end: DateTime.utc(2026, 12, 27),
      allDay: true,
    );
    for (final day in [24, 25, 26]) {
      expect(eventCoversDay(e, DateTime(2026, 12, day)), isTrue,
          reason: 'Tag $day');
    }
    expect(eventCoversDay(e, DateTime(2026, 12, 27)), isFalse);
  });

  test('Uhrzeit-Beschriftung', () {
    expect(
      deviceEventTimeLabel(event(
        start: DateTime(2026, 8, 13, 9, 5),
        end: DateTime(2026, 8, 13, 10),
      )),
      '09:05 Uhr',
    );
    expect(
      deviceEventTimeLabel(event(
        start: DateTime.utc(2026, 8, 13),
        end: DateTime.utc(2026, 8, 14),
        allDay: true,
      )),
      'ganztägig',
    );
  });
}
