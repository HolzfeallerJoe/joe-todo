# Plan 03 – Wiederholung: Einmalig, Monatlich, Jährlich, Alle X Tage + Wochenskala

**Schritt A:** Strang 0a (Welle 0), **erster** Commit des Strangs.
**Schritt B:** Strang 1a (Welle 1), nach Plan 01.
**Abhängig von:** nichts. Plan 02 (Dauer) baut auf Schritt A auf.

## Ziel

Im Aufgabenblatt wählt man die Wiederholung so:

- Auswahl-Chips: **Einmalig · Monatlich · Jährlich · Alle X Tage**
- darunter eine **Wochenskala Mo Di Mi Do Fr Sa So**. Markiert man einen oder
  mehrere Tage, wiederholt sich die Aufgabe **wöchentlich an genau diesen
  Tagen**.

## Ist-Zustand

- `lib/models.dart:53` `enum RecurrenceType { none, daily, weekly, monthly, everyXDays }`
- `Task.occursOn` (Z. 107): `weekly` heißt „am Wochentag des Startdatums“,
  mehrere Tage gehen nicht. `everyXDays` rechnet mit
  `d.difference(s).inDays`, siehe Nebenbefund unten.
- `Task.recurrenceLabel` (Z. 132), `toJson`/`fromJson` (Z. 147/159).
- `AppState._seed` legt „Blumen gießen“ als `daily` an.
- `lib/widgets.dart:1564–1613` `showTaskSheet`: Chips aus `RecurrenceType.values`
  mit einem `switch`-Ausdruck für die Beschriftung, dazu der Plus/Minus-Regler
  für „Alle X Tage“ (Minimum 2).
- Wer `occursOn` nutzt, ist automatisch mit dabei: `tasksForDay`, `_dueToday`,
  `isLowLeftover`, `reminders.dart` `pendingReminders`, `home_widget.dart`.
- Tests mit `RecurrenceType.daily`: `models_test.dart`, `reminders_test.dart`,
  `home_widget_test.dart`.

### Nebenbefund: „Alle X Tage“ verrutscht an der Sommerzeit

`d.difference(s).inDays` misst echte Stunden. Zwischen zwei lokalen
Mitternächten über die Sommerzeit-Umstellung im März liegen 23 Stunden
weniger, also `n*24 - 1` Stunden, und `inDays` rundet auf `n - 1` ab. Eine
Aufgabe „alle 2 Tage ab 28.3.“ fällt dann nicht mehr auf den 30.3., sondern
auf den 31.3. und bleibt bis zum Herbst um einen Tag verschoben.
`reminders.dart` umgeht dasselbe Problem schon mit `nextCalendarDay`. Hier
wird es in Schritt A mit einem Kalendertag-Zähler behoben.

## Entscheidungen

- **E4**: `daily` fällt als eigener Typ weg. Sieben markierte Tage bedeuten
  täglich. Alte Daten: `'daily'` → `weekly` mit allen sieben Tagen; `'weekly'`
  ohne `weekdays` → `weekly` mit dem Wochentag des Startdatums.
- **E5**: Jährlich am 29.2. → in Nicht-Schaltjahren am 28.2.
- Monatlich am 31. bleibt wie bisher (Monate ohne 31. werden übersprungen).
  Nicht angefragt, deshalb nicht angefasst. Ein Kommentar vermerkt es.
- „Alle X Tage“ behält das Minimum 2: Jeden Tag deckt die Wochenskala ab.

## Schritt A – Modell (Strang 0a, Welle 0)

### `lib/util.dart`

```dart
/// Kalendertage von [from] bis [to] (beides nur als Datum gelesen), an der
/// Sommerzeit-Grenze stabil: gezaehlt wird ueber UTC-Daten, nicht ueber eine
/// Dauer – zwischen zwei lokalen Mitternaechten liegen im Maerz nur 23 Stunden.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// [d] plus [days] Kalendertage, als lokales Datum.
DateTime addCalendarDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);
```

### `lib/models.dart`

1. Enum: `enum RecurrenceType { none, weekly, monthly, yearly, everyXDays }`.
   Kommentar: warum es `daily` nicht mehr gibt (E4) und dass der Name
   `'daily'` nur noch beim Laden vorkommt.
2. Konstante `const allWeekdays = {1, 2, 3, 4, 5, 6, 7};` (1 = Montag, wie
   `DateTime.weekday`).
3. `Task` bekommt `Set<int> weekdays` (nur für `weekly` von Bedeutung). Im
   Konstruktor optional. Ist `recurrence == weekly` und die Menge leer,
   gilt `{startDate.weekday}`: eine wöchentliche Aufgabe ohne Tag gibt es
   nicht. Ungültige Werte (<1, >7) werden verworfen.
