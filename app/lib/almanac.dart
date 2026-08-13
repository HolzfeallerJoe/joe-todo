import 'dart:math' as math;

import 'util.dart';

/// Berechnete Kalender-Ebenen: gesetzliche Feiertage und Mondphasen.
///
/// Alles hier ist reine Rechnung – kein Netz, keine Berechtigung, kein
/// gespeicherter Bestand. Der Kalender fragt pro Tag nach, die Antworten
/// kommen aus der Osterformel bzw. dem Mondphasen-Algorithmus von Meeus.

// ---- Feiertage ----

/// Bundesweit oder eines der 16 Bundeslaender. "Bundesweit" zeigt nur die
/// neun Feiertage, die ueberall gelten – der sichere Standard, solange kein
/// Land gewaehlt ist.
enum HolidayRegion {
  bund('Bundesweit'),
  bw('Baden-Württemberg'),
  by('Bayern'),
  be('Berlin'),
  bb('Brandenburg'),
  hb('Bremen'),
  hh('Hamburg'),
  he('Hessen'),
  mv('Mecklenburg-Vorpommern'),
  ni('Niedersachsen'),
  nw('Nordrhein-Westfalen'),
  rp('Rheinland-Pfalz'),
  sl('Saarland'),
  sn('Sachsen'),
  st('Sachsen-Anhalt'),
  sh('Schleswig-Holstein'),
  th('Thüringen');

  final String label;
  const HolidayRegion(this.label);

  static HolidayRegion fromJson(Object? value) => HolidayRegion.values
      .firstWhere((r) => r.name == value, orElse: () => HolidayRegion.bund);
}

/// Ostersonntag nach der anonymen gregorianischen Gauss-Formel.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

class _Holiday {
  final DateTime date;
  final String name;

  /// null bedeutet: gilt bundesweit.
  final Set<HolidayRegion>? regions;

  const _Holiday(this.date, this.name, [this.regions]);
}

final _holidayCache = <int, List<_Holiday>>{};

List<_Holiday> _holidaysOfYear(int year) => _holidayCache.putIfAbsent(year, () {
      final easter = easterSunday(year);
      // dateOnly, weil die Addition ueber die Sommerzeit-Umstellung laufen
      // kann – dann steht sonst 01:00 statt Mitternacht im Datum.
      DateTime fromEaster(int days) =>
          dateOnly(easter.add(Duration(days: days)));
      // Buss- und Bettag: der Mittwoch vor dem 23. November.
      final nov22 = DateTime(year, 11, 22);
      final bussUndBettag = dateOnly(nov22
          .subtract(Duration(days: (nov22.weekday - DateTime.wednesday) % 7)));
      return [
        _Holiday(DateTime(year, 1, 1), 'Neujahr'),
        _Holiday(DateTime(year, 1, 6), 'Heilige Drei Könige',
            {HolidayRegion.bw, HolidayRegion.by, HolidayRegion.st}),
        _Holiday(DateTime(year, 3, 8), 'Internationaler Frauentag',
            {HolidayRegion.be, HolidayRegion.mv}),
        _Holiday(fromEaster(-2), 'Karfreitag'),
        _Holiday(fromEaster(0), 'Ostersonntag', {HolidayRegion.bb}),
        _Holiday(fromEaster(1), 'Ostermontag'),
        _Holiday(DateTime(year, 5, 1), 'Tag der Arbeit'),
        _Holiday(fromEaster(39), 'Christi Himmelfahrt'),
        _Holiday(fromEaster(49), 'Pfingstsonntag', {HolidayRegion.bb}),
        _Holiday(fromEaster(50), 'Pfingstmontag'),
        _Holiday(fromEaster(60), 'Fronleichnam', {
          HolidayRegion.bw, HolidayRegion.by, HolidayRegion.he,
          HolidayRegion.nw, HolidayRegion.rp, HolidayRegion.sl,
        }),
        // In Bayern nur in ueberwiegend katholischen Gemeinden gesetzlich –
        // das sind die allermeisten, darum zeigt der Kalender ihn landesweit.
        _Holiday(DateTime(year, 8, 15), 'Mariä Himmelfahrt',
            {HolidayRegion.by, HolidayRegion.sl}),
        _Holiday(DateTime(year, 9, 20), 'Weltkindertag', {HolidayRegion.th}),
        _Holiday(DateTime(year, 10, 3), 'Tag der Deutschen Einheit'),
        _Holiday(DateTime(year, 10, 31), 'Reformationstag', {
          HolidayRegion.bb, HolidayRegion.hb, HolidayRegion.hh,
          HolidayRegion.mv, HolidayRegion.ni, HolidayRegion.sn,
          HolidayRegion.st, HolidayRegion.sh, HolidayRegion.th,
        }),
        _Holiday(DateTime(year, 11, 1), 'Allerheiligen', {
          HolidayRegion.bw, HolidayRegion.by, HolidayRegion.nw,
          HolidayRegion.rp, HolidayRegion.sl,
        }),
        _Holiday(bussUndBettag, 'Buß- und Bettag', {HolidayRegion.sn}),
        _Holiday(DateTime(year, 12, 25), '1. Weihnachtstag'),
        _Holiday(DateTime(year, 12, 26), '2. Weihnachtstag'),
      ];
    });

