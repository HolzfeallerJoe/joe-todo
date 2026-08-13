import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';

// Der Kalender-Screen braucht den Event-Typ und die Einstellungen die
// Kalender-Liste, beide sollen aber nur diese Datei kennen muessen – das
// Plugin bleibt hier gekapselt.
export 'package:device_calendar_plus/device_calendar_plus.dart'
    show Calendar, Event;

import 'log.dart';
import 'toast.dart';
import 'util.dart';

/// Die Kalender des Geraets (Android Calendar Provider) als eigene,
/// nur lesende Ebene im In-App-Kalender: alles, was die Google-Kalender-App
/// synchronisiert (Gmail-Termine, abonnierte Kalender), liegt dort bereits
/// lokal – Joe selbst spricht weiterhin nicht ins Netz.
///
/// Grundsaetze:
/// - Nichts hier darf die App stoeren: jeder Plugin-Aufruf ist gefangen,
///   auf Plattformen ohne Kalender (Web, Desktop) bleibt die Ebene leer.
/// - **Aber nichts bleibt still.** Ein gescheiterter Abruf setzt
///   [lastError], meldet sich als Toast und faerbt den Kalender-Hinweis –
///   eine leere Ebene, die eigentlich ein Fehler ist, waere die schlimmere
///   Stoerung.
/// - Nichts wird gespeichert – der Bestand gehoert dem System, Joe zeigt
///   ihn nur an. Gecacht wird pro Monat, solange die App laeuft.
class DeviceCalendarFeed extends ChangeNotifier {
  DeviceCalendarFeed._();
  static final DeviceCalendarFeed instance = DeviceCalendarFeed._();

  /// Termine pro Monat ('yyyy-mm'); null heisst: Abruf laeuft gerade.
  final Map<String, List<Event>?> _monthCache = {};

  /// Monate, deren Abruf gescheitert ist. Sie stehen bewusst getrennt vom
  /// Cache: frueher landete bei einem Fehler eine leere Liste im Cache und
  /// blieb dort – der Kalender sah dann fuer immer so aus, als gaebe es an
  /// diesen Tagen nichts. Jetzt heisst "gescheitert" nicht "leer", und
  /// [retry] kann es erneut versuchen.
  final Set<String> _failed = {};

  /// Welche Kalender gezeigt werden; null heisst alle, leer heisst keiner –
  /// siehe `AppState.deviceCalendarIds`.
  Set<String>? _calendarIds;

  /// Was zuletzt schiefging, in Nutzerworten – null heisst: alles in
  /// Ordnung. Der Kalender-Screen zeigt es als Hinweiszeile.
  String? lastError;

  /// Ob der Fehler an einer fehlenden Berechtigung liegt. Dann hilft nur der
  /// Weg in die System-Einstellungen, kein erneuter Versuch.
  bool permissionMissing = false;

  bool get hasProblem => lastError != null;

