# Plan 02 – Dauer für Aufgaben und Termine

**Schritt A (Modell):** Strang 0a (Welle 0), **zweiter** Commit, nach Plan 03 A.
**Schritt B (Eingabeblätter, Aufgabenzeile):** Strang 1a (Welle 1), nach Plan 03 B.
**Schritt C (Termin- und Kalenderanzeige):** Strang 1b (Welle 1).
**Abhängig von:** Plan 03 Schritt A (`startsOn`, `calendarDaysBetween`, `addCalendarDays`).

## Ziel

„Dass ich zum Beispiel etwas von Montag 12:00 Uhr bis Donnerstag 18:00 Uhr
eintragen kann“, und zwar bei **Aufgaben und Terminen**.

## Ist-Zustand

- `Task` hat nur ein Datum (`startDate`) und **keine Uhrzeit**. Die Erinnerung
  bringt ihre eigene mit (`reminderMinuteOfDay`).
- `Appointment` hat einen Zeitpunkt (`when`), kein Ende.
- Tagesbezug: `AppState.tasksForDay` (Datum gleich Starttag),
  `_dueToday` (überfällig = `startDate` vor heute), `appointmentsForDay`
  (`dateOnly(a.when) == d`), `agenda.dart` `agendaForDay` (dieselbe Bedingung),
  `home_widget.dart` `widgetTasksForDay` (überfällig = `startDate` vor dem Tag).
- Blätter: `widgets.dart` `showTaskSheet` (Z. 1500), `showAppointmentSheet` (Z. 1707).

## Entscheidungen

- **E2**: Die Dauer ist optional, der Schalter „Dauer“ steht im Blatt.
  - **Aufgabe mit Dauer** hat Startuhrzeit, Endtag und Enduhrzeit. Sie gilt an
    **jedem Tag** der Spanne als fällig: Sie steht unter „Heute abhaken“,
    zählt in „x offene Aufgaben“ und hat im Kalender an jedem Tag ihren Punkt.
    Abgehakt wird sie **einmal**, dann ist sie an allen Tagen der Spanne
    erledigt. Überfällig ist sie erst **nach** dem letzten Tag.
  - **Termin mit Dauer** hat ein Ende (Datum + Uhrzeit) nach dem Start. Er steht
    an jedem berührten Tag. Starttag: mit Uhrzeit. Mitteltage: „ganztägig“.
    Endtag: „bis 18:00“. So hält es die App heute schon für mehrtägige
    Geräte-Termine.
- **E3**: Bei einer wiederkehrenden Aufgabe bekommt jede Wiederholung dieselbe
  Dauer (Start am Wiederholungstag, Ende *N* Tage später). Zwei Wiederholungen
  dürfen sich nicht überlappen, sonst wäre unklar, welche man abhakt. Das
  Blatt lehnt das ab.
- Erinnerungen:
  - Aufgabe: wie bisher zur eingestellten Uhrzeit, aber nur am **ersten** Tag
    der Spanne, nicht an jedem.
  - Termin: wie bisher, vor dem **Start**.
- Neue Termine haben weiter kein Ende: Ein Zeitpunkt bleibt der Normalfall.

## Schritt A – Modell (Strang 0a, Welle 0)

### `lib/models.dart` – `Task`

Neue Felder, alle optional im Konstruktor:

```dart
/// Wie viele Tage eine Wiederholung ueber ihren Starttag hinaus dauert
/// (0 = nur der Starttag). "Mo 12:00 bis Do 18:00" ist 3.
int spanDays;

/// Uhrzeiten der Dauer als Minuten seit Mitternacht; beide null heisst:
/// keine Uhrzeit (wie bisher). Es gibt sie nur zusammen – eine allein wird
/// beim Laden verworfen.
int? startMinute;
int? endMinute;
```

Neue bzw. geänderte Methoden (Plan 03 hat `startsOn` schon eingeführt):