/// Die gesetzlichen Feiertage, die in [region] auf [day] fallen. Fast immer
/// hoechstens einer – aber Himmelfahrt kann auf den 1. Mai fallen (2008),
/// darum eine Liste.
List<String> holidaysOn(DateTime day, HolidayRegion region) {
  final d = dateOnly(day);
  return [
    for (final h in _holidaysOfYear(d.year))
      if (h.date == d &&
          (h.regions == null ||
              (region != HolidayRegion.bund && h.regions!.contains(region))))
        h.name,
  ];
}

// ---- Mondphasen ----

enum MoonPhaseKind {
  newMoon('Neumond'),
  firstQuarter('Zunehmender Halbmond'),
  fullMoon('Vollmond'),
  lastQuarter('Abnehmender Halbmond');

  final String label;
  const MoonPhaseKind(this.label);
}

/// Eine Hauptphase mit ihrem Zeitpunkt in UTC. Auf welchen Kalendertag sie
/// faellt, entscheidet erst die lokale Zeitzone – siehe [moonPhaseOnDay].
class MoonEvent {
  final MoonPhaseKind kind;
  final DateTime timeUtc;
  const MoonEvent(this.kind, this.timeUtc);
}

double _sinDeg(double deg) => math.sin(deg * math.pi / 180);
double _cosDeg(double deg) => math.cos(deg * math.pi / 180);

