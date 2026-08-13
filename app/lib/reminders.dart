import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'log.dart';
import 'models.dart';
import 'util.dart';

/// Erinnerungen als lokale Benachrichtigungen – die Uhr des Telefons stellt
/// sie zu, nichts davon geht ins Netz.
///
/// Die Rechnung steht als freie Funktionen hier drin ([pendingReminders],
/// [reminderNotificationId] …) und ist ohne Plugin pruefbar; [JoeReminders]
/// haelt allein die Platform-Aufrufe und faengt sie ab: eine fehlende
/// Berechtigung oder eine Plattform ganz ohne Benachrichtigungen darf die
/// App nie stoeren.

/// Die Vorlaufzeiten, die ein Termin anbieten kann – null ist "Keine".
const reminderLeadChoices = <int?>[null, 0, 5, 10, 15, 30, 60, 120, 1440];

/// Was der Nutzer zur Auswahl liest: "30 Minuten vorher", "1 Tag vorher" …
String reminderLeadLabel(int? minutes) {
  if (minutes == null) return 'Keine';
  if (minutes == 0) return 'Zur Terminzeit';
  if (minutes < 60) return '$minutes Minuten vorher';
  if (minutes < 1440) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 Stunde vorher' : '$hours Stunden vorher';
  }
  final days = minutes ~/ 1440;
  return days == 1 ? '1 Tag vorher' : '$days Tage vorher';
}

/// Die Uhrzeit einer Aufgaben-Erinnerung: "09:00 Uhr" bzw. "Keine".
String reminderTimeLabel(int? minuteOfDay) {
  if (minuteOfDay == null) return 'Keine';
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m Uhr';
}

/// Eine geplante Benachrichtigung, fertig zum Einstellen.
class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  /// Zwei Plaene sind gleich, wenn jede Zeile gleich ist – daran erkennt
  /// [JoeReminders.sync], dass nichts neu gestellt werden muss.
  String get signature => '$id|$title|$body|${when.toIso8601String()}';
}

/// Wie viele Tage im Voraus geplant wird und wie viele Termine ein
/// wiederkehrender Eintrag hoechstens belegt. Beides bewusst knapp: Android
/// deckelt die offenen Benachrichtigungen, und der Plan wird bei jeder
/// Aenderung und bei jedem App-Start ohnehin neu gestellt.
const reminderHorizonDays = 60;
const remindersPerTask = 8;

/// Die Nummer, unter der eine Erinnerung beim System steht. Sie muss
/// zwischen zwei Laeufen dieselbe bleiben (sonst bliebe eine alte
/// Benachrichtigung ungeloescht stehen) und in einen 32-Bit-Int passen.
///
/// Aus der Eintrags-ID werden 23 Bit gehasht, die unteren 8 gehoeren dem
/// [slot] – dem wievielten Termin eines wiederkehrenden Eintrags. Zwei
/// verschiedene Eintraege koennen theoretisch auf denselben Hash fallen;
/// dann verdraengt die eine Erinnerung die andere. Bei den Groessen, um die
/// es hier geht (Dutzende), ist das nicht zu erwarten, und der Preis waere
/// eine ausgefallene Erinnerung, kein Datenverlust.
int reminderNotificationId(String entityId, int slot) {
  // FNV-1a, 32 Bit – kurz, stabil und ohne Abhaengigkeit.
  var hash = 0x811c9dc5;
  for (final unit in entityId.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0xffffffff;
  }
  return (hash & 0x7fffff) * 256 + (slot & 0xff);
}

/// Alle Erinnerungen, die ab [from] noch anstehen – erst die Termine, dann
/// die Aufgaben, jeweils in der Reihenfolge ihrer Zeit.
///
/// Erledigtes faellt raus: eine abgehakte Aufgabe erinnert nicht mehr, auch
/// eine wiederkehrende nicht an dem Tag, an dem sie schon erledigt ist.
List<Reminder> pendingReminders({
  required List<Task> tasks,
  required List<Appointment> appointments,
  required DateTime from,
  int horizonDays = reminderHorizonDays,
  int perTask = remindersPerTask,
}) {
  final out = <Reminder>[];
  final horizon = from.add(Duration(days: horizonDays));

  for (final a in appointments) {
    final lead = a.reminderLeadMinutes;
    if (lead == null) continue;
    final when = a.when.subtract(Duration(minutes: lead));
    if (!when.isAfter(from) || when.isAfter(horizon)) continue;
    out.add(Reminder(
      id: reminderNotificationId(a.id, 0),
      title: a.title,
      body: '${formatRelativeDay(a.when)} um ${formatTime(a.when)}',
      when: when,
    ));
  }

  for (final task in tasks) {
    final minute = task.reminderMinuteOfDay;
    if (minute == null) continue;
    var slot = 0;
    // occursOn deckt beide Faelle ab: der einmalige Eintrag hat genau einen
    // Termin (seinen Starttag), der wiederkehrende viele.
    for (var day = dateOnly(from);
        slot < perTask && !day.isAfter(horizon);
        day = day.add(const Duration(days: 1))) {
      if (!task.occursOn(day) || task.isCompletedOn(day)) continue;
      final when = day.add(Duration(minutes: minute));
      if (!when.isAfter(from)) continue;
      out.add(Reminder(
        id: reminderNotificationId(task.id, slot),
        title: task.title,
        body: 'Aufgabe für heute',
        when: when,
      ));
      slot++;
    }
  }

  out.sort((a, b) => a.when.compareTo(b.when));
  return out;
}

