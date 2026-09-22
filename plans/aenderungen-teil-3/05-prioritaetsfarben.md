# Plan 05 – Farben für die Prioritäten der Aufgaben

**Schritt A (Palette + Farbregel):** Strang 0a (Welle 0), **dritter** Commit.
**Schritt B (Hinweis im Aufgabenblatt):** Strang 1a (Welle 1), letzter Schritt.
**Schritt C (Einstellungen):** Strang 1c (Welle 1).
**Abhängig von:** nichts.

## Ziel

„In den Einstellungen eine Farbauswahl (25 Farben inklusive Mint und ‚keine
Farbe‘) für die Prioritäten der Aufgaben hinzufügen. Wenn dann eine Aufgabe
mit Priorität erstellt wird, soll diese Farbe angezeigt werden. Ist ‚keine
Farbe‘ ausgewählt, soll die Farbe angezeigt werden, die im Aufgabenmenü
gewählt wurde.“

## Ist-Zustand

- `lib/models.dart:22` `taskPalette`: 20 Farben, `taskPaletteNames` daneben.
  Die ersten acht behalten ihren Index, neue werden nur **angehängt**
  (gespeichert ist der Index `colorIndex`). Index 14 ist „Minze“ `#7FBFA5`.
- `Task.color` (Z. 101) wird an vielen Stellen gelesen:
  - `TaskTile` (Kästchen)
  - `tasks.dart` (Farbstrich)
  - `calendar.dart` (Punkte)
  - `home_widget.dart` (Liste und Punkt im Monatsraster)
  - `history.dart:73`
- `ColorDotPicker` (`widgets.dart:1100`) läuft über `taskPalette.length`,
  wächst also von selbst mit.
- `test/models_test.dart:311` prüft „20 Farben, die ersten acht behalten ihren
  Index“.

## Entscheidungen

- **E7**: Die Palette wächst auf **25** Farben. Diese fünf werden angehängt:

  | Index | Name | Wert |
  | --- | --- | --- |
  | 20 | Mint | `#9FDFC4` (hell, klar mint) |
  | 21 | Himmel | `#86BEE0` |
  | 22 | Koralle | `#EE8A73` |
  | 23 | Flieder | `#B9A1D6` |
  | 24 | Schiefer | `#66727F` |

  Die bestehende „Minze“ (Index 14, `#7FBFA5`) heißt künftig **„Jade“**. Der
  Farbwert bleibt, damit gespeicherte Aufgaben ihre Farbe behalten; zwei
  „Minzen“ wären verwirrend. Dieselben 25 gelten im Aufgaben- und
  Terminblatt. „Keine Farbe“ gibt es **zusätzlich**, nur in den
  Einstellungen.
- **E8**: Die Prioritätsfarbe wirkt **beim Anzeigen**. Man stellt „Hoch = Mint“
  ein, und jede Aufgabe der Stufe Hoch erscheint mint, auch die schon
  vorhandenen. Setzt man „Keine Farbe“, kommt überall die eigene Farbe der
  Aufgabe zurück. Die eigene Farbe wird nie überschrieben.
  - Warum nicht beim Anlegen in die Aufgabe kopieren: Dann wäre „Keine Farbe“
    nicht umkehrbar, und alte Aufgaben blieben bunt gemischt.
  - Gilt nur für **Aufgaben** („für die Prioritäten der Aufgaben“). Termine
    behalten ihre eigene Farbe.
  - Standard: alle drei Stufen „Keine Farbe“, nach dem Update sieht also alles
    aus wie vorher.
- **Umsetzungsweg**: `Task.color` liefert die **wirksame** Farbe. Damit
  bleiben alle ~10 Leser unverändert (Kalender, Widgets, Listen), und kein
  Welle-1-Strang muss fremde Dateien anfassen. Die Einstellung hält eine
  statische Tabelle. Das hat ein Vorbild: `PetPlacement` hält seinen Startwert
  ebenfalls statisch, aus demselben Grund (viele Leser ohne `BuildContext`).

## Schritt A (Strang 0a, Welle 0) – `lib/models.dart`

1. `taskPalette` und `taskPaletteNames` um die fünf Farben erweitern,
   Index 14 umbenennen. Den Kommentar über der Palette auf 25 anpassen.
2. Statische Farbregel:
   ```dart
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
     static int? of(Priority p) => _active[p];
     static void use(Map<Priority, int> colors) => _active = Map.unmodifiable(colors);
     static void reset() => _active = const {};
   }
   ```
3. `Task`:
   ```dart
   /// Die Farbe, die im Aufgabenblatt gewaehlt wurde.
   Color get ownColor => taskPalette[colorIndex % taskPalette.length];

   /// Die Farbe, in der die Aufgabe erscheint: die ihrer Prioritaet, wenn die
   /// Einstellungen eine vorgeben, sonst die eigene.
   Color get color {
     final p = PriorityColors.of(priority);
     return p == null ? ownColor : taskPalette[p % taskPalette.length];
   }
   ```
4. `AppState`:
   - Feld `Map<Priority, int> priorityColors = {}`.
   - `_save`: `'priorityColors': {'hoch': 20, ...}`, nur gesetzte Stufen.
   - `load()`: Map lesen, Schlüssel über `Priority.name`, Wert `int` im Bereich
     `0 ≤ i < taskPalette.length`. Alles andere still verwerfen, kein
     Verlust. Danach `PriorityColors.use(priorityColors)`. **Auch** im Zweig
     „erster Start“ `PriorityColors.use(const {})`, damit ein Test, der
     mehrere `AppState` nacheinander lädt, keinen alten Stand mitnimmt.
   - `setPriorityColor(Priority p, int? index)`: `null` = keine Farbe
     (Schlüssel entfernen). Dann `PriorityColors.use(...)` und `_changed()`.
     Das Neuzeichnen löst `notifyListeners` aus, das Widget holt den
     Schnappschuss über den vorhandenen Listener in `main.dart` neu.