/// Julianisches Datum (Ephemeridenzeit) der Hauptphase Nummer [k]:
/// ganzzahliges k ist Neumond, +0.25 zunehmender Halbmond, +0.5 Vollmond,
/// +0.75 abnehmender Halbmond. Meeus, "Astronomical Algorithms", Kap. 49 –
/// mit allen Korrekturtermen, damit die Zeiten auf ~1 Minute stimmen.
double _truePhaseJde(double k) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;

  var jde = 2451550.09766 +
      29.530588861 * k +
      0.00015437 * t2 -
      0.000000150 * t3 +
      0.00000000073 * t4;

  final e = 1 - 0.002516 * t - 0.0000074 * t2;

  // Mittlere Anomalien von Sonne (m) und Mond (ms), Breitenargument f,
  // aufsteigender Knoten omega – alles in Grad.
  final m = 2.5534 + 29.10535670 * k - 0.0000014 * t2 - 0.00000011 * t3;
  final ms = 201.5643 +
      385.81693528 * k +
      0.0107582 * t2 +
      0.00001238 * t3 -
      0.000000058 * t4;
  final f = 160.7108 +
      390.67050284 * k -
      0.0016118 * t2 -
      0.00000227 * t3 +
      0.000000011 * t4;
  final omega = 124.7746 - 1.56375588 * k + 0.0020672 * t2 + 0.00000215 * t3;

  final phase = ((k % 1) + 1) % 1;
  double corr;
  if (phase < 0.01 || phase > 0.99) {
    // Neumond
    corr = -0.40720 * _sinDeg(ms) +
        0.17241 * e * _sinDeg(m) +
        0.01608 * _sinDeg(2 * ms) +
        0.01039 * _sinDeg(2 * f) +
        0.00739 * e * _sinDeg(ms - m) -
        0.00514 * e * _sinDeg(ms + m) +
        0.00208 * e * e * _sinDeg(2 * m) -
        0.00111 * _sinDeg(ms - 2 * f) -
        0.00057 * _sinDeg(ms + 2 * f) +
        0.00056 * e * _sinDeg(2 * ms + m) -
        0.00042 * _sinDeg(3 * ms) +
        0.00042 * e * _sinDeg(m + 2 * f) +
        0.00038 * e * _sinDeg(m - 2 * f) -
        0.00024 * e * _sinDeg(2 * ms - m) -
        0.00017 * _sinDeg(omega) -
        0.00007 * _sinDeg(ms + 2 * m) +
        0.00004 * _sinDeg(2 * ms - 2 * f) +
        0.00004 * _sinDeg(3 * m) +
        0.00003 * _sinDeg(ms + m - 2 * f) +
        0.00003 * _sinDeg(2 * ms + 2 * f) -
        0.00003 * _sinDeg(ms + m + 2 * f) +
        0.00003 * _sinDeg(ms - m + 2 * f) -
        0.00002 * _sinDeg(ms - m - 2 * f) -
        0.00002 * _sinDeg(3 * ms + m) +
        0.00002 * _sinDeg(4 * ms);
  } else if ((phase - 0.5).abs() < 0.01) {
    // Vollmond – gleiche Terme wie Neumond, leicht andere Koeffizienten.
    corr = -0.40614 * _sinDeg(ms) +
        0.17302 * e * _sinDeg(m) +
        0.01614 * _sinDeg(2 * ms) +
        0.01043 * _sinDeg(2 * f) +
        0.00734 * e * _sinDeg(ms - m) -
        0.00515 * e * _sinDeg(ms + m) +
        0.00209 * e * e * _sinDeg(2 * m) -
        0.00111 * _sinDeg(ms - 2 * f) -
        0.00057 * _sinDeg(ms + 2 * f) +
        0.00056 * e * _sinDeg(2 * ms + m) -
        0.00042 * _sinDeg(3 * ms) +
        0.00042 * e * _sinDeg(m + 2 * f) +
        0.00038 * e * _sinDeg(m - 2 * f) -
        0.00024 * e * _sinDeg(2 * ms - m) -
        0.00017 * _sinDeg(omega) -
        0.00007 * _sinDeg(ms + 2 * m) +
        0.00004 * _sinDeg(2 * ms - 2 * f) +
        0.00004 * _sinDeg(3 * m) +
        0.00003 * _sinDeg(ms + m - 2 * f) +
        0.00003 * _sinDeg(2 * ms + 2 * f) -
        0.00003 * _sinDeg(ms + m + 2 * f) +
        0.00003 * _sinDeg(ms - m + 2 * f) -
        0.00002 * _sinDeg(ms - m - 2 * f) -
        0.00002 * _sinDeg(3 * ms + m) +
        0.00002 * _sinDeg(4 * ms);
  } else {
    // Halbmonde
    corr = -0.62801 * _sinDeg(ms) +
        0.17172 * e * _sinDeg(m) -
        0.01183 * e * _sinDeg(ms + m) +
        0.00862 * _sinDeg(2 * ms) +
        0.00804 * _sinDeg(2 * f) +
        0.00454 * e * _sinDeg(ms - m) +
        0.00204 * e * e * _sinDeg(2 * m) -
        0.00180 * _sinDeg(ms - 2 * f) -
        0.00070 * _sinDeg(ms + 2 * f) -
        0.00040 * _sinDeg(3 * ms) -
        0.00034 * e * _sinDeg(2 * ms - m) +
        0.00032 * e * _sinDeg(m + 2 * f) +
        0.00032 * e * _sinDeg(m - 2 * f) -
        0.00028 * e * e * _sinDeg(ms + 2 * m) +
        0.00027 * e * _sinDeg(2 * ms + m) -
        0.00017 * _sinDeg(omega) -
        0.00005 * _sinDeg(ms - m - 2 * f) +
        0.00004 * _sinDeg(2 * ms + 2 * f) -
        0.00004 * _sinDeg(ms + m + 2 * f) +
        0.00004 * _sinDeg(ms - 2 * m) +
        0.00003 * _sinDeg(ms + m - 2 * f) +
        0.00003 * _sinDeg(3 * m) +
        0.00002 * _sinDeg(2 * ms - 2 * f) +
        0.00002 * _sinDeg(ms - m + 2 * f) -
        0.00002 * _sinDeg(3 * ms + m);
    // Der Halbmond haengt zusaetzlich davon ab, ob er zu- oder abnimmt.
    final w = 0.00306 -
        0.00038 * e * _cosDeg(m) +
        0.00026 * _cosDeg(ms) -
        0.00002 * _cosDeg(ms - m) +
        0.00002 * _cosDeg(ms + m) +
        0.00002 * _cosDeg(2 * f);
    corr += (phase - 0.5).isNegative ? w : -w;
  }

  // Planetare Zusatzterme (Meeus Tab. 49.1) – zusammen bis zu ~1 Minute.
  final planetary = 0.000325 * _sinDeg(299.77 + 0.107408 * k - 0.009173 * t2) +
      0.000165 * _sinDeg(251.88 + 0.016321 * k) +
      0.000164 * _sinDeg(251.83 + 26.651886 * k) +
      0.000126 * _sinDeg(349.42 + 36.412478 * k) +
      0.000110 * _sinDeg(84.66 + 18.206239 * k) +
      0.000062 * _sinDeg(141.74 + 53.303771 * k) +
      0.000060 * _sinDeg(207.14 + 2.453732 * k) +
      0.000056 * _sinDeg(154.84 + 7.306860 * k) +
      0.000047 * _sinDeg(34.52 + 27.261239 * k) +
      0.000042 * _sinDeg(207.19 + 0.121824 * k) +
      0.000040 * _sinDeg(291.34 + 1.844379 * k) +
      0.000037 * _sinDeg(161.72 + 24.198154 * k) +
      0.000035 * _sinDeg(239.56 + 25.513099 * k) +
      0.000023 * _sinDeg(331.55 + 3.592518 * k);

  return jde + corr + planetary;
}

