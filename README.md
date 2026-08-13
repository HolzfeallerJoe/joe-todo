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
- **Aufgaben** – eigener Reiter mit allen Aufgaben nach Heute, Kann warten,
  Demnächst, Wiederkehrend und Erledigt. Stufe 3 steht auch dort für sich und
  nicht unter „Heute"; abgehakt bleibt sie im Block stehen, damit sich ein
  wiederkehrender Haken zurücknehmen lässt.
- **Kalender** – Monatsansicht mit farbigen Markern; erledigte Aufgaben bleiben
  am jeweiligen Tag sichtbar (Ring statt Punkt), Tage mit Notizen tragen unten
  mittig ein „N". Tagesdetail darunter, mit einem Plus, das nach Aufgabe oder Termin
  fragt, und einem Knopf für eine Notiz an diesem Tag.
- **Feiertage & Mondphasen** – beides rechnet die App selbst aus
  (`lib/almanac.dart`: Gauß-Osterformel bzw. Meeus-Mondalgorithmus), kein
  Netz, keine Berechtigung. Feiertage tragen einen Stern links des „N",
  die vier Hauptphasen des Mondes ein gemaltes Mond-Icon rechts davon; im
  Tagesdetail stehen beide ganz oben. In den Einstellungen abschaltbar
  (Standard: an) und das Bundesland wählbar (Standard: nur die bundesweiten
  Feiertage).
- **Wiederkehrende Aufgaben** – täglich, wöchentlich, monatlich, alle X Tage.
- **Notizen** – einfache Liste + Editor, ohne Untermenüs; speichert beim
  Zurückgehen automatisch. Jede Notiz hängt an einem Tag (Standard: der Tag,
  an dem sie entsteht), der im Editor umgestellt werden kann.
- **Historie** – alle erledigten Aufgaben, nach Tag gruppiert.
- **Termine** – mit Datum, Uhrzeit, Priorität und Farbe; lange drücken zum
  Löschen.
- **Design** – vier Notizbuch-Themen mit gemalten Texturen (Holz, Papier,
  Stoff, Aquarell) plus elf Foto-Hintergründe, wählbar über eine Klappliste in
  den Einstellungen; 20 warme frei wählbare Farben pro Aufgabe/Termin. Die
  Reiterfarben der Foto-Designs stehen in der Vorlage (siehe unten). Der
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
  lib/almanac.dart    Feiertage (Gauß) + Mondphasen (Meeus), rein berechnet
  lib/theme.dart      Themes + Textur-Painter
  lib/pets.dart       Begleiter-Katalog (Name, Gruppe, Asset-Pfad)
  lib/widgets.dart    PaperCard, Ordner-Reiter, Aufgaben-Zeile, Sheets
  lib/screens/        Dashboard, Aufgaben, Termine, Kalender, Notizen,
                      Historie, Einstellungen
  assets/themes/      Hintergründe – Originale + ausgelieferte compressed/
  assets/pets/        Begleiter als WebP, ein Ordner je Gruppe
  test/               Unit-Tests (Wiederholung, Priorität, Notiz-Datum,
                      Reiterfarben, Feiertage/Mondphasen gegen Referenz-
                      daten) + Widget-Tests für Dashboard und Aufgaben-Reiter
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

## Reiterfarben aus der Vorlage

Zu jedem Foto-Hintergrund gehört im Themes-Ordner der Vorlage ein Blatt
`<Name>Set.jpg`: links das Bild, rechts genau sechs beschriftete Farbfelder –
so viele, wie es Reiter gibt. Diese sechs Werte sind die Reiterfarben, in der
Reihenfolge des Blattes. Die Blätter selbst liegen nicht im Repo (~4 MB je
Blatt), ihre Werte hier:

| Design | Reiter 1–6 |
| --- | --- |
| Eisig | `CCE2EF` `9FBAD5` `75A0C0` `548AB0` `3E759C` `2A5D94` |
| Halloween | `D2D1D9` `6A7175` `9F1BCF` `7C4394` `448740` `5FC546` |
| Holzmaser | `D19D6D` `7B4316` `C8B28A` `A66A42` `4F6B4A` (`3F5147`) |
| Maritim | `2F6FAF` `248FC9` `5EB8C7` `00A8A8` `1FA38B` `D4BA82` |
| Ozean | `0B888C` `74BEC7` `BCD8DB` `00A8A8` `D4BA82` `B8954A` |
| Pfoten | `F5EEE7` `E8DDD3` `D1C0AE` `BAA691` `A38F79` `8C7863` |
| Rainbow | `FAD1CD` `FAE0BE` `FAF1B6` `D3FAC8` `C3DEF7` `F8D2FA` |
| Regenbogen | `AB10B2` `1078D9` `15C04D` `F6DA17` `EF9608` `EC0D10` |
| Weihnachten | `EED8A7` `C8252A` `A6131D` `C7A46C` `335A2E` `476E3F` |
| Zitronen | `F8E8C8` `FCF09F` `EFCA31` `9FBE43` `72A33B` `549034` |