### Tests (Strang 0a)

- `models_test.dart`: „20 Farben …“ → „25 Farben, die ersten zwanzig behalten
  Index und Wert“ (die alten 20 Werte als Liste im Test festhalten). Namen und
  Werte gleich lang. „Mint“ ist dabei.
- Neu in `models_test.dart`, Gruppe „Prioritätsfarben“, mit
  `setUp`/`tearDown` → `PriorityColors.reset()`:
  - Ohne Einstellung: `task.color == task.ownColor`.
  - Hoch = 20: Eine Hoch-Aufgabe mit eigener Farbe 3 zeigt `taskPalette[20]`,
    `ownColor` bleibt `taskPalette[3]`. Eine Mittel-Aufgabe ist unberührt.
  - Zurück auf `null` → wieder die eigene.
- `persistence_test.dart`: Rundreise. `{'hoch': 99, 'egal': 3, 'mittel': 'x'}`
  lädt als leere Einstellung, ohne Verlust.
- `home_widget_test.dart` wird hier **nicht** angefasst (außer den
  `RecurrenceType`-Ersetzungen aus Plan 03). Dass der Schnappschuss die
  wirksame Farbe trägt, prüft 1b bei Gelegenheit mit, siehe unten.
- **Wichtig:** Alle bestehenden Testdateien, die `AppState.load()` benutzen,
  laufen unverändert. Falls ein Test die statische Tabelle verschmutzt, dort
  `PriorityColors.reset()` in `tearDown`.

## Schritt B – Hinweis im Aufgabenblatt (Strang 1a, Welle 1)

Datei: `lib/widgets.dart` → `showTaskSheet`.

Gibt `PriorityColors.of(priority)` für die gewählte Stufe eine Farbe vor, dann:
- unter „Farbe“ eine kleine Zeile mit Punkt in der Prioritätsfarbe:
  „Wird in der Farbe der Priorität *Hoch* angezeigt (Einstellungen).“
- `ColorDotPicker` bleibt bedienbar (die eigene Farbe gilt wieder, sobald die
  Einstellung auf „Keine Farbe“ steht), aber mit `Opacity(0.45)`, damit klar
  ist, dass sie gerade nicht sichtbar ist.
- Wechselt man im Blatt die Priorität, aktualisiert sich der Hinweis sofort.
- Das Terminblatt bleibt unverändert (E8).

Test in `test/task_sheet_test.dart`: Mit `PriorityColors.use({Priority.hoch: 20})`
und Priorität Hoch erscheint der Hinweis, bei Mittel nicht. `tearDown` → `reset()`.

## Schritt C – Einstellungen (Strang 1c, Welle 1)

Datei: `lib/screens/settings.dart`.

Neuer Abschnitt **„Prioritäten“** direkt unter „Design“:

```
Prioritäten
┌──────────────────────────────────────────┐
│ Stufe 1 · Hoch          ● Mint         › │
│ Stufe 2 · Mittel        Keine Farbe    › │
│ Stufe 3 · Niedrig       ● Jade         › │
│ Keine Farbe: Aufgaben zeigen ihre eigene │
│ Farbe aus dem Aufgabenblatt.             │
└──────────────────────────────────────────┘
```

- Ein Tipp auf eine Zeile öffnet ein Blatt (`showJoeSheet(expand: true)`), aufgebaut
  wie `_CalendarPickerSheet` (Griff, Titel „Farbe für Hoch“):
  - oben eine Auswahl **„Keine Farbe“** (durchgestrichener Kreis
    `Icons.block` oder Ring ohne Füllung plus Text), markiert, wenn nichts
    gesetzt ist;
  - darunter die 25 Farben als Raster, **5 × 5**, Punkte ≥ 40 px
    (größer als im Aufgabenblatt, dort müssen sie eng stehen), markiert wie
    in `ColorDotPicker` (weißer Rand, Häkchen);
  - Semantik je Punkt: `'Farbe ${taskPaletteNames[i]}'`, `selected:`.
  - Ein Tipp setzt `state.setPriorityColor(p, i)` bzw. `null` und schließt
    das Blatt.
- Das Blatt als private Klasse in `settings.dart`. **Nicht** in `widgets.dart`:
  die Datei gehört in Welle 1 dem Strang 1a.

### Tests (Strang 1c) – `test/settings_test.dart`

- Abschnitt „Prioritäten“ zeigt drei Zeilen, anfangs „Keine Farbe“.
- Zeile „Hoch“ → Blatt → „Mint“ antippen → `state.priorityColors[Priority.hoch] == 20`.
  Die Zeile zeigt „Mint“.
- Wieder öffnen → „Keine Farbe“ → Eintrag entfernt.
- `tearDown` → `PriorityColors.reset()`.

## Akzeptanzkriterien

- 25 Farben + „Keine Farbe“ je Stufe wählbar, Mint ist dabei.
- Aufgaben erscheinen überall (Listen, Dashboard, Kalender, Startbildschirm-Widget)
  in der Farbe ihrer Stufe, wenn eine gesetzt ist, sonst in ihrer eigenen.
- Vorhandene Aufgaben behalten ihre eigene Farbe gespeichert.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- **Features → Design**: „20 warme frei wählbare Farben“ → 25, Mint ergänzt,
  „Minze“ heißt jetzt „Jade“.
- **Features → Prioritäten**: Prioritätsfarben in den Einstellungen, wirken
  beim Anzeigen (E8), nur Aufgaben, Standard „Keine Farbe“.
- Warum `PriorityColors` statisch ist (ein Satz, Verweis auf `PetPlacement`).
