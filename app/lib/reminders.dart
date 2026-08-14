import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'log.dart';
import 'models.dart';
import 'toast.dart';
import 'util.dart';

/// Erinnerungen als lokale Benachrichtigungen – die Uhr des Telefons stellt
/// sie zu, nichts davon geht ins Netz.
///
/// Die Rechnung steht als freie Funktionen hier drin ([pendingReminders],
/// [reminderNotificationId] …) und ist ohne Plugin pruefbar; [JoeReminders]
/// haelt allein die Platform-Aufrufe.
///
/// Gefangen wird dort weiterhin alles – eine fehlende Berechtigung oder eine
/// Plattform ganz ohne Benachrichtigungen darf die App nie stoeren. Aber
/// **gefangen heisst nicht verschwiegen**: was schiefgeht, geht als Toast an
/// den Nutzer. Eine Erinnerung, von der man glaubt, sie stehe, ist schlimmer
/// als gar keine.

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

/// Worauf eine angetippte Erinnerung zeigt. Steckt als [Reminder.payload] in
/// der Benachrichtigung und kommt beim Antippen zurueck.
class ReminderTarget {
  final bool isTask;
  final String id;
  final DateTime day;

  const ReminderTarget({
    required this.isTask,
    required this.id,
    required this.day,
  });
}

/// `aufgabe|<id>|<yyyy-mm-dd>` bzw. `termin|…`. Der Tag steht mit drin, weil
/// eine wiederkehrende Aufgabe an vielen Tagen erinnert und das Antippen den
/// richtigen treffen soll.
String reminderPayload({
  required bool isTask,
  required String id,
  required DateTime day,
}) =>
    '${isTask ? 'aufgabe' : 'termin'}|$id|${dateKey(day)}';

/// Liest [reminderPayload] zurueck; null, wenn nichts Brauchbares drinsteht –
/// etwa aus einer aelteren Version, die noch keinen Payload gesetzt hat.
ReminderTarget? parseReminderPayload(String? payload) {
  if (payload == null) return null;
  final parts = payload.split('|');
  if (parts.length != 3) return null;
  if (parts[0] != 'aufgabe' && parts[0] != 'termin') return null;
  if (parts[1].isEmpty) return null;
  try {
    final day = parseDateKey(parts[2]);
    // parseDateKey rechnet Unsinn glatt: aus '2026-13-45' wuerde sonst
    // klaglos der 14. Februar 2027. Der Rueckweg deckt das auf.
    if (dateKey(day) != parts[2]) return null;
    return ReminderTarget(
      isTask: parts[0] == 'aufgabe',
      id: parts[1],
      day: day,
    );
  } catch (_) {
    return null;
  }
}

/// Eine geplante Benachrichtigung, fertig zum Einstellen.
class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  /// Wohin das Antippen fuehrt – siehe [reminderPayload].
  final String payload;

  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    this.payload = '',
  });

  /// Zwei Plaene sind gleich, wenn jede Zeile gleich ist – daran erkennt
  /// [JoeReminders.sync], was neu gestellt werden muss und was stehen bleibt.
  /// [payload] steht bewusst nicht drin: er folgt aus [id] und [when].
  String get signature => '$id|$title|$body|${when.toIso8601String()}';
}

/// Wie weit im Voraus geplant wird.
const reminderHorizonDays = 60;

/// Wie viele Termine ein wiederkehrender Eintrag hoechstens belegt.
///
/// Neu gestellt wird nur bei einer Aenderung oder beim App-Start – und wer
/// die App laenger nicht oeffnet, bekommt danach nichts mehr. Genau dann ist
/// die Erinnerung aber das, was die App oeffnen wuerde. Darum reicht das
/// hier fuer einen Monat einer taeglichen Aufgabe, nicht fuer eine Woche.
const remindersPerTask = 30;

