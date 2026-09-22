# Änderungen Teil 3 – Hauptdatei

Diese Datei ist der Einstieg für die Umsetzung. Sie sagt, **was** gebaut wird
(Verweise auf die sieben Einzelpläne), **in welcher Reihenfolge**, **was
parallel laufen darf** und **wem welche Datei gehört**. Eine KI, die die
Umsetzung übernimmt, arbeitet diese Datei von oben nach unten ab.

Vor jeder Arbeit lesen: [`AGENTS.md`](../../AGENTS.md) (Versionsregel, analyze/test
grün) und [`README.md`](../../README.md) (wie die App gebaut ist).

---

## 1. Die sieben Punkte

| # | Punkt | Plan | Art | Ändert gespeicherte Daten |
| --- | --- | --- | --- | --- |
| 1 | Kopfzeile „X offene Aufgaben / X Termine heute“ zweizeilig, Zahlen untereinander | [01-kopfzeile-zeilenumbruch.md](01-kopfzeile-zeilenumbruch.md) | UI | nein |
| 2 | Dauer für Aufgaben und Termine (z. B. Mo 12:00 bis Do 18:00) | [02-dauer-aufgaben-termine.md](02-dauer-aufgaben-termine.md) | Feature | ja |
| 3 | Wiederholung: Einmalig, Monatlich, Jährlich, Alle X Tage + Wochenskala Mo–So | [03-wiederholung.md](03-wiederholung.md) | Feature | ja (Umschreiben von „täglich“) |
| 4 | Begleiter größer, Regler in den Einstellungen | [04-begleiter-groesse.md](04-begleiter-groesse.md) | Feature | ja (neue Einstellung) |
| 5 | Farben für Prioritäten (25 Farben + „Keine Farbe“) | [05-prioritaetsfarben.md](05-prioritaetsfarben.md) | Feature | ja (neue Einstellung) |
| 6 | Ganztägige Termine aus dem Geräte-Kalender stehen auf zwei Tagen | [06-geraetekalender-ganztaegig.md](06-geraetekalender-ganztaegig.md) | **Fehler** | nein |
| 7 | Einkaufsliste (eigener Reiter **oder** je Tag in den Notizen, umschaltbar) | [07-einkaufsliste.md](07-einkaufsliste.md) | Feature | ja (neue Liste + Einstellung) |

Zu Punkt 6 ist die Ursache schon gefunden, der Verdacht „zwei Tage“ stimmt. Das
Plugin (`device_calendar_plus_android` 0.7.1) liefert Ganztagstermine schon als
**lokale** Mitternacht. `eventCoversDay` in `lib/device_calendar.dart` rechnet
sie dann noch einmal nach UTC um. In Deutschland wird aus „18.9. 00:00“ dadurch
„17.9. 22:00 UTC“, und der Termin steht am 17. **und** 18. Die Tests merken es
nicht: Sie bauen Termine mit `DateTime.utc` und laufen in der CI unter UTC.
Details stehen in Plan 06.

---

## 2. Entscheidungen, die ich getroffen habe – bitte vor dem Start prüfen

Wo die Anforderung zwei Lesarten zulässt, habe ich eine gewählt. Jede
Entscheidung steht ausführlich im jeweiligen Plan. Wer eine anders will, ändert
sie **hier und im Plan**, bevor die Umsetzung beginnt.

