import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almanac.dart';
import 'env.dart';
import 'log.dart';
import 'pets.dart';
import 'util.dart';

/// Warm color palette for tasks and appointments.
///
/// The first eight are the original palette and keep their index: a stored
/// `colorIndex` points into this list, so new colors only ever get appended.
const taskPalette = [
  Color(0xFFC0563B), // Terrakotta
  Color(0xFFD98E32), // Bernstein
  Color(0xFF8A9A5B), // Salbei
  Color(0xFF4E937A), // Tanne
  Color(0xFFB23A5E), // Beere
  Color(0xFF7A5C3E), // Walnuss
  Color(0xFF5B7C99), // Taubenblau
  Color(0xFFC9A227), // Senf
  Color(0xFFA34A22), // Rost
  Color(0xFFE08A6A), // Lachs
  Color(0xFFE07B39), // Kürbis
  Color(0xFFD9B382), // Sand
  Color(0xFF6E7A3A), // Oliv
  Color(0xFF5A8F4C), // Farn
  Color(0xFF7FBFA5), // Minze
  Color(0xFF3A6E78), // Petrol
  Color(0xFF3B4E70), // Nachtblau
  Color(0xFF7B4B6E), // Pflaume
  Color(0xFFC77F92), // Altrosa
  Color(0xFF8E7BB0), // Lavendel
];

const taskPaletteNames = [
  'Terrakotta', 'Bernstein', 'Salbei', 'Tanne',
  'Beere', 'Walnuss', 'Taubenblau', 'Senf',
  'Rost', 'Lachs', 'Kürbis', 'Sand',
  'Oliv', 'Farn', 'Minze', 'Petrol',
  'Nachtblau', 'Pflaume', 'Altrosa', 'Lavendel',
];

enum RecurrenceType { none, daily, weekly, monthly, everyXDays }

/// Three priority levels for tasks and appointments. Level 3 ("Niedrig") is
/// the quiet one: an ihrem Faelligkeitstag zaehlt sie mit wie jede andere,
/// danach faellt sie aus "x offene Aufgaben heute" heraus und steht nur noch
/// unter "Hat Zeit" (siehe [isLowLeftover]).
enum Priority {
  hoch(1, 'Hoch'),
  mittel(2, 'Mittel'),
  niedrig(3, 'Niedrig');

  final int level;
  final String label;
  const Priority(this.level, this.label);

  static Priority fromJson(Object? value) => Priority.values.firstWhere(
        (p) => p.name == value,
        orElse: () => Priority.mittel,
      );
}

class Task {
  final String id;
  String title;
  RecurrenceType recurrence;
  int intervalDays;
  DateTime startDate;
  int colorIndex;
  Priority priority;
  Set<String> completedDates;

  /// Uhrzeit der Erinnerung am Faelligkeitstag, als Minuten seit
  /// Mitternacht; null heisst: keine Erinnerung. Aufgaben haben keine
  /// eigene Uhrzeit, deshalb bringt die Erinnerung ihre eigene mit.
  int? reminderMinuteOfDay;

  Task({
    required this.id,
    required this.title,
    this.recurrence = RecurrenceType.none,
    this.intervalDays = 2,
    required this.startDate,
    this.colorIndex = 0,
    this.priority = Priority.mittel,
    this.reminderMinuteOfDay,
    Set<String>? completedDates,
  }) : completedDates = completedDates ?? {};

  Color get color => taskPalette[colorIndex % taskPalette.length];

  bool get isRecurring => recurrence != RecurrenceType.none;