/// Der harte Deckel ueber alles zusammen.
///
/// Android laesst pro App 500 offene Alarme zu (`MAX_ALARMS_PER_UID`, ab
/// API 31); darueber wirft das System. [remindersPerTask] allein schuetzt
/// davor nicht – zwanzig wiederkehrende Aufgaben kaemen auf 600. Der Deckel
/// muss deshalb global sein. Abgeschnitten wird am Ende der nach Zeit
/// sortierten Liste: die naechsten Erinnerungen gewinnen, die fernsten
/// fallen weg und sind beim naechsten Lauf ohnehin wieder dran.
const maxScheduledReminders = 400;

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
  int maxTotal = maxScheduledReminders,
}) {
  final out = <Reminder>[];
  final horizon = from.add(Duration(days: horizonDays));

  for (final a in appointments) {
    final lead = a.reminderLeadMinutes;
    if (lead == null) continue;
    final when = a.when.subtract(Duration(minutes: lead));
    if (!when.isAfter(from) || when.isAfter(horizon)) continue;
    out.add(
      Reminder(
        id: reminderNotificationId(a.id, 0),
        title: a.title,
        body: '${formatRelativeDay(a.when)} um ${formatTime(a.when)}',
        when: when,
        payload: reminderPayload(isTask: false, id: a.id, day: a.when),
      ),
    );
  }

  for (final task in tasks) {
    final minute = task.reminderMinuteOfDay;
    if (minute == null) continue;
    var slot = 0;
    // occursOn deckt beide Faelle ab: der einmalige Eintrag hat genau einen
    // Termin (seinen Starttag), der wiederkehrende viele.
    for (var day = dateOnly(from);
        slot < perTask && !day.isAfter(horizon);
        day = nextCalendarDay(day)) {
      if (!task.occursOn(day) || task.isCompletedOn(day)) continue;
      final when = timeOnCalendarDay(day, minute);
      if (!when.isAfter(from)) continue;
      out.add(
        Reminder(
          id: reminderNotificationId(task.id, slot),
          title: task.title,
          body: 'Aufgabe für heute',
          when: when,
          payload: reminderPayload(isTask: true, id: task.id, day: day),
        ),
      );
      slot++;
    }
  }

  out.sort((a, b) => a.when.compareTo(b.when));
  // Erst sortieren, dann deckeln – sonst haenge es vom Zufall der
  // Eintragsreihenfolge ab, wessen Erinnerung wegfaellt.
  return out.length <= maxTotal ? out : out.sublist(0, maxTotal);
}

/// Der naechste lokale Kalendertag. Eine Dauer von 24 Stunden waere an der
/// Sommerzeitgrenze nicht dasselbe und koennte bei einer taeglichen Reihe aus
/// Mitternacht 01:00 machen.
DateTime nextCalendarDay(DateTime day) =>
    DateTime(day.year, day.month, day.day + 1);

/// Eine lokale Uhrzeit auf einem Kalendertag. Auch hier ist Addition ab
/// Mitternacht ungeeignet: der Tag der Zeitumstellung hat 23 bzw. 25 Stunden.
DateTime timeOnCalendarDay(DateTime day, int minuteOfDay) =>
    DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);

/// Der Draht zum System.
class JoeReminders {
  JoeReminders._();
  static final JoeReminders instance = JoeReminders._();

  static const _channelId = 'joe_reminders';
  static const _channelName = 'Erinnerungen';
  static const _channelDescription = 'Erinnerungen an Aufgaben und Termine';

  final _plugin = fln.FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Der laufende bzw. abgeschlossene [init]. Alles Weitere wartet darauf,
  /// statt in der Zwischenzeit "geht nicht" zu behaupten.
  Future<void>? _initFuture;

  /// Was gerade beim System steht: Nummer -> [Reminder.signature]. Frueher
  /// war das ein einziger Plan-String plus `cancelAll()`; damit riss jede
  /// Aenderung auch alle bereits *zugestellten* Erinnerungen aus der Leiste.
  /// Jetzt wird pro Nummer verglichen und nur angefasst, was sich aendert.
  final Map<int, String> _scheduled = {};

  /// Serialisiert die Laeufe. Zwei gleichzeitige [sync] haben sich sonst
  /// gegenseitig die frisch gestellten Erinnerungen weggeloescht: der zweite
  /// Lauf raeumte ab, waehrend der erste noch stellte.
  Future<void> _queue = Future<void>.value();

