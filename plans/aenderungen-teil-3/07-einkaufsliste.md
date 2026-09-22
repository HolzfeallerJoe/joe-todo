# Plan 07 – Einkaufsliste

**Schritt A (Modell, Persistenz, Begleiter-Seite):** Strang 0a (Welle 0), **fünfter** Commit.
**Schritt B (Oberfläche):** Strang 1d (Welle 1).
**Schritt C (Umschalter in den Einstellungen):** Strang 1c (Welle 1).
**Abhängig von:** nichts.

## Ziel

Eine Einkaufsliste. Darstellung und etwas Funktion lassen sich in den
Einstellungen umschalten:

1. **Eigener Reiter** (Standard): ein neuer Ordner-Reiter auf der ersten
   Seite. Dahinter liegt **eine** Liste, dauerhaft über alle Tage.
2. **In den Notizen**: In der Notizen-Ansicht schaltet man oben zwischen
   „Notizen“ und „Einkaufsliste“ um. Diese Liste gehört **einem Tag**.

In beiden Fällen: eine Checkliste, Einträge über ein Eingabefeld **am unteren
Rand**. Langes Drücken auf einen Eintrag öffnet unten das bekannte Blatt
(„Bearbeiten“, „Löschen“, Löschen fragt nach).

## Ist-Zustand, der hier zählt

- Reiter: `lib/screens/dashboard.dart:42–77`, sechs `FolderTabButton` mit
  `theme.tabColors[0..5]`. **Jedes Design hat genau sechs Reiterfarben**
  (`lib/theme.dart`, aus den Vorlagen-Blättern, siehe README „Reiterfarben aus
  der Vorlage“).
- Notizen: `lib/screens/notes.dart` `NotesScreen` (Liste + Stift-FAB).
- Blatt „Bearbeiten/Löschen“: `showEntryOptions` in `widgets.dart:1035`.
  Einzeiliger Text: `showTextEntrySheet` (`widgets.dart:992`). Beide werden
  **nur aufgerufen**, nicht geändert (die Datei gehört in Welle 1 dem
  Strang 1a).
- Begleiter: Jede Seite braucht einen `PetPage`-Eintrag (`lib/pets.dart:166`).
  `PetPlacement.spotOn` mischt `page.index` in den Startwert, **neue Einträge
  deshalb ans Ende** des Enums, sonst springen die Plätze der anderen Seiten.
- Leere Zustände stehen auf einer `PaperCard`, das prüft `test/legibility_test.dart`.

## Entscheidungen

- **E9**: Der Reiter „Einkaufsliste“ steht zwischen „Notizen“ und „Historie“.
  Die Vorlagen haben nur sechs Farben, deshalb:
  `shoppingTabColor = Color.lerp(tabColors[3], tabColors[4], 0.5)`. Das ist die
  Mitte der beiden Nachbarn, passt zum Design und hebt sich von beiden ab. Wer
  echte Vorlagenfarben nachliefert, trägt sie später als siebten Wert ein.
- **E10**: Im Modus „In den Notizen“ zeigt die Liste zuerst **heute**, mit
  Datumsumschalter `‹ Freitag, 18. September ›` (Tipp aufs Datum öffnet den
  Datumsdialog). Beide Modi teilen sich den Speicher: Einträge ohne Tag
  gehören zur Reiter-Liste, Einträge mit Tag zur Liste dieses Tages.
  Umschalten löscht nichts, der andere Teil ist nur nicht zu sehen.
- **E11**: Abgehakte Einträge bleiben durchgestrichen unter den offenen stehen.
  Neue Einträge landen **unten** bei den offenen, nahe am Eingabefeld, wo der
  Blick gerade ist. Ein „Erledigte entfernen“ ist nicht angefragt und kommt
  nicht dazu.
- Tipp auf einen Eintrag hakt ihn ab bzw. nimmt den Haken zurück (wie bei
  Aufgaben).
- Kein Plus-Knopf auf der Einkaufsseite: Das Eingabefeld ist der Weg zum
  Hinzufügen. Der Begleiter sitzt dort nur **oben**, unten wäre das
  Eingabefeld.