```dart
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
  // Die juengste Wiederholung gewinnt; ueberlappen duerfen sie nicht (E3).
  for (var k = 0; k <= spanDays; k++) {
    final candidate = addCalendarDays(d, -k);
    if (startsOn(candidate)) return candidate;
  }
  return null;
}

bool occursOn(DateTime day) => occurrenceStartFor(day) != null;

/// Letzter Tag der ersten (bei einmaligen: der einzigen) Wiederholung.
DateTime get lastDay => addCalendarDays(dateOnly(startDate), spanDays);

/// Beginn und Ende der Wiederholung, die an [occurrenceStart] beginnt.
({DateTime start, DateTime end}) spanOf(DateTime occurrenceStart) {
  final s = dateOnly(occurrenceStart);
  final e = addCalendarDays(s, spanDays);
  return (
    start: DateTime(s.year, s.month, s.day, 0, startMinute ?? 0),
    end: DateTime(e.year, e.month, e.day, 0, endMinute ?? 24 * 60),
  );
}

bool isCompletedOn(DateTime day) {
  if (!isRecurring) return completedDates.isNotEmpty;
  final start = occurrenceStartFor(day);
  return start != null && completedDates.contains(dateKey(start));
}

/// Die laengste Dauer, bei der sich zwei Wiederholungen nicht ueberlappen
/// (E3). Das Blatt prueft dagegen.
static int maxSpanDays(RecurrenceType r, Set<int> weekdays, int intervalDays) =>
    switch (r) {
      RecurrenceType.none => 365,
      RecurrenceType.weekly => _smallestWeekdayGap(weekdays) - 1,
      RecurrenceType.monthly => 27,
      RecurrenceType.yearly => 364,
      RecurrenceType.everyXDays => intervalDays - 1,
    };
```

`_smallestWeekdayGap`: sortierte Tage, kleinster Abstand zwischen Nachbarn
**zyklisch** (von So zurück zu Mo zählt `7 - letzter + erster`). Bei einem Tag
ist das 7.

JSON:
- `toJson`: `'spanDays'`, `'startMinute'`, `'endMinute'` (nur schreiben, wenn
  gesetzt bzw. > 0).
- `fromJson`: `spanDays` als nicht negativer `int`, sonst 0. Minuten über
  das vorhandene `minuteOfDayFromJson`. Ist nur eine der beiden Minuten
  gültig, beide auf `null` setzen.

### `lib/models.dart` – `Appointment`

```dart
/// Ende des Termins, exklusiv wie im Kalender: bis 18:00 heisst, um 18:00
/// ist er vorbei; ein Ende um Mitternacht gehoert nicht mehr auf den
/// Folgetag. null = ein Zeitpunkt, wie bisher.
DateTime? end;

DateTime get lastDay {
  final e = end;
  if (e == null || !e.isAfter(when)) return dateOnly(when);
  return dateOnly(e.subtract(const Duration(seconds: 1)));
}

bool coversDay(DateTime day) {
  final d = dateOnly(day);
  return !d.isBefore(dateOnly(when)) && !d.isAfter(lastDay);
}
```

JSON: `'end'` als ISO-String. Beim Laden nicht parsebar oder nicht nach
`when` → `null` (kein Verlust, der Termin bleibt als Zeitpunkt).

### `lib/models.dart` – `AppState`

- `tasksForDay(day)`: `tasks.where((t) => t.occursOn(d))`. Den veralteten
  Doc-Kommentar („plus the completion day“) richtigstellen.
- `_dueToday()`: die Überfällig-Bedingung für Einmaliges liest
  `task.lastDay.isBefore(t)` statt `startDate`.
- `toggleTask(task, day)`: bei Wiederkehrendem ist der Schlüssel
  `dateKey(task.occurrenceStartFor(day) ?? day)`. Die Historie zeigt damit den
  Starttag der Wiederholung.
- `appointmentsForDay(day)`: `a.coversDay(d)`, sortiert nach `when`.
- `upcomingAppointments`: `!a.lastDay.isBefore(t)`; `pastAppointments`:
  `a.lastDay.isBefore(t)`. Ein laufender Termin steht so weiter unter
  „kommend“.

### `lib/reminders.dart`

In `pendingReminders` für Aufgaben `task.startsOn(day)` statt
`task.occursOn(day)`. Erinnert wird am **ersten** Tag der Spanne. Den
Kommentar darüber anpassen.

### `lib/util.dart` – Formatierung (für 1a und 1b)

```dart
/// "12:00"
String formatHm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Spanne fuer Listen und Blaetter:
///   gleicher Tag  -> "12:00 – 18:00 Uhr"
///   sonst         -> "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00"
String formatSpan(DateTime start, DateTime end) { ... }
```