  /// Ob das System exakte Alarme zulaesst. Auf Android 12 ohne
  /// SCHEDULE_EXACT_ALARM und auf 13+ mit entzogener "Wecker und
  /// Erinnerungen"-Freigabe ist das false – dann wird ungefaehr geplant,
  /// statt gar nicht.
  bool _exactAllowed = true;
  bool _warnedInexact = false;

  /// Wohin ein Antippen fuehrt. Setzt die App, sobald ihr Navigator steht.
  void Function(ReminderTarget)? onOpen;
  ReminderTarget? _pendingTarget;

  /// Ob diese Plattform ueberhaupt im Voraus planen kann. Linux kennt kein
  /// `zonedSchedule` (das Plugin wirft dort `UnimplementedError`); dann wird
  /// einmal gewarnt und nicht bei jedem Lauf erneut vergeblich versucht.
  bool _schedulingSupported = true;
  bool _warnedNoScheduling = false;

  bool get ready => _ready;

  fln.AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

  fln.IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          fln.IOSFlutterLocalNotificationsPlugin>();

  fln.MacOSFlutterLocalNotificationsPlugin? get _macos =>
      _plugin.resolvePlatformSpecificImplementation<
          fln.MacOSFlutterLocalNotificationsPlugin>();

  fln.WebFlutterLocalNotificationsPlugin? get _web =>
      _plugin.resolvePlatformSpecificImplementation<
          fln.WebFlutterLocalNotificationsPlugin>();

  /// Die Einstellungen fuer *jede* Plattform, nicht nur fuer Android.
  ///
  /// `initialize` sucht sich den Eintrag der laufenden Plattform und wirft,
  /// wenn er fehlt – mit nur `android:` blieb [_ready] auf iOS, macOS, Linux
  /// und Windows auf false, es kam nie eine Erinnerung an und bei jedem
  /// Start ein Fehler-Toast. Android bleibt die Hauptplattform, aber der
  /// Dart-Code soll ueberall laufen koennen.
  static const _initSettings = fln.InitializationSettings(
    android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: _darwinInit,
    macOS: _darwinInit,
    linux: fln.LinuxInitializationSettings(defaultActionName: 'Öffnen'),
    windows: fln.WindowsInitializationSettings(
      appName: 'Joe',
      appUserModelId: 'dev.joe.joe_todo',
      // Fest verdrahtet und nie zu aendern: unter dieser GUID meldet sich
      // das angetippte Toast zurueck.
      guid: 'b9a5f4c2-3d7e-4a16-9c8b-5e2f1d0a7c34',
    ),
  );

