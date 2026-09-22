# Plan 04 – Begleiter größer, Regler in den Einstellungen

**Schritt A (Modell + Größenrechnung):** Strang 0a (Welle 0), **vierter** Commit.
**Schritt B (Regler):** Strang 1c (Welle 1).
**Abhängig von:** nichts.

## Ziel

„Begleiter größer (anpassbar via Slider in den Einstellungen) – sollten
dennoch default (also bei 100 %) etwas größer sein als jetzt.“

## Ist-Zustand

- `lib/pets.dart:247` `petBox(Pet pet, PetSpot spot)`: Größe über das
  geometrische Mittel `_gaugeTop = 78` / `_gaugeBottom = 94`, gedeckelt durch
  `_maxHeightTop 96`, `_maxWidthTop 124`, `_maxHeightBottom 132`,
  `_maxWidthBottom 168`.
- `petOverlap` (Z. 273) nutzt `petBox`. Die Überlappung oben bleibt auf
  `_maxTopOverlap = 12` gedeckelt, das bleibt so.
- Aufrufer: `lib/widgets.dart` `_PetLayer.build` (Z. 168) und `petPadding`
  (Z. 261–262). Beide haben den `AppState` zur Hand.
- `test/pets_test.dart` prüft die Deckel mit festen Zahlen (132 / 168) und die
  gleiche gefühlte Größe aller Motive.
- Einstellungen: Karte „Begleiter“ in `lib/screens/settings.dart:65–97`
  (Schalter und Auswahl).

## Entscheidungen (E6)

- **100 % = das 1,25-Fache von heute.** Die Konstante `_baseScale = 1.25`
  steht mit Begründung in `pets.dart`.
- Regler **60 % bis 160 %**, Schritte zu 10 % (`divisions: 10`).
- Harte Obergrenzen, damit auch 160 % nichts verdeckt, was man tippen will:
  Breite höchstens **200 px oben / 240 px unten**, Höhe höchstens **160 px
  oben / 200 px unten**. `petBox` kennt die Bildschirmbreite nicht, die Werte
  sind so gewählt, dass auf einem 360-dp-Telefon neben dem Plus-Knopf
  (72 px) Platz bleibt.
- Ist der Begleiter ausgeschaltet, ist der Regler ausgegraut und gesperrt
  (das Muster der Auswahlzeile darüber).

## Schritt A (Strang 0a, Welle 0)

### `lib/pets.dart`

```dart
/// Grundmass: 100 % im Regler sind das 1,25-Fache der ersten Fassung – die
/// Tierchen waren auf grossen Telefonen zu klein, um sie zu bemerken.
const _baseScale = 1.25;

/// Grenzen des Reglers in den Einstellungen.
const minPetScale = 0.6;
const maxPetScale = 1.6;

({double width, double height}) petBox(Pet pet, PetSpot spot, {double scale = 1}) {
  final s = _baseScale * scale.clamp(minPetScale, maxPetScale);
  final gauge = (spot.isTop ? _gaugeTop : _gaugeBottom) * s;
  final maxHeight = math.min((spot.isTop ? _maxHeightTop : _maxHeightBottom) * s,
      spot.isTop ? _hardMaxHeightTop : _hardMaxHeightBottom);
  final maxWidth = math.min((spot.isTop ? _maxWidthTop : _maxWidthBottom) * s,
      spot.isTop ? _hardMaxWidthTop : _hardMaxWidthBottom);
  ... // Rest wie bisher
}

double petOverlap(Pet pet, PetSpot spot, PetPage page, {double scale = 1})
```

Auch die Deckel wachsen mit, sonst hätte der Regler bei Lama und Hai kaum
Wirkung. Die harten Grenzen fangen die Extreme ab. Der Kommentar über den
Konstanten erklärt beide Ebenen.

### `lib/models.dart` – `AppState`

