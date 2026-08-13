import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';

// Der Kalender-Screen braucht den Event-Typ, soll aber nur diese Datei
// kennen muessen – das Plugin bleibt hier gekapselt.
export 'package:device_calendar_plus/device_calendar_plus.dart' show Event;

import 'log.dart';
import 'util.dart';

/// Die Kalender des Geraets (Android Calendar Provider) als eigene,
/// nur lesende Ebene im In-App-Kalender: alles, was die Google-Kalender-App
/// synchronisiert (Gmail-Termine, abonnierte Kalender), liegt dort bereits
/// lokal – Joe selbst spricht weiterhin nicht ins Netz.
///
/// Grundsaetze:
/// - Nichts hier darf die App stoeren: jeder Plugin-Aufruf ist gefangen,
///   auf Plattformen ohne Kalender (Web, Desktop) bleibt die Ebene leer.
/// - Nichts wird gespeichert – der Bestand gehoert dem System, Joe zeigt
///   ihn nur an. Gecacht wird pro Monat, solange die App laeuft.
class DeviceCalendarFeed extends ChangeNotifier {
  DeviceCalendarFeed._();
  static final DeviceCalendarFeed instance = DeviceCalendarFeed._();

  /// Termine pro Monat ('yyyy-mm'); null heisst: Abruf laeuft gerade.
  final Map<String, List<Event>?> _monthCache = {};

  static String _monthKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}';

  /// Fragt die Kalender-Berechtigung an (zeigt beim ersten Mal den
  /// System-Dialog). false auch dann, wenn es auf dieser Plattform gar
  /// keinen Geraete-Kalender gibt.
  Future<bool> ensurePermission() async {
    try {
      final status = await DeviceCalendar.instance.requestPermissions();
      final granted = status == CalendarPermissionStatus.granted;
      JoeLog.log('Geraete-Kalender: Berechtigung ${granted ? 'da' : 'fehlt'}');
      return granted;
    } catch (e) {
      JoeLog.log('Geraete-Kalender: Berechtigungsanfrage fehlgeschlagen: $e');
      return false;
    }
  }

  /// Oeffnet die App-Einstellungen des Systems – der Weg zurueck, wenn die
  /// Berechtigung einmal dauerhaft abgelehnt wurde.
  Future<void> openSystemSettings() async {
    try {
      await DeviceCalendar.instance.openAppSettings();
    } catch (e) {
      JoeLog.log('Geraete-Kalender: App-Einstellungen nicht erreichbar: $e');
    }
  }

  /// Die Geraete-Termine, die (lokale Zeit) den Tag [day] beruehren.
  /// Ist der Monat noch nicht geladen, kommt erst einmal eine leere Liste
  /// und der Abruf startet; danach meldet sich [notifyListeners].
  List<Event> eventsForDay(DateTime day) {
    final d = dateOnly(day);
    final key = _monthKey(d);
    if (!_monthCache.containsKey(key)) {
      _monthCache[key] = null;
      _loadMonth(key, DateTime(d.year, d.month));
    }
    final events = _monthCache[key];
    if (events == null) return const [];
    return [
      for (final e in events)
        if (eventCoversDay(e, d)) e,
    ];
  }

  Future<void> _loadMonth(String key, DateTime monthStart) async {
    try {
      // Eine Woche Rand in beide Richtungen: mehrtaegige Termine, die vor
      // dem Monatsersten beginnen, gehoeren auch auf ihre Tage im Monat.
      final events = await DeviceCalendar.instance.listEvents(
        monthStart.subtract(const Duration(days: 7)),
        DateTime(monthStart.year, monthStart.month + 1, 7),
      );
      _monthCache[key] = events;
      JoeLog.log('Geraete-Kalender: ${events.length} Termine fuer $key');
      notifyListeners();
    } catch (e) {
      // Kein Plugin (Web/Desktop), Berechtigung entzogen, was auch immer –
      // die Ebene bleibt leer und der Kalender laeuft ungestoert weiter.
      _monthCache[key] = const [];
      JoeLog.log('Geraete-Kalender: Abruf fuer $key fehlgeschlagen: $e');
    }
  }

  /// Vergessen, was geladen war – beim Abschalten in den Einstellungen und
  /// als Auffrischen beim naechsten Anschalten.
  void clear() {
    _monthCache.clear();
    notifyListeners();
  }
}

/// Ob [event] den Kalendertag [day] (lokale Zeit) beruehrt. Als freie
/// Funktion herausgeloest, damit die Tests sie ohne Plugin pruefen koennen.
bool eventCoversDay(Event event, DateTime day) {
  final d = dateOnly(day);
  DateTime first;
  DateTime last;
  if (event.isAllDay) {
    // Ganztaegige Termine liegen im Calendar Provider auf UTC-Mitternacht,
    // das Ende exklusiv auf der Mitternacht nach dem letzten Tag. Lokale
    // Umrechnung wuerde sie je nach Zeitzone auf den Nachbartag schieben.
    final s = event.startDate.toUtc();
    final e = event.endDate.toUtc().subtract(const Duration(seconds: 1));
    first = DateTime(s.year, s.month, s.day);
    last = DateTime(e.year, e.month, e.day);
  } else {
    first = dateOnly(event.startDate.toLocal());
    // Das Ende ist exklusiv: ein Termin bis Mitternacht gehoert nicht
    // mehr auf den Folgetag. Gleiches Start-/Endmoment bleibt ein Tag.
    var end = event.endDate;
    if (end.isAfter(event.startDate)) {
      end = end.subtract(const Duration(seconds: 1));
    }
    last = dateOnly(end.toLocal());
  }
  return !d.isBefore(first) && !d.isAfter(last);
}

/// Zeile fuers Tagesdetail: "14:30 Uhr" bzw. "ganztägig".
String deviceEventTimeLabel(Event event) =>
    event.isAllDay ? 'ganztägig' : formatTime(event.startDate.toLocal());
