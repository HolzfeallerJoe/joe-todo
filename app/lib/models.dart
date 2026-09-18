import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almanac.dart';
import 'env.dart';
import 'log.dart';
import 'pets.dart';
import 'util.dart';
import 'wellbeing.dart';

// Das Befinden gehoert zum Datenmodell; es steht nur in einer eigenen Datei,
// weil es mit Katalog und Skala fuer sich schon einiges ist. Wer models
// kennt, kennt es mit.
export 'wellbeing.dart';

/// Warm color palette for tasks and appointments – 25 Farben.
///
/// The first eight are the original palette and keep their index: a stored
/// `colorIndex` points into this list, so new colors only ever get appended.
/// Das gilt fuer jede Erweiterung: die fuenf seit der zweiten (Mint bis
/// Schiefer) stehen hinten, und die fruehere "Minze" (14) heisst jetzt
/// "Jade" – ihr Farbwert blieb, zwei Minzen waeren nur verwirrend.
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
  Color(0xFF7FBFA5), // Jade (frueher "Minze")
  Color(0xFF3A6E78), // Petrol
  Color(0xFF3B4E70), // Nachtblau
  Color(0xFF7B4B6E), // Pflaume
  Color(0xFFC77F92), // Altrosa
  Color(0xFF8E7BB0), // Lavendel
  Color(0xFF9FDFC4), // Mint
  Color(0xFF86BEE0), // Himmel
  Color(0xFFEE8A73), // Koralle
  Color(0xFFB9A1D6), // Flieder
  Color(0xFF66727F), // Schiefer
];

const taskPaletteNames = [
  'Terrakotta', 'Bernstein', 'Salbei', 'Tanne',
  'Beere', 'Walnuss', 'Taubenblau', 'Senf',
  'Rost', 'Lachs', 'Kürbis', 'Sand',
  'Oliv', 'Farn', 'Jade', 'Petrol',
  'Nachtblau', 'Pflaume', 'Altrosa', 'Lavendel',
  'Mint', 'Himmel', 'Koralle', 'Flieder', 'Schiefer',
];

/// Wie sich eine Aufgabe wiederholt.
///
/// "Taeglich" ist kein eigener Typ mehr: die Wochenskala im Blatt deckt es
/// ab, alle sieben Tage markiert heisst taeglich ([allWeekdays]). Zwei Wege
/// zum selben Ergebnis haetten nur die Frage aufgeworfen, welcher gilt. Den
/// Namen 'daily' gibt es noch im Bestand aelterer Fassungen; [Task.fromJson]
/// schreibt ihn beim Laden um.
enum RecurrenceType { none, weekly, monthly, yearly, everyXDays }

/// Alle sieben Wochentage, 1 = Montag wie bei [DateTime.weekday]. Eine
/// woechentliche Aufgabe mit diesen Tagen ist eine taegliche.
const allWeekdays = {1, 2, 3, 4, 5, 6, 7};

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

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

/// Die Farben, die die Einstellungen den Prioritaeten der Aufgaben geben
/// (Index in [taskPalette]). Fehlt eine Stufe, gilt "keine Farbe": die
/// Aufgabe zeigt ihre eigene.
///
/// Statisch wie [PetPlacement]: [Task.color] wird an vielen Stellen ohne
/// BuildContext gelesen (Kalender, Listen, Widget-Schnappschuss),
/// und jede davon soll dieselbe Farbe sehen. Gesetzt wird sie nur vom
/// [AppState] – beim Laden und in [AppState.setPriorityColor].
class PriorityColors {
  PriorityColors._();

  static Map<Priority, int> _active = const {};

  /// Der Palettenindex fuer [p]; null heisst "keine Farbe".
  static int? of(Priority p) => _active[p];

  static void use(Map<Priority, int> colors) =>
      _active = Map.unmodifiable(colors);

  /// Zurueck auf "keine Farbe" fuer alle Stufen – fuer Tests.
  static void reset() => _active = const {};
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

  /// Die Wochentage einer woechentlichen Aufgabe (1 = Montag wie bei
  /// [DateTime.weekday]); fuer die anderen Arten ohne Bedeutung. Eine
  /// woechentliche Aufgabe ohne Tag gibt es nicht – fehlt die Angabe, gilt
  /// der Wochentag des Starts, wie in der Fassung vor der Wochenskala.
  Set<int> weekdays;

  /// Wie viele Tage eine Wiederholung ueber ihren Starttag hinaus dauert
  /// (0 = nur der Starttag). "Mo 12:00 bis Do 18:00" ist 3.
  int spanDays;

  /// Uhrzeiten der Dauer als Minuten seit Mitternacht; beide null heisst:
  /// keine Uhrzeit (wie bisher). Es gibt sie nur zusammen – eine allein wird
  /// beim Laden verworfen.
  int? startMinute;
  int? endMinute;