  /// Whether a recurring task has an occurrence on [day] (also true for a
  /// one-off task on its due date).
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final s = dateOnly(startDate);
    if (d.isBefore(s)) return false;
    switch (recurrence) {
      case RecurrenceType.none:
        return d == s;
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return d.weekday == s.weekday;
      case RecurrenceType.monthly:
        return d.day == s.day;
      case RecurrenceType.everyXDays:
        return d.difference(s).inDays % (intervalDays < 1 ? 1 : intervalDays) == 0;
    }
  }

  /// One-off tasks are done once and stay done; recurring tasks are completed
  /// per occurrence day.
  bool isCompletedOn(DateTime day) {
    if (!isRecurring) return completedDates.isNotEmpty;
    return completedDates.contains(dateKey(day));
  }

  String get recurrenceLabel {
    switch (recurrence) {
      case RecurrenceType.none:
        return 'Einmalig';
      case RecurrenceType.daily:
        return 'Täglich';
      case RecurrenceType.weekly:
        return 'Wöchentlich';
      case RecurrenceType.monthly:
        return 'Monatlich';
      case RecurrenceType.everyXDays:
        return 'Alle $intervalDays Tage';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recurrence': recurrence.name,
        'intervalDays': intervalDays,
        'startDate': dateKey(startDate),
        'colorIndex': colorIndex,
        'priority': priority.name,
        'reminderMinuteOfDay': reminderMinuteOfDay,
        'completedDates': completedDates.toList(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        recurrence: RecurrenceType.values
            .firstWhere((r) => r.name == json['recurrence'], orElse: () => RecurrenceType.none),
        intervalDays: json['intervalDays'] as int? ?? 2,
        startDate: parseDateKey(json['startDate'] as String),
        colorIndex: json['colorIndex'] as int? ?? 0,
        priority: Priority.fromJson(json['priority']),
        reminderMinuteOfDay: minuteOfDayFromJson(json['reminderMinuteOfDay']),
        completedDates: (json['completedDates'] as List<dynamic>? ?? []).cast<String>().toSet(),
      );
}

class Appointment {
  final String id;
  String title;
  DateTime when;
  int colorIndex;
  Priority priority;

  /// Vorlauf der Erinnerung in Minuten (0 = zur Terminzeit); null heisst:
  /// keine Erinnerung.
  int? reminderLeadMinutes;

  Appointment({
    required this.id,
    required this.title,
    required this.when,
    this.colorIndex = 4,
    this.priority = Priority.mittel,
    this.reminderLeadMinutes,
  });

  Color get color => taskPalette[colorIndex % taskPalette.length];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'colorIndex': colorIndex,
        'priority': priority.name,
        'reminderLeadMinutes': reminderLeadMinutes,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        title: json['title'] as String,
        when: DateTime.parse(json['when'] as String),
        colorIndex: json['colorIndex'] as int? ?? 4,
        priority: Priority.fromJson(json['priority']),
        reminderLeadMinutes: leadMinutesFromJson(json['reminderLeadMinutes']),
      );
}

/// Ob [task] an [day] nur noch liegen *bleibt*: Stufe 3, deren
/// Faelligkeitstag vorbei ist.
///
/// Das ist die Grenze, an der sich Stufe 3 vom Rest trennt. An ihrem
/// Faelligkeitstag ist eine leise Aufgabe eine Aufgabe wie jede andere: sie
/// steht unter "Heute abhaken" und zaehlt in "x offene Aufgaben heute". Erst
/// danach faellt sie aus der Zahl heraus und wandert in den Block "Hat Zeit"
/// – sie sollte an ihrem Tag erledigt sein, muss aber nicht, und eine Zahl,
/// die von so etwas jeden Tag weiterwaechst, sagt bald nichts mehr.
///
/// Nur einmalige Aufgaben koennen liegenbleiben: eine wiederkehrende ist an
/// einem Tag entweder faellig oder gar nicht dabei.
///
/// Steht hier und nicht im [AppState], weil die Startbildschirm-Widgets
/// dieselbe Grenze fuer *jeden* Tag ihres Schnappschusses brauchen, nicht
/// nur fuer heute (siehe home_widget.dart).
bool isLowLeftover(Task task, DateTime day) =>
    task.priority == Priority.niedrig && !task.occursOn(day);

