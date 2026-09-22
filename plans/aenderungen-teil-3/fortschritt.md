# Fortschritt Umsetzung Teil 3 (vom Orchestrator gepflegt)

Worktrees: `C:\Users\Dominik\Projects\Private\wt-teil3\<strang>` (App liegt dort unter `software\joe-todo\app`).
Branches: `teil3/<strang>`. Nach dem Merge einer Welle landen die Branches auf `main` (lokal, kein Push).

## Welle 0
- [x] 0a Fundament (Branch teil3/0a-fundament) – fertig, 5 Commits (Bericht: welle0-bericht.md)
- [x] 0b Kalender-Fix (Branch teil3/0b-kalender) – fertig (c303501)
  - Uebergabe an 1d: test/legibility_test.dart „Kalender: leerer Tag“ haengt vom Datum ab (Mondphase/Feiertag) -> festes Datum
  - Uebergabe an 1b: Ganztagstermine in test/agenda_test.dart lokal statt UTC bauen
  - README (Welle 2): Geraete-Kalender-Abschnitt + Hinweis CI unter UTC
- [x] Merge 0a + 0b nach main (d5185c3), 266 Tests gruen + 1 bekannter Datumsfehler

## Welle 1 (Worktrees wt-teil3\1a..1d, gestartet)
- [ ] 1a Eingabe & Aufgaben (teil3/1a-eingabe)
- [x] 1b Termine & Kalender (teil3/1b-termine) – fertig (37dce84)
  - Uebergabe Welle 2: Endtag „bis HH:MM“ auch fuer Geraete-Termine: device_calendar.dart deviceEventTimeLabel + agenda.dart _deviceEntry (allDay false, when: day, until: end) + device_calendar_test.dart Z.154 'bis 09:00'
  - README: Unterzeile Termine zeigt Spanne; Ende um Mitternacht belegt Folgetag nicht
- [x] 1c Einstellungen (teil3/1c-einstellungen) – fertig (eaf26db, df10d0d, c0bdd4c)
  - Uebergabe Welle 2: ColorDotPicker dotSize/columns/int? selected, Doc „20“ -> 25; settings.dart _PriorityColorSheet FittedBox-Umweg ersetzen
  - Uebergabe Welle 2: PaperCard.build Kind in Material(transparency, radius 16), dann _TileCard in settings.dart durch PaperCard ersetzen
  - Maestro 07_settings_pet.yaml evtl. scrollUntilVisible vor Z.19 und Z.56
  - README: Regler-Details, Prioritaeten-Abschnitt, Einkaufs-Umschalter, settings_test.dart
- [x] 1d Einkaufsliste + legibility-Testfix (teil3/1d-einkauf) – fertig (f250809, f86a488, 9543004)
  - Uebergabe Welle 2 (optional): widgets.dart showTextEntrySheet Parameter emptyMessage, shopping.dart uebergibt „Bitte gib etwas ein.“
  - Maestro-Flows nicht auf Emulator gelaufen
  - README: Reiterreihenfolge, shoppingTabColor, ShoppingList.header, Flows 01–10, Testhinweis legibility
- [x] 1a Eingabe & Aufgaben – fertig (3d21baf, 8fee54a, 4f08f12, f6b9e73), keine Uebergaben
- [x] Merge 1a–1d nach main (d2f49ad): analyze sauber, 328 Tests gruen

## Welle 2 (zwei Straenge: 2c Uebergaben in wt-teil3\2c, 2r README in wt-teil3\2r)
- [x] 2c Code-Uebergaben – fertig, Maestro 01–10 gruen auf Emulator
- [x] Merge nach main (38bb620): analyze sauber, 334 Tests gruen, Debug-APK gebaut; Strang-Branches geloescht
- [ ] Version + README-CI-Satz, dann Push – wartet auf Benutzer
- [x] 2r README (Branch teil3/2-readme) – fertig (1a50d7b); README-CI-Satz „aktuell 1.1.0+5“ beim Versionssprung mit anpassen
- Emulator Maestro_ANDROID_pixel_6_android-33 laeuft (emulator-5554)
- [ ] Reste wt-teil3\1c und \1d loeschen (war gesperrt), git worktree prune
- [ ] README
- [ ] Gesamtpruefung (analyze, test, build-debug-apk)
- [ ] Version (Rueckfrage beim Benutzer!) und Push erst nach Okay

## Wiederaufnahme nach Usage-Limit
Stand der Branches mit `git log main..teil3/<strang>` pruefen. Ein Strang, der
nicht fertig ist, wird mit demselben Auftrag neu gestartet und macht ab dem
letzten Commit weiter (Plan-Schritte mit Commit gelten als erledigt).
