# Joe – dein warmes Notizbuch 🌿

Flutter-App nach dem „Joe-Konzept": ein warmes, ruhiges To-do-Notizbuch mit
Dashboard, Kalender, wiederkehrenden Aufgaben, Notizen und Historie.

## Features

- **Dashboard** – Heute-Karte (offene Aufgaben, nächster Termin), Aufgaben zum
  Abhaken, nächste Termine, Ordner-Reiter zu allen Bereichen (Layout nach der
  Referenz aus `requirements/`).
- **Kalender** – Monatsansicht mit farbigen Markern; erledigte Aufgaben bleiben
  am jeweiligen Tag sichtbar (Ring statt Punkt), Tagesdetail darunter.
- **Wiederkehrende Aufgaben** – täglich, wöchentlich, monatlich, alle X Tage.
- **Notizen** – einfache Liste + Editor, ohne Untermenüs; speichert beim
  Zurückgehen automatisch.
- **Historie** – alle erledigten Aufgaben, nach Tag gruppiert.
- **Termine** – mit Datum, Uhrzeit und Farbe; lange drücken zum Löschen.
- **Design** – vier Notizbuch-Themen mit gemalten Texturen (Holz, Papier,
  Stoff, Aquarell) plus elf Foto-Hintergründe, wählbar über eine Klappliste in
  den Einstellungen; warme frei wählbare Farben pro Aufgabe/Termin.
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
  lib/screens/        Dashboard, Kalender, Termine, Notizen, Historie, Einstellungen
  assets/themes/      Hintergründe – Originale + ausgelieferte compressed/
  assets/pets/        Begleiter als WebP, ein Ordner je Gruppe
  test/               Unit-Tests für die Wiederholungslogik
maestro/              Maestro-UI-Flows (01–07) + Screenshots in shots/
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

Hinweis zu Maestro: Flutter fasst Karten zu einem Accessibility-Knoten
zusammen, daher matchen die Flows mit `(?s)…​.*`-Regex; `inputText` kann nur
ASCII (keine Umlaute in Testeingaben).
