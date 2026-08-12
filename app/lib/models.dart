import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pets.dart';
import 'util.dart';

/// Warm color palette for tasks and appointments.
const taskPalette = [
  Color(0xFFC0563B), // Terrakotta
  Color(0xFFD98E32), // Bernstein
  Color(0xFF8A9A5B), // Salbei
  Color(0xFF4E937A), // Tanne
  Color(0xFFB23A5E), // Beere
  Color(0xFF7A5C3E), // Walnuss
  Color(0xFF5B7C99), // Taubenblau
  Color(0xFFC9A227), // Senf
];

const taskPaletteNames = [
  'Terrakotta', 'Bernstein', 'Salbei', 'Tanne',
  'Beere', 'Walnuss', 'Taubenblau', 'Senf',
];

enum RecurrenceType { none, daily, weekly, monthly, everyXDays }

class Task {
  final String id;
  String title;
  RecurrenceType recurrence;
  int intervalDays;
  DateTime startDate;
  int colorIndex;
  Set<String> completedDates;

  Task({
    required this.id,
    required this.title,
    this.recurrence = RecurrenceType.none,
    this.intervalDays = 2,
    required this.startDate,
    this.colorIndex = 0,
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
        completedDates: (json['completedDates'] as List<dynamic>? ?? []).cast<String>().toSet(),
      );
}

class Appointment {
  final String id;
  String title;
  DateTime when;
  int colorIndex;

  Appointment({
    required this.id,
    required this.title,
    required this.when,
    this.colorIndex = 4,
  });

  Color get color => taskPalette[colorIndex % taskPalette.length];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'colorIndex': colorIndex,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        title: json['title'] as String,
        when: DateTime.parse(json['when'] as String),
        colorIndex: json['colorIndex'] as int? ?? 4,
      );
}

class Note {
  final String id;
  String title;
  String body;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// A single completed occurrence, used for the history screen.
class HistoryEntry {
  final DateTime day;
  final Task task;
  HistoryEntry(this.day, this.task);
}

class AppState extends ChangeNotifier {
  static const _storageKey = 'joe_data_v1';

  List<Task> tasks = [];
  List<Appointment> appointments = [];
  List<Note> notes = [];
  int themeIndex = 0;
  bool showPet = true;
  String petId = defaultPetId;

  int _idCounter = 0;

  String nextId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _seed();
      await _save();
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    tasks = (data['tasks'] as List<dynamic>? ?? [])
        .map((j) => Task.fromJson(j as Map<String, dynamic>))
        .toList();
    appointments = (data['appointments'] as List<dynamic>? ?? [])
        .map((j) => Appointment.fromJson(j as Map<String, dynamic>))
        .toList();
    notes = (data['notes'] as List<dynamic>? ?? [])
        .map((j) => Note.fromJson(j as Map<String, dynamic>))
        .toList();
    themeIndex = data['themeIndex'] as int? ?? 0;
    // 'showCat' ist der alte Schluessel aus der Zeit vor den Begleiterbildern.
    showPet = data['showPet'] as bool? ?? data['showCat'] as bool? ?? true;
    petId = data['petId'] as String? ?? defaultPetId;
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
      }),
    );
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---- Tasks ----

  void addTask(Task task) {
    tasks.add(task);
    _changed();
  }

  void updateTask(Task task) => _changed();

  void deleteTask(Task task) {
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

  /// Tasks for the dashboard "Heute" list: today's occurrences (open and
  /// done, so completed items stay visible) plus overdue one-offs.
  List<Task> tasksDueToday() {
    final t = today();
    final result = tasks.where((task) {
      if (task.occursOn(t)) return true;
      if (!task.isRecurring &&
          task.completedDates.isEmpty &&
          dateOnly(task.startDate).isBefore(t)) {
        return true;
      }
      return false;
    }).toList();
    result.sort((a, b) {
      final ad = a.isCompletedOn(t) ? 1 : 0;
      final bd = b.isCompletedOn(t) ? 1 : 0;
      return ad != bd ? ad - bd : a.title.compareTo(b.title);
    });
    return result;
  }

  int openTodayCount() {
    final t = today();
    return tasksDueToday().where((task) => !task.isCompletedOn(t)).length;
  }

  // ---- Appointments ----

  void addAppointment(Appointment a) {
    appointments.add(a);
    _changed();
  }

  void updateAppointment(Appointment a) => _changed();

  void deleteAppointment(Appointment a) {
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
    notes.insert(0, n);
    _changed();
  }

  void updateNote(Note n) {
    n.updatedAt = DateTime.now();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _changed();
  }

  void deleteNote(Note n) {
    notes.removeWhere((x) => x.id == n.id);
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
