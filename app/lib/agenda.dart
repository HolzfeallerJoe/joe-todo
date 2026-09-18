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

  /// Der Termin hat vor diesem Tag begonnen – hier laeuft er nur weiter.
  final bool continued;

  /// Wann der Termin an diesem Tag endet; null, wenn er nicht an diesem Tag
  /// endet (oder gar kein Ende hat). Am Endtag eines mehrtaegigen Termins
  /// wird daraus "bis 18:00".
  final DateTime? until;

  /// Nur eigene Termine haben eine Prioritaet.
  final Priority? priority;

  /// Der eigene Termin dahinter; null heisst: aus einem Kalender des Geraets.
  final Appointment? appointment;

  const AgendaEntry({
    required this.when,
    required this.title,
    required this.color,
    this.allDay = false,
    this.continued = false,
    this.until,
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
/// Ein eigener Termin mit Dauer steht an jedem Tag seiner Spanne.
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
      if (a.coversDay(d)) _ownEntry(a, d),
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

/// Ein eigener Termin an [day] (einem Tag seiner Spanne):
///   Starttag  -> mit seiner Uhrzeit
///   Mitteltag -> ganztaegig
///   Endtag    -> "bis 18:00"
/// Endet er um Mitternacht, ist der Tag davor sein letzter und steht ganz
/// als "ganztägig" da – das Ende ist exklusiv (siehe [Appointment.end]).
AgendaEntry _ownEntry(Appointment a, DateTime day) {
  final end = a.end;
  final until =
      end != null && end.isAfter(a.when) && _endsWithTimeOn(end, day)
          ? end
          : null;
  final continued = dateOnly(a.when) != day;
  return AgendaEntry(
    // Folgetage stehen auf dem Tagesbeginn, wie die des Geraets.
    when: continued ? day : a.when,
    title: a.title,
    color: a.color,
    allDay: continued && until == null,
    continued: continued,
    until: until,
    priority: a.priority,
    appointment: a,
  );
}

/// Ob ein Termin mit dem (exklusiven) Ende [end] an [day] zu einer Uhrzeit
/// endet. Ein Ende genau um Mitternacht zaehlt nicht: dann gehoert [day]
/// schon nicht mehr zum Termin.
bool _endsWithTimeOn(DateTime end, DateTime day) =>
    dateOnly(end) == day && end.isAfter(day);

AgendaEntry _deviceEntry(Event event, DateTime day, Color fallback) {
  final start = event.startDate.toLocal();
  // Ein mehrtaegiger Termin faengt an seinen Folgetagen nicht noch einmal an:
  // dort ist er den ganzen Tag da, und die Uhrzeit von vorgestern waere
  // schlicht falsch. An seinem Endtag steht "bis 09:00", genau wie bei einem
  // eigenen Termin mit Dauer (_ownEntry) und wie im Tagesdetail des
  // Kalenders (deviceEventTimeLabel) – die beiden Dateien reden dieselbe
  // Sprache; agenda_test.dart haelt sie beisammen. Ganztaegige bleiben
  // ganztaegig, auch falls ein Plugin ihr Ende nicht auf Mitternacht legt.
  final end = event.endDate.toLocal();
  final continued = dateOnly(start) != day;
  final until = !event.isAllDay && continued && _endsWithTimeOn(end, day)
      ? end
      : null;
  final allDay = event.isAllDay || (continued && until == null);
  return AgendaEntry(
    when: allDay || until != null ? day : start,
    title: event.title,
    color: event.color ?? fallback,
    allDay: allDay,
    continued: dateOnly(start).isBefore(day),
    until: until,
  );
}

/// Die Zeile rechts an einem Eintrag: "14:30 Uhr", "ganztägig" bzw. am
/// Endtag eines mehrtaegigen Termins "bis 18:00". Alle drei sind kurz genug
/// fuer die schmale Zeitspalte des Dashboards.
String agendaTimeLabel(AgendaEntry entry) {
  if (entry.allDay) return 'ganztägig';
  final until = entry.until;
  if (entry.continued && until != null) return 'bis ${formatHm(until)}';
  return formatTime(entry.when);
}

/// Wie [agendaTimeLabel], aber fuer einen eigenen Termin an [day] – die
/// Tageszeile im Kalender.
String appointmentDayLabel(Appointment a, DateTime day) =>
    agendaTimeLabel(_ownEntry(a, dateOnly(day)));

/// Die ganze Spanne eines eigenen Termins, fuer Tagesdetail und Terminliste:
/// "12:00 Uhr", "12:00 – 14:00 Uhr", "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00".
String appointmentRangeLabel(Appointment a) {
  final end = a.end;
  if (end == null || !end.isAfter(a.when)) return formatTime(a.when);
  return formatSpan(a.when, end);
}

/// Die Unterzeile einer Karte im Reiter "Termine": "Heute · 12:00 Uhr",
/// "Morgen · 12:00 – 14:00 Uhr". Ein Termin ueber mehrere Tage nennt seine
/// Tage schon in der Spanne; "Heute" davor waere doppelt.
String appointmentListLabel(Appointment a) {
  final end = a.end;
  final range = appointmentRangeLabel(a);
  // Dieselbe Grenze wie in formatSpan: sobald das Ende auf einem anderen
  // Datum liegt, traegt die Spanne beide Tage.
  if (end != null && end.isAfter(a.when) && dateOnly(end) != dateOnly(a.when)) {
    return range;
  }
  return '${formatRelativeDay(a.when)} · $range';
}