  Task({
    required this.id,
    required this.title,
    this.recurrence = RecurrenceType.none,
    this.intervalDays = 2,
    required this.startDate,
    this.colorIndex = 0,
    this.priority = Priority.mittel,
    this.reminderMinuteOfDay,
    Set<int>? weekdays,
    this.spanDays = 0,
    this.startMinute,
    this.endMinute,
    Set<String>? completedDates,
  })  : weekdays = _validWeekdays(weekdays, recurrence, startDate),
        completedDates = completedDates ?? {};

  /// Die laengste Dauer, die beim Laden angenommen wird: ein Jahr. Mehr
  /// bietet das Blatt nicht an ([maxSpanDays]), und [occurrenceStartFor]
  /// schaut so viele Tage zurueck – eine kaputte Riesenzahl im Bestand
  /// darf daraus keine Schleife ohne Ende machen.
  static const maxStoredSpanDays = 365;

  /// Nur 1–7 zaehlen; eine woechentliche Aufgabe ohne gueltigen Tag bekommt
  /// den Wochentag ihres Starts.
  static Set<int> _validWeekdays(
      Iterable<int>? days, RecurrenceType recurrence, DateTime startDate) {
    final valid = {...?days?.where((d) => d >= 1 && d <= 7)};
    if (recurrence == RecurrenceType.weekly && valid.isEmpty) {
      return {startDate.weekday};
    }
    return valid;
  }

  /// Die Tage, an denen eine woechentliche Aufgabe tatsaechlich faellt.
  /// [weekdays] ist ein oeffentliches Feld und koennte nach dem Bau geleert
  /// werden; dann gilt dieselbe Regel wie im Konstruktor.
  Set<int> get _weeklyDays =>
      weekdays.isEmpty ? {dateOnly(startDate).weekday} : weekdays;

  /// Die Farbe, die im Aufgabenblatt gewaehlt wurde.
  Color get ownColor => taskPalette[colorIndex % taskPalette.length];

  /// Die Farbe, in der die Aufgabe erscheint: die ihrer Prioritaet, wenn die
  /// Einstellungen eine vorgeben, sonst die eigene. Die eigene wird dabei
  /// nie ueberschrieben – "Keine Farbe" in den Einstellungen bringt sie
  /// zurueck.
  Color get color {
    final p = PriorityColors.of(priority);
    return p == null ? ownColor : taskPalette[p % taskPalette.length];
  }

  bool get isRecurring => recurrence != RecurrenceType.none;

  /// Ob an [day] eine Wiederholung der Aufgabe *beginnt* (bei einer
  /// einmaligen: ob [day] ihr Starttag ist).
  bool startsOn(DateTime day) {
    final d = dateOnly(day);
    final s = dateOnly(startDate);
    if (d.isBefore(s)) return false;
    switch (recurrence) {
      case RecurrenceType.none:
        return d == s;
      case RecurrenceType.weekly:
        return _weeklyDays.contains(d.weekday);
      case RecurrenceType.monthly:
        // Am 31. begonnen heisst: Monate ohne 31. fallen aus – wie bisher.
        return d.day == s.day;
      case RecurrenceType.yearly:
        if (d.month != s.month) return false;
        if (d.day == s.day) return true;
        // Am 29.2. begonnen: in Jahren ohne Schalttag am 28.2.
        return s.month == 2 &&
            s.day == 29 &&
            d.day == 28 &&
            !_isLeapYear(d.year);
      case RecurrenceType.everyXDays:
        // In Kalendertagen gezaehlt, nicht in Stunden: ueber die
        // Sommerzeit-Umstellung hinweg fehlt sonst eine Stunde, und
        // Duration.inDays rundet einen ganzen Tag weg.
        return calendarDaysBetween(s, d) %
                (intervalDays < 1 ? 1 : intervalDays) ==
            0;
    }
  }

  /// Ob die Aufgabe eine Dauer hat: mehrere Tage oder Uhrzeiten.
  bool get hasDuration => spanDays > 0 || startMinute != null;

  /// Der Starttag der Wiederholung, die [day] abdeckt – bei einer Aufgabe
  /// "Mo bis Do" also fuer Mi der Montag. null: [day] liegt in keiner.
  DateTime? occurrenceStartFor(DateTime day) {
    final d = dateOnly(day);
    if (recurrence == RecurrenceType.none) {
      // Ohne Wiederholung genuegt ein Vergleich – keine Schleife.
      final s = dateOnly(startDate);
      return !d.isBefore(s) && !d.isAfter(lastDay) ? s : null;
    }
    // Die juengste Wiederholung gewinnt; ueberlappen duerfen sie nicht
    // (siehe [maxSpanDays]).
    for (var k = 0; k <= spanDays; k++) {
      final candidate = addCalendarDays(d, -k);
      if (startsOn(candidate)) return candidate;
    }
    return null;
  }

