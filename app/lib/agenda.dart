import 'package:flutter/material.dart';

import 'device_calendar.dart';
import 'models.dart';
import 'util.dart';

/// Ein Termin, wie ihn das Dashboard zeigt – aus Joe selbst oder aus einem
/// Kalender des Geraets (siehe device_calendar.dart).
///
/// Fuer die Liste sehen beide gleich aus; unterschiedlich ist nur, was man
/// mit ihnen tun kann: ein eigener Termin geht auf Tipp zum Bearbeiten auf,
/// ein Geraete-Termin wird in seiner eigenen App gepflegt und ist hier reine
/// Anzeige.
class AgendaEntry {
  /// Wann der Termin an dem Tag beginnt, an dem er steht. Ganztaegige – und
  /// mehrtaegige an ihren Folgetagen – stehen auf dem Tagesbeginn: so liegen
  /// sie in der Sortierung vorn und tragen keine Uhrzeit von gestern.
  final DateTime when;
  final String title;
  final Color color;

  /// Ohne eigene Uhrzeit an diesem Tag: "ganztägig" statt "14:30 Uhr".
  final bool allDay;

  /// Nur eigene Termine haben eine Prioritaet.
  final Priority? priority;

  /// Der eigene Termin dahinter; null heisst: aus einem Kalender des Geraets.
  final Appointment? appointment;

  const AgendaEntry({
    required this.when,
    required this.title,
    required this.color,
    this.allDay = false,
    this.priority,
    this.appointment,
  });

  bool get fromDevice => appointment == null;
}

/// Die Termine eines Tages, quer ueber beide Quellen: ganztaegige zuerst,
/// danach nach Uhrzeit, und bei gleicher Zeit die eigenen vor denen des
/// Geraets – was man selbst eingetragen hat, steht vorn (so haelt es auch
/// das Tagesdetail im Kalender).
///
/// [deviceEvents] sind die Termine, die diesen Tag beruehren; der Aufrufer
/// holt sie aus `DeviceCalendarFeed.eventsForDay`. Die Funktion selbst kennt
/// kein Plugin und laesst sich damit ohne Geraet pruefen.
List<AgendaEntry> agendaForDay(
  DateTime day, {
  required List<Appointment> appointments,
  List<Event> deviceEvents = const [],
  required Color deviceColor,
}) {
  final d = dateOnly(day);
  final entries = <AgendaEntry>[
    for (final a in appointments)
      if (dateOnly(a.when) == d)
        AgendaEntry(
          when: a.when,
          title: a.title,
          color: a.color,
          priority: a.priority,
          appointment: a,
        ),
    for (final e in deviceEvents)
      _deviceEntry(e, d, deviceColor),
  ];
  entries.sort((a, b) {
    final byTime = a.when.compareTo(b.when);
    if (byTime != 0) return byTime;
    final bySource = (a.fromDevice ? 1 : 0) - (b.fromDevice ? 1 : 0);
    if (bySource != 0) return bySource;
    return a.title.compareTo(b.title);
  });
  return entries;
}

AgendaEntry _deviceEntry(Event event, DateTime day, Color fallback) {
  final start = event.startDate.toLocal();
  // Ein mehrtaegiger Termin faengt an seinen Folgetagen nicht noch einmal an:
  // dort ist er den ganzen Tag da, und die Uhrzeit von vorgestern waere
  // schlicht falsch.
  final allDay = event.isAllDay || dateOnly(start) != day;
  return AgendaEntry(
    when: allDay ? day : start,
    title: event.title,
    color: event.color ?? fallback,
    allDay: allDay,
  );
}

/// Die Zeile rechts an einem Eintrag: "14:30 Uhr" bzw. "ganztägig".
String agendaTimeLabel(AgendaEntry entry) =>
    entry.allDay ? 'ganztägig' : formatTime(entry.when);
