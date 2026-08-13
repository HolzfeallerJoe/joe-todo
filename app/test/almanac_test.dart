import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/almanac.dart';
import 'package:joe_todo/util.dart';

/// Feiertage und Mondphasen sind reine Rechnung – hier gegen bekannte
/// Kalenderdaten geprueft. Die Mondzeiten stammen aus einem astronomischen
/// Referenzkalender fuer 2026 (kalender-365.eu, Angaben in deutscher
/// Ortszeit, hier nach UTC umgerechnet).
void main() {
  group('Ostern (Gauss-Formel)', () {
    test('bekannte Osterdaten', () {
      expect(easterSunday(2024), DateTime(2024, 3, 31));
      expect(easterSunday(2025), DateTime(2025, 4, 20));
      expect(easterSunday(2026), DateTime(2026, 4, 5));
      expect(easterSunday(2027), DateTime(2027, 3, 28));
      // Extremfaelle: fruehestes und spaetestes Ostern der Umgebung.
      expect(easterSunday(2008), DateTime(2008, 3, 23));
      expect(easterSunday(2038), DateTime(2038, 4, 25));
    });
  });

  group('Feiertage', () {
    test('bundesweite Feiertage gelten ueberall', () {
      for (final region in HolidayRegion.values) {
        expect(holidaysOn(DateTime(2026, 1, 1), region), ['Neujahr']);
        expect(holidaysOn(DateTime(2026, 10, 3), region),
            ['Tag der Deutschen Einheit']);
        expect(holidaysOn(DateTime(2026, 4, 3), region), ['Karfreitag']);
      }
    });

    test('Bundesweit zeigt nur die neun ueberall gueltigen', () {
      var count = 0;
      for (var d = DateTime(2026, 1, 1);
          d.year == 2026;
          d = d.add(const Duration(days: 1))) {
        count += holidaysOn(d, HolidayRegion.bund).length;
      }
      expect(count, 9);
    });

    test('Laender-Feiertage nur im richtigen Land', () {
      // Fronleichnam 2026: 60 Tage nach Ostern (5.4.) ist der 4.6.
      final fronleichnam = DateTime(2026, 6, 4);
      expect(holidaysOn(fronleichnam, HolidayRegion.by), ['Fronleichnam']);
      expect(holidaysOn(fronleichnam, HolidayRegion.be), isEmpty);
      expect(holidaysOn(fronleichnam, HolidayRegion.bund), isEmpty);

      expect(holidaysOn(DateTime(2026, 10, 31), HolidayRegion.sn),
          ['Reformationstag']);
      expect(holidaysOn(DateTime(2026, 11, 1), HolidayRegion.by),
          ['Allerheiligen']);
      expect(holidaysOn(DateTime(2026, 11, 1), HolidayRegion.sn), isEmpty);
      expect(holidaysOn(DateTime(2026, 3, 8), HolidayRegion.be),
          ['Internationaler Frauentag']);
      expect(holidaysOn(DateTime(2026, 8, 15), HolidayRegion.sl),
          ['Mariä Himmelfahrt']);
    });

    test('Buss- und Bettag ist der Mittwoch vor dem 23. November', () {
      expect(holidaysOn(DateTime(2026, 11, 18), HolidayRegion.sn),
          ['Buß- und Bettag']);
      expect(holidaysOn(DateTime(2025, 11, 19), HolidayRegion.sn),
          ['Buß- und Bettag']);
      // Und nur in Sachsen.
      expect(holidaysOn(DateTime(2026, 11, 18), HolidayRegion.by), isEmpty);
    });

    test('2008: Himmelfahrt faellt auf den Tag der Arbeit', () {
      expect(holidaysOn(DateTime(2008, 5, 1), HolidayRegion.bund),
          ['Tag der Arbeit', 'Christi Himmelfahrt']);
    });
  });

  group('Mondphasen', () {
    // Referenzzeiten 2026, von deutscher Ortszeit (CET/CEST) nach UTC
    // umgerechnet. Toleranz drei Minuten – die Quellen runden verschieden.
    const tolerance = Duration(minutes: 3);

    void expectEvent(MoonPhaseKind kind, DateTime expectedUtc) {
      final events = moonEventsBetween(
        expectedUtc.subtract(const Duration(hours: 12)),
        expectedUtc.add(const Duration(hours: 12)),
      ).where((e) => e.kind == kind).toList();
      expect(events, hasLength(1),
          reason: 'genau ein $kind nahe $expectedUtc erwartet');
      final diff = events.single.timeUtc.difference(expectedUtc).abs();
      expect(diff, lessThanOrEqualTo(tolerance),
          reason: '$kind: ${events.single.timeUtc} vs. $expectedUtc');
    }

    test('Referenzzeiten 2026 (UTC)', () {
      expectEvent(MoonPhaseKind.fullMoon, DateTime.utc(2026, 1, 3, 10, 4));
      expectEvent(MoonPhaseKind.lastQuarter, DateTime.utc(2026, 1, 10, 15, 49));
      expectEvent(MoonPhaseKind.newMoon, DateTime.utc(2026, 1, 18, 19, 53));
      expectEvent(MoonPhaseKind.firstQuarter, DateTime.utc(2026, 1, 26, 4, 48));
      // Sommerzeit (CEST = UTC+2):
      expectEvent(MoonPhaseKind.fullMoon, DateTime.utc(2026, 6, 29, 23, 58));
      expectEvent(MoonPhaseKind.newMoon, DateTime.utc(2026, 8, 12, 17, 37));
      expectEvent(MoonPhaseKind.firstQuarter, DateTime.utc(2026, 8, 20, 2, 46));
      expectEvent(MoonPhaseKind.fullMoon, DateTime.utc(2026, 8, 28, 4, 19));
      expectEvent(
          MoonPhaseKind.lastQuarter, DateTime.utc(2026, 10, 3, 13, 26));
      // Nach dem Ende der Sommerzeit (25.10.) wieder CET = UTC+1:
      expectEvent(MoonPhaseKind.fullMoon, DateTime.utc(2026, 10, 26, 4, 13));
      expectEvent(MoonPhaseKind.fullMoon, DateTime.utc(2026, 12, 24, 1, 29));
      expectEvent(
          MoonPhaseKind.lastQuarter, DateTime.utc(2026, 12, 30, 19, 0));
    });

    test('2026 hat 50 Hauptphasen', () {
      final events = moonEventsBetween(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 12, 31, 23, 59, 59),
      );
      expect(events, hasLength(50));
      // Die Phasen wechseln sich in fester Reihenfolge ab.
      const order = [
        MoonPhaseKind.newMoon,
        MoonPhaseKind.firstQuarter,
        MoonPhaseKind.fullMoon,
        MoonPhaseKind.lastQuarter,
      ];
      for (var i = 1; i < events.length; i++) {
        expect(events[i].kind,
            order[(order.indexOf(events[i - 1].kind) + 1) % 4]);
      }
    });

    test('moonPhaseOnDay findet den lokalen Kalendertag der Phase', () {
      // Zeitzonenfest: der erwartete Tag wird aus dem Ereignis selbst
      // abgeleitet, statt einen lokalen Tag fest zu verdrahten.
      final events = moonEventsBetween(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 4, 30),
      );
      expect(events, isNotEmpty);
      for (final event in events) {
        final localDay = dateOnly(event.timeUtc.toLocal());
        expect(moonPhaseOnDay(localDay), event.kind);
      }
    });

    test('Tage ohne Hauptphase bleiben leer', () {
      // Zwischen zwei Phasen liegen gut sieben Tage; der Tag drei Tage nach
      // einer Phase gehoert sicher zu keiner.
      final events = moonEventsBetween(
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 31),
      );
      final localDay =
          dateOnly(events.first.timeUtc.toLocal()).add(const Duration(days: 3));
      expect(moonPhaseOnDay(localDay), isNull);
    });
  });
}