  /// Ob die Aufgabe an [day] faellig ist: an jedem Tag der Spanne einer
  /// Wiederholung, nicht nur an ihrem Starttag.
  bool occursOn(DateTime day) => occurrenceStartFor(day) != null;

  /// Letzter Tag der ersten (bei einmaligen: der einzigen) Wiederholung.
  /// Ueberfaellig ist eine einmalige Aufgabe erst danach.
  DateTime get lastDay => addCalendarDays(dateOnly(startDate), spanDays);

  /// Beginn und Ende der Wiederholung, die an [occurrenceStart] beginnt.
  /// Ohne Uhrzeit beginnt sie um Mitternacht und endet um Mitternacht nach
  /// ihrem letzten Tag (das Ende ist exklusiv, wie im Kalender).
  ({DateTime start, DateTime end}) spanOf(DateTime occurrenceStart) {
    final s = dateOnly(occurrenceStart);
    final e = addCalendarDays(s, spanDays);
    return (
      start: DateTime(s.year, s.month, s.day, 0, startMinute ?? 0),
      end: DateTime(e.year, e.month, e.day, 0, endMinute ?? 24 * 60),
    );
  }

  /// Einmalige Aufgaben sind einmal erledigt und bleiben es; wiederkehrende
  /// je Wiederholung – abgehakt wird am Starttag der Wiederholung, und das
  /// gilt fuer jeden Tag ihrer Spanne.
  bool isCompletedOn(DateTime day) {
    if (!isRecurring) return completedDates.isNotEmpty;
    final start = occurrenceStartFor(day);
    return start != null && completedDates.contains(dateKey(start));
  }

  /// Die laengste Dauer, bei der sich zwei Wiederholungen nicht ueberlappen
  /// – sonst waere unklar, welche man abhakt. Das Blatt prueft dagegen.
  static int maxSpanDays(
          RecurrenceType r, Set<int> weekdays, int intervalDays) =>
      switch (r) {
        RecurrenceType.none => maxStoredSpanDays,
        RecurrenceType.weekly => _smallestWeekdayGap(weekdays) - 1,
        // Der kuerzeste Monat hat 28 Tage.
        RecurrenceType.monthly => 27,
        RecurrenceType.yearly => 364,
        RecurrenceType.everyXDays => intervalDays < 2 ? 0 : intervalDays - 1,
      };

  /// Der kleinste Abstand zwischen zwei gewaehlten Wochentagen, ueber das
  /// Wochenende hinweg gezaehlt (von So zurueck zu Mo). Ein Tag allein hat
  /// den Abstand einer Woche.
  static int _smallestWeekdayGap(Set<int> weekdays) {
    final days = weekdays.where((d) => d >= 1 && d <= 7).toSet().toList()
      ..sort();
    if (days.length < 2) return 7;
    var gap = 7 - days.last + days.first;
    for (var i = 1; i < days.length; i++) {
      final g = days[i] - days[i - 1];
      if (g < gap) gap = g;
    }
    return gap;
  }

  String get recurrenceLabel {
    switch (recurrence) {
      case RecurrenceType.none:
        return 'Einmalig';
      case RecurrenceType.weekly:
        return weekdaysLabel(_weeklyDays);
      case RecurrenceType.monthly:
        return 'Monatlich';
      case RecurrenceType.yearly:
        return 'Jährlich';
      case RecurrenceType.everyXDays:
        return 'Alle $intervalDays Tage';
    }
  }