  static String _monthKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}';

  /// Fragt die Kalender-Berechtigung an (zeigt beim ersten Mal den
  /// System-Dialog). false auch dann, wenn es auf dieser Plattform gar
  /// keinen Geraete-Kalender gibt.
  ///
  /// `full` (lesen *und* schreiben) ist keine Vorratshaltung, sondern die
  /// Stufe, die `listEvents` verlangt – siehe AndroidManifest.
  Future<bool> ensurePermission() async {
    try {
      final status = await DeviceCalendar.instance.requestPermissions();
      final granted = status == CalendarPermissionStatus.granted;
      JoeLog.log('Geraete-Kalender: Berechtigung ${granted ? 'da' : 'fehlt'}');
      if (granted) {
        lastError = null;
        permissionMissing = false;
      }
      return granted;
    } catch (e) {
      JoeLog.log('Geraete-Kalender: Berechtigungsanfrage fehlgeschlagen: $e');
      JoeToast.error('Kalender-Berechtigung konnte nicht abgefragt werden.');
      return false;
    }
  }

  /// Prueft die Berechtigung, **ohne** zu fragen – fuer den App-Start: der
  /// Schalter kann seit dem letzten Mal an geblieben sein, waehrend die
  /// Berechtigung in den System-Einstellungen entzogen wurde. Ohne diese
  /// Pruefung stuende der Schalter auf "an" und der Kalender bliebe leer.
  Future<bool> checkPermission() async {
    try {
      final status = await DeviceCalendar.instance.hasPermissions();
      final granted = status == CalendarPermissionStatus.granted;
      if (granted) {
        lastError = null;
        permissionMissing = false;
      } else {
        _noteProblem(
          'Joe darf die Kalender des Telefons nicht mehr lesen.',
          permission: true,
        );
      }
      JoeLog.log(
          'Geraete-Kalender: Berechtigung beim Start ${granted ? 'da' : 'fehlt'}');
      notifyListeners();
      return granted;
    } catch (e) {
      // Keine Plattform mit Geraete-Kalender – kein Fehler, den der Nutzer
      // sehen muesste; die Ebene bleibt einfach leer.
      JoeLog.log('Geraete-Kalender: Berechtigungspruefung nicht moeglich: $e');
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
      // Sonst tippt der Nutzer auf "Einstellungen" und es passiert nichts.
      JoeToast.error(
          'Die System-Einstellungen ließen sich nicht öffnen. '
          'Bitte dort von Hand: Apps → Joe → Berechtigungen.');
    }
  }

  /// Die Kalender des Geraets fuer die Auswahl in den Einstellungen.
  /// null heisst: ging nicht – die Meldung steht dann schon als Toast.
  Future<List<Calendar>?> listCalendars() async {
    try {
      final calendars = await DeviceCalendar.instance.listCalendars();
      JoeLog.log('Geraete-Kalender: ${calendars.length} Kalender gefunden');
      return calendars;
    } catch (e) {
      JoeLog.log('Geraete-Kalender: Kalenderliste fehlgeschlagen: $e');
      JoeToast.error(_messageFor(e, 'Die Kalender des Telefons ließen sich '
          'nicht auflisten.'));
      return null;
    }
  }

  /// Setzt die Auswahl aus den Einstellungen. Aendert sie sich, faellt der
  /// Bestand weg und wird beim naechsten Blick neu geholt.
  void setCalendarIds(Set<String>? ids) {
    if (_calendarIds == null && ids == null) return;
    if (_calendarIds != null && ids != null && setEquals(_calendarIds, ids)) {
      return;
    }
    _calendarIds = ids == null ? null : Set.unmodifiable(ids);
    clear();
  }

  /// Die Geraete-Termine, die (lokale Zeit) den Tag [day] beruehren.
  /// Ist der Monat noch nicht geladen, kommt erst einmal eine leere Liste
  /// und der Abruf startet; danach meldet sich [notifyListeners].
  List<Event> eventsForDay(DateTime day) {
    final d = dateOnly(day);
    final key = _monthKey(d);
    // Ein gescheiterter Monat wird nicht von allein neu versucht: der Aufruf
    // kommt aus `build`, ein Fehler wuerde sich sonst 42-mal pro Frame
    // wiederholen. Neu versucht wird ueber [retry].
    if (_failed.contains(key)) return const [];
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
    final ids = _calendarIds;
    // Ausdruecklich kein Kalender ausgewaehlt: dann gibt es nichts zu holen.
    // Eine leere Liste an `listEvents` hiesse dort "alle" – genau falsch.
    if (ids != null && ids.isEmpty) {
      _monthCache[key] = const [];
      notifyListeners();
      return;
    }
    try {
      // Eine Woche Rand in beide Richtungen: mehrtaegige Termine, die vor
      // dem Monatsersten beginnen, gehoeren auch auf ihre Tage im Monat.
      final events = await DeviceCalendar.instance.listEvents(
        monthStart.subtract(const Duration(days: 7)),
        DateTime(monthStart.year, monthStart.month + 1, 7),
        calendarIds: ids?.toList(),
      );
      _monthCache[key] = events;
      _failed.remove(key);
      lastError = null;
      permissionMissing = false;
      JoeLog.log('Geraete-Kalender: ${events.length} Termine fuer $key');
      notifyListeners();
    } catch (e) {
      // Berechtigung entzogen, Provider-Fehler, kein Plugin (Web/Desktop) –
      // der Kalender laeuft weiter, aber der Nutzer erfaehrt davon.
      _monthCache.remove(key);
      _failed.add(key);
      JoeLog.log('Geraete-Kalender: Abruf fuer $key fehlgeschlagen: $e');
      _noteProblem(
        _messageFor(e, 'Die Termine des Telefons ließen sich nicht laden.'),
        permission: _isPermissionProblem(e),
      );
      // Auch der Fehlerfall meldet sich: der Kalender zeigt daraufhin seine
      // Hinweiszeile statt einer stillen Luecke.
      notifyListeners();
    }
  }

  static bool _isPermissionProblem(Object e) =>
      e is DeviceCalendarException &&
      (e.errorCode == DeviceCalendarError.permissionDenied ||
          e.errorCode == DeviceCalendarError.permissionsNotDeclared);

  static String _messageFor(Object e, String fallback) => _isPermissionProblem(e)
      ? 'Joe darf die Kalender des Telefons nicht mehr lesen.'
      : fallback;

  void _noteProblem(String message, {required bool permission}) {
    lastError = message;
    permissionMissing = permission;
    JoeToast.error(
      message,
      action: permission
          ? ToastAction('Einstellungen', openSystemSettings)
          : ToastAction('Erneut', retry),
    );
  }

  /// Noch einmal versuchen – aus der Hinweiszeile im Kalender heraus.
  void retry() {
    _failed.clear();
    _monthCache.clear();
    lastError = null;
    permissionMissing = false;
    notifyListeners();
  }

  /// Vergessen, was geladen war – beim Abschalten in den Einstellungen und
  /// als Auffrischen beim naechsten Anschalten.
  void clear() {
    _monthCache.clear();
    _failed.clear();
    lastError = null;
    permissionMissing = false;
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