  /// Auf iOS und macOS fragt das Plugin die Berechtigung sonst schon bei
  /// [init] – Joe fragt aber erst, wenn die erste Erinnerung gesetzt wird
  /// bzw. beim Hauptschalter, genau wie auf Android.
  static const _darwinInit = fln.DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  /// Wie die Erinnerung aussieht, je Plattform. Fehlt der Eintrag der
  /// laufenden Plattform, stellt das Plugin sie zwar zu, aber ohne alles,
  /// was hier steht (auf Android etwa ohne den Kanal).
  static const _details = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: fln.Importance.high,
      priority: fln.Priority.high,
    ),
    iOS: fln.DarwinNotificationDetails(),
    macOS: fln.DarwinNotificationDetails(),
    windows: fln.WindowsNotificationDetails(),
  );

  /// Zeitzonen laden, den Kanal anlegen, Antippen verdrahten. Wird von
  /// main() vor dem ersten [sync] aufgerufen.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      // Ohne die Zone des Geraets rechnete das Plugin in UTC – die
      // Erinnerung kaeme je nach Jahreszeit ein bis zwei Stunden daneben.
      // Scheitert das, ist UTC immer noch besser als gar keine Erinnerung:
      // frueher riss dieser eine Fehler das ganze Feature mit.
      try {
        final local = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(local.identifier));
      } catch (e) {
        JoeLog.log('Erinnerungen: Zeitzone unbekannt, es gilt UTC: $e');
        JoeToast.error(
          'Zeitzone des Telefons unbekannt – Erinnerungen '
          'können um Stunden danebenliegen.',
        );
      }

      await _plugin.initialize(
        settings: _initSettings,
        onDidReceiveNotificationResponse: (response) =>
            _handleTap(response.payload),
      );
      await _android?.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: fln.Importance.high,
        ),
      );
      await _refreshExactAllowed();

      // Was aus dem vorigen App-Lauf noch beim System steht, uebernehmen –
      // sonst wuesste der erste [sync] nichts davon und liesse eine
      // Erinnerung stehen, die im neuen Plan nicht mehr vorkommt. Frueher
      // erledigte das ein `cancelAll()`; das riss aber auch die bereits
      // zugestellten aus der Leiste. `pendingNotificationRequests` meldet
      // allein die geplanten. Die Signatur '?' passt auf keine echte, jede
      // uebernommene Nummer wird also entweder abgeraeumt oder neu gestellt.
      // Eigener try: auf Linux kennt das Plugin diese Abfrage nicht und
      // wirft. Das darf nicht die ganze Einrichtung mitreissen – ohne die
      // Uebernahme faengt der Plan eben bei null an.
      try {
        for (final pending in await _plugin.pendingNotificationRequests()) {
          _scheduled[pending.id] = '?';
        }
      } catch (e) {
        JoeLog.log(
          'Erinnerungen: Uebernahme vom letzten Mal nicht '
          'moeglich: $e',
        );
      }
      // Erst jetzt: ein [sync], der zwischen Uebernahme und hier
      // dazwischenkaeme, saehe einen halb gefuellten Stand.
      _ready = true;
      JoeLog.log(
        'Erinnerungen: bereit (${tz.local.name}, '
        'exakt: $_exactAllowed, ${_scheduled.length} vom letzten Mal)',
      );

      // Die App kann ueber ein Antippen gestartet worden sein – dann steht
      // der Payload nicht im Callback, sondern in den Startdetails.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _handleTap(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      JoeLog.log('Erinnerungen: Einrichtung fehlgeschlagen: $e');
      JoeToast.error(
        'Erinnerungen konnten nicht eingerichtet werden – '
        'es wird keine zugestellt.',
      );
    }
  }

  Future<void> _refreshExactAllowed() async {
    final android = _android;
    if (android == null) {
      _exactAllowed = true;
      return;
    }
    try {
      _exactAllowed = await android.canScheduleExactNotifications() ?? true;
    } catch (e) {
      JoeLog.log('Erinnerungen: Pruefung auf exakte Alarme fehlgeschlagen: $e');
      _exactAllowed = false;
    }
  }

  void _handleTap(String? payload) {
    final target = parseReminderPayload(payload);
    if (target == null) return;
    final open = onOpen;
    if (open == null) {
      // Die Oberflaeche steht noch nicht – aufheben und nachholen.
      _pendingTarget = target;
      return;
    }
    open(target);
  }

  /// Meldet den Empfaenger fuers Antippen an und holt nach, was vor dem
  /// ersten Frame hereinkam.
  set tapHandler(void Function(ReminderTarget) handler) {
    onOpen = handler;
    final pending = _pendingTarget;
    if (pending == null) return;
    _pendingTarget = null;
    handler(pending);
  }

  /// Fragt die Benachrichtigungs-Berechtigung an (ab Android 13 noetig).
  /// Gibt zurueck, ob zugestellt werden darf.
  Future<bool> ensurePermission() async {
    // Warten statt "geht nicht": wer schnell genug in die Einstellungen
    // tippt, bekam sonst eine Absage, obwohl nur der Start noch lief.
    await _initFuture;
    if (!_ready) {
      JoeToast.error(
        'Erinnerungen stehen auf diesem Gerät nicht zur '
        'Verfügung.',
      );
      return false;
    }
    try {
      final granted = await _requestPermission();
      // Auf Plattformen ohne eigene Abfrage (Windows, Linux) gilt die
      // Erlaubnis als da – dort entscheidet das System beim Zustellen.
      if (granted == null) return true;
      JoeLog.log('Erinnerungen: Berechtigung ${granted ? 'da' : 'fehlt'}');
      if (!granted) {
        // Ab Android 13 zeigt das System den Dialog nach zweimaligem
        // Ablehnen gar nicht mehr – ohne diesen Weg saesse der Nutzer fest.
        JoeToast.error(
          'Ohne Benachrichtigungen kann Joe nicht erinnern.',
          action: ToastAction('Einstellungen', openNotificationSettings),
        );
      }
      return granted;
    } catch (e) {
      JoeLog.log('Erinnerungen: Berechtigungsanfrage fehlgeschlagen: $e');
      JoeToast.error(
        'Die Benachrichtigungs-Berechtigung ließ sich nicht '
        'abfragen.',
      );
      return false;
    }
  }

  /// Die Anfrage der laufenden Plattform. null heisst: diese kennt gar
  /// keine – dann darf ohne Weiteres zugestellt werden.
  Future<bool?> _requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    // iOS und macOS fragen alles auf einmal; ohne diese drei Flags kaeme
    // eine stumme Erinnerung ohne Banner an, also gar keine sichtbare. Die
    // beiden stehen getrennt, weil ihr gemeinsamer Obertyp die Methode
    // nicht kennt.
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final macos = _macos;
    if (macos != null) {
      return await macos.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final web = _web;
    if (web != null) {
      return await web.requestNotificationsPermission() ?? false;
    }
    return null;
  }

  /// Prueft beim Start, ob ueberhaupt zugestellt werden kann: der
  /// Hauptschalter kann an geblieben sein, waehrend die Benachrichtigungen
  /// im System abgeschaltet wurden. Sonst stuende "an" und es kaeme nie
  /// etwas an.
  Future<void> checkDelivery(bool remindersEnabled) async {
    await _initFuture;
    if (!_ready || !remindersEnabled) return;
    try {
      final enabled = await _deliveryEnabled();
      // null: diese Plattform sagt es nicht – dann auch nicht warnen.
      if (enabled == null || enabled) return;
      JoeLog.log('Erinnerungen: Benachrichtigungen im System abgeschaltet');
      JoeToast.error(
        'Benachrichtigungen für Joe sind abgeschaltet – es kommt keine '
        'Erinnerung an.',
        action: ToastAction('Einstellungen', openNotificationSettings),
      );
    } catch (e) {
      JoeLog.log('Erinnerungen: Zustellpruefung fehlgeschlagen: $e');
    }
  }

  /// Ob das System die Zustellung ueberhaupt zulaesst. null heisst: diese
  /// Plattform beantwortet die Frage nicht.
  Future<bool?> _deliveryEnabled() async {
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? true;
    final ios = _ios;
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? true;
    final macos = _macos;
    if (macos != null) {
      return (await macos.checkPermissions())?.isEnabled ?? true;
    }
    final web = _web;
    if (web != null) {
      return web.permissionStatus == fln.WebNotificationPermission.granted;
    }
    return null;
  }

  /// Der Weg in die System-Einstellungen. Nicht ueber [_android], sondern
  /// ueber das Plugin selbst: das trifft auch iOS und macOS. Wo es den Weg
  /// nicht gibt (Web, Desktop), wirft es – und der Nutzer liest, wo er
  /// selbst nachsehen kann.
  Future<void> openNotificationSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      JoeLog.log(
        'Erinnerungen: Benachrichtigungs-Einstellungen '
        'nicht erreichbar: $e',
      );
      JoeToast.error(
        'Die System-Einstellungen ließen sich nicht öffnen. '
        'Bitte dort von Hand: Apps → Joe → Benachrichtigungen.',
      );
    }
  }

  /// Stellt den Plan nach. Aufgerufen nach jeder Aenderung am Bestand.
  ///
  /// Laeuft serialisiert: ein zweiter Aufruf haengt sich hinten an, statt
  /// sich in einen laufenden hineinzuschieben.
  Future<void> sync(AppState state) {
    // Das catchError ist nicht Zierde: ohne es bliebe [_queue] nach einem
    // einzigen Fehler ein gescheitertes Future, und jedes spaetere `then`
    // wuerde uebersprungen – die Erinnerungen waeren bis zum Neustart tot.
    _queue = _queue.then((_) => _syncNow(state)).catchError((Object e) {
      JoeLog.log('Erinnerungen: Lauf abgebrochen: $e');
      JoeToast.error('Erinnerungen konnten nicht gestellt werden.');
    });
    return _queue;
  }

  Future<void> _syncNow(AppState state) async {
    if (!_ready) return;
    final reminders = state.remindersEnabled
        ? pendingReminders(
            tasks: state.tasks,
            appointments: state.appointments,
            from: DateTime.now(),
          )
        : const <Reminder>[];

    // Bei einer Nummernkollision gewinnt der letzte – die Nummer kann nur
    // einmal beim System stehen.
    final wanted = <int, Reminder>{for (final r in reminders) r.id: r};
    final signatures = {
      for (final e in wanted.entries) e.key: e.value.signature,
    };
    if (mapEquals(signatures, _scheduled)) return;

    // Die Freigabe kann sich seit dem Start geaendert haben (der Nutzer war
    // in den System-Einstellungen), also vor jedem Lauf frisch nachsehen.
    await _refreshExactAllowed();
    if (!_exactAllowed && !_warnedInexact && wanted.isNotEmpty) {
      _warnedInexact = true;
      JoeLog.log('Erinnerungen: nur ungefaehre Alarme moeglich');
      JoeToast.info(
        'Dieses Gerät lässt Joe keine exakten Alarme stellen – '
        'Erinnerungen können einige Minuten später kommen.',
        action: ToastAction('Erlauben', _requestExactAlarms),
      );
    }

    try {
      // Erst abraeumen, was weg soll oder sich geaendert hat …
      for (final id in _scheduled.keys.toList()) {
        if (signatures[id] == _scheduled[id]) continue;
        await _plugin.cancel(id: id);
        _scheduled.remove(id);
      }
      // Kann dieses System nicht im Voraus planen, bleibt es beim
      // Abraeumen – der Versuch gaebe bei jedem Lauf denselben Fehler.
      if (!_schedulingSupported) return;
      // … dann stellen, was fehlt. `_scheduled` wird dabei Schritt fuer
      // Schritt fortgeschrieben: bricht es in der Mitte ab, steht dort die
      // Wahrheit und der naechste Lauf macht genau den Rest.
      for (final r in reminders) {
        if (_scheduled[r.id] == r.signature) continue;
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          payload: r.payload,
          scheduledDate: tz.TZDateTime.from(r.when, tz.local),
          notificationDetails: _details,
          androidScheduleMode: _exactAllowed
              ? fln.AndroidScheduleMode.exactAllowWhileIdle
              : fln.AndroidScheduleMode.inexactAllowWhileIdle,
        );
        _scheduled[r.id] = r.signature;
      }
      JoeLog.log('Erinnerungen: ${_scheduled.length} gestellt');
    } on UnimplementedError catch (e) {
      // Linux: das System kennt nur sofortige Benachrichtigungen. Einmal
      // sagen und danach nicht bei jedem Lauf erneut anlaufen – der Fehler
      // geht ja nicht weg.
      _schedulingSupported = false;
      JoeLog.log('Erinnerungen: dieses System plant nicht im Voraus: $e');
      if (!_warnedNoScheduling) {
        _warnedNoScheduling = true;
        JoeToast.error(
          'Dieses System kann keine Erinnerungen im Voraus '
          'zustellen – Joe merkt sie sich, meldet sich aber nicht von '
          'selbst.',
        );
      }
    } catch (e) {
      JoeLog.log('Erinnerungen: Planen fehlgeschlagen: $e');
      JoeToast.error(
        'Erinnerungen konnten nicht gestellt werden – '
        'möglicherweise kommt keine an.',
      );
    }
  }

  Future<void> _requestExactAlarms() async {
    try {
      await _android?.requestExactAlarmsPermission();
      await _refreshExactAllowed();
    } catch (e) {
      JoeLog.log('Erinnerungen: Anfrage fuer exakte Alarme fehlgeschlagen: $e');
      JoeToast.error(
        'Die Freigabe für exakte Alarme ließ sich nicht '
        'öffnen.',
      );
    }
  }
}
