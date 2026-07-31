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
- **Design** – vier Notizbuch-Themen (Holz, Papier, Stoff, Aquarell) mit
  gemalten Texturen, warme frei wählbare Farben pro Aufgabe/Termin, optionales
  Kätzchen als Deko. Alles lokal gespeichert (shared_preferences).

## Struktur

```
app/                  Flutter-Projekt (Android)
  lib/models.dart     Datenmodell, Wiederholungslogik, Persistenz (AppState)
  lib/theme.dart      Themes + Textur-Painter
  lib/widgets.dart    PaperCard, Ordner-Reiter, Aufgaben-Zeile, Sheets
  lib/screens/        Dashboard, Kalender, Termine, Notizen, Historie, Einstellungen
  test/               Unit-Tests für die Wiederholungslogik
maestro/              Maestro-UI-Flows (01–06) + Screenshots in shots/
requirements/         Original-Anforderungen (PDF + Layout-Referenzbild)
```

## Bauen & Testen

```powershell
cd app
flutter test                      # Unit-Tests
flutter build apk --debug         # APK bauen
adb install -r build\app\outputs\flutter-apk\app-debug.apk

cd ..\maestro
maestro test .                    # alle UI-Flows auf dem Emulator
```

Hinweis zu Maestro: Flutter fasst Karten zu einem Accessibility-Knoten
zusammen, daher matchen die Flows mit `(?s)…​.*`-Regex; `inputText` kann nur
ASCII (keine Umlaute in Testeingaben).