- Kein Eintrag im Kalender und keiner im Startbildschirm-Widget, beides ist
  nicht angefragt.

## Schritt A (Strang 0a, Welle 0)

### `lib/models.dart`

```dart
/// Wo die Einkaufsliste wohnt (Einstellungen).
enum ShoppingListMode {
  /// Ein eigener Reiter auf der ersten Seite, eine Liste fuer alle Tage.
  tab('Eigener Reiter', 'Eine Liste für alle Tage'),

  /// In den Notizen, je Tag eine eigene Liste.
  perDay('In den Notizen', 'Jeder Tag hat seine eigene Liste');

  final String label;
  final String description;
  const ShoppingListMode(this.label, this.description);

  static ShoppingListMode fromJson(Object? v) => ShoppingListMode.values
      .firstWhere((m) => m.name == v, orElse: () => ShoppingListMode.tab);
}

class ShoppingItem {
  final String id;
  String title;
  bool done;

  /// Der Tag, an den der Eintrag gebunden ist; null = die Liste im Reiter.
  final DateTime? day;
  final DateTime createdAt;
  ...toJson / fromJson ('id','title','done','day' als dateKey oder null,'createdAt' ISO)
}
```

`AppState`:
- `List<ShoppingItem> shopping = [];`, `ShoppingListMode shoppingMode = ShoppingListMode.tab;`
- `load`: `shopping = _readList(data['shopping'], ShoppingItem.fromJson, onLoss: loss);`,
  `shoppingMode = ShoppingListMode.fromJson(data['shoppingMode']);`
- `_save`: `'shopping'`, `'shoppingMode'`.
- Abfrage und Änderungen (Log **ohne** Titel, wie überall):
  ```dart
  /// Die Eintraege einer Liste: [day] null = die im Reiter, sonst die dieses
  /// Tages. Offene zuerst, darin aelteste oben (neue landen unten, nahe am
  /// Eingabefeld); danach die abgehakten.
  List<ShoppingItem> shoppingItemsFor(DateTime? day)
  ShoppingItem? addShoppingItem(String title, {DateTime? day}) // leer → null, nichts angelegt
  void toggleShoppingItem(ShoppingItem item)
  void renameShoppingItem(ShoppingItem item, String title)     // leer → nichts
  void deleteShoppingItem(ShoppingItem item)
  void setShoppingMode(ShoppingListMode mode)
  ```
  `day` immer über `dateOnly` ablegen und vergleichen.

### `lib/pets.dart`

Am **Ende** von `PetPage` anhängen:

```dart
/// Die Einkaufsliste: unten steht das Eingabefeld, dort sitzt niemand.
shopping([PetSpot.contentTopRight, PetSpot.contentTopLeft]),
```

### Tests (Strang 0a)

- `test/shopping_model_test.dart` (neu, gehört 0a):
  - Reiter- und Tageslisten sind getrennt. Zwei Tage sind getrennt.
  - Reihenfolge: offen vor erledigt, innerhalb nach `createdAt`.
  - Leerer oder nur aus Leerzeichen bestehender Titel legt nichts an.
    `rename` auf leer ändert nichts.
  - JSON-Rundreise. Kaputter Eintrag kostet nur sich selbst.
- `persistence_test.dart`: `shoppingMode` Standard `tab`, Rundreise `perDay`,
  Unsinn → `tab`.
- `pets_test.dart`: `PetPage.shopping` in die Liste „kein Platz neben dem Plus“
  (Z. ~102) aufnehmen.

## Schritt B – Oberfläche (Strang 1d, Welle 1)

Dateien: `lib/screens/shopping.dart` (neu), `lib/screens/dashboard.dart`,
`lib/screens/notes.dart`, `lib/theme.dart`, `test/shopping_test.dart` (neu),
`test/legibility_test.dart`, `test/notes_test.dart`, `maestro/10_shopping.yaml` (neu).

### `lib/theme.dart`

```dart
/// Farbe des siebten Reiters (Einkaufsliste). Die Vorlagen bringen genau
/// sechs Farben mit; die Mitte der beiden Nachbarreiter (Notizen, Historie)
/// passt zum Design und hebt sich von beiden ab.
Color get shoppingTabColor => Color.lerp(tabColors[3], tabColors[4], 0.5)!;
```

