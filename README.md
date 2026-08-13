# Joe – dein warmes Notizbuch 🌿

Flutter-App nach dem „Joe-Konzept": ein warmes, ruhiges To-do-Notizbuch mit
Dashboard, Kalender, wiederkehrenden Aufgaben, Notizen und Historie.

## Features

- **Dashboard** – Heute-Karte (offene Aufgaben, nächster Termin) mit „Heute
  abhaken" als Ausklappmenü direkt darunter, nächste Termine, Ordner-Reiter zu
  allen Bereichen (Layout nach der Referenz aus `requirements/`). Die Reiter
  stehen in der Reihenfolge Aufgaben, Termine, Kalender, Notizen, Historie,
  Einstellungen.
- **Prioritäten** – drei Stufen für Aufgaben und Termine. Stufe 3 („Niedrig")
  ist die leise: solche Aufgaben zählen nicht in „x offene Aufgaben heute" und
  stehen nur im Ausklappmenü unter „Kann warten", neuste zuerst und mit
  „offen seit …".
- **Aufgaben** – eigener Reiter mit allen Aufgaben nach Heute, Demnächst,
  Wiederkehrend und Erledigt.
- **Kalender** – Monatsansicht mit farbigen Markern; erledigte Aufgaben bleiben
  am jeweiligen Tag sichtbar (Ring statt Punkt), Tage mit Notizen tragen ein
  „N". Tagesdetail darunter, mit einem Plus, das nach Aufgabe oder Termin
  fragt, und einem Knopf für eine Notiz an diesem Tag.
- **Wiederkehrende Aufgaben** – täglich, wöchentlich, monatlich, alle X Tage.
- **Notizen** – einfache Liste + Editor, ohne Untermenüs; speichert beim
  Zurückgehen automatisch. Jede Notiz hängt an einem Tag (Standard: der Tag,
  an dem sie entsteht), der im Editor umgestellt werden kann.
- **Historie** – alle erledigten Aufgaben, nach Tag gruppiert.
- **Termine** – mit Datum, Uhrzeit, Priorität und Farbe; lange drücken zum
  Löschen.
- **Design** – vier Notizbuch-Themen mit gemalten Texturen (Holz, Papier,
  Stoff, Aquarell) plus elf Foto-Hintergründe, wählbar über eine Klappliste in
  den Einstellungen; 20 warme frei wählbare Farben pro Aufgabe/Termin. Der
  Hintergrund läuft randlos hinter Status- und Navigationsleiste durch; die
  Systemsymbole richten sich nach dem Design (siehe unten).
- **Begleiter** – 53 gemalte Tierchen, die oben rechts über der Heute-Karte
  sitzen. Die Auswahl öffnet sich als Blatt von unten: pro Gruppe (Aquarell,
  Axos, Dinos & Drachen, KalasStuff, Katzen, Obst, Weihnachten) ein
  aufklappbarer Abschnitt mit den Motiven als Bildraster, immer nur einer
  offen. Ganz abschaltbar; dann ist auch die Auswahl gesperrt.
  Alles lokal gespeichert (shared_preferences).

## Struktur

```
app/                  Flutter-Projekt (Android)
  lib/models.dart     Datenmodell, Wiederholungslogik, Persistenz (AppState)
  lib/theme.dart      Themes + Textur-Painter
  lib/pets.dart       Begleiter-Katalog (Name, Gruppe, Asset-Pfad)
  lib/widgets.dart    PaperCard, Ordner-Reiter, Aufgaben-Zeile, Sheets
  lib/screens/        Dashboard, Aufgaben, Termine, Kalender, Notizen,
                      Historie, Einstellungen
  assets/themes/      Hintergründe – Originale + ausgelieferte compressed/
  assets/pets/        Begleiter als WebP, ein Ordner je Gruppe
  test/               Unit-Tests (Wiederholung, Priorität, Notiz-Datum,
                      Reiterfarben) + Widget-Tests fürs Dashboard
maestro/              Maestro-UI-Flows (01–08) + Screenshots in shots/
requirements/         Original-Anforderungen (PDF + Layout-Referenzbild)
```

## Bauen & Testen

```powershell
.\build-debug-apk.ps1             # Debug-APK bauen (wie Android Studio)
.\build-debug-apk.ps1 -Install    # bauen + per adb aufs Geraet schieben

cd app
flutter test                      # Unit-Tests

cd ..\maestro
maestro test .                    # alle UI-Flows auf dem Emulator
```

## Bildmaterial

Beide Bildsorten liegen im Repo nur in der Fassung, die auch im APK landet;
die Skripte im Wurzelverzeichnis erzeugen sie aus den Originalen:

```powershell
.\compress-theme-assets.ps1       # assets\themes\*.jpg|png -> themes\compressed\*.jpg
.\compress-pet-assets.ps1         # Begleiter-PNGs -> assets\pets\<gruppe>\<slug>.webp
```

Bei den Hintergründen liegen die Originale mit im Repo. Bei den Begleitern
nicht: die 53 PNGs sind zusammen ~52 MB, die ausgelieferten WebPs ~0,9 MB.
`compress-pet-assets.ps1` erwartet den Original-Ordner deshalb über `-Source`
(Standard: der Download-Ordner) und braucht `ffmpeg` im PATH. Die Gruppen- und
Dateinamen der Vorlage sind dort auf ASCII-Slugs abgebildet
(`Axos\BücherAxo.png` → `axos\buecher-axo.webp`). Neue Begleiter kommen in die
Tabelle `$map` im Skript und in `app\lib\pets.dart`.

`build-debug-apk.ps1` liefert dasselbe Artefakt wie „Build > Build APK(s)" in
Android Studio: debuggable, signiert mit dem Android-Debug-Keystore, alle ABIs.
Standardmaessig laeuft `flutter build apk --debug` (Ausgabe unter
`app\build\app\outputs\flutter-apk\app-debug.apk`); mit `-Gradle` stattdessen
woertlich der Gradle-Task `assembleDebug` wie in Android Studio (Ausgabe unter
`app\build\app\outputs\apk\debug\app-debug.apk`). Weitere Schalter: `-Device`
fuer eine adb-Seriennummer, `-SkipPubGet`.

## CI

`.github/workflows/joe-todo-apk.yml` (im Repo-Wurzelverzeichnis) baut bei
jedem Push auf `main` und in jedem PR `flutter analyze`, `flutter test` und
das Debug-APK und haengt das APK als Artefakt an den Lauf. Der Workflow ist
per `paths`-Filter auf `software/joe-todo/**` beschraenkt, damit Aenderungen
an den anderen Projekten im Repo ihn nicht ausloesen; die Konventionen dafuer
stehen in `.github/workflows/README.md`. Die Flutter-Version ist dort fest
eingetragen (aktuell 3.38.4) und sollte mit der lokalen uebereinstimmen.

Hinweis zu Maestro: Flutter fasst Karten zu einem Accessibility-Knoten
zusammen, daher matchen die Flows mit `(?s)…​.*`-Regex; `inputText` kann nur
ASCII (keine Umlaute in Testeingaben). Datumsabhängige Prüfungen rechnen den
erwarteten Wert per `evalScript` aus dem heutigen Datum aus, statt ihn fest
einzutragen – sonst läuft der Flow beim nächsten Monatswechsel auf.

Die Emulatoren mit `Maestro_` im Namen sind die Testgeräte; steht daneben ein
echtes Telefon an adb, braucht `maestro` ein `--device emulator-XXXX`.

## Systemleisten

Ab Android 15 zeichnet die App zwingend randlos, der Hintergrund liegt also
hinter Status- und Navigationsleiste. `main()` schaltet dafür
`SystemUiMode.edgeToEdge`, und `JoeScaffold` setzt über eine `AnnotatedRegion`
den Leistenstil des aktuellen Designs (`JoeTheme.systemOverlayStyle`): beide
Leisten transparent, `systemNavigationBarContrastEnforced: false` und die
Symbolhelligkeit passend zu `onBg`. Ohne das legt Android unten einen
schwarzen Kontrastbalken über die App, während oben die Textur durchscheint,
und die Statusleistensymbole bleiben hell – auf den hellen Designs unlesbar.
Zum Nachstellen im Emulator hilft die Drei-Knopf-Leiste, weil sie mit 48 dp
deutlich höher ist als die Gestenleiste:

```powershell
adb shell cmd overlay enable  com.android.internal.systemui.navbar.threebutton
adb shell cmd overlay disable com.android.internal.systemui.navbar.gestural
```

Der Abstand des Inhalts zu den Tasten kommt aus dem `SafeArea` in jedem
Screen und in den Eingabeblättern – das bleibt nötig, transparent heißt
nicht, dass dort Inhalt stehen darf.

Für die Eingabeblätter reicht `SafeArea` allein nicht: `showModalBottomSheet`
nimmt dem Blatt per `MediaQuery.removePadding(removeTop: true)` die obere
Einbuchtung weg, deshalb brauchen sie `useSafeArea: true`, sonst schiebt sich
der Titel bei offener Tastatur hinter die Uhr. Die Höhe von `SheetFrame`
rechnet mit `size.height - viewInsets.bottom`; ein fester Anteil der
Bildschirmhöhe ist bei offener Tastatur größer als der Rest des Bildschirms.
Der Speichern-Knopf steht als `footer` außerhalb des scrollenden Teils, damit
er nie halb unter der Tastatur landet. `test/sheet_test.dart` hält beides
fest.