  /// Wie eine Auswahl auf der Wochenskala heisst: "Täglich", "Werktags",
  /// "Am Wochenende", "Jeden Montag" oder die Kurznamen in Wochenfolge
  /// ("Mo, Mi, Fr").
  static String weekdaysLabel(Set<int> days) {
    final sorted = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    if (sorted.length == 7) return 'Täglich';
    if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
      return 'Werktags';
    }
    if (sorted.length == 2 && sorted.first == 6 && sorted.last == 7) {
      return 'Am Wochenende';
    }
    if (sorted.length == 1) return 'Jeden ${weekdayNames[sorted.single - 1]}';
    return sorted.map((d) => weekdayNamesShort[d - 1]).join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recurrence': recurrence.name,
        'intervalDays': intervalDays,
        'startDate': dateKey(startDate),
        if (recurrence == RecurrenceType.weekly)
          'weekdays': _weeklyDays.toList()..sort(),
        if (spanDays > 0) 'spanDays': spanDays,
        'startMinute': ?startMinute,
        'endMinute': ?endMinute,
        'colorIndex': colorIndex,
        'priority': priority.name,
        'reminderMinuteOfDay': reminderMinuteOfDay,
        'completedDates': completedDates.toList(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    final storedRecurrence = json['recurrence'];
    // 'daily' stammt aus der Fassung vor der Wochenskala (siehe
    // [RecurrenceType]): taeglich ist jetzt woechentlich an allen Tagen.
    final wasDaily = storedRecurrence == 'daily';
    final storedDays = json['weekdays'];
    // Die Dauer: Unbrauchbares heisst "keine Dauer", kein Verlust. Die
    // Uhrzeiten gibt es nur als Paar – ein Anfang ohne Ende sagt nichts.
    final storedSpan = json['spanDays'];
    final spanDays = storedSpan is int && storedSpan > 0
        ? (storedSpan > maxStoredSpanDays ? maxStoredSpanDays : storedSpan)
        : 0;
    var startMinute = minuteOfDayFromJson(json['startMinute']);
    var endMinute = minuteOfDayFromJson(json['endMinute']);
    if (startMinute == null || endMinute == null) {
      startMinute = null;
      endMinute = null;
    }
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      recurrence: wasDaily
          ? RecurrenceType.weekly
          : RecurrenceType.values.firstWhere((r) => r.name == storedRecurrence,
              orElse: () => RecurrenceType.none),
      intervalDays: json['intervalDays'] as int? ?? 2,
      startDate: parseDateKey(json['startDate'] as String),
      colorIndex: json['colorIndex'] as int? ?? 0,
      priority: Priority.fromJson(json['priority']),
      reminderMinuteOfDay: minuteOfDayFromJson(json['reminderMinuteOfDay']),
      // Fremdkoerper in der Liste fallen still weg; ein fehlender Tag ist
      // kein Verlust, der Konstruktor setzt den Wochentag des Starts.
      weekdays: wasDaily
          ? allWeekdays
          : storedDays is List
              ? storedDays.whereType<int>().toSet()
              : null,
      spanDays: spanDays,
      startMinute: startMinute,
      endMinute: endMinute,
      completedDates: (json['completedDates'] as List<dynamic>? ?? []).cast<String>().toSet(),
    );
  }
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

  /// Ende des Termins, exklusiv wie im Kalender: bis 18:00 heisst, um 18:00
  /// ist er vorbei; ein Ende um Mitternacht gehoert nicht mehr auf den
  /// Folgetag. null = ein Zeitpunkt, wie bisher.
  DateTime? end;

  Appointment({
    required this.id,
    required this.title,
    required this.when,
    this.end,
    this.colorIndex = 4,
    this.priority = Priority.mittel,
    this.reminderLeadMinutes,
  });

  Color get color => taskPalette[colorIndex % taskPalette.length];

  /// Der letzte Tag, den der Termin beruehrt. Ein Ende, das nicht nach dem
  /// Start liegt, zaehlt nicht – dann ist er ein Zeitpunkt.
  DateTime get lastDay {
    final e = end;
    if (e == null || !e.isAfter(when)) return dateOnly(when);
    return dateOnly(e.subtract(const Duration(seconds: 1)));
  }

  /// Ob der Termin an [day] stattfindet – an jedem Tag seiner Spanne.
  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(dateOnly(when)) && !d.isAfter(lastDay);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'end': ?end?.toIso8601String(),
        'colorIndex': colorIndex,
        'priority': priority.name,
        'reminderLeadMinutes': reminderLeadMinutes,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final when = DateTime.parse(json['when'] as String);
    // Ein unlesbares Ende oder eines vor dem Start kostet nur das Ende: der
    // Termin bleibt als Zeitpunkt stehen.
    final storedEnd = json['end'];
    final end = storedEnd is String ? DateTime.tryParse(storedEnd) : null;
    return Appointment(
      id: json['id'] as String,
      title: json['title'] as String,
      when: when,
      end: end != null && end.isAfter(when) ? end : null,
      colorIndex: json['colorIndex'] as int? ?? 4,
      priority: Priority.fromJson(json['priority']),
      reminderLeadMinutes: leadMinutesFromJson(json['reminderLeadMinutes']),
    );
  }
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

/// Wo die Einkaufsliste wohnt (Einstellungen).
///
/// Beide Modi teilen sich einen Speicher ([AppState.shopping]): Eintraege
/// ohne Tag gehoeren zum Reiter, Eintraege mit Tag zur Liste dieses Tages.
/// Umschalten loescht nichts, der andere Teil ist nur nicht zu sehen.
enum ShoppingListMode {
  /// Ein eigener Reiter auf der ersten Seite, eine Liste fuer alle Tage.
  tab('Eigener Reiter', 'Eine Liste für alle Tage'),

  /// In den Notizen, je Tag eine eigene Liste.
  perDay('In den Notizen', 'Jeder Tag hat seine eigene Liste');

