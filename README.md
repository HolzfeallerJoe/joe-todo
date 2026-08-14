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
  Feiertage). Die Meeus-Reihe ist zu teuer, um sie für 42 Rasterzellen in
  einem Frame zu rechnen; `MoonWarmup` arbeitet den Monat deshalb
  häppchenweise vor, und zwar dort zuerst, wo der Blick hingeht: der laufende
  Monat ab heute bis zum Monatsende und der Anfang als Nachtrag, ein
  künftiger Monat vom Ersten nach vorn, ein vergangener vom Letzten
  rückwärts. Das Raster liest nur den Cache (`cachedMoonPhaseOnDay`) und
  füllt sich sichtbar auf; das Tagesdetail rechnet seinen einen Tag sofort.
- **Geräte-Kalender** – zeigt auf Wunsch die Termine aus den Kalendern des
  Telefons (Android Calendar Provider) im Monatsraster (Farbpunkte in der
  Kalenderfarbe, nach den eigenen Einträgen) und im Tagesdetail (nach den
  eigenen Terminen, mit Uhrzeit bzw. „ganztägig"). Damit landet alles, was
  die Google-Kalender-App synchronisiert – Gmail-Termine, abonnierte
  Kalender –, ohne dass Joe selbst ins Netz spricht. Standard: aus; der
  Schalter in den Einstellungen fragt die Kalender-Berechtigung an, ein
  Untermenü darunter wählt, welche der Kalender überhaupt gezeigt werden
  (siehe „Daten & Sicherheit").
- **Wiederkehrende Aufgaben** – täglich, wöchentlich, monatlich, alle X Tage.
- **Notizen** – einfache Liste + Editor, ohne Untermenüs; speichert beim
  Zurückgehen automatisch. Jede Notiz hängt an einem Tag (Standard: der Tag,
  an dem sie entsteht), der im Editor umgestellt werden kann.
- **Historie** – alle erledigten Aufgaben, nach Tag gruppiert.
- **Termine** – mit Datum, Uhrzeit, Priorität und Farbe; lange drücken zum
  Löschen.
- **Erinnerungen** – wie im Google-Kalender: ein Termin bekommt einen
  Vorlauf („Zur Terminzeit" bis „1 Tag vorher"), eine Aufgabe eine Uhrzeit
  am Fälligkeitstag – bei wiederkehrenden Aufgaben an jedem ihrer Tage.
  Zugestellt wird lokal vom Telefon, nichts geht ins Netz. Neue Termine
  starten mit dem Standard-Vorlauf aus den Einstellungen (30 Minuten),
  neue Aufgaben ohne; ein Hauptschalter schaltet alles auf einmal ab. Ein
  Antippen führt in den Kalender auf den Tag der Erinnerung.
- **Startbildschirm-Widgets** – vier Stück: Aufgaben (2×2), Termine (2×2),
  Kalender (2×2) und ein großer Block (4×4) mit Monatsraster, Aufgaben und
  Terminen nebeneinander. Sie tragen die Farben des gewählten Designs,
  markieren den heutigen Tag und führen beim Antippen dorthin, wo das
  Angetippte auch in der App steht. Sie zeigen nur – abgehakt wird in der App
  (siehe unten). Alle vier lassen sich in beide Richtungen frei ziehen (2×3,
  2×4, 3×5 …) und wachsen dabei mit: mehr Zeilen, größere Schrift, größere
  Kalenderzellen. Bleibt unter den Aufgaben von heute Platz, füllt ihn
  „Demnächst" mit den nächsten Tagen.
- **Meldungen** – Fehler und Bestätigungen erscheinen als Toast am oberen
  Rand (`lib/toast.dart`), drei Sekunden, mit Aktion länger; antippen oder
  nach oben wischen räumt sie weg. Bewusst ein Singleton statt einer
  Snackbar: die meisten dieser Meldungen entstehen ohne Bildschirm – ein
  fehlgeschlagener Erinnerungsplan im Hintergrund hat keinen `BuildContext`.
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
  lib/device_calendar.dart  Geraete-Kalender als lesende Ebene (Plugin-Kapsel)
  lib/reminders.dart  Erinnerungsplan (rechnend) + Zustellung (Plugin-Kapsel)
  lib/home_widget.dart      Schnappschuss fuer die Widgets (rechnend) + Kanal
  android/.../widget/       Die Widgets selbst: Daten lesen, zeichnen, wecken
  android/app/src/main/res/layout/joe_widget_*.xml   ihre Layouts
  android/app/src/main/res/xml/joe_widget_*_info.xml ihre Groessen
  lib/env.dart        Schalter aus env/ (siehe unten), nur ueber JoeEnv
  env/.env.example    Vorlage; die echten env-Dateien sind nicht im Repo
  lib/toast.dart      Meldungen am oberen Rand – der eine Weg zum Nutzer
  lib/theme.dart      Themes + Textur-Painter
  lib/pets.dart       Begleiter-Katalog (Name, Gruppe, Asset-Pfad)
  lib/widgets.dart    PaperCard, Ordner-Reiter, Aufgaben-Zeile, Sheets
  lib/screens/        Dashboard, Aufgaben, Termine, Kalender, Notizen,
                      Historie, Einstellungen
  assets/themes/      Hintergründe – Originale + ausgelieferte compressed/
  assets/pets/        Begleiter als WebP, ein Ordner je Gruppe
  test/               Unit-Tests (Wiederholung, Priorität, Notiz-Datum,
                      Reiterfarben, Feiertage/Mondphasen gegen Referenz-
                      daten, Erinnerungsplan) + Widget-Tests für Dashboard
                      und Aufgaben-Reiter
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
                                  # (braucht JOE_MOCK_DATA=true, siehe "Schalter")
```

## Schalter (env)

Was ein Build anders macht als der naechste, steht in `app/env/`:

```
app/env/.env.example     Vorlage, im Repo – welche Schluessel es gibt
app/env/.env             Entwicklung (Debug/Profile), nicht im Repo
app/env/.env.production  Release, nicht im Repo
```

Die beiden echten Dateien sind ignoriert und duerfen Geheimnisse enthalten.
Nach dem Klonen einmal:

```powershell
Copy-Item app\env\.env.example app\env\.env
```

| Schluessel | Standard | Bedeutung |
| --- | --- | --- |
| `JOE_MOCK_DATA` | `false` | Beispieldaten beim allerersten Start (`AppState._seed`): Aufgaben, Termine, Willkommensnotiz. Aus heisst: Joe startet leer. |

Sie werden **nicht zur Laufzeit gelesen und sind kein Asset** – sie gehen beim
Bauen mit:

```powershell
flutter build apk --debug   --dart-define-from-file=env/.env
flutter build apk --release --dart-define-from-file=env/.env.production
flutter run                 --dart-define-from-file=env/.env
```

Daraus macht der Uebersetzer Konstanten (`bool.fromEnvironment` in
`lib/env.dart`). Ins APK wandern also die Werte, nicht die Dateien: im
fertigen Paket ist keine env-Datei zu finden. Im Code steht ein
Schluesselname nur in `JoeEnv`, alles andere fragt dessen Getter.

`build-debug-apk.ps1` haengt das Flag von selbst an, die CI ebenso.

### Ohne das Flag gilt der Standard

Fehlt die env-Datei (frischer Klon) oder wird ohne Flag gebaut – „Run" aus der
IDE, `build-debug-apk.ps1 -Gradle`, weil Gradle die Schalter nicht
entgegennimmt –, gelten die Standardwerte aus `lib/env.dart`. Das ist
Absicht: der Standard ist der ausgelieferte Wert, ein vergessenes Flag kann
also nichts kaputtmachen, sondern nur eine Abweichung verschlucken. Wer die
Schalter in der IDE braucht, traegt `--dart-define-from-file=env/.env` einmal
in die zusaetzlichen Run-Argumente der Konfiguration ein.

### Was davon im APK landet

Nicht die Dateien – die sind kein Asset. Von den Werten kommt nur an, was der
Kode auch liest, und zwar so:

| in der env-Datei | im APK |
| --- | --- |
| Schluessel, den kein `fromEnvironment` liest | gar nichts |
| `bool.fromEnvironment` | nichts – der Uebersetzer setzt ihn ein und wirft den toten Zweig weg |
| `String.fromEnvironment` | der Text, mit `strings` zu finden |

Nachgemessen am Release-Build: ein `JOE_PROBE_SECRET`, das kein Kode liest,
taucht weder in `libapp.so` noch in irgendeiner Zwischendatei auf; mit
`JOE_MOCK_DATA=false` sind auch alle Beispieldaten-Texte ("Zahnarzt",
"Kaffee mit Anna", ...) restlos verschwunden.

Fuer die letzte Zeile der Tabelle gilt trotzdem, was fuer jeden Weg gilt –
Asset, `--dart-define`, Konstante im Quelltext: was die App *benutzt*, kennt
auch der Nutzer. Ein Geheimnis, das wirklich eines bleiben muss
(API-Schluessel mit Kosten oder Schreibrecht), gehoert hinter einen eigenen
Server, den die App fragt.

### Maestro braucht `JOE_MOCK_DATA=true`

Die UI-Flows starten mit `clearState: true` und suchen danach die
Beispieldaten ("Blumen gießen", "Willkommen bei Joe", ...). Also vor
`maestro test .` in `app/env/.env` `JOE_MOCK_DATA=true` setzen, neu bauen und
installieren – mit dem Standard `false` laufen sie ins Leere. Ein neuer Start
saet ausserdem nur, solange noch kein Bestand gespeichert ist; `clearState`
sorgt dafuer. Die `flutter test`-Suite ist unberuehrt: Konstanten lassen sich
im Test nicht ueber eine Datei umstellen, die Tests setzen deshalb
`JoeEnv.debugMockData`.

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

- shared_preferences, share_plus, path_provider, flutter_local_notifications
  und flutter_timezone sind föderiert und decken Mobil, Desktop und Web ab.
  Einzige Ausnahme ist `device_calendar_plus` (nur Android und iOS): reiner
  Dart-Code, baut also überall, und jeder Aufruf ist gefangen – anderswo
  bleibt die Geräte-Kalender-Ebene schlicht leer.
- Die Startbildschirm-Widgets sind das einzige Stück Android-Code der App
  (`android/.../widget/`). Auf jeder anderen Plattform fehlt der
  Methodenkanal schlicht; `home_widget.dart` fängt das einmalig ab und
  vermerkt es im Log, statt bei jedem Speichern zu klagen. Der Dart-Anteil –
  der gerechnete Schnappschuss – ist plattformneutral und getestet.
- `dart:io` kommt im App-Code nur im Datei-Backend des Logs vor, hinter
  einem bedingten Import (`log_sink_io.dart` / `log_sink_stub.dart`): auf
  Plattformen ohne Dateisystem (Web) trägt der Speicherpuffer, „Logs teilen"
  teilt dann Text statt Dateien.
- **Die Erinnerungen brauchen die Einstellungen jeder Plattform, nicht nur
  Androids.** `flutter_local_notifications` wirft in `initialize`, wenn für
  die laufende Plattform kein Eintrag dabei ist; mit nur `android:` blieb
  `JoeReminders` auf iOS, macOS, Linux und Windows tot (kein Alarm, dafür bei
  jedem Start ein Fehler-Toast). `reminders.dart` gibt deshalb alle fünf mit.
  Genauso plattformweise: die Berechtigungsanfrage (Android / Darwin / Web),
  die Zustellprüfung und der Weg in die System-Einstellungen. Linux kennt
  kein `zonedSchedule` – das meldet die App einmal und versucht es danach
  nicht bei jedem Lauf erneut.
- Als Probe sind `flutter build web --release`, `flutter build windows
  --release` und `flutter build apk --debug` durchgelaufen (Web- und
  Windows-Ordner danach wieder entfernt). Der Windows-Build wurde zusätzlich
  gestartet: das Log meldet „Erinnerungen: bereit (Europe/Berlin …)" und
  „1 gestellt", die Erinnerungen laufen dort also wirklich und nicht nur auf
  dem Papier. Web ist die strengste Plattform, dort gibt es kein `dart:io`.

## Startbildschirm-Widgets

Vier Widgets, alle aus derselben Quelle: Aufgaben (2×2), Termine (2×2),
Kalender (2×2) und die Übersicht (4×4). Sie sind reines Android
(`AppWidgetProvider` + RemoteViews), kein Flutter – **wenn das Telefon sie
zeichnet, ist die App fast immer tot.** Daraus folgt fast alles andere:

- **Sie rechnen nichts.** Kein Wiederholungsmuster, keinen Feiertag, keine
  Sortierung nach Priorität. Das alles steht in Dart und würde in Kotlin ein
  zweites Mal stehen – mit der Aussicht, dass die beiden Fassungen
  auseinanderlaufen. Stattdessen legt `lib/home_widget.dart` bei jeder
  Änderung einen fertig gerechneten Schnappschuss ab
  (`buildWidgetSnapshot`, JSON in den eigenen shared_preferences unter
  `joe_widgets`), und Kotlin sucht sich daraus den Tag heraus, den die Uhr
  gerade zeigt.
- **Der Schnappschuss ist nach Tagen geordnet, nicht nach „heute".** Um
  Mitternacht wechselt der Tag, und um Mitternacht läuft die App nicht. Eine
  fertige Heute-Liste wäre jeden Morgen falsch, bis jemand die App öffnet.
  Gerechnet wird deshalb vom Monatsersten bis 45 Tage voraus
  (`widgetHorizonDays`); danach steht im Widget der Hinweis „Joe öffnen"
  statt eines alten Standes.
- **Liste und Kalenderpunkt sind zweierlei.** Die Heute-Liste trägt
  Liegengebliebenes von Tag zu Tag weiter (so steht es auch im Dashboard) –
  das Monatsraster darf das nicht, sonst wäre jeder kommende Tag markiert,
  nur weil heute etwas offen ist. Der Punkt kommt deshalb aus einem eigenen
  Feld (`mark`), das nur zählt, was an dem Tag fällig ist, in derselben
  Reihenfolge wie im Kalender der App (Termine vor Aufgaben, Ring statt Punkt
  für erledigt). `test/home_widget_test.dart` hält beides fest.
- **Sie zeigen nur.** Abhaken direkt im Widget hieße, dass Kotlin in den
  Bestand schreibt – dasselbe Datenmodell ein zweites Mal, und ein Rennen mit
  der laufenden App um dieselbe Datei. Ein Antippen führt darum in die App,
  und zwar dorthin, wo das Angetippte auch dort steht (Aufgaben, Termine,
  Kalender). Beim Kaltstart holt Dart das Ziel ab, sobald der Navigator steht;
  läuft die App schon, kommt es als `onNewIntent` herein. Beide Wege werden
  gebraucht.
- **Neu gezeichnet wird dreifach abgesichert:** die App schiebt bei jeder
  Änderung (gebündelt, 250 ms – ein Zug an einer Aufgabe löst mehrere
  Änderungen aus, und jeder Schnappschuss weckt vier Empfänger); ein Wecker
  auf kurz nach Mitternacht zieht den Tageswechsel nach
  (`setAndAllowWhileIdle`: ungenau, aber nicht im Doze verschlafend – ein
  exakter Alarm wäre fürs Neuzeichnen nicht zu rechtfertigen); und darunter
  liegt das `updatePeriodMillis` von einer halben Stunde plus Neustart,
  Zeitumstellung und App-Update.

**Größer ziehen soll etwas bringen.** Alle vier sind in beide Richtungen
frei ziehbar (`resizeMode`, ohne obere Schranke); die Voreinstellung ist
2×2 bzw. 4×4, nach unten geht es bis auf ein Feld Höhe bei den Listen. Wer
zieht, soll aber nicht dieselbe Miniatur in einer größeren Karte bekommen,
darum richtet sich alles nach der gemeldeten Höhe:

- Das **Monatsraster im Kalender-Widget** teilt seine Wochen über die ganze
  Höhe auf (Zeilen mit `layout_weight`), es füllt also jede Größe statt unten
  Luft zu lassen. Die Zellen gibt es in drei Stufen (14/25/32 dp): klein trägt
  die Farbe des Eintrags in der Zahl selbst, die beiden größeren haben den
  Punkt darunter wie der Kalender der App. Im **Übersichts-Widget** wird das
  Raster bewusst *nicht* gedehnt – darunter stehen noch zwei Listen, denen
  mindestens fünf Zeilen bleiben sollen.
- **Listenzeilen** haben zwei Stufen (20 dp/12 sp und 26 dp/14 sp). Ab etwa
  drei Feldern Höhe wird die Zeile größer – und es passen trotzdem mehr
  hinein als vorher.

Bleibt unter der Heute-Liste noch Platz, füllt ihn der Blick nach vorn:
„Morgen", „So, 16. Aug" und was dort ansteht, so weit es reicht. Die Zeilen
auseinanderzuziehen, bis es voll aussieht, wäre die schlechtere Antwort
gewesen – eine Liste wächst mit ihrem Inhalt, nicht mit ihrem Rahmen.

Dabei gilt eine Feinheit, ohne die das Ganze Unsinn wäre: **die Tagesliste im
Schnappschuss trägt Liegengebliebenes mit** (so steht es auch im Dashboard) –
eine heute offene Aufgabe taucht deshalb an jedem kommenden Tag darin auf.
Unter „Demnächst" darf nur stehen, was an dem Tag wirklich neu fällig ist.
Jeder Eintrag bringt darum ein `over`-Kennzeichen mit, ob er an seinem Tag
fällig ist oder nur mitgeschleppt wird; `test/home_widget_test.dart` hält das
fest.

Drei Fallen, die es beim Bauen wirklich gab:

- **Zeichnen kann sich im Kreis drehen, und das legt das ganze Telefon
  lahm.** Ein `updateAppWidget` lässt den Startbildschirm die Ansicht neu
  vermessen; fällt sie anders aus als vorher, meldet er die neue Größe
  zurück, das System ruft `onAppWidgetOptionsChanged` – und wer *dort* wieder
  blind zeichnet, fängt von vorn an. Das Ergebnis waren hunderte Updates in
  Sekunden, dann „System UI reagiert nicht", und danach ein **schwarzer
  Bildschirm für alle Apps**, nicht nur für Joe. Die Suche lief lange in die
  falsche Richtung, weil es aussah, als starte Joe nicht mehr – in Wahrheit
  hing der Startbildschirm, der Joes Fenster mitzeichnet. Der Beweis war ein
  Build vom letzten Commit, ganz ohne Widgets: auch der blieb schwarz.
  Deshalb zeichnet `JoeWidget.show()` nur noch, wenn sich die Unterschrift
  aus **Größe, Datenstand und Tag** geändert hat, und `JoeWidgetData.save()`
  meldet einen unveränderten Schnappschuss zurück, statt einen Rundruf
  auszulösen. Zum Nachsehen liegt beides im Log (`adb logcat -s JoeWidget`):
  jede Zeichnung mit ihrer Unterschrift, jeder Schnappschuss mit „neu" oder
  „unverändert".

- **Die Höhe.** Der Startbildschirm meldet in `OPTION_APPWIDGET_MIN_HEIGHT`
  nicht die Höhe von jetzt, sondern die Spanne über beide Lagen – hochkant
  ist das Widget schmal und hoch, quer breit und flach. `MIN_HEIGHT` ist also
  die Höhe im *Querformat*; wer sie hochkant nimmt, füllt nur die halbe Karte
  und lässt den Rest leer. Hochkant zählt `MAX_HEIGHT`.
- **Kein `FLAG_ACTIVITY_NEW_TASK` beim Antippen.** Joes Activity trägt
  `taskAffinity=""` (so kommt die Vorlage von Flutter). Mit leerer Affinität
  macht NEW_TASK aus jedem Antipper eine *neue* Aufgabe, statt die
  vorhandene nach vorn zu holen – samt Übergangsanimation auf ein Fenster,
  das gerade erst seine Oberfläche bekommt. Einmal endete das in einem
  `SurfaceSyncGroup: Failed to receive transaction ready in 1000ms` und
  einem schwarzen Bild. Was `PendingIntent.getActivity` an Flags braucht,
  ergänzt das System selbst; damit läuft der Weg wie beim Antippen einer
  Erinnerung, und der ist erprobt.
- **`<View>` gibt es nicht.** RemoteViews lässt im fremden Prozess nur eine
  Handvoll View-Klassen zu, und ein blankes `<View>` gehört nicht dazu. Der
  Trennstrich im großen Widget war zuerst eines – das Ergebnis war „Widget
  kann nicht geladen werden", schon im Widget-Verzeichnis. Jetzt ist es ein
  `ImageView`.

Was die Widgets bewusst **nicht** können: scrollen (das wäre ein
`RemoteViewsService` mit eigenem Adapter; in 2×2 ist dafür kein Platz, und
was nicht mehr hineinpasst, sagt die letzte Zeile als „+3 weitere"), das
Foto-Design zeigen (die Karte trägt die Papierfarbe, kein Bild – ein Foto
müsste als Bitmap in den fremden Prozess und stritte dort mit dem
Hintergrundbild) und die Termine der Geräte-Kalender (die liest Joe nur,
während er selbst einen Monat anzeigt).

## Daten & Sicherheit

Alles liegt lokal in den shared_preferences unter einem Schlüssel
(`joe_data_v1`). Daneben liegt seit den Widgets eine zweite, abgeleitete
Kopie: `joe_widgets` trägt den Schnappschuss, und darin stehen zwangsläufig
auch Titel – ein Widget, das nur Punkte zeigte, wäre keins. Beides sind die
privaten Einstellungen der App, kein anderes Programm kommt daran, und
„Logs teilen" fasst den Schnappschuss nicht an (das Log hält Titel weiterhin
draußen). Die Widgets brauchen **keine zusätzliche Berechtigung**: der Wecker
um Mitternacht ist ein ungefährer.
Die App spricht nicht ins Netz: keine Netzwerk-Abhängigkeit,
und die INTERNET-Permission steht nur in den Debug-/Profile-Manifesten fürs
Flutter-Tooling, nicht im Release. Androids Auto-Backup bleibt auf dem
Standard (an), damit der Bestand Gerätewechsel überlebt.

Für die Erinnerungen kommen POST_NOTIFICATIONS (ab Android 13 zur Laufzeit
bestätigt), RECEIVE_BOOT_COMPLETED (Plan nach einem Neustart neu stellen) und
für die exakte Zustellung **zwei** Alarm-Rechte dazu: USE_EXACT_ALARM (ab
API 33, für Kalender- und Wecker-Apps ohne Extra-Dialog vorgesehen) und
SCHEDULE_EXACT_ALARM mit `maxSdkVersion="32"`. Die zweite Zeile ist kein
Doppel: Android 12 kennt USE_EXACT_ALARM noch nicht, dort lieferte
`canScheduleExactAlarms()` sonst `false` und **jedes** `zonedSchedule` würfe –
Erinnerungen kämen auf einer ganzen Android-Generation nie an. Zusätzlich
prüft `reminders.dart` die Freigabe vor jedem Lauf und weicht auf einen
ungefähren Alarm aus, statt gar nichts zu stellen; dass es dann ein paar
Minuten später werden kann, sagt ein Toast.

Gefragt wird beim ersten Setzen einer Erinnerung bzw. beim Hauptschalter;
ohne Erlaubnis wird nichts gesetzt und ein Toast sagt warum, mit Knopf in die
System-Einstellungen – ab Android 13 zeigt das System den Dialog nach
zweimaligem Ablehnen gar nicht mehr. Beim Start prüft
`JoeReminders.checkDelivery`, ob die Benachrichtigungen inzwischen im System
abgeschaltet wurden; sonst stünde der Hauptschalter auf „an", während nichts
mehr ankommt. Ein Antippen führt in den Kalender auf den Tag der Erinnerung.

Der Plan selbst wird nicht gespeichert: `reminders.dart` rechnet ihn bei jeder
Änderung neu aus dem Bestand (`pendingReminders`, 60 Tage voraus, höchstens
30 Termine je wiederkehrender Aufgabe). Die 30 decken eine tägliche Aufgabe
einen Monat weit ab – neu gestellt wird nur bei einer Änderung oder beim
App-Start, und wer die App eine Woche nicht öffnet, bekäme sonst nichts mehr,
obwohl genau die Erinnerung ihn hineinholen würde. Darüber liegt ein globaler
Deckel von 400 (`maxScheduledReminders`), denn Android lässt pro App nur 500
offene Alarme zu und zwanzig wiederkehrende Aufgaben kämen sonst auf 600.
Abgeschnitten wird am Ende der nach Zeit sortierten Liste: die nächsten
Erinnerungen gewinnen. Verglichen wird **pro Erinnerung**,
und angefasst wird nur, was sich unterscheidet – ein `cancelAll()` risse sonst
auch schon zugestellte Erinnerungen aus der Leiste. Die Läufe sind
serialisiert (`_queue`): zwei gleichzeitige `sync` haben sich sonst gegenseitig
die frisch gestellten Erinnerungen gelöscht. `flutter_local_notifications`
verlangt außerdem Core Library Desugaring – siehe
`android/app/build.gradle.kts`.

Die weiteren Berechtigungen im Release sind READ_CALENDAR und WRITE_CALENDAR
(device_calendar_plus) für die Geräte-Kalender-Ebene. **Joe schreibt nicht** –
es gibt keine Stelle in der App, die einen Geräte-Termin anlegt oder ändert.
WRITE_CALENDAR steht trotzdem im Manifest, weil `device_calendar_plus` zum
*Lesen* die Stufe `full` verlangt und deren Anfrage beide Rechte deklariert
haben will (`PermissionService.checkPermissionsDeclared`); ohne die Zeile
schlägt schon die Berechtigungsanfrage fehl. Wer das nicht will, müsste den
Calendar Provider selbst lesen.

Angefragt wird erst, wenn der Schalter in den Einstellungen umgelegt wird;
abgelehnt heißt: der Schalter bleibt aus, ein Toast verlinkt die
System-Einstellungen. Welche Kalender angezeigt werden, wählt ein Untermenü
darunter (`AppState.deviceCalendarIds`: `null` = alle, auch später
hinzukommende; leer = keiner; gefüllt = genau diese). Gelesen wird nur zur
Anzeige, gespeichert nichts (Monats-Cache nur im Speicher, siehe
`lib/device_calendar.dart`).

Jeder Plugin-Aufruf ist gefangen – auf Plattformen ohne Geräte-Kalender (Web,
Desktop) bleibt die Ebene einfach leer, der Rest der App läuft ungestört.
**Gefangen heißt aber nicht verschwiegen:** ein gescheiterter Abruf landet
nicht mehr als leere Liste dauerhaft im Cache (dann sähe ein Tag ohne Termine
genauso aus wie einer, dessen Termine nicht geladen werden konnten), sondern
setzt einen Fehlerzustand, meldet sich als Toast und stellt eine Hinweiszeile
über das Tagesdetail – mit „Erneut" bzw. „Einstellungen". Beim Start prüft
`checkPermission()` ohne Dialog, ob die einmal erteilte Berechtigung noch
steht.

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

Bei einem Push auf `main` landet das APK zusaetzlich als GitHub-Release unter
dem Tag `joe-todo-v<version>` (Version aus `app/pubspec.yaml`, aktuell
`1.0.3+4` → `joe-todo-v1.0.3+4`). Das Repo enthaelt mehrere Projekte mit einer
gemeinsamen Release-Liste, darum steht der Projektname im Tag. Solange die
Version in `pubspec.yaml` unveraendert bleibt, wird dasselbe Release
ueberschrieben und der Tag auf den neuen Commit gesetzt; fuer einen dauerhaft
abgelegten Stand vorher die Version anheben. Die Releases sind als
Pre-Release markiert, weil es Debug-Builds sind. Aus Pull Requests entsteht
kein Release, dort bleibt es beim Artefakt.

Signiert wird mit demselben Debug-Keystore wie lokal. Das ist kein Detail:
ohne ihn erzeugt jeder Runner beim ersten Gradle-Lauf einen eigenen, jede APK
traegt dann eine andere Signatur, und Android verweigert jedes Update ueber
eine Signaturgrenze hinweg – auch von einem CI-Build auf den naechsten. Die
App liesse sich nur durch Deinstallation ersetzen, und damit waeren To-dos,
Termine und Notizen weg (alles liegt in den SharedPreferences, siehe
`lib/models.dart`). Der Schritt „Debug-Keystore einspielen" entpackt deshalb
das Repository-Secret `JOE_TODO_DEBUG_KEYSTORE` – die base64-kodierte
`~/.android/debug.keystore` – nach `$RUNNER_TEMP` und reicht den Pfad als
`JOE_DEBUG_KEYSTORE` weiter. Angelegt wird das Secret einmalig aus dem
lokalen Keystore:

```powershell
$b64 = [Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))
gh secret set JOE_TODO_DEBUG_KEYSTORE --body $b64
# Oder zum Einfuegen im Browser: Set-Clipboard -Value $b64
```

(Kein `< datei` – PowerShell hat keine Eingabeumleitung, `<` ist dort ein
reserviertes Zeichen.)

Die Variable liest `android/app/build.gradle.kts` im `signingConfigs`-Block.
Den Standardpfad zu ueberschreiben reicht naemlich nicht: AGP sucht den
Debug-Keystore ueber `ANDROID_USER_HOME`, `ANDROID_PREFS_ROOT` und
`ANDROID_SDK_HOME` und erst zuletzt in `user.home` – auf dem Runner greift
eine der vorderen Variablen, eine Datei in `$HOME/.android` blieb schlicht
liegen und AGP legte sich still einen eigenen Schluessel an. Ist
`JOE_DEBUG_KEYSTORE` nicht gesetzt, bleibt es beim Standardverhalten, lokale
Builds merken davon nichts.

Der Schritt „Signatur der APK pruefen" vergleicht danach den Fingerabdruck der
gebauten APK (`apksigner verify --print-certs`) mit dem des Keystores und
laesst den Lauf scheitern, wenn er abweicht. Das ist der eigentliche Nachweis:
dass der Keystore eingespielt wurde, steht im Log, aber ob der Build ihn auch
genommen hat, sieht man nur an der fertigen Datei – sonst faellt es erst auf
dem Telefon auf.

Ist es nicht gesetzt, laeuft der Build weiter (Warnung im Log) und nutzt den
Schluessel des Runners – noetig fuer PRs aus einem Fork, die keine Secrets
bekommen. Passwort und Alias sind die Debug-Standards (`android` /
`androiddebugkey`), das Secret schuetzt also nichts Geheimes, es haelt nur die
Signatur fest. Fuer eine App, die wirklich verteilt wird, gehoert an diese
Stelle ein eigener Release-Keystore.

Die env-Dateien liegen nicht im Repo (siehe „Schalter"). Der Build-Schritt
schreibt `app/env/.env` aus dem Repository-Secret `JOE_TODO_ENV` und haengt
`--dart-define-from-file=env/.env` an; der Inhalt des Secrets ist die ganze
Datei, Zeile fuer Zeile wie lokal:

```
JOE_MOCK_DATA=false
```

Ist das Secret nicht gesetzt, baut derselbe Schritt ohne das Flag, also mit
den Standardwerten aus `lib/env.dart`. Damit laeuft der Workflow auch in einem
PR aus einem Fork (die bekommen keine Secrets) und ohne dass ueberhaupt eines
angelegt sein muss. Gebaut wird ein Debug-APK, das nimmt `env/.env`; sobald
hier einmal ein Release-Build steht, gehoert dort ein zweites Secret fuer
`env/.env.production` hin.

Den Gradle-Cache macht `gradle/actions/setup-gradle`, nicht `setup-java`.
Grund: `setup-java` mit `cache: gradle` schluesselt ueber den Hash der
`*.gradle*`-Dateien und speichert bei einem exakten Treffer gar nicht neu — ein
Build-Cache kann sich so nie fuellen. Damit der ueberhaupt etwas zu speichern
hat, steht `org.gradle.caching=true` (zusammen mit `org.gradle.parallel=true`)
in `app/android/gradle.properties`; Gradles lokaler Build-Cache ist per Default
aus. Der erste Lauf nach einer Aenderung daran ist noch langsam, danach greift
`caches/build-cache-1`.

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