(`two` ist das vorhandene `padLeft(2, '0')`-Muster. Als private Hilfe
anlegen, falls es sie nicht gibt.)

### Tests (Strang 0a)

In `test/recurrence_test.dart` (aus Plan 03) eine Gruppe „Dauer“:
- Einmalig Mo 14.9. bis Do 17.9.: `occursOn` Mo–Do ja, So und Fr nein.
  `lastDay` = 17.9. Einmal abhaken (an einem beliebigen Tag) → an allen vier
  Tagen erledigt.
- Wöchentlich Mo, `spanDays` 3: Mi der Folgewoche → `occurrenceStartFor` = Mo
  der Folgewoche. Abhaken am Mi → erledigt Mo–Do dieser Woche, nicht der
  nächsten.
- `maxSpanDays`: Mo+Mi → 1, Mo allein → 6, Mo+So → 0, alle sieben → 0,
  alle 3 Tage → 2.
- Über die Sommerzeit (28.3.–31.3.2026) bleibt `occursOn` tageweise richtig.
- `Appointment`: 14.9. 12:00 bis 17.9. 18:00 → `coversDay` 14.–17.; Ende
  17.9. 00:00 → nur 14.–16.; Ende ≤ Start → wie ohne Ende.
- JSON-Rundreise beider Klassen. Altbestand ohne die neuen Schlüssel lädt
  unverändert.

`models_test.dart`:
- `tasksDueToday`/`openTodayCount`: Eine einmalige Aufgabe von vorgestern
  bis morgen zählt heute und ist **nicht** überfällig. Eine, die gestern
  endete, ist überfällig.
- `appointmentsForDay` mit einem Drei-Tages-Termin.

`reminders_test.dart`: Aufgabe Mo–Do mit Erinnerung 09:00 → genau **eine**
Erinnerung am Mo.

`persistence_test.dart`: Speichern und Laden mit Dauer. Ungültige Werte
(`spanDays: -2`, nur `startMinute`, `end` vor `when`) laden ohne Verlust und
ohne Rettungsschlüssel.

## Schritt B – Blätter und Aufgabenzeile (Strang 1a, Welle 1)

Dateien: `lib/widgets.dart`, `lib/screens/tasks.dart`, `test/task_sheet_test.dart`,
`test/tasks_test.dart`, `test/sheet_test.dart`.

### Aufgabenblatt (`showTaskSheet`)

Unter der Datumszeile eine Zeile **„Dauer“** mit `Switch`
(`activeThumbColor: theme.accent`, wie in den Einstellungen).

- **Aus** (Standard bei neuen Aufgaben): alles wie bisher.
- **An**:
  - **Einmalig**:
    ```
    Von  [Mo, 14. Sep]  [12:00]
    Bis  [Do, 17. Sep]  [18:00]
    ```
    Die „Von“-Zeile ersetzt die bisherige Datumszeile. Standard beim
    Einschalten: Start 12:00, Ende gleicher Tag 18:00. Verschiebt man das
    Startdatum, wandert das Enddatum um dieselbe Zahl Tage mit, die Dauer
    bleibt also.
  - **Wiederkehrend** (Enddatum gäbe es nur für die erste Wiederholung, und die
    fällt bei der Wochenskala nicht zwingend auf das „Ab“-Datum):
    ```
    Beginn  an jedem Wiederholungstag um [12:00]
    Ende    [−] am selben Tag / +1 Tag / +3 Tage [+]   um [18:00]
    ```
    Der Zähler steuert `spanDays` direkt (0 bis `Task.maxSpanDays(...)`). Das
    Plus ist gesperrt, sobald die Grenze erreicht ist. Ein kleiner Hinweis
    darunter sagt, warum („länger würde die nächste Wiederholung
    überlappen“).
- Speichern:
  - Einmalig: `spanDays = calendarDaysBetween(von, bis)`. Liegt `bis` samt
    Uhrzeit nicht nach `von` → Toast `'Das Ende liegt vor dem Anfang.'`, nicht
    speichern.
  - Wiederkehrend: Bei `spanDays == 0` muss `endMinute > startMinute` sein,
    sonst derselbe Toast. Wurde die Wiederholung **nach** dem Einstellen der
    Dauer geändert und `spanDays > maxSpanDays` → Toast
    `'Die Dauer ist länger als der Abstand zwischen zwei Wiederholungen.'`.
  - Schalter aus → `spanDays = 0`, beide Minuten `null`.