### `lib/screens/shopping.dart`

1. **`ShoppingList`** (Widget, wiederverwendbar), Parameter `DateTime? day`:
   - `Column`: `Expanded(ListView)` mit den Einträgen auf **einer** `PaperCard`
     (wie `_TaskCard`), darunter die **Eingabeleiste**.
   - Leer: `PaperCard` mit „Noch nichts auf der Liste. Unten eintippen und
     mit Enter hinzufügen.“ (auf Papier, nicht frei auf dem Hintergrund,
     siehe README „Lesbarkeit“).
   - Zeile `_ShoppingRow`: Kästchen wie `TaskTile` (Farbe `theme.accent`,
     erledigt = gefüllt mit Häkchen), Titel, erledigt durchgestrichen in
     `theme.inkSoft`. `onTap` → `toggleShoppingItem`. `onLongPress` →
     `showEntryOptions(deleteTitle: 'Eintrag löschen?', subject: item.title,
     onEdit: …, onDelete: () => state.deleteShoppingItem(item))`. `onEdit`
     öffnet `showTextEntrySheet(title: 'Eintrag bearbeiten', hint: 'Was fehlt?', initialText: item.title)`
     und ruft danach `renameShoppingItem`. Semantik wie `TaskTile`
     (`checked`, `button`, `onLongPress`).
   - Eingabeleiste: `PaperCard` am unteren Rand, `SafeArea(top: false)`,
     `TextField` (Hinweis „Was fehlt?“, `textInputAction: TextInputAction.done`,
     `textCapitalization: TextCapitalization.sentences`) plus Knopf
     `Icons.add_circle` (Tooltip „Hinzufügen“). `onSubmitted` und Knopf legen
     an, leeren das Feld und **behalten den Fokus** (`focusNode.requestFocus()`),
     damit man zügig mehrere Einträge tippt. Leere Eingabe tut nichts.
   - Die Tastatur schiebt die Leiste nach oben (Scaffold-Standard
     `resizeToAvoidBottomInset`). Nach dem Anlegen zum neuen Eintrag scrollen,
     falls die Liste länger als der Bildschirm ist.
   - `ListView`-Padding über `petPadding(context, PetPage.shopping, …)`, damit
     der Begleiter oben auf der Karte sitzt und mitscrollt.
2. **`ShoppingListScreen`** (Reiter-Modus): `JoeScaffold(page: PetPage.shopping,
   title: 'Einkaufsliste', body: SafeArea(child: ShoppingList(day: null)))`.
   Kein FAB.

### `lib/screens/dashboard.dart`

Nur im Modus `tab`, zwischen „Notizen“ und „Historie“:

```dart
if (state.shoppingMode == ShoppingListMode.tab)
  FolderTabButton(
    icon: Icons.shopping_basket_outlined,
    label: 'Einkaufsliste',
    color: theme.shoppingTabColor,
    onTap: () => _push(context, const ShoppingListScreen()),
  ),
```

(`DashboardScreen.build` braucht dafür `AppScope.of(context)`.)

### `lib/screens/notes.dart`

Nur im Modus `perDay`:
- `NotesScreen` wird `StatefulWidget` mit `_tab` (Notizen | Einkaufsliste) und
  `_day` (Standard `today()`).
- Oben, vor der Liste, ein `SegmentedButton<_NotesTab>` („Notizen“,
  „Einkaufsliste“) im Joe-Look (Akzentfarbe, Papierhintergrund), auf einer
  `PaperCard` bzw. als erste Zeile.
- Tab „Notizen“: alles wie bisher, mit FAB.
- Tab „Einkaufsliste“: kein FAB. Datumszeile `‹ formatDateFull(_day) ›`
  (Pfeile ±1 Tag, Tipp auf das Datum → `showDatePicker`). Darunter
  `ShoppingList(day: _day)`.
- `JoeScaffold.page`: im Einkaufs-Tab `PetPage.shopping`, sonst `PetPage.notes`.
  So sitzt der Begleiter nie auf dem Eingabefeld.