4. **`bool startsOn(DateTime day)`**: an welchen Tagen eine Wiederholung
   *beginnt*. Plan 02 braucht die Unterscheidung „beginnt“ gegenüber
   „läuft“. Bis dahin gilt `occursOn(day) => startsOn(day)`.
   ```dart
   bool startsOn(DateTime day) {
     final d = dateOnly(day);
     final s = dateOnly(startDate);
     if (d.isBefore(s)) return false;
     switch (recurrence) {
       case RecurrenceType.none:
         return d == s;
       case RecurrenceType.weekly:
         return weekdays.contains(d.weekday);
       case RecurrenceType.monthly:
         // Am 31. begonnen heisst: Monate ohne 31. fallen aus – wie bisher.
         return d.day == s.day;
       case RecurrenceType.yearly:
         if (d.month != s.month) return false;
         if (d.day == s.day) return true;
         // Am 29.2. begonnen: in Jahren ohne Schalttag am 28.2.
         return s.month == 2 && s.day == 29 && d.day == 28 && !_isLeapYear(d.year);
       case RecurrenceType.everyXDays:
         return calendarDaysBetween(s, d) % (intervalDays < 1 ? 1 : intervalDays) == 0;
     }
   }
   ```
5. `recurrenceLabel`:
   - `none` → `'Einmalig'`
   - `weekly`: alle sieben → `'Täglich'`; genau Mo–Fr → `'Werktags'`; genau
     Sa+So → `'Am Wochenende'`; ein Tag → `'Jeden Montag'` (voller Name aus
     `weekdayNames`); sonst → `'Mo, Mi, Fr'` (Kurznamen aus
     `weekdayNamesShort`, in Wochenreihenfolge, mit `', '` verbunden).
   - `monthly` → `'Monatlich'`, `yearly` → `'Jährlich'`,
     `everyXDays` → `'Alle $intervalDays Tage'`
6. JSON:
   - `toJson`: `'weekdays': weekdays sortiert als Liste` (nur bei `weekly`,
     sonst weglassen).
   - `fromJson`: `'daily'` → `weekly` + `allWeekdays`. Unbekannter Name →
     `none` (wie bisher). `'weekdays'` als Liste lesen, nur `int` 1–7
     übernehmen, alles andere still verwerfen (kein Verlust). Leer bei
     `weekly` → Wochentag des Starts (siehe 3.).
7. `_seed`: „Blumen gießen“ → `weekly` mit `allWeekdays`.

### `lib/widgets.dart`: nur Pflicht-Anpassung, damit es übersetzt

Im `switch`-Ausdruck der Chips (Z. 1571) `daily` streichen und
`RecurrenceType.yearly => 'Jährlich'` ergänzen. Beim Speichern
`weekdays: recurrence == RecurrenceType.weekly ? {date.weekday} : null`
übergeben. So bleibt das alte Verhalten („wöchentlich am Wochentag des
Datums“) stehen, bis 1a das Blatt umbaut. **Nichts weiter** im Blatt ändern.

### Tests (Strang 0a)

- `test/recurrence_test.dart` (neu):
  - Wochenskala Mo+Mi+Fr: trifft genau diese Tage, auch vor dem ersten
    passenden Tag nach dem Start nicht.
  - alle sieben = jeden Tag ab Start, nicht davor.
  - Jährlich: 14.3.2026 → 14.3.2027 ja, 15.3.2027 nein. 29.2.2028 → 28.2.2029
    ja, 29.2.2032 ja, 28.2.2032 nein.
  - **Sommerzeit**: alle 2 Tage ab 28.3.2026 → 30.3.2026 ja, 31.3.2026 nein.
    Kommentar: Mit dem alten `inDays` wäre es umgekehrt, *wenn* der Rechner in
    einer Zeitzone mit Umstellung läuft. In UTC (CI) wäre es nie aufgefallen.
  - `recurrenceLabel` für alle Fälle aus A.5.
  - JSON: Rundreise mit `weekdays`. Altbestand `'daily'` → weekly/alle sieben.
    Altbestand `'weekly'` ohne `weekdays` → Wochentag des Starts.
    `'weekdays': [0, 3, 'x', 9]` → `{3}`.
- `models_test.dart`, `reminders_test.dart`, `home_widget_test.dart`:
  `RecurrenceType.daily` durch `RecurrenceType.weekly, weekdays: allWeekdays`
  ersetzen. Die Aussagen der Tests bleiben dieselben. Den Test „daily occurs
  every day from start“ in „alle sieben Wochentage = jeden Tag“ umbenennen.
