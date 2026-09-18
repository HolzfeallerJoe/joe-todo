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

  // Ganztaegige Termine baut dieser Test so, wie das Plugin sie *liefert*:
  // als lokale Mitternacht, Ende exklusiv auf der Mitternacht nach dem
  // letzten Tag. Der Provider speichert sie zwar auf UTC-Mitternacht, aber
  // device_calendar_plus_android (0.7.1) rechnet sie mit `utcToLocalMidnight`
  // schon selbst um. Frueher bauten die Tests sie mit DateTime.utc – so, wie
  // Joe sie faelschlich erwartete – und merkten die doppelte Umrechnung nicht.

  test('ganztaegig: lokale Mitternacht bis exklusive lokale Mitternacht', () {
    final e = event(
      start: DateTime(2026, 8, 13),
      end: DateTime(2026, 8, 14),
      allDay: true,
    );
    expect(eventCoversDay(e, DateTime(2026, 8, 13)), isTrue);
    expect(eventCoversDay(e, DateTime(2026, 8, 12)), isFalse);
    expect(eventCoversDay(e, DateTime(2026, 8, 14)), isFalse);
  });

  test('ganztaegig: steht nur auf seinem Tag, auch oestlich von UTC', () {
    // Laeuft bewusst in der Zeitzone des Rechners (unter Windows ignoriert
    // Dart TZ). Der alte Code rechnete den lokalen Start noch einmal nach
    // UTC um: in Europe/Berlin wurde aus "18.9. 00:00" dann "17.9. 22:00",
    // der Termin stand am 17. *und* 18. Auf dem Entwicklerrechner schlaegt
    // dieser Test mit dem alten Code fehl; die CI (UTC) haette den Fehler
    // nie gezeigt. Mit dem neuen Code ist er in jeder Zeitzone gruen.
    final e = event(
      start: DateTime(2026, 9, 18),
      end: DateTime(2026, 9, 19),
      allDay: true,
    );
    final covered = [
      for (var day = 15; day <= 21; day++)
        if (eventCoversDay(e, DateTime(2026, 9, day))) day,
    ];
    expect(covered, [18]);
  });

  test('ganztaegig ohne +1-Tag-Konvention (Ende == Start) ist ein Tag', () {
    final e = event(
      start: DateTime(2026, 8, 13),
      end: DateTime(2026, 8, 13),
      allDay: true,
    );
    expect(eventCoversDay(e, DateTime(2026, 8, 13)), isTrue);
    expect(eventCoversDay(e, DateTime(2026, 8, 12)), isFalse);
    expect(eventCoversDay(e, DateTime(2026, 8, 14)), isFalse);
  });

  test('ganztaegig ueber mehrere Tage', () {
    final e = event(
      start: DateTime(2026, 12, 24),
      end: DateTime(2026, 12, 27),
      allDay: true,
    );
    for (final day in [24, 25, 26]) {
      expect(eventCoversDay(e, DateTime(2026, 12, day)), isTrue,
          reason: 'Tag $day');
    }
    expect(eventCoversDay(e, DateTime(2026, 12, 23)), isFalse);
    expect(eventCoversDay(e, DateTime(2026, 12, 27)), isFalse);
  });

  test('Uhrzeit-Beschriftung', () {
    expect(
      deviceEventTimeLabel(
        event(
          start: DateTime(2026, 8, 13, 9, 5),
          end: DateTime(2026, 8, 13, 10),
        ),
        DateTime(2026, 8, 13),
      ),
      '09:05 Uhr',
    );
    expect(
      deviceEventTimeLabel(
        event(
          start: DateTime(2026, 8, 13),
          end: DateTime(2026, 8, 14),
          allDay: true,
        ),
        DateTime(2026, 8, 13),
      ),
      'ganztägig',
    );
  });

  test('mehrtaegiger Termin: Starttag mit Uhrzeit, Folgetage ganztaegig', () {
    // Frueher stand im Tagesdetail an jedem Folgetag die Startuhrzeit, weil
    // die Beschriftung den Tag nicht kannte.
    final e = event(
      start: DateTime(2026, 8, 13, 18),
      end: DateTime(2026, 8, 15, 9),
    );
    expect(deviceEventTimeLabel(e, DateTime(2026, 8, 13)), '18:00 Uhr');
    expect(deviceEventTimeLabel(e, DateTime(2026, 8, 14)), 'ganztägig');
    expect(deviceEventTimeLabel(e, DateTime(2026, 8, 15)), 'ganztägig');
  });

  test('Beschriftung: der Tag darf eine Uhrzeit tragen', () {
    // Der Kalender reicht seinen ausgewaehlten Tag durch; ob der auf
    // Mitternacht steht, darf fuer den Vergleich keine Rolle spielen.
    final e = event(
      start: DateTime(2026, 8, 13, 18),
      end: DateTime(2026, 8, 13, 19),
    );
    expect(
      deviceEventTimeLabel(e, DateTime(2026, 8, 13, 12, 30)),
      '18:00 Uhr',
    );
  });
}