### Terminblatt (`showAppointmentSheet`)

Unter der Datum/Uhrzeit-Zeile eine Zeile **„Dauer“** mit `Switch`. Ist sie an:

```
Bis  [Do, 17. Sep]  [18:00]
```

- Standard beim Einschalten: Start + 1 Stunde.
- Ändert man Start-Datum oder -Uhrzeit, wandert das Ende mit (die Dauer
  bleibt).
- Speichern: Ende nicht nach Start → Toast `'Das Ende liegt vor dem Anfang.'`.
  Schalter aus → `end = null`.
- Ein bestehender Termin mit `end` öffnet mit Schalter an.

### Aufgabenzeile (`TaskTile`)

- Hat die Aufgabe eine Dauer, steht in der Unterzeile die konkrete Spanne der
  Wiederholung, die `day` abdeckt:
  `formatSpan(task.spanOf(task.occurrenceStartFor(day) ?? task.startDate))`.
  Ohne Uhrzeit (nur `spanDays`): `'${formatDate(start)} – ${formatDate(end)}'`.
- Überfällig: `task.lastDay.isBefore(today())` statt `startDate`. Die Anzeige
  „offen seit …“ nennt `task.lastDay`.
- Die Unterzeile ist heute eine `Row` mit bis zu zwei Texten. Mit der Spanne
  werden es drei. Auf `Wrap(spacing: 8)` umstellen, sonst läuft sie auf
  schmalen Telefonen über.
- Semantik: Die Spanne kommt ins Label.

### `lib/screens/tasks.dart`

- „Demnächst“ (`_DatedTaskRow`): bei `spanDays > 0` das Label
  `'${formatDate(start)} – ${formatDate(lastDay)}'`.
- „Wiederkehrend“: bei `spanDays > 0` `'${recurrenceLabel} · ${spanDays + 1} Tage'`.

### Tests (Strang 1a)

`test/task_sheet_test.dart`:
- Dauer an, Enddatum drei Tage später, speichern → `spanDays == 3`, Minuten
  gesetzt.
- Ende vor Anfang → Toast, das Blatt bleibt offen, nichts angelegt.
- Wöchentlich Mo+Mi: Das Plus bleibt bei `+1 Tag` stehen.
- Terminblatt: Dauer an → `end == when + 1h`. Start um zwei Stunden
  verschieben → Ende wandert mit.

`test/tasks_test.dart`: Eine Aufgabe von gestern bis morgen steht unter
„Heute“, nicht als überfällig, mit der Spanne in der Unterzeile.
`sheet_test.dart`: Der Speichern-Knopf bleibt mit eingeschalteter Dauer und
offener Tastatur sichtbar (das Blatt ist länger geworden).

## Schritt C – Termin- und Kalenderanzeige (Strang 1b, Welle 1)

Dateien: `lib/agenda.dart`, `lib/screens/calendar.dart`,
`lib/screens/appointments.dart`, `lib/home_widget.dart`,
`lib/device_calendar.dart` (in Welle 1 gehört sie 1b), `test/agenda_test.dart`,
`test/calendar_test.dart`, `test/home_widget_test.dart`.

**Nicht** in `dashboard.dart` eingreifen (gehört 1d). Dort liest `_AgendaRow`
seine Beschriftung aus `agendaTimeLabel` und hat nur **78 px** Breite. Die
Beschriftungen unten sind so kurz gewählt, dass sie dort passen.

### `lib/agenda.dart`

- `AgendaEntry` bekommt `bool continued` (der Termin hat vor diesem Tag
  begonnen) und `DateTime? until` (endet an diesem Tag zu dieser Uhrzeit).
- Eigene Termine: Filter `a.coversDay(d)` statt `dateOnly(a.when) == d`.
  Einträge:

  | Tag | `when` | `allDay` | `until` | `agendaTimeLabel` |
  | --- | --- | --- | --- | --- |
  | Starttag | `a.when` | nein | Ende, falls am selben Tag | `'12:00 Uhr'` |
  | Mitteltag | Tagesbeginn | ja | – | `'ganztägig'` |
  | Endtag (Ende nicht 00:00) | Tagesbeginn | nein | `a.end` | `'bis 18:00'` |