- Feld `double petScale = 1.0;`, gespeichert als `'petScale'`.
- `load()`: `num` lesen, auf `[minPetScale, maxPetScale]` klemmen, sonst `1.0`
  (falscher Typ ist kein Verlust).
- `setPetScale(double v)`: auf eine Nachkommastelle runden (keine
  `0.7000000001` im Bestand), klemmen, `_changed()`.

### `lib/widgets.dart`: nur Pflicht-Anpassung

In `_PetLayer` und `petPadding` `scale: state.petScale` an `petBox` und
`petOverlap` durchreichen. `_PetLayer` bekommt dafür den Wert als Parameter
von `_JoeScaffoldState.build`. Nichts weiter.

### Tests (Strang 0a) – `test/pets_test.dart`

- „die Deckel halten die Extreme im Rahmen“: Die festen Zahlen richten sich
  nach den neuen Konstanten. Zusätzlich für `scale: maxPetScale`: Das Lama
  bleibt ≤ harte Höhe, der Hai ≤ harte Breite.
- Neu: Bei `scale: 1` ist jedes Motiv an jedem Platz **größer** als die alte
  Formel (alte Werte im Test nachrechnen oder `_baseScale > 1` über
  Vergleich `scale: 1/1.25` prüfen).
- Neu: `petBox` wächst monoton mit `scale` (0,6 < 1,0 < 1,6), solange keine
  harte Grenze greift.
- „alle Motive wirken an einem Platz gleich gross“ weiter für `scale: 1` und
  `scale: 1.6`. Bei 1,6 drücken die harten Grenzen stärker, Toleranz
  bei Bedarf begründet anheben.
- Die Widget-Tests für Plätze und Mitscrollen (Z. ~300 ff.) laufen mit dem
  Standard weiter. Scheitern sie an neuen Maßen, die Erwartung anpassen und
  nicht die Logik.

`persistence_test.dart`: `petScale` kommt nach Speichern und Laden zurück.
`'petScale': 'gross'` → 1.0, `'petScale': 9` → 1.6.

## Schritt B – Regler (Strang 1c, Welle 1)

Datei: `lib/screens/settings.dart`.

In der Karte des Begleiters (unter der Auswahlzeile, im selben
`Opacity`/`IgnorePointer`-Muster wie „Welche Kalender“) eine Zeile:

```
Größe                                   125 %
[────────────●──────────────]
```

- `Slider(min: minPetScale, max: maxPetScale, divisions: 10, value: state.petScale)`,
  `activeColor: theme.accent`.
- `onChanged: state.setPetScale`. So ist die Änderung sofort zu sehen, der
  Begleiter sitzt auch auf der Einstellungsseite. Zehn Stufen heißt höchstens
  zehn Speichervorgänge je Zug, das ist unbedenklich.
- Beschriftung rechts: `'${(state.petScale * 100).round()} %'`.
- Semantik: `Slider` bringt sie mit. `label:` auf dieselbe Prozentangabe
  setzen.
- Den Untertitel des Schalters „Kleine Deko auf dem Dashboard“ korrigieren:
  Der Begleiter sitzt längst auf **jeder** Seite. Neu: „Kleine Deko auf jeder
  Seite“.

### Tests (Strang 1c) – `test/settings_test.dart` (neu)

- Regler auf das Maximum ziehen → `state.petScale == 1.6`. Die Beschriftung
  zeigt „160 %“.
- Begleiter aus → der Regler reagiert nicht (Wert bleibt).

## Akzeptanzkriterien

- Nach dem Update ist der Begleiter sichtbar größer als vorher, ohne dass
  man etwas einstellt.
- Der Regler ändert die Größe sofort und dauerhaft.
- Auch bei 160 %: Die erste Karte bleibt lesbar (das Tierchen sitzt auf der
  Kante, `petPadding` hält den Platz frei), und der Plus-Knopf ist frei.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- **Features → Begleiter**: Größe per Regler (60–160 %), 100 % ist größer als
  in der ersten Fassung. Die harten Grenzen und warum es sie gibt.