/// Eine Erinnerungs-Uhrzeit aus dem Bestand: alles, was keine gueltige
/// Minute im Tag ist (fehlt, falscher Typ, ausserhalb 0–1439), heisst
/// "keine Erinnerung" – eine kaputte Zahl darf nicht zu einem Alarm zu
/// unmoeglicher Zeit werden.
int? minuteOfDayFromJson(Object? value) =>
    value is int && value >= 0 && value < 1440 ? value : null;

/// Ein Erinnerungs-Vorlauf aus dem Bestand. Negativ waere "nach dem
/// Termin" und ist nicht vorgesehen; nach oben deckelt [maxReminderLead]
/// (eine Woche) den Wert.
int? leadMinutesFromJson(Object? value) =>
    value is int && value >= 0 && value <= maxReminderLead ? value : null;

/// Der groesste Vorlauf, den die App anbietet: eine Woche.
const maxReminderLead = 7 * 24 * 60;

class Note {
  final String id;
  String title;
  String body;

  /// The day the note belongs to – this is what the calendar marks with "N".
  /// Defaults to the day it was written and can be moved in the editor;
  /// [updatedAt] keeps tracking the last edit for the notes list order.
  DateTime date;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    DateTime? date,
  }) : date = dateOnly(date ?? updatedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': dateKey(date),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.parse(json['updatedAt'] as String);
    final stored = json['date'] as String?;
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      updatedAt: updatedAt,
      // Notes written before the calendar marker keep the day they were
      // last touched, which is the only date they ever had.
      date: stored == null ? updatedAt : parseDateKey(stored),
    );
  }
}

/// A single completed occurrence, used for the history screen.
class HistoryEntry {
  final DateTime day;
  final Task task;
  HistoryEntry(this.day, this.task);
}

class AppState extends ChangeNotifier {
  static const _storageKey = 'joe_data_v1';

  /// Wohin ein unlesbarer Bestand gelegt wird, bevor die App weiterlaeuft.
  /// Grundsatz beim Laden: nie ueber die einzige Kopie der Daten schreiben.
  static const rescueKey = 'joe_data_v1_rescue';

  List<Task> tasks = [];
  List<Appointment> appointments = [];
  List<Note> notes = [];
  int themeIndex = 0;
  bool showPet = true;
  String petId = defaultPetId;

  /// Whether the dashboard's "Heute abhaken" fold-out stands open. Kept in
  /// storage so the dashboard comes back the way it was left.
  bool todayExpanded = true;

  /// Berechnete Kalender-Ebenen (siehe almanac.dart): Feiertage und
  /// Mondphasen sind von Haus aus an, das Bundesland waehlt der Nutzer.
  bool showHolidays = true;
  bool showMoon = true;
  HolidayRegion holidayRegion = HolidayRegion.bund;

  /// Die Kalender des Geraets (siehe device_calendar.dart) sind von Haus
  /// aus aus: sie brauchen eine Berechtigung, und die fragt Joe erst an,
  /// wenn der Schalter in den Einstellungen umgelegt wird.
  bool showDeviceCalendar = false;

  /// Welche Kalender des Geraets gezeigt werden. Drei Zustaende, und alle
  /// drei werden gebraucht:
  ///
  /// * **null** – nie ausgewaehlt, also alle. Auch ein Kalender, der spaeter
  ///   dazukommt, ist dann dabei.
  /// * **leer** – ausgewaehlt, dass keiner gezeigt wird. Ohne diesen
  ///   Unterschied zu null koennte man nicht alle abwaehlen.
  /// * **gefuellt** – genau diese. Eine ID, die es nicht mehr gibt, bleibt
  ///   stehen und stoert nicht.
  Set<String>? deviceCalendarIds;

  /// Der Hauptschalter fuer Erinnerungen (siehe reminders.dart). Aus heisst:
  /// nichts wird geplant, die Einstellung am einzelnen Eintrag bleibt aber
  /// stehen und gilt wieder, sobald der Schalter zurueckkommt.
  bool remindersEnabled = true;

  /// Womit ein neuer Termin startet – wie der Standard-Vorlauf im
  /// Google-Kalender. Aufgaben starten bewusst ohne (null): sie haben keine
  /// Uhrzeit, ein Alarm auf jeder neuen Aufgabe waere blosser Laerm.
  int? defaultAppointmentLead = 30;