| ID | Entscheidung | Plan |
| --- | --- | --- |
| E1 | Zeile 1: „3 offene Aufgaben“, Zeile 2: „2 Termine heute“. Die Vorlesehilfe liest weiter den ganzen Satz mit „und“ (so bleiben auch die Maestro-Flows gültig). | 01 |
| E2 | Die Dauer ist optional (Schalter „Dauer“ im Blatt). Eine Aufgabe mit Dauer steht an **jedem** Tag der Spanne unter „Heute abhaken“ und im Kalender und wird **einmal** abgehakt (bei Wiederholung: einmal pro Wiederholung). Mit Dauer hat eine Aufgabe eine Start- und eine Enduhrzeit. | 02 |
| E3 | Wiederkehrende Aufgabe mit Dauer: jede Wiederholung bekommt dieselbe Dauer. Zwei Wiederholungen dürfen sich nicht überlappen; das Blatt lehnt das mit einem Toast ab. | 02, 03 |
| E4 | „Täglich“ ist keine eigene Option mehr: alle sieben Tage der Wochenskala markiert = täglich (die Beschriftung sagt dann „Täglich“). Gespeicherte „täglich“-Aufgaben werden beim Laden umgeschrieben. | 03 |
| E5 | Jährlich am 29. Februar heißt in Nicht-Schaltjahren: am 28. Februar. | 03 |
| E6 | Begleiter: 100 % entspricht dem 1,25-Fachen der heutigen Größe. Der Regler geht von 60 % bis 160 % in 10er-Schritten. | 04 |
| E7 | Die Farbpalette wächst von 20 auf 25 Farben. Fünf werden **angehängt**, darunter ein helles „Mint“. Die bestehende „Minze“ heißt künftig „Jade“, der Farbwert bleibt. Dieselbe Palette gilt im Aufgaben-/Terminblatt. „Keine Farbe“ gibt es zusätzlich, also 25 Farben + „Keine Farbe“. | 05 |
| E8 | Die Prioritätsfarbe wirkt **beim Anzeigen**: Wer die Einstellung ändert, färbt alle Aufgaben dieser Stufe um. Sie gilt nur für **Aufgaben**, nicht für Termine. Standard ist bei allen drei Stufen „Keine Farbe“, es ändert sich also nichts, bis man eine wählt. | 05 |
| E9 | Der Reiter „Einkaufsliste“ steht zwischen „Notizen“ und „Historie“. Seine Farbe wird aus den beiden Nachbarreitern gemischt; die Vorlagen-Blätter haben nur sechs Felder. | 07 |
| E10 | Die Liste je Tag (Modus „In den Notizen“) zeigt zuerst **heute** und hat einen Datumsumschalter (‹ Datum ›). Einträge des jeweils anderen Modus bleiben gespeichert, sind aber unsichtbar, bis man zurückschaltet. | 07 |
| E11 | Abgehakte Einkaufs-Einträge bleiben stehen (durchgestrichen, unter den offenen); nichts wird automatisch gelöscht. Neue Einträge landen unten bei den offenen, nahe am Eingabefeld. | 07 |
| E12 | Version: Minor-Sprung auf `1.2.0+6` (neue Funktionen, gespeicherte Daten ändern sich). Laut AGENTS.md vor dem Push trotzdem beim Benutzer nachfragen. | – |

---

## 3. Wellenplan – was parallel laufen darf

Grundregel: **Innerhalb einer Welle fasst keine Datei mehr als ein Strang
an.** Das gilt auch für Tests, Maestro-Flows und die README. So entstehen
keine Merge-Konflikte, und niemand wartet auf jemand anderen.

Der Engpass ist klar: `lib/models.dart` brauchen fünf der sieben Punkte, und
`lib/widgets.dart` (die Eingabeblätter) vier. Deshalb baut **ein** Strang
zuerst das gemeinsame Fundament (Datenmodell, Persistenz, Rechenlogik). Danach
teilen sich vier Stränge die Oberfläche, jeder auf eigenen Dateien.

```
Welle 0 ──┬── 0a  Fundament (Datenmodell für 2, 3, 4, 5, 7)   ── nacheinander, 5 Commits
          └── 0b  Geräte-Kalender-Fix (Punkt 6)               ── parallel zu 0a
                        │
                 merge 0a + 0b  →  Integrationsstand
                        │
Welle 1 ──┬── 1a  Eingabeblätter & Aufgabenzeile (1, 2B, 3B, 5B)
          ├── 1b  Termin- & Kalenderanzeige (2C)
          ├── 1c  Einstellungen (4B, 5C, 7C)
          └── 1d  Einkaufsliste – Oberfläche (7B)
                        │
                 merge 1a–1d (konfliktfrei, Dateien disjunkt)
                        │
Welle 2 ────── Abschluss: README, Gesamtprüfung, Version, Push (nach Rückfrage)
```

### Welle 0

| Strang | Inhalt | Reihenfolge der Commits |
| --- | --- | --- |
| **0a Fundament** | Plan 03 Schritt A → Plan 02 Schritt A → Plan 05 Schritt A → Plan 04 Schritt A → Plan 07 Schritt A | Genau diese Reihenfolge: Die Dauer (02) baut auf der neuen Wiederholungslogik (03) auf. Nach **jedem** Commit sind `flutter analyze` und `flutter test` grün. |
| **0b Kalender-Fix** | Plan 06 komplett | ein Commit |

Warum 0a ein einziger Strang ist: Alle fünf Schritte ändern dieselben Klassen
(`Task`, `AppState.load/_save`) und dieselben Tests. Parallel ginge das nur mit
Konflikten.

### Welle 1 (startet erst, wenn 0a **und** 0b gemergt sind)