/// Der Draht zum System. Alles hier drin ist gefangen: ohne
/// Benachrichtigungen (Web, verweigerte Berechtigung) bleibt die App
/// vollstaendig benutzbar, es kommt nur nichts an.
class JoeReminders {
  JoeReminders._();
  static final JoeReminders instance = JoeReminders._();

  static const _channelId = 'joe_reminders';

  final _plugin = fln.FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _plan = '';

  /// Zeitzonen laden und den Kanal anlegen. Wird von main() vor dem ersten
  /// [sync] aufgerufen; schlaegt es fehl, bleibt [_ready] false und alles
  /// Weitere ist ein stiller No-Op.
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      // Ohne die Zone des Geraets rechnete das Plugin in UTC – die
      // Erinnerung kaeme je nach Jahreszeit ein bis zwei Stunden daneben.
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));

      await _plugin.initialize(
        settings: const fln.InitializationSettings(
          android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              fln.AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const fln.AndroidNotificationChannel(
            _channelId,
            'Erinnerungen',
            description: 'Erinnerungen an Aufgaben und Termine',
            importance: fln.Importance.high,
          ));
      _ready = true;
      JoeLog.log('Erinnerungen: bereit (${tz.local.name})');
    } catch (e) {
      JoeLog.log('Erinnerungen: Einrichtung fehlgeschlagen: $e');
    }
  }

  /// Fragt die Benachrichtigungs-Berechtigung an (ab Android 13 noetig).
  /// Gibt zurueck, ob zugestellt werden darf.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();
      // Auf Plattformen ohne eigene Abfrage gilt die Erlaubnis als da –
      // dort entscheidet das System beim Zustellen.
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission() ?? false;
      JoeLog.log('Erinnerungen: Berechtigung ${granted ? 'da' : 'fehlt'}');
      return granted;
    } catch (e) {
      JoeLog.log('Erinnerungen: Berechtigungsanfrage fehlgeschlagen: $e');
      return false;
    }
  }

  /// Stellt den Plan neu: alles Alte weg, alles Anstehende hin. Aufgerufen
  /// nach jeder Aenderung am Bestand – deshalb steigt es aus, wenn derselbe
  /// Plan schon steht (ein Designwechsel meldet sich genauso wie eine neue
  /// Aufgabe, soll aber keine Platform-Aufrufe ausloesen).
  Future<void> sync(AppState state) async {
    if (!_ready) return;
    final reminders = state.remindersEnabled
        ? pendingReminders(
            tasks: state.tasks,
            appointments: state.appointments,
            from: DateTime.now(),
          )
        : const <Reminder>[];
    final plan = reminders.map((r) => r.signature).join('\n');
    if (plan == _plan) return;

    try {
      // Erst alles loeschen, dann neu stellen: verschobene, geloeschte und
      // abgehakte Eintraege verschwinden so sicher, ohne dass Joe Buch
      // ueber die vergebenen Nummern fuehren muss.
      await _plugin.cancelAll();
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.when, tz.local),
          notificationDetails: const fln.NotificationDetails(
            android: fln.AndroidNotificationDetails(
              _channelId,
              'Erinnerungen',
              channelDescription: 'Erinnerungen an Aufgaben und Termine',
              importance: fln.Importance.high,
              priority: fln.Priority.high,
            ),
          ),
          androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
      _plan = plan;
      JoeLog.log('Erinnerungen: ${reminders.length} geplant');
    } catch (e) {
      // _plan bleibt auf dem alten Stand – der naechste Lauf sieht den
      // Unterschied wieder und versucht es erneut.
      JoeLog.log('Erinnerungen: Planen fehlgeschlagen: $e');
    }
  }
}