- `persistence_test.dart`: Laden eines gespeicherten Bestands mit `'daily'`
  ergibt weekly/alle sieben, ohne Verlust (kein Rettungsschlüssel).

## Schritt B – Aufgabenblatt (Strang 1a, Welle 1)

Datei: `lib/widgets.dart` → `showTaskSheet`.

### Aufbau des Abschnitts „Wiederholung“

```
Wiederholung
[Einmalig] [Monatlich] [Jährlich] [Alle X Tage]        ← ChoiceChips
  (bei Alle X Tage: der bekannte Plus/Minus-Regler)
  (bei Monatlich: kleine Zeile "am 14. jedes Monats")
  (bei Jährlich:  kleine Zeile "jedes Jahr am 14. März")
Wöchentlich an
 (Mo)(Di)(Mi)(Do)(Fr)(Sa)(So)                           ← 7 runde Umschalter
```

### Verhalten

- Tipp auf einen **Wochentag**:
  - ist `recurrence != weekly` → `recurrence = weekly`, `weekdays = {tag}`
    (der vorher gewählte Chip verliert seine Markierung);
  - sonst Tag umschalten. Wird die Menge dadurch **leer**, fällt es auf
    `Einmalig` zurück: keine Tage markiert heißt keine Wochenwiederholung.
- Tipp auf einen **Chip** → `recurrence = chip`, `weekdays` leeren (die Skala
  zeigt nichts mehr markiert).
- Es ist immer genau eins aktiv: ein Chip **oder** mindestens ein Wochentag.
- Neue Aufgabe: `Einmalig`. Beim Bearbeiten kommen `recurrence`/`weekdays` aus
  der Aufgabe.
- Die Datumszeile sagt weiter „Datum: …“ bei Einmalig und „Ab: …“ sonst.
- Speichern übergibt `weekdays` (bei weekly), sonst eine leere Menge.

### Die Wochenskala als eigenes Widget

`class WeekdayPicker extends StatelessWidget` in `widgets.dart`
(`selected: Set<int>`, `onToggle: ValueChanged<int>`):

- sieben gleich breite Felder (`Expanded`), darin je ein Kreis mit ≥ 40 px
  Tippfläche und dem Kurznamen aus `weekdayNamesShort`;
- markiert: `theme.accent` gefüllt, Beschriftung `theme.bestOn(theme.accent)`;
  nicht markiert: Rand `theme.inkSoft` mit Alpha 0,5, Beschriftung `theme.ink`.
  Das ist dieselbe Formensprache wie `PriorityPicker`;
- Semantik je Feld: `label: weekdayNames[i]`, `selected:`, `button: true`.

### Tests (Strang 1a) – `test/task_sheet_test.dart` (neu)

Den Aufbau aus `sheet_test.dart` / `tasks_test.dart` übernehmen (Blatt über
`showTaskSheet` öffnen, `AppState` ohne Persistenz):

- Mo und Mi antippen, Titel eintippen, speichern → Aufgabe `weekly`,
  `weekdays == {1, 3}`.
- Mo antippen, dann „Monatlich“ → `monthly`, `weekdays` leer.
- Mo an- und wieder abtippen → `none`.
- alle sieben antippen, speichern → in der Liste steht „🔁 Täglich“.
- Eine Aufgabe von vorher (`weekly`, `{5}`) bearbeiten → Fr ist markiert.

### Maestro

`maestro/03_recurring_task.yaml` läuft unverändert weiter („Alle X Tage“
gibt es noch). Einen zweiten Teil anhängen: neue Aufgabe „Sport“, `Mo` und
`Do` antippen, speichern, `assertVisible: "(?s)Sport.*Mo, Do.*"`.

## Akzeptanzkriterien

- Chips Einmalig/Monatlich/Jährlich/Alle X Tage plus Wochenskala. Mehrere Tage
  wählbar.
- Alte Aufgaben laufen nach dem Update weiter wie vorher (täglich = jeden Tag,
  wöchentlich = am alten Wochentag).
- Erinnerungen und Startbildschirm-Widgets folgen automatisch, weil beide
  `occursOn` benutzen. Das decken die bestehenden Tests ab.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- **Features → Wiederkehrende Aufgaben**: „täglich, wöchentlich, monatlich, alle
  X Tage“ ersetzen durch: einmalig, monatlich, jährlich, alle X Tage, dazu eine
  Wochenskala Mo–So für eine oder mehrere Wochentage (alle sieben = täglich).
  Alte „täglich“-Aufgaben werden beim Laden umgeschrieben.
- Einen Satz zum Sommerzeit-Fix bei „Alle X Tage“ (gezählt wird in
  Kalendertagen, nicht in Stunden).
- **Struktur → test/**: `recurrence_test` ergänzen.