  int _idCounter = 0;

  String nextId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      // Beispieldaten haengen am Schalter JOE_MOCK_DATA (siehe env.dart) und
      // sind ueberall aus: Joe faengt leer an. Gespeichert wird trotzdem,
      // sonst gilt jeder Start als der erste.
      if (JoeEnv.mockData) {
        JoeLog.log('Erster Start: Beispieldaten angelegt');
        _seed();
      } else {
        JoeLog.log('Erster Start: leer (Beispieldaten sind aus)');
      }
      await _save();
      return;
    }

    // Nichts hier darf den Start verhindern: main() wartet auf load(), ein
    // unlesbarer Bestand hiesse also weisser Bildschirm auf ewig – und der
    // naechste Griff des Nutzers waere "App-Daten loeschen". Deshalb wird
    // Eintrag fuer Eintrag gelesen: Kaputtes kostet nur sich selbst, und
    // sobald etwas verloren ging, wandert der komplette alte Bestand unter
    // [rescueKey], bevor der bereinigte gespeichert wird.
    var losses = 0;
    void loss() => losses++;

    Map<String, dynamic> data = const {};
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      loss();
    }
    tasks = _readList(data['tasks'], Task.fromJson, onLoss: loss);
    appointments =
        _readList(data['appointments'], Appointment.fromJson, onLoss: loss);
    notes = _readList(data['notes'], Note.fromJson, onLoss: loss);
    // Falsch getypte Einstellungen sind kein Verlust, nur ihr Standardwert.
    // 'showCat' ist der alte Schluessel aus der Zeit vor den Begleiterbildern.
    final storedTheme = data['themeIndex'];
    themeIndex = storedTheme is int ? storedTheme : 0;
    final storedShowPet = data['showPet'] ?? data['showCat'];
    showPet = storedShowPet is bool ? storedShowPet : true;
    final storedPet = data['petId'];
    petId = storedPet is String ? storedPet : defaultPetId;
    final storedExpanded = data['todayExpanded'];
    todayExpanded = storedExpanded is bool ? storedExpanded : true;
    final storedHolidays = data['showHolidays'];
    showHolidays = storedHolidays is bool ? storedHolidays : true;
    final storedMoon = data['showMoon'];
    showMoon = storedMoon is bool ? storedMoon : true;
    holidayRegion = HolidayRegion.fromJson(data['holidayRegion']);
    final storedDevice = data['showDeviceCalendar'];
    showDeviceCalendar = storedDevice is bool ? storedDevice : false;
    final storedCalendarIds = data['deviceCalendarIds'];
    deviceCalendarIds = storedCalendarIds is List
        ? storedCalendarIds.whereType<String>().toSet()
        : null;
    final storedReminders = data['remindersEnabled'];
    remindersEnabled = storedReminders is bool ? storedReminders : true;
    // Der Standard-Vorlauf darf auch bewusst "keine Erinnerung" sein, also
    // trennt erst das Fehlen des Schluessels den Standard vom leeren Wert.
    defaultAppointmentLead = data.containsKey('defaultAppointmentLead')
        ? leadMinutesFromJson(data['defaultAppointmentLead'])
        : 30;

    JoeLog.log('Geladen: ${tasks.length} Aufgaben, '
        '${appointments.length} Termine, ${notes.length} Notizen');
    if (losses > 0) {
      JoeLog.log('ACHTUNG: $losses Eintraege unlesbar, '
          'alter Bestand unter $rescueKey gesichert');
      await prefs.setString(rescueKey, raw);
      await _save();
    }
  }

  /// Liest eine Liste Eintrag fuer Eintrag: ein einzelner kaputter Eintrag
  /// kostet nur sich selbst, nicht die ganze Liste.
  static List<T> _readList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson, {
    required void Function() onLoss,
  }) {
    if (raw == null) return [];
    if (raw is! List) {
      onLoss();
      return [];
    }
    final out = <T>[];
    for (final item in raw) {
      try {
        out.add(fromJson(item as Map<String, dynamic>));
      } catch (_) {
        onLoss();
      }
    }
    return out;
  }

  void _seed() {
    final t = today();
    tasks = [
      Task(
        id: nextId(),
        title: 'Blumen gießen',
        recurrence: RecurrenceType.daily,
        startDate: t.subtract(const Duration(days: 3)),
        colorIndex: 2,
        completedDates: {
          dateKey(t.subtract(const Duration(days: 1))),
          dateKey(t.subtract(const Duration(days: 2))),
        },
      ),
      Task(
        id: nextId(),
        title: 'Wochenputz',
        recurrence: RecurrenceType.weekly,
        startDate: t,
        colorIndex: 3,
      ),
      Task(
        id: nextId(),
        title: 'Joe ausprobieren',
        startDate: t,
        colorIndex: 0,
        priority: Priority.hoch,
      ),
      // Stufe 3, und ihr Faelligkeitstag ist vorbei: sie zaehlt nicht mehr
      // in "offene Aufgaben heute" mit und steht unter "Hat Zeit".
      Task(
        id: nextId(),
        title: 'Bücherregal sortieren',
        startDate: t.subtract(const Duration(days: 5)),
        colorIndex: 5,
        priority: Priority.niedrig,
      ),
    ];
    appointments = [
      Appointment(
        id: nextId(),
        title: 'Kaffee mit Anna',
        when: t.add(const Duration(days: 1, hours: 15)),
        colorIndex: 4,
      ),
      Appointment(
        id: nextId(),
        title: 'Zahnarzt',
        when: t.add(const Duration(days: 3, hours: 9, minutes: 30)),
        colorIndex: 6,
        priority: Priority.hoch,
      ),
    ];
    notes = [
      Note(
        id: nextId(),
        title: 'Willkommen bei Joe',
        body: 'Hier ist Platz für deine Gedanken – einfach und ohne '
            'zwanzig Untermenüs.\n\nTippe auf das Stift-Symbol, um eine '
            'neue Notiz anzulegen.',
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'tasks': tasks.map((t) => t.toJson()).toList(),
          'appointments': appointments.map((a) => a.toJson()).toList(),
          'notes': notes.map((n) => n.toJson()).toList(),
          'themeIndex': themeIndex,
          'showPet': showPet,
          'petId': petId,
          'todayExpanded': todayExpanded,
          'showHolidays': showHolidays,
          'showMoon': showMoon,
          'holidayRegion': holidayRegion.name,
          'showDeviceCalendar': showDeviceCalendar,
          'deviceCalendarIds': deviceCalendarIds?.toList(),
          'remindersEnabled': remindersEnabled,
          'defaultAppointmentLead': defaultAppointmentLead,
        }),
      );
    } catch (e) {
      // _changed() wirft das Speichern fire-and-forget an; ohne das Log
      // verschwaende ein Fehler hier spurlos.
      JoeLog.log('FEHLER beim Speichern: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---- Tasks ----

  void addTask(Task task) {
    JoeLog.log('Aufgabe angelegt (${task.id})');
    tasks.add(task);
    _changed();
  }

  void updateTask(Task task) => _changed();

  void deleteTask(Task task) {
    JoeLog.log('Aufgabe geloescht (${task.id})');
    tasks.removeWhere((t) => t.id == task.id);
    _changed();
  }

  void toggleTask(Task task, DateTime day) {
    if (!task.isRecurring) {
      if (task.completedDates.isEmpty) {
        task.completedDates.add(dateKey(day));
      } else {
        task.completedDates.clear();
      }
    } else {
      final key = dateKey(day);
      if (!task.completedDates.remove(key)) {
        task.completedDates.add(key);
      }
    }
    _changed();
  }

  /// Tasks shown on a calendar day: occurrences plus (for one-offs completed
  /// on another day) the completion day.
  List<Task> tasksForDay(DateTime day) {
    final d = dateOnly(day);
    return tasks.where((t) {
      if (t.isRecurring) return t.occursOn(d);
      return dateOnly(t.startDate) == d;
    }).toList();
  }

  /// Everything that lands on today's plate: today's occurrences (open and
  /// done, so completed items stay visible) plus overdue one-offs.
  List<Task> _dueToday() {
    final t = today();
    return tasks.where((task) {
      if (task.occursOn(t)) return true;
      if (!task.isRecurring &&
          task.completedDates.isEmpty &&
          dateOnly(task.startDate).isBefore(t)) {
        return true;
      }
      return false;
    }).toList();
  }

  // ---- Sortierbausteine ----
  //
  // Die Listen unten sortieren alle aus denselben Kriterien; [_ordered] reiht
  // sie aneinander, und den Gleichstand bricht am Ende immer der Titel –
  // List.sort ist nicht stabil, ohne den Titel wackelte die Reihenfolge.

  static Comparator<Task> _ordered(List<Comparator<Task>> steps) => (a, b) {
        for (final step in steps) {
          final r = step(a, b);
          if (r != 0) return r;
        }
        return a.title.compareTo(b.title);
      };

  /// Offene vor erledigten Aufgaben, bezogen auf [day].
  static Comparator<Task> _openFirstOn(DateTime day) => (a, b) =>
      (a.isCompletedOn(day) ? 1 : 0) - (b.isCompletedOn(day) ? 1 : 0);

  static int _importantFirst(Task a, Task b) =>
      a.priority.level - b.priority.level;

  static int _newestFirst(Task a, Task b) =>
      b.startDate.compareTo(a.startDate);

  static int _soonestFirst(Task a, Task b) =>
      a.startDate.compareTo(b.startDate);

  /// Tasks for the dashboard "Heute abhaken" list, without the level-3
  /// leftovers – those get their own block underneath, see
  /// [lowLeftoverTasks]. Open items first, then the ones already ticked off.
  List<Task> tasksDueToday() {
    final t = today();
    return _dueToday().where((task) => !isLowLeftover(task, t)).toList()
      ..sort(_ordered([_openFirstOn(t), _importantFirst]));
  }

  /// Die liegengebliebenen Stufe-3-Aufgaben, neuste zuerst – der Block
  /// "Hat Zeit" unter "Heute abhaken" und auf dem Aufgaben-Reiter.
  ///
  /// Sie sind immer offen: liegenbleiben kann nur eine einmalige Aufgabe,
  /// die noch niemand abgehakt hat.
  List<Task> lowLeftoverTasks() {
    final t = today();
    return _dueToday().where((task) => isLowLeftover(task, t)).toList()
      ..sort(_ordered([_newestFirst]));
  }

  /// Was heute noch offen auf dem Teller liegt. Stufe 3 zaehlt an ihrem
  /// Faelligkeitstag mit – da ist sie so faellig wie alles andere –, danach
  /// nicht mehr (siehe [isLowLeftover]).
  int openTodayCount() {
    final t = today();
    return _dueToday()
        .where((task) => !task.isCompletedOn(t) && !isLowLeftover(task, t))
        .length;
  }

  /// One-off tasks dated after today, soonest first.
  List<Task> upcomingTasks() {
    final t = today();
    return tasks
        .where((task) =>
            !task.isRecurring &&
            task.completedDates.isEmpty &&
            dateOnly(task.startDate).isAfter(t))
        .toList()
      ..sort(_ordered([_soonestFirst]));
  }

  /// All recurring tasks, most important first.
  List<Task> recurringTasks() {
    return tasks.where((task) => task.isRecurring).toList()
      ..sort(_ordered([_importantFirst]));
  }

  /// One-off tasks that are done and stay done, newest completion first.
  List<Task> doneTasks() {
    String doneOn(Task task) =>
        task.completedDates.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return tasks
        .where((task) => !task.isRecurring && task.completedDates.isNotEmpty)
        .toList()
      ..sort(_ordered([(a, b) => doneOn(b).compareTo(doneOn(a))]));
  }

  // ---- Appointments ----

  void addAppointment(Appointment a) {
    JoeLog.log('Termin angelegt (${a.id})');
    appointments.add(a);
    _changed();
  }

  void updateAppointment(Appointment a) => _changed();

  void deleteAppointment(Appointment a) {
    JoeLog.log('Termin geloescht (${a.id})');
    appointments.removeWhere((x) => x.id == a.id);
    _changed();
  }

  List<Appointment> upcomingAppointments({int? limit}) {
    final t = today();
    final list = appointments.where((a) => !a.when.isBefore(t)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    if (limit != null && list.length > limit) return list.sublist(0, limit);
    return list;
  }

  List<Appointment> pastAppointments() {
    final t = today();
    return appointments.where((a) => a.when.isBefore(t)).toList()
      ..sort((a, b) => b.when.compareTo(a.when));
  }

  List<Appointment> appointmentsForDay(DateTime day) {
    final d = dateOnly(day);
    final list =
        appointments.where((a) => dateOnly(a.when) == d).toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return list;
  }

  // ---- Notes ----

  void addNote(Note n) {
    JoeLog.log('Notiz angelegt (${n.id})');
    notes.insert(0, n);
    _changed();
  }

  void updateNote(Note n) {
    n.updatedAt = DateTime.now();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _changed();
  }

  /// Speichert den laufenden Stand eines Notiz-Editors, ohne den gesamten
  /// App-Baum neu zu bauen. Ein solcher Neuaufbau mitten in der Texteingabe
  /// kann Fokus und Eingabemethode unterbrechen. Beim Verlassen des Editors
  /// folgt [updateNote], damit Listen und Widgets den neuen Stand sehen.
  void autosaveNote(Note n, {required bool isNew}) {
    if (isNew) {
      JoeLog.log('Notiz angelegt (${n.id})');
      notes.insert(0, n);
    }
    n.updatedAt = DateTime.now();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _save();
  }

  void deleteNote(Note n) {
    JoeLog.log('Notiz geloescht (${n.id})');
    notes.removeWhere((x) => x.id == n.id);
    _changed();
  }

  /// Notes filed under [day] – the calendar marks those days with an "N".
  List<Note> notesForDay(DateTime day) {
    final d = dateOnly(day);
    return notes.where((n) => dateOnly(n.date) == d).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // ---- History ----

  List<HistoryEntry> history() {
    final entries = <HistoryEntry>[];
    for (final task in tasks) {
      for (final key in task.completedDates) {
        entries.add(HistoryEntry(parseDateKey(key), task));
      }
    }
    entries.sort((a, b) => b.day.compareTo(a.day));
    return entries;
  }

  // ---- Settings ----

  void setTheme(int index) {
    themeIndex = index;
    _changed();
  }

  void setShowPet(bool value) {
    showPet = value;
    _changed();
  }

  void setTodayExpanded(bool value) {
    todayExpanded = value;
    _changed();
  }

  void setShowHolidays(bool value) {
    showHolidays = value;
    _changed();
  }

  void setShowMoon(bool value) {
    showMoon = value;
    _changed();
  }

  void setHolidayRegion(HolidayRegion region) {
    holidayRegion = region;
    _changed();
  }

  void setShowDeviceCalendar(bool value) {
    showDeviceCalendar = value;
    _changed();
  }

  void setDeviceCalendarIds(Set<String>? ids) {
    deviceCalendarIds = ids == null ? null : Set.unmodifiable(ids);
    _changed();
  }

  void setRemindersEnabled(bool value) {
    remindersEnabled = value;
    _changed();
  }

  void setDefaultAppointmentLead(int? minutes) {
    defaultAppointmentLead = minutes;
    _changed();
  }

  /// Der aktuell gewaehlte Begleiter, robust gegen einen gespeicherten
  /// Schluessel, den es nicht mehr gibt.
  Pet get pet => petById(petId);

  void setPet(String id) {
    petId = id;
    _changed();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
