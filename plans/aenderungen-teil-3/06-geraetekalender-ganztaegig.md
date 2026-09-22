# Plan 06 – Ganztägige Geräte-Termine stehen auf zwei Tagen (Fehler)

**Strang:** 0b (Welle 0, parallel zu 0a) · **Dateien:**
`lib/device_calendar.dart`, `lib/screens/calendar.dart` (nur `_DeviceEventRow`),
`test/device_calendar_test.dart` · **Abhängig von:** nichts.

## Symptom

„Termine von den importierten Kalendern werden nicht ganz korrekt angezeigt.
Es sieht so aus, als wenn immer 2 Tage benutzt werden für ein
Ganztagestermin.“ Der Verdacht stimmt.

## Ursache (nachgewiesen im Plugin-Quelltext)

1. Android legt Ganztagstermine im Calendar Provider auf **UTC-Mitternacht** ab.
2. Das Plugin `device_calendar_plus_android` **0.7.1** rechnet sie beim Lesen
   **schon selbst** auf lokale Mitternacht um:
   `EventsService.kt` → `buildEventMapFromCursor` → `if (allDay) { start = utcToLocalMidnight(rawStart); end = utcToLocalMidnight(rawEnd) }`.
   Die Dart-Seite macht daraus `DateTime.fromMillisecondsSinceEpoch(...)`, also
   eine **lokale** `DateTime` um 00:00 (siehe `device_calendar_plus-0.8.0/lib/src/event.dart`:
   „For all-day events, treat this as a floating date“).
3. Joe nimmt in `eventCoversDay` (`lib/device_calendar.dart:254`) aber noch
   UTC-Mitternacht an und rechnet **ein zweites Mal** um:
   ```dart
   final s = event.startDate.toUtc();
   final e = event.endDate.toUtc().subtract(const Duration(seconds: 1));
   ```
   Beispiel in Deutschland (UTC+2), Ganztagstermin am 18.9.:
   - start = 18.9. 00:00 lokal → `toUtc()` = **17.9.** 22:00 → first = 17.9.
   - end = 19.9. 00:00 lokal → `toUtc()` = 18.9. 22:00, minus 1 s → last = 18.9.
   - Ergebnis: der Termin steht am **17. und 18.**, also auf zwei Tagen und dazu
     einen Tag zu früh.
4. Die Tests fangen das nicht: `test/device_calendar_test.dart` baut
   Ganztagstermine mit `DateTime.utc(...)`, so wie Joe es *erwartet*, nicht wie
   das Plugin sie *liefert*. Die CI läuft unter UTC, dort fällt der Fehler
   ohnehin nicht auf.

Ein zweiter Fehler steckt im selben Bereich. Das Tagesdetail im Kalender
(`_DeviceEventRow` in `lib/screens/calendar.dart:588`) zeigt bei einem
**mehrtägigen Termin mit Uhrzeit** an jedem Folgetag die Startuhrzeit, denn
`deviceEventTimeLabel(event)` kennt den Tag nicht. Die README verspricht aber:
„Ein mehrtägiger Termin fängt an seinen Folgetagen nicht neu an – er steht dort
als ‚ganztägig‘“. Das stimmt bisher nur auf dem Dashboard (`agenda.dart`
`_deviceEntry`). Das gehört zu „nicht ganz korrekt angezeigt“ und wird hier
mitbehoben.

## Umsetzung

### 1. `eventCoversDay` richtigstellen (`lib/device_calendar.dart`)

```dart
if (event.isAllDay) {
  // Das Plugin liefert ganztaegige Termine schon als lokale Mitternacht
  // (es rechnet die UTC-Mitternacht des Providers selbst um). Hier also nur
  // noch das Datum ablesen – ein zweites toUtc() schob den Termin in jeder
  // Zeitzone oestlich von UTC auf den Vortag und liess ihn zwei Tage belegen.
  final s = event.startDate.toLocal();
  final e = event.endDate.toLocal();
  first = DateTime(s.year, s.month, s.day);
  // Ende exklusiv; ein Termin ohne das "+1 Tag" (Ende == Start) ist ein Tag.
  final lastDay = e.isAfter(s) ? e.subtract(const Duration(seconds: 1)) : s;
  last = DateTime(lastDay.year, lastDay.month, lastDay.day);
}
```

- Den bisherigen Kommentar („Ganztaegige Termine liegen im Calendar Provider auf
  UTC-Mitternacht …“) ersetzen: Er beschreibt den Provider, nicht das, was
  beim Plugin-Nutzer ankommt. Die Plugin-Version nennen, gegen die das
  nachgesehen wurde (0.7.1 / 0.8.0), damit man bei einem Plugin-Update weiß,
  was zu prüfen ist.