| Strang | Inhalt | Reihenfolge der Commits |
| --- | --- | --- |
| **1a Eingabe & Aufgaben** | Plan 01 komplett, Plan 03 Schritt B, Plan 02 Schritt B, Plan 05 Schritt B | 01 → 03B → 02B → 05B |
| **1b Termine & Kalender** | Plan 02 Schritt C | ein bis zwei Commits |
| **1c Einstellungen** | Plan 04 Schritt B, Plan 05 Schritt C, Plan 07 Schritt C | 04B → 05C → 07C |
| **1d Einkaufsliste** | Plan 07 Schritt B | ein bis zwei Commits |

Alle vier Stränge dürfen gleichzeitig laufen, am besten je in einem eigenen
Git-Worktree bzw. auf einem eigenen Branch (`teil3/1a-eingabe`, …).

### Welle 2 (ein Strang, nach dem Merge von Welle 1)

1. README: Die Abschnitte „Doku für Welle 2“ aus allen sieben Plänen einarbeiten.
2. `flutter analyze`, `flutter test`, `.\build-debug-apk.ps1` und die manuelle
   Prüfliste unten.
3. Maestro: Ob `maestro test .` laufen kann, hängt vom Emulator ab. Wenn er
   läuft, alle Flows; sonst im Bericht erwähnen.
4. Version in `app/pubspec.yaml` anheben (Vorschlag E12), **vorher den Benutzer
   fragen**. Gepusht wird erst nach seinem Okay.

---

## 4. Datei-Besitz

Wer eine Datei hier nicht besitzt, fasst sie in dieser Welle **nicht** an.
Braucht ein Strang doch eine Änderung in einer fremden Datei, schreibt er sie
als Punkt in seinen Abschlussbericht („Übergabe“). Umgesetzt wird sie dann in
Welle 2. Er baut keinen Umweg.

| Datei | Welle 0 | Welle 1 | Welle 2 |
| --- | --- | --- | --- |
| `lib/models.dart` | **0a** | – (nur lesen) | – |
| `lib/util.dart` | **0a** | – | – |
| `lib/pets.dart` | **0a** | – | – |
| `lib/reminders.dart` | **0a** | – | – |
| `lib/widgets.dart` | **0a** (nur Pflicht-Anpassungen, siehe Pläne 03 A und 04 A) | **1a** | – |
| `lib/screens/tasks.dart` | – | **1a** | – |
| `lib/device_calendar.dart` | **0b** | **1b** (Endtag-Beschriftung, Plan 02 C) | – |
| `lib/screens/calendar.dart` | **0b** (nur `_DeviceEventRow`) | **1b** | – |
| `lib/agenda.dart` | – | **1b** | – |
| `lib/screens/appointments.dart` | – | **1b** | – |
| `lib/home_widget.dart` | – | **1b** | – |
| `lib/screens/settings.dart` | – | **1c** | – |
| `lib/screens/shopping.dart` (neu) | – | **1d** | – |
| `lib/screens/dashboard.dart` | – | **1d** | – |
| `lib/screens/notes.dart` | – | **1d** | – |
| `lib/theme.dart` | – | **1d** | – |
| `lib/main.dart`, `lib/screens/history.dart`, `lib/screens/wellbeing.dart`, Kotlin | – (keine Änderung geplant) | – | – |
| `test/models_test.dart` | **0a** | – | – |
| `test/persistence_test.dart` | **0a** | – | – |
| `test/reminders_test.dart` | **0a** | – | – |
| `test/pets_test.dart` | **0a** | – | – |
| `test/recurrence_test.dart` (neu, Wiederholung + Dauer) | **0a** | – | – |
| `test/shopping_model_test.dart` (neu) | **0a** | – | – |
| `test/home_widget_test.dart` | **0a** (nur `RecurrenceType.daily` ersetzen) | **1b** | – |
| `test/device_calendar_test.dart` | **0b** | – | – |
| `test/dashboard_test.dart`, `test/tasks_test.dart`, `test/sheet_test.dart` | – | **1a** | – |
| `test/task_sheet_test.dart` (neu) | – | **1a** | – |
| `test/agenda_test.dart`, `test/calendar_test.dart` | – | **1b** | – |
| `test/settings_test.dart` (neu) | – | **1c** | – |
| `test/shopping_test.dart` (neu), `test/legibility_test.dart`, `test/notes_test.dart` | – | **1d** | – |
| `maestro/03_recurring_task.yaml` | – | **1a** | – |
| `maestro/10_shopping.yaml` (neu) | – | **1d** | – |
| `README.md` | – | – | **Welle 2** |
| `app/pubspec.yaml` (Version) | – | – | **Welle 2** |

Anmerkung zu `widgets.dart` in 0a: Der Strang darf dort nur so viel ändern,
dass die App nach der Modelländerung übersetzt (neue Enum-Werte im Blatt,
`scale:` an zwei `petBox`-Aufrufen). Alles Sichtbare am Blatt macht 1a.