- Geräte-Termine (`_deviceEntry`) bekommen dieselbe Endtag-Regel: Ein
  mehrtägiger Termin mit Uhrzeit sagt am letzten Tag `'bis 09:00'` statt
  „ganztägig“.
- Neue Funktion für die **langen** Beschriftungen (Kalender-Tagesdetail,
  Terminliste):
  ```dart
  /// "12:00 Uhr", "12:00 – 14:00 Uhr", "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00"
  String appointmentRangeLabel(Appointment a)
  ```
  und eine für die Tageszeile im Kalender:
  ```dart
  /// Wie agendaTimeLabel, aber fuer einen eigenen Termin an [day].
  String appointmentDayLabel(Appointment a, DateTime day)
  ```

### `lib/device_calendar.dart`

`deviceEventTimeLabel(event, day)` (aus Plan 06) um die Endtag-Regel ergänzen
(`'bis 09:00'`), damit Kalender und Dashboard gleich reden.

### `lib/screens/calendar.dart`

- `_AppointmentRow` bekommt den Tag und zeigt `appointmentDayLabel(a, day)`
  statt `formatTime(a.when)`.
- `_DayCell`: keine Änderung nötig. `appointmentsForDay` liefert den Termin
  schon an jedem Tag seiner Spanne, die Uhr steht dann an jedem Tag.
- Aufgaben mit Dauer erscheinen über `tasksForDay` schon an jedem Tag.

### `lib/screens/appointments.dart`

- Karten-Unterzeile: `formatRelativeDay(a.when)` + `appointmentRangeLabel(a)`,
  z. B. „Heute · 12:00 – 14:00 Uhr“ bzw. bei mehreren Tagen nur die Spanne.
- „Vergangen“ kommt aus `pastAppointments()` (Modell, Schritt A). Ein
  laufender Termin steht oben.

### `lib/home_widget.dart`

- Termine: `'minute'` nur am **Starttag** setzen, sonst `-1`. Kotlin zeigt bei
  `-1` keine Uhrzeit (`JoeWidgetText.time` gibt `null` zurück), ein
  Kotlin-Umbau ist nicht nötig. Kurz im Emulator/Telefon ansehen.
- `widgetTasksForDay`: überfällig über `task.lastDay.isBefore(d)` statt
  `startDate`.
- Das Format bleibt, `widgetSnapshotVersion` bleibt 1.

### Tests (Strang 1b)

- `agenda_test.dart`: eigener Drei-Tages-Termin → Beschriftungen
  „12:00 Uhr“ / „ganztägig“ / „bis 18:00“. Termin 12:00–14:00 am selben Tag →
  „12:00 Uhr“ im Dashboard, „12:00 – 14:00 Uhr“ in `appointmentRangeLabel`.
  Geräte-Termin 13.8. 18:00 bis 15.8. 09:00 → „18:00 Uhr“ / „ganztägig“ /
  „bis 09:00“. Ganztagstermine in dieser Datei auf lokale Werte umstellen
  (siehe Plan 06).
- `calendar_test.dart`: Drei-Tages-Termin → an allen drei Tagen eine Uhr.
  Tagesdetail am Mitteltag zeigt „ganztägig“.
- `home_widget_test.dart`: `'minute'` am Folgetag `-1`. Eine Aufgabe von
  gestern bis morgen hat heute `'over': false`.

## Akzeptanzkriterien

- Aufgabe und Termin lassen sich „Mo 12:00 bis Do 18:00“ eintragen und
  bearbeiten. Die Dauer lässt sich wieder abschalten.
- Überall (Dashboard, Aufgaben, Termine, Kalender, Widgets) steht der Eintrag
  an jedem Tag seiner Spanne und passend beschriftet.
- Eine Aufgabe mit Dauer wird einmal abgehakt, wiederkehrende einmal je
  Wiederholung.
- Keine Erinnerungsflut: eine Erinnerung je Wiederholung.
- Alter Bestand lädt unverändert.

## Doku für Welle 2 (README)

- **Features → Aufgaben / Termine**: Dauer beschreiben (E2, E3). Wie die Tage
  beschriftet sind (Uhrzeit / ganztägig / „bis …“). Einmal abhaken genügt.
  Erinnerung nur am ersten Tag.
- **Features → Prioritäten**: „überfällig“ heißt jetzt „nach dem letzten Tag“.
- **Startbildschirm-Widgets**: Folgetage eines Termins ohne Uhrzeit.