- Im Modus `tab` sieht die Notizen-Seite **genau** aus wie heute (kein
  Umschalter).
- Den gewählten Tab nicht speichern: Die Notizen öffnen immer mit „Notizen“.

### Tests (Strang 1d) – `test/shopping_test.dart`

- Modus `tab`: Das Dashboard zeigt den Reiter „Einkaufsliste“ zwischen
  „Notizen“ und „Historie“. Tipp darauf öffnet die Liste.
- Modus `perDay`: kein Reiter. In den Notizen gibt es den Umschalter. Der
  Eintrag landet unter `dateKey(today())`. Pfeil ›, dann ist die Liste leer
  (anderer Tag).
- Eintippen + Enter → Eintrag steht in der Liste, das Feld ist leer und hat
  weiter den Fokus. Enter auf leerem Feld → nichts.
- Tipp → erledigt (durchgestrichen, rutscht unter die offenen).
- Langes Drücken → Blatt mit „Bearbeiten“/„Löschen“. „Löschen“ fragt nach
  (`confirmDelete`), danach ist der Eintrag weg. „Bearbeiten“ ändert den Titel.
- Für jedes Design: `onTab(shoppingTabColor)` hat ≥ 3:1 Kontrast zur
  Reiterfarbe (wie der Reiterfarben-Test in `models_test.dart`).

`test/legibility_test.dart`: den leeren Zustand der Einkaufsliste
(beide Modi) in die Prüfung „jeder leere Zustand steht auf Papier“ aufnehmen.

`test/notes_test.dart`: Im Modus `tab` hat die Notizen-Seite keinen
Umschalter. Die bestehenden Tests laufen unverändert.

### `maestro/10_shopping.yaml` (neu)

Hinzufügen über Dashboard → „Einkaufsliste“ → `inputText: "Milch"` →
`pressKey: Enter` → `inputText: "Brot"` → Enter → `assertVisible` beider →
Tipp auf „Milch“ → `longPressOn: "Brot"` → „Löschen“ → „Löschen“ →
`assertNotVisible: "Brot"` → Screenshot `shots/10_shopping`. (Nur ASCII
eingeben, siehe README „Hinweis zu Maestro“.)

## Schritt C – Umschalter (Strang 1c, Welle 1)

Datei: `lib/screens/settings.dart`.

Neuer Abschnitt **„Einkaufsliste“** (nach „Kalender“, vor „Erinnerungen“),
eine `PaperCard` mit zwei `RadioListTile<ShoppingListMode>`. Titel ist
`mode.label`, Untertitel `mode.description`, Farbe `theme.accent`,
`onChanged: state.setShoppingMode`.

Test in `test/settings_test.dart`: Umschalten auf „In den Notizen“ →
`state.shoppingMode == perDay`.

## Akzeptanzkriterien

- Standard: Reiter „Einkaufsliste“ auf der ersten Seite, eine dauerhafte
  Liste. Nach einem App-Neustart ist alles noch da.
- Umgeschaltet: kein Reiter. In den Notizen „Notizen | Einkaufsliste“, je
  Tag eine eigene Liste.
- Hinzufügen über das Feld unten, Abhaken per Tipp, Bearbeiten und Löschen per
  langem Druck (mit Rückfrage).
- Der Begleiter verdeckt weder Eingabefeld noch Einträge.
- `flutter analyze` / `flutter test` grün.

## Doku für Welle 2 (README)

- **Features**: neuer Punkt „Einkaufsliste“ mit beiden Modi, E10/E11. Warum das
  Eingabefeld unten steht.
- **Features → Dashboard**: Reihenfolge der Reiter mit „Einkaufsliste“.
- **Reiterfarben aus der Vorlage**: Absatz zum siebten Reiter (Mischfarbe, E9).
- **Daten & Sicherheit**: Die Einkaufsliste liegt im selben Schlüssel
  `joe_data_v1`, Titel stehen nicht im Log.
- **Struktur**: `lib/screens/shopping.dart`, neue Tests, Maestro-Flow 10.