Taucht in 0a ein **weiterer** Test auf, der wegen der Modelländerung bricht,
repariert 0a ihn. In Welle 0 fasst niemand sonst Tests an außer 0b (nur
`device_calendar_test.dart`).

---

## 5. Regeln für jeden Strang

- **Plan zuerst ganz lesen**, dann den Code, den er nennt. Zeilennummern in den
  Plänen gelten für den Stand vor Welle 0. Maßgeblich sind die Symbolnamen.
- **Stil der Umgebung übernehmen:** deutsche Kommentare ohne Umlaute im Code
  (`ae`, `oe`, `ue`), in Texten für den Nutzer echte Umlaute, so dicht
  kommentiert wie der Nachbarcode. Kommentare begründen das *Warum*.
- **Nichts darf den Start verhindern:** Neue Felder in `AppState.load()` folgen
  dem vorhandenen Muster. Falscher Typ heißt Standardwert, kein Verlust.
  Unlesbare Listeneinträge laufen über `_readList`.
- **Keine Titel ins Log**, nur Ereignisse, Anzahlen und IDs (siehe `lib/log.dart`).
- **Löschen fragt nach** (`showEntryOptions` → `confirmDelete`).
- Nach **jedem** Commit: `cd app; flutter analyze; flutter test`, beides grün.
- Commit-Nachrichten auf Deutsch, eine Zeile Zusammenfassung, darunter kurz das
  Warum. Kein Push. Gepusht wird nur in Welle 2 nach Rückfrage.
- **README und Version nicht anfassen**, beides ist Welle 2. Stattdessen im
  Abschlussbericht die Punkte aus „Doku für Welle 2“ des Plans bestätigen oder
  ergänzen.
- Abschlussbericht je Strang: was umgesetzt ist, welche Tests neu sind, was
  abweicht und warum, welche Übergaben offen sind.

---

## 6. Vorlage für den Auftrag an einen Strang

```
Du setzt Strang <ID> aus plans/aenderungen-teil-3/00-uebersicht.md um.
Lies zuerst AGENTS.md, README.md, die Hauptdatei und diese Pläne:
<Liste der Plan-Schritte des Strangs>.
Du darfst nur die Dateien ändern, die Abschnitt 4 der Hauptdatei deinem
Strang in dieser Welle zuweist. Arbeite die Schritte in der angegebenen
Reihenfolge ab. Nach jedem Schritt: flutter analyze und flutter test grün,
dann ein Commit. Kein Push, keine README- oder Versionsänderung.
Zum Schluss: Abschlussbericht nach Abschnitt 5.
```

---

## 7. Manuelle Prüfliste (Welle 2, auf dem Telefon)

- [ ] Dashboard: zwei Zeilen, Zahlen rechtsbündig untereinander, auch bei „12“ über „3“.
- [ ] Aufgabe „Mo 12:00 – Do 18:00“ anlegen. Sie steht Mo bis Do unter „Heute abhaken“, an allen vier Tagen im Kalender und ist nach einmaligem Abhaken an allen vier Tagen erledigt.
- [ ] Termin mit Dauer über drei Tage: Starttag mit Uhrzeit, Mitteltag „ganztägig“, Endtag „bis 18:00 Uhr“. Das gilt im Dashboard, im Kalender und im Reiter „Termine“.
- [ ] Wochenskala: Mo+Mi+Fr gewählt, die Aufgabe erscheint nur an diesen Tagen. Alle sieben gewählt, die Beschriftung sagt „Täglich“.
- [ ] Eine alte „täglich“-Aufgabe (aus dem Stand vor dem Update) steht nach dem Update an jedem Tag.
- [ ] „Jährlich“: nächstes Jahr am selben Tag im Kalender.
- [ ] Begleiter bei 100 % sichtbar größer als vorher. Der Regler ändert die Größe sofort, auch bei 160 % überdeckt der Begleiter keinen Knopf.
- [ ] Prioritätsfarbe „Hoch“ = Mint: Alle Hoch-Aufgaben werden mint, auch im Kalender und im Startbildschirm-Widget. Zurück auf „Keine Farbe“: wieder die eigene Farbe.
- [ ] Geräte-Kalender: ein ganztägiger Termin am 20. steht **nur** am 20.
- [ ] Einkaufsliste als Reiter: Eintrag tippen + Enter, abhaken, lange drücken → Bearbeiten und Löschen. Nach einem App-Neustart ist alles noch da.
- [ ] Umschalten auf „In den Notizen“: Der Reiter verschwindet, in den Notizen gibt es „Notizen | Einkaufsliste“ mit einer Liste für heute, ein anderer Tag hat eine eigene Liste.