  final String label;
  final String description;
  const ShoppingListMode(this.label, this.description);

  static ShoppingListMode fromJson(Object? v) => ShoppingListMode.values
      .firstWhere((m) => m.name == v, orElse: () => ShoppingListMode.tab);
}

/// Ein Eintrag der Einkaufsliste.
class ShoppingItem {
  final String id;
  String title;
  bool done;

  /// Der Tag, an den der Eintrag gebunden ist; null = die Liste im Reiter.
  final DateTime? day;

  /// Wann er angelegt wurde – danach richtet sich die Reihenfolge.
  final DateTime createdAt;

  ShoppingItem({
    required this.id,
    required this.title,
    this.done = false,
    DateTime? day,
    required this.createdAt,
  }) : day = day == null ? null : dateOnly(day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'day': day == null ? null : dateKey(day!),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final storedDay = json['day'];
    return ShoppingItem(
      id: json['id'] as String,
      title: json['title'] as String,
      // Ein falsch getypter Haken ist kein Grund, den Eintrag zu verlieren.
      done: json['done'] == true,
      day: storedDay == null ? null : parseDateKey(storedDay as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AppState extends ChangeNotifier {
  static const _storageKey = 'joe_data_v1';

  /// Wohin ein unlesbarer Bestand gelegt wird, bevor die App weiterlaeuft.
  /// Grundsatz beim Laden: nie ueber die einzige Kopie der Daten schreiben.
  static const rescueKey = 'joe_data_v1_rescue';

  List<Task> tasks = [];
  List<Appointment> appointments = [];
  List<Note> notes = [];

  /// Das Befinden – beliebig viele Eintraege je Tag, jeder mit seiner
  /// Uhrzeit (siehe wellbeing.dart).
  List<WellbeingEntry> wellbeing = [];

  /// Selbst angelegte Symptome, zusaetzlich zu den zehn festen.
  List<Symptom> customSymptoms = [];

  /// Die Einkaufsliste – die des Reiters und die der Tage in einem
  /// (siehe [ShoppingListMode]).
  List<ShoppingItem> shopping = [];
  ShoppingListMode shoppingMode = ShoppingListMode.tab;
  int themeIndex = 0;
  bool showPet = true;
  String petId = defaultPetId;

  /// Groesse des Begleiters aus dem Regler, 1.0 = 100 % (siehe [petBox]),
  /// immer zwischen [minPetScale] und [maxPetScale].
  double petScale = 1.0;

  /// Whether the dashboard's "Heute abhaken" fold-out stands open. Kept in
  /// storage so the dashboard comes back the way it was left.
  bool todayExpanded = true;

  /// Dasselbe fuer "Naechste Termine" im Termin-Block darunter.
  bool appointmentsExpanded = true;

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

  /// Die Farben der Prioritaeten (Index in [taskPalette]); eine Stufe ohne
  /// Eintrag hat "keine Farbe". Wirksam wird die Tabelle ueber
  /// [PriorityColors] – geaendert wird sie nur mit [setPriorityColor],
  /// sonst liefen beide auseinander.
  Map<Priority, int> priorityColors = {};

  int _idCounter = 0;

  String nextId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      // Die Tabelle ist statisch: ohne das hier naehme ein zweiter
      // AppState (in Tests) die Farben des ersten mit.
      PriorityColors.use(const {});
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
    wellbeing = _readList(data['wellbeing'], WellbeingEntry.fromJson,
        onLoss: loss);
    customSymptoms =
        _readList(data['customSymptoms'], Symptom.fromJson, onLoss: loss);
    shopping = _readList(data['shopping'], ShoppingItem.fromJson, onLoss: loss);
    shoppingMode = ShoppingListMode.fromJson(data['shoppingMode']);
    // Falsch getypte Einstellungen sind kein Verlust, nur ihr Standardwert.
    // 'showCat' ist der alte Schluessel aus der Zeit vor den Begleiterbildern.
    final storedTheme = data['themeIndex'];
    themeIndex = storedTheme is int ? storedTheme : 0;
    final storedShowPet = data['showPet'] ?? data['showCat'];
    showPet = storedShowPet is bool ? storedShowPet : true;
    final storedPet = data['petId'];
    petId = storedPet is String ? storedPet : defaultPetId;
    final storedScale = data['petScale'];
    petScale = storedScale is num
        ? _clampPetScale(storedScale.toDouble())
        : 1.0;
    final storedExpanded = data['todayExpanded'];
    todayExpanded = storedExpanded is bool ? storedExpanded : true;
    final storedAppointments = data['appointmentsExpanded'];
    appointmentsExpanded =
        storedAppointments is bool ? storedAppointments : true;
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
    priorityColors = _readPriorityColors(data['priorityColors']);
    PriorityColors.use(priorityColors);

    JoeLog.log('Geladen: ${tasks.length} Aufgaben, '
        '${appointments.length} Termine, ${notes.length} Notizen, '
        '${wellbeing.length} Befinden, ${shopping.length} Einkauf');
    // Aus der Zeit, als das Befinden noch am Tag hing (siehe dort).
    adoptOrphanWellbeing();
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

  /// Die Prioritaetsfarben aus dem Bestand: nur bekannte Stufen mit einem
  /// Index, den es in der Palette gibt. Alles andere heisst "keine Farbe" –
  /// eine Einstellung, kein Verlust.
  static Map<Priority, int> _readPriorityColors(Object? raw) {
    final out = <Priority, int>{};
    if (raw is! Map) return out;
    for (final p in Priority.values) {
      final index = raw[p.name];
      if (index is int && index >= 0 && index < taskPalette.length) {
        out[p] = index;
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
        recurrence: RecurrenceType.weekly,
        weekdays: allWeekdays,
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
          'wellbeing': wellbeing.map((w) => w.toJson()).toList(),
          'customSymptoms': customSymptoms.map((s) => s.toJson()).toList(),
          'shopping': shopping.map((s) => s.toJson()).toList(),
          'shoppingMode': shoppingMode.name,
          'themeIndex': themeIndex,
          'showPet': showPet,
          'petId': petId,
          'petScale': petScale,
          'todayExpanded': todayExpanded,
          'appointmentsExpanded': appointmentsExpanded,
          'showHolidays': showHolidays,
          'showMoon': showMoon,
          'holidayRegion': holidayRegion.name,
          'showDeviceCalendar': showDeviceCalendar,
          'deviceCalendarIds': deviceCalendarIds?.toList(),
          'remindersEnabled': remindersEnabled,
          'defaultAppointmentLead': defaultAppointmentLead,
          'priorityColors': {
            for (final e in priorityColors.entries) e.key.name: e.value,
          },
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
      // Abgehakt wird die Wiederholung, nicht der Tag: der Schluessel ist
      // ihr Starttag, so gilt der Haken an jedem Tag ihrer Spanne (und die
      // Historie zeigt den Starttag).
      final key = dateKey(task.occurrenceStartFor(day) ?? day);
      if (!task.completedDates.remove(key)) {
        task.completedDates.add(key);
      }
    }
    _changed();
  }

  /// Die Aufgaben eines Kalendertags: jede, die an ihm faellig ist – mit
  /// Dauer an jedem Tag ihrer Spanne. Eine einmalige Aufgabe steht an ihren
  /// eigenen Tagen, nicht am Tag, an dem sie abgehakt wurde.
  List<Task> tasksForDay(DateTime day) {
    final d = dateOnly(day);
    return tasks.where((t) => t.occursOn(d)).toList();
  }

  /// Everything that lands on today's plate: today's occurrences (open and
  /// done, so completed items stay visible) plus overdue one-offs.
  /// Ueberfaellig ist eine einmalige Aufgabe erst nach ihrem letzten Tag.
  List<Task> _dueToday() {
    final t = today();
    return tasks.where((task) {
      if (task.occursOn(t)) return true;
      if (!task.isRecurring &&
          task.completedDates.isEmpty &&
          task.lastDay.isBefore(t)) {
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

  /// Termine ab heute. Ein mehrtaegiger, der schon begonnen hat, aber noch
  /// laeuft, zaehlt mit: er ist nicht vergangen.
  List<Appointment> upcomingAppointments({int? limit}) {
    final t = today();
    final list = appointments.where((a) => !a.lastDay.isBefore(t)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    if (limit != null && list.length > limit) return list.sublist(0, limit);
    return list;
  }

  List<Appointment> pastAppointments() {
    final t = today();
    return appointments.where((a) => a.lastDay.isBefore(t)).toList()
      ..sort((a, b) => b.when.compareTo(a.when));
  }

  /// Die Termine eines Tages – ein mehrtaegiger an jedem Tag seiner Spanne.
  List<Appointment> appointmentsForDay(DateTime day) {
    final d = dateOnly(day);
    final list =
        appointments.where((a) => a.coversDay(d)).toList()
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
    // Das Befinden gehoert der Notiz, in der es eingetragen wurde – also
    // geht es mit. Dass es mitgeht, sagt die Loeschkarte vorher an.
    final entries = wellbeing.where((e) => e.noteId == n.id).length;
    JoeLog.log('Notiz geloescht (${n.id}, $entries Befinden)');
    notes.removeWhere((x) => x.id == n.id);
    wellbeing.removeWhere((e) => e.noteId == n.id);
    _changed();
  }

  /// Notes filed under [day] – the calendar marks those days with an "N".
  List<Note> notesForDay(DateTime day) {
    final d = dateOnly(day);
    return notes.where((n) => dateOnly(n.date) == d).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // ---- Befinden ----

  /// Die Eintraege der Notiz [noteId], nach Uhrzeit – morgens zuerst.
  List<WellbeingEntry> wellbeingOfNote(String? noteId) {
    if (noteId == null) return const [];
    return wellbeing.where((e) => e.noteId == noteId).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Ein neuer Eintrag zum Bearbeiten, standardmaessig auf jetzt. Er
  /// entsteht hier nur als Entwurf und wird erst mit [saveWellbeing]
  /// aufbewahrt – das blosse Oeffnen des Editors soll nichts anlegen.
  ///
  /// Faellt [day] auf einen anderen Tag als heute (die Notiz haengt an einem
  /// vergangenen Tag), bekommt der Entwurf die aktuelle Uhrzeit an *diesem*
  /// Tag: der Tag ist die Aussage, die Uhrzeit nur ihre Einordnung.
  WellbeingEntry newWellbeingDraft(DateTime day, {required String noteId}) {
    final now = DateTime.now();
    final d = dateOnly(day);
    return WellbeingEntry(
      id: nextId(),
      noteId: noteId,
      at: DateTime(d.year, d.month, d.day, now.hour, now.minute),
      updatedAt: now,
    );
  }

  /// Eintraege aus der Fassung, in der das Befinden noch am Tag hing und
  /// nicht an einer Notiz, bekommen beim Start eine Notiz zugewiesen: die
  /// aelteste ihres Tages.
  ///
  /// Ein Tag ohne Notiz behaelt seine heimatlosen Eintraege – sie sind dann
  /// zwar nirgends zu sehen, aber wegwerfen waere schlimmer: Aufzeichnungen
  /// ueber die eigene Gesundheit loescht man nicht im Vorbeigehen.
  void adoptOrphanWellbeing() {
    var adopted = 0;
    var homeless = 0;
    for (final entry in wellbeing) {
      if (entry.noteId != null) continue;
      final sameDay = notes.where((n) => dateOnly(n.date) == entry.day).toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      if (sameDay.isEmpty) {
        homeless++;
        continue;
      }
      entry.noteId = sameDay.first.id;
      adopted++;
    }
    if (adopted > 0 || homeless > 0) {
      JoeLog.log('Befinden: $adopted Eintraege einer Notiz zugeordnet, '
          '$homeless ohne Notiz an ihrem Tag');
      _save();
    }
  }

  /// Nimmt einen bearbeiteten Eintrag auf – erkannt an seiner id, damit
  /// mehrere Eintraege desselben Tages nebeneinander bestehen.
  ///
  /// Ein leerer Eintrag (keine Stimmung, kein Symptom) wird nicht
  /// aufbewahrt, sondern entfernt: sonst saehe ein Zeitpunkt, an dem man den
  /// Editor nur aufgemacht hat, aus wie ein eingetragenes Befinden.
  void saveWellbeing(WellbeingEntry entry) {
    wellbeing.removeWhere((e) => e.id == entry.id);
    if (entry.isEmpty) {
      JoeLog.log('Befinden geleert (${dateKey(entry.day)})');
    } else {
      entry.updatedAt = DateTime.now();
      wellbeing.add(entry);
      JoeLog.log('Befinden gespeichert (${dateKey(entry.day)})');
    }
    _changed();
  }

  void deleteWellbeing(WellbeingEntry entry) {
    JoeLog.log('Befinden geloescht (${dateKey(entry.day)})');
    wellbeing.removeWhere((e) => e.id == entry.id);
    _changed();
  }

  /// Der ganze Symptom-Katalog: erst die zehn festen, dann die eigenen in
  /// der Reihenfolge, in der sie angelegt wurden.
  List<Symptom> get symptomCatalog => [...fixedSymptoms, ...customSymptoms];

  /// Das Symptom zu [id]; null, wenn es den Schluessel nicht mehr gibt.
  Symptom? symptomById(String id) {
    for (final s in symptomCatalog) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Legt ein eigenes Symptom an und gibt es zurueck. Ein Name, den es
  /// schon gibt, legt nichts Neues an – sonst stuenden zwei gleich
  /// heissende Zeilen untereinander.
  Symptom addCustomSymptom(String name) {
    final trimmed = name.trim();
    for (final s in symptomCatalog) {
      if (s.name.toLowerCase() == trimmed.toLowerCase()) return s;
    }
    final symptom = Symptom('eigen_${nextId()}', trimmed, custom: true);
    customSymptoms.add(symptom);
    JoeLog.log('Symptom angelegt (${symptom.id})');
    _changed();
    return symptom;
  }

  /// In wie vielen Eintraegen [symptomId] vorkommt – die Loeschkarte sagt
  /// es dazu, damit niemand ungewollt seine Aufzeichnungen wegwirft.
  int wellbeingUsageOf(String symptomId) =>
      wellbeing.where((e) => e.symptoms.containsKey(symptomId)).length;

  /// Loescht ein eigenes Symptom – samt seiner Werte in allen Eintraegen.
  ///
  /// Die Werte stehenzulassen waere die schlechtere Wahl: sie gehoerten zu
  /// einem Namen, den es nicht mehr gibt, und wuerden nirgends mehr
  /// angezeigt. Ein Eintrag, der dadurch leer wird, faellt mit weg.
  void deleteCustomSymptom(String symptomId) {
    customSymptoms.removeWhere((s) => s.id == symptomId);
    for (final entry in wellbeing) {
      entry.symptoms.remove(symptomId);
    }
    wellbeing.removeWhere((e) => e.isEmpty);
    JoeLog.log('Symptom geloescht ($symptomId)');
    _changed();
  }

  // ---- Einkaufsliste ----

  /// Die Eintraege einer Liste: [day] null = die im Reiter, sonst die dieses
  /// Tages. Offene zuerst, darin aelteste oben (neue landen unten, nahe am
  /// Eingabefeld); danach die abgehakten.
  List<ShoppingItem> shoppingItemsFor(DateTime? day) {
    final d = day == null ? null : dateOnly(day);
    // Die Stelle in der Liste bricht einen Gleichstand der Zeit: zwei
    // schnell hintereinander getippte Eintraege koennen dieselbe haben, und
    // List.sort ist nicht stabil.
    final indexed = [
      for (var i = 0; i < shopping.length; i++)
        if (shopping[i].day == d) (i, shopping[i]),
    ]..sort((a, b) {
        final done = (a.$2.done ? 1 : 0) - (b.$2.done ? 1 : 0);
        if (done != 0) return done;
        final time = a.$2.createdAt.compareTo(b.$2.createdAt);
        if (time != 0) return time;
        return a.$1 - b.$1;
      });
    return [for (final (_, item) in indexed) item];
  }

  /// Legt einen Eintrag an und gibt ihn zurueck; ein leerer Titel legt
  /// nichts an (null).
  ShoppingItem? addShoppingItem(String title, {DateTime? day}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final item = ShoppingItem(
      id: nextId(),
      title: trimmed,
      day: day,
      createdAt: DateTime.now(),
    );
    JoeLog.log('Einkauf angelegt (${item.id})');
    shopping.add(item);
    _changed();
    return item;
  }

  void toggleShoppingItem(ShoppingItem item) {
    item.done = !item.done;
    _changed();
  }

  /// Ein leerer Titel aendert nichts – geloescht wird nur ueber
  /// [deleteShoppingItem], mit Rueckfrage.
  void renameShoppingItem(ShoppingItem item, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    item.title = trimmed;
    _changed();
  }

  void deleteShoppingItem(ShoppingItem item) {
    JoeLog.log('Einkauf geloescht (${item.id})');
    shopping.removeWhere((s) => s.id == item.id);
    _changed();
  }

  void setShoppingMode(ShoppingListMode mode) {
    shoppingMode = mode;
    _changed();
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

  void setAppointmentsExpanded(bool value) {
    appointmentsExpanded = value;
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

  /// Gibt der Stufe [p] eine Farbe (Index in [taskPalette]); null heisst
  /// "keine Farbe", die Aufgaben zeigen wieder ihre eigene. Das Neuzeichnen
  /// – auch des Startbildschirm-Widgets – loest [notifyListeners] aus.
  void setPriorityColor(Priority p, int? index) {
    final next = {...priorityColors};
    if (index == null || index < 0 || index >= taskPalette.length) {
      next.remove(p);
    } else {
      next[p] = index;
    }
    priorityColors = next;
    PriorityColors.use(next);
    _changed();
  }

  /// Der aktuell gewaehlte Begleiter, robust gegen einen gespeicherten
  /// Schluessel, den es nicht mehr gibt.
  Pet get pet => petById(petId);

  void setPet(String id) {
    petId = id;
    _changed();
  }

  /// Stellt die Groesse des Begleiters ein – auf eine Nachkommastelle
  /// gerundet (der Regler hat Zehnerschritte, und im Bestand soll keine
  /// 0.7000000001 stehen) und in die Grenzen des Reglers geklemmt.
  void setPetScale(double value) {
    petScale = _clampPetScale((value * 10).round() / 10);
    _changed();
  }

  /// NaN und Unendlich werden zu 100 %, alles andere in die Grenzen des
  /// Reglers gelegt.
  static double _clampPetScale(double value) =>
      value.isFinite ? value.clamp(minPetScale, maxPetScale) : 1.0;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