/// Ephemeridenzeit -> UTC. Delta-T liegt seit 2016 fast unveraendert bei
/// ~69 Sekunden; fuer Kalendertage ist die Naeherung mehr als genau genug.
DateTime _jdeToUtc(double jde) {
  const deltaTDays = 69.0 / 86400.0;
  final unixMillis = ((jde - deltaTDays - 2440587.5) * 86400000).round();
  return DateTime.fromMillisecondsSinceEpoch(unixMillis, isUtc: true);
}

/// Alle Hauptphasen zwischen [fromUtc] und [toUtc] (beide einschliesslich),
/// zeitlich sortiert.
List<MoonEvent> moonEventsBetween(DateTime fromUtc, DateTime toUtc) {
  const kinds = [
    MoonPhaseKind.newMoon,
    MoonPhaseKind.firstQuarter,
    MoonPhaseKind.fullMoon,
    MoonPhaseKind.lastQuarter,
  ];
  // k grob aus dem Datum schaetzen, dann grosszuegig um den Bereich herum
  // rechnen – der Filter unten wirft weg, was danebenliegt.
  double kNear(DateTime d) =>
      (d.millisecondsSinceEpoch / 86400000 + 2440587.5 - 2451550.09766) /
      29.530588861;
  final kStart = kNear(fromUtc).floor() - 1;
  final kEnd = kNear(toUtc).ceil() + 1;

  final events = <MoonEvent>[];
  for (var k = kStart; k <= kEnd; k++) {
    for (var q = 0; q < 4; q++) {
      final time = _jdeToUtc(_truePhaseJde(k + q * 0.25));
      if (!time.isBefore(fromUtc) && !time.isAfter(toUtc)) {
        events.add(MoonEvent(kinds[q], time));
      }
    }
  }
  events.sort((a, b) => a.timeUtc.compareTo(b.timeUtc));
  return events;
}

/// Merkt sich pro Kalendertag (lokale Zeit), welche Hauptphase auf ihn
/// faellt – der Monatsraster fragt jede Zelle einzeln an.
final _moonDayCache = <String, MoonPhaseKind?>{};

/// Die Hauptphase, die (in lokaler Zeit) auf den Kalendertag [day] faellt,
/// oder null. Nur die vier Phasentage tragen einen Mond – ein Mond an jedem
/// Tag wuerde den Kalender fluten.
MoonPhaseKind? moonPhaseOnDay(DateTime day) {
  final d = dateOnly(day);
  return _moonDayCache.putIfAbsent(dateKey(d), () {
    // Zwei Tage Rand: die lokale Zeitzone kann eine Phase ueber die
    // UTC-Tagesgrenze schieben.
    final from = d.subtract(const Duration(days: 2)).toUtc();
    final to = d.add(const Duration(days: 3)).toUtc();
    for (final event in moonEventsBetween(from, to)) {
      if (dateOnly(event.timeUtc.toLocal()) == d) return event.kind;
    }
    return null;
  });
}