- `toLocal()` ist bei einer schon lokalen `DateTime` ein No-op. Es steht nur
  zur Absicherung da, falls eine Plugin-Version doch UTC liefert. Dann stimmt
  das Datum trotzdem, *sofern* der Wert lokale Mitternacht meint. Mehr kann
  man ohne die Zeitzone des Termins nicht tun.

### 2. Beschriftung je Tag (`deviceEventTimeLabel`)

Signatur erweitern: `String deviceEventTimeLabel(Event event, DateTime day)`.

- ganztägig → `'ganztägig'`
- mit Uhrzeit, `day` ist der Starttag → `formatTime(start)` („14:30 Uhr“)
- mit Uhrzeit, `day` liegt **nach** dem Starttag → `'ganztägig'`. Das ist
  dieselbe Regel wie `_deviceEntry` in `agenda.dart`. Ob der Endtag
  „bis 09:00 Uhr“ sagen soll, entscheidet Plan 02 Schritt C (Strang 1b) für
  eigene **und** Geräte-Termine einheitlich. Hier nur die Folgetage richtig
  machen.

`_DeviceEventRow` in `calendar.dart` bekommt dafür den Tag
(`_DeviceEventRow(event: e, day: _selected)`) und reicht ihn weiter. Mehr wird
in `calendar.dart` nicht geändert (die Datei gehört in Welle 1 dem Strang 1b).

### 3. Tests (`test/device_calendar_test.dart`)

- Die beiden Ganztags-Tests auf das umstellen, **was das Plugin liefert**:
  Start `DateTime(2026, 8, 13)` (lokal), Ende `DateTime(2026, 8, 14)` (lokal).
  Kommentar: warum lokal und nicht UTC (Verweis auf `utcToLocalMidnight` im
  Plugin).
- Test „ganztaegig: steht nur auf seinem Tag, auch oestlich von UTC“. Er muss
  unabhängig von der Zeitzone des Rechners grün sein und schlägt mit dem alten
  Code in jeder Zeitzone östlich von UTC fehl, etwa auf dem Entwicklerrechner
  in Europe/Berlin. Den Test also *lokal* laufen lassen und im Kommentar
  festhalten, dass die CI (UTC) den alten Fehler nicht gezeigt hätte.
- Test „ganztaegig ohne +1-Tag-Konvention (Ende == Start) ist ein Tag“.
- Test „ganztaegig ueber mehrere Tage“ (24.–26.12., Ende 27.12. exklusiv) mit
  lokalen Werten.
- Tests für `deviceEventTimeLabel(event, day)`: Starttag → Uhrzeit, Folgetag →
  „ganztägig“, ganztägig → „ganztägig“.
- Den bestehenden Aufruf in „Uhrzeit-Beschriftung“ an die neue Signatur
  anpassen.

Hinweis: Unter Windows ignoriert Dart die Umgebungsvariable `TZ`. Die
Zeitzone ist die des Systems. Auf dem Entwicklerrechner (Europe/Berlin) zeigt
der neue Test den alten Fehler. Das genügt als Nachweis. Auch in
`agenda_test.dart` stehen Ganztagstermine, dort ist aber nur `isAllDay`
entscheidend. Die Datei bleibt in Welle 0 unangetastet (sie gehört in Welle 1
dem Strang 1b, der sie bei Bedarf auf lokale Werte umstellt).

## Akzeptanzkriterien

- Ein ganztägiger Google-Termin am 20. steht im Monatsraster, im Tagesdetail
  und auf dem Dashboard **nur** am 20.
- Ein mehrtägiger Ganztagstermin (24.–26.) steht an genau drei Tagen.
- Ein Termin 13.8. 18:00 bis 15.8. 09:00 zeigt im Tagesdetail am 13.
  „18:00 Uhr“, am 14. und 15. „ganztägig“.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- Im Abschnitt **Geräte-Kalender** einen Satz ergänzen: Ganztägige Termine
  kommen vom Plugin bereits als lokale Mitternacht und werden nur noch nach
  Datum einsortiert. Eine zweite UTC-Umrechnung hatte sie östlich von UTC auf
  zwei Tage verteilt. Plugin-Version nennen.
- Den Satz „Ein mehrtägiger Termin fängt an seinen Folgetagen nicht neu an“
  gilt jetzt auch fürs Tagesdetail im Kalender. Ggf. so formulieren, dass er
  Dashboard **und** Kalender meint.