Zwei Ausnahmen: Auf `HolzSet.jpg` trägt das dritte Feld dieselbe Beschriftung
wie das erste (`#D19D6D`), obwohl die Felder verschieden gefüllt sind – dort
steht bis auf Weiteres `3F5147` als sechster Reiter. Und zu `Kaffee.jpg` gibt
es gar kein Blatt; dessen sechs Töne sind aus dem Foto gezogen.

Übernommen wird immer die **Beschriftung**, nicht der Pixelwert: die JPEGs
tragen ein Farbprofil aus dem Corel-Export, ihre Rohwerte sind deutlich dunkler
(`#D19D6D` liegt in der Datei als `8D4C18` vor). Ob die Beschriftung auf ihrer
Fläche lesbar ist, entscheidet `JoeTheme.onTab`; `test/models_test.dart` prüft
für jede Reiterfarbe 3:1.

Dass die Laschen sich farblich kaum vom Hintergrund abheben, ist so gewollt und
kein Fehler: Die Farben stammen aus dem Foto, also gleichen sie ihm (auf Eisig
liegen 93 % des Hintergrunds unter 1,5:1 zur zweiten Reiterfarbe, auf Pfoten
98 %, auf Rainbow 100 %). Getragen wird die Lasche von ihrer Form und ihrem
Schlagschatten. Eine Kontrastkante darum war ausprobiert und ist wieder
rausgeflogen – sie sah nach Umrandung aus und nahm den Reitern die Ruhe.

## Plattformen

Android ist die Hauptplattform und der einzige eingecheckte Plattform-Ordner
(`app/android`). Der Dart-Code bleibt aber absichtlich plattformneutral,
damit eine weitere Plattform später nur ein
`flutter create --platforms=web,windows,...` im `app`-Ordner entfernt ist
(danach das dabei erzeugte Template-`test/widget_test.dart` löschen):

- Alle Plugins (shared_preferences, share_plus, path_provider) sind
  föderiert und decken Mobil, Desktop und Web ab.
- `dart:io` kommt im App-Code nur im Datei-Backend des Logs vor, hinter
  einem bedingten Import (`log_sink_io.dart` / `log_sink_stub.dart`): auf
  Plattformen ohne Dateisystem (Web) trägt der Speicherpuffer, „Logs teilen"
  teilt dann Text statt Dateien.
- Als Probe ist `flutter build web --release` durchgelaufen (Ordner danach
  wieder entfernt) – Web ist die strengste Plattform, dort gibt es kein
  `dart:io`.

## Daten & Sicherheit

Alles liegt lokal in den shared_preferences unter einem Schlüssel
(`joe_data_v1`). Die App spricht nicht ins Netz: keine Netzwerk-Abhängigkeit,
und die INTERNET-Permission steht nur in den Debug-/Profile-Manifesten fürs
Flutter-Tooling, nicht im Release. Androids Auto-Backup bleibt auf dem
Standard (an), damit der Bestand Gerätewechsel überlebt.

Beim Laden gilt: **nichts darf den Start verhindern, und nie wird über die
einzige Kopie geschrieben.** `main()` wartet auf `AppState.load()` – würfe
das bei einem unlesbaren Bestand, bliebe die App auf ewig auf weißem
Bildschirm, und der nächste Griff wäre „App-Daten löschen". Deshalb liest
`load()` Eintrag für Eintrag (ein kaputter Eintrag kostet nur sich selbst,
falsch getypte Einstellungen fallen auf ihren Standard), und sobald dabei
etwas verloren ging, wandert der komplette alte Bestand unter
`joe_data_v1_rescue`, bevor der bereinigte gespeichert wird.
`test/persistence_test.dart` hält das fest.

Löschen fragt überall nach (Aufgabe, Termin, Notiz – `confirmDelete` in
`widgets.dart`): es gibt kein Undo, ein verrutschter Tipper wäre sonst
endgültig.

### Logs

`lib/log.dart` schreibt ein schlichtes App-Log (Zeitstempel je Zeile) nach
`joe.log` im Support-Verzeichnis der App, mit einfacher Rotation ab 256 KB
(`joe.log` → `joe.log.1`). Geloggt werden App-Start, Laden (samt
Rettungsfall), Speicherfehler, Anlegen/Löschen sowie unbehandelte Fehler
(`FlutterError.onError`, `PlatformDispatcher.onError`) – **nur Ereignisse,
Anzahlen und IDs, nie Titel oder Notiztexte**, denn „Logs teilen" in den
Einstellungen reicht die Dateien per Share-Intent an Dritte weiter
(share_plus; ohne Dateisystem trägt ein Speicherpuffer). Zwei Grundsätze,
festgehalten in `test/log_test.dart`: Loggen darf nie stören, und Inhalte
bleiben draußen.

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

Haengen mehrere Geraete an adb – etwa ein Emulator und ein Telefon –, listet
`-Install` sie mit Seriennummer und Modell auf und verlangt `-Device`, statt in
das blosse `more than one device/emulator` von adb zu laufen. Das kommt nach
dem fertigen Build und sieht sonst wie ein Build-Fehler aus.

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
