# Plan 01 – Kopfzeile zweizeilig, Zahlen untereinander

**Strang:** 1a (Welle 1) · **Dateien:** `lib/widgets.dart` (`TodayHeadline`),
`test/dashboard_test.dart` · **Abhängig von:** nichts. Liegt nur deshalb in
Welle 1, weil 0a in Welle 0 ebenfalls `widgets.dart` anfasst.

## Ziel

Heute steht auf der Heute-Karte ein Satz:

> **3** offene Aufgaben und **2** Termine heute

Künftig zwei Zeilen, das „und“ entfällt. Die Zahlen stehen untereinander:

> **3** offene Aufgaben
> **2** Termine heute

## Ist-Zustand

- `lib/widgets.dart:323` `class TodayHeadline`: ein `Text.rich` mit sechs
  `TextSpan`s, darunter `' und '`. Die Klasse umschließt ein `Semantics` mit
  eigenem Label (`excludeSemantics: true`).
- Der Kommentar darüber (Z. 314–322) begründet noch den einen Satz („Bewusst
  ein fließender Text und keine Spalten: er bricht bei grosser Systemschrift
  von selbst um“). Er muss neu geschrieben werden.
- `lib/screens/dashboard.dart:145` ruft `TodayHeadline(tasks:, appointments:)`
  auf. Das bleibt unverändert.
- `test/dashboard_test.dart` sucht die Kopfzeile über eine Hilfsfunktion
  `headline(tasks, appointments)`. Vor der Änderung prüfen, ob sie über das
  Semantics-Label oder über den Text sucht.
- Die Maestro-Flows 01, 06 und 07 prüfen `"(?s).*offene Aufgaben und.*Termine heute.*"`
  gegen den Accessibility-Text.

## Entscheidung (E1)

- Zeile 1 „offene Aufgabe(n)“, Zeile 2 „Termin(e) heute“. „heute“ steht nur
  hinten: Es sind zwei Zeilen eines Gedankens, keine zwei Aussagen.
- **Das Semantics-Label bleibt der ganze Satz mit „und“**
  (`'3 offene Aufgaben und 2 Termine heute'`). Vorgelesen klingt das natürlich,
  zwei Zeilen ohne Bindewort klängen abgehackt. Nebenbei bleiben die
  Maestro-Flows und der Test gültig.

## Umsetzung

1. `TodayHeadline.build`: Statt `Text.rich` eine **`Table`** mit zwei Spalten
   bauen:
   - Spalte 0 (`IntrinsicColumnWidth()`): die Zahl, **rechtsbündig**
     (`TextAlign.right`), mit `fontFeatures: [FontFeature.tabularFigures()]` im
     Stil `number`. Damit stehen „3“ und „12“ bündig, und die Wörter beginnen
     auf derselben Kante.
   - Spalte 1 (`FlexColumnWidth()`): das Wort mit führendem Leerzeichen, Stil
     `word`. Weil die Spalte flexibel ist, bricht ein Wort bei großer
     Systemschrift innerhalb seiner Zeile um, statt über den Kartenrand zu
     laufen. Damit ist der Grund für den alten Fließtext erledigt.
   - `defaultVerticalAlignment: TableCellVerticalAlignment.baseline` und
     `textBaseline: TextBaseline.alphabetic`. So sitzen die große Zahl und das
     kleinere Wort auf einer Grundlinie.
   - Zwischen den Zeilen kein zusätzlicher Abstand; `height: 1.1` der Zahl
     reicht. Wirkt es gedrängt, die zweite Zeile mit `Padding(top: 2)` in den
     Zellen absetzen.
2. Das Semantics-Label unverändert lassen (siehe E1).
3. Den Doc-Kommentar der Klasse neu schreiben: zwei Zeilen, Zahlen als Spalte,
   damit man sie auf einen Blick vergleicht. Warum die Tabelle trotzdem
   umbricht (flexible Wortspalte). Warum die Vorlesehilfe den Satz mit „und“
   bekommt.
4. `dashboard_test.dart`:
   - Bestehenden Test „die Kopfzeile nennt Aufgaben und Termine in einem Satz“
     umbenennen, z. B. „die Kopfzeile nennt Aufgaben und Termine in zwei Zeilen“.
   - Neuer Test: Mit 12 Aufgaben und 3 Terminen liegen die rechten Kanten der
     Zahlen-Texte `'12'` und `'3'` auf derselben x-Position
     (`tester.getTopRight(find.text('12')).dx == tester.getTopRight(find.text('3')).dx`,
     mit kleiner Toleranz). Die Wörter „offene Aufgaben“ und „Termine heute“
     beginnen auf derselben x-Position.
   - Neuer Test: `find.textContaining(' und ')` findet in der Karte nichts
     Sichtbares mehr. Das Semantics-Label enthält weiter „und“.
   - Neuer Test mit `MediaQuery(textScaler: TextScaler.linear(2.0))`: kein
     Overflow (`tester.takeException()` ist `null`).

## Akzeptanzkriterien

- Zwei Zeilen, kein „und“ sichtbar, Zahlen rechtsbündig untereinander.
- Singular/Plural wie bisher („1 offene Aufgabe“, „1 Termin heute“).
- Große Systemschrift: kein Overflow.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- Im Abschnitt **Features → Dashboard** den Satz „darunter beide Zahlen des
  Tages in einem Satz („3 offene Aufgaben und 2 Termine heute“)“ ersetzen durch:
  „darunter beide Zahlen des Tages in zwei Zeilen, die Zahlen untereinander
  („3 offene Aufgaben“ / „2 Termine heute“); vorgelesen wird es als ein Satz“.
