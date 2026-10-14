# Update-Prüfung – Plan

Stand: 14.10.2026, nach Version `1.3.0+7`. Nur als Plan abgelegt, die
Umsetzung ist noch nicht beauftragt.

Vor jeder Arbeit lesen: [`AGENTS.md`](../../AGENTS.md) (Versionsregel,
analyze/test grün) und [`README.md`](../../README.md) (wie die App gebaut ist).

---

## 1. Ziel

Kurz nach dem Start fragt Joe **einmal** auf GitHub nach, ob es ein neueres
Release gibt. Wenn ja, erscheint ein Hinweis mit:

- **„Jetzt updaten“**
- **„Abbrechen“**
- darunter ein Kästchen **„Diese Version überspringen“**: Für genau diese
  Version fragt Joe nicht mehr nach. Erst bei einer noch neueren Version kommt
  der Hinweis wieder.

## 2. Vorgaben des Benutzers

| # | Vorgabe |
| --- | --- |
| U1 | Prüfung einmal kurz nach dem Start. |
| U2 | Hinweis mit „Jetzt updaten“ und „Abbrechen“, darunter „Diese Version überspringen“. |
| U3 | Einstellung **„Nach Updates suchen“**, ab Werk **an**. |
| U4 | „Jetzt updaten“ hat zwei Wege, umschaltbar in den Einstellungen. **Standard: Der Browser lädt das APK.** Eingeschaltet: **Joe lädt das APK selbst und startet die Installation.** |
| U5 | **Kein Changelog** für den Anfang, nur als Idee notiert (Abschnitt 8). |

## 3. Entscheidungen – bitte vor dem Start prüfen

| ID | Entscheidung |
| --- | --- |
| D1 | Der Hinweis ist ein **Blatt in der App**, keine native Benachrichtigung. Eine Systembenachrichtigung kann kein Kästchen tragen (U2), und die Prüfung läuft ohnehin nur, während Joe offen ist. |
| D2 | Das Blatt erscheint erst, wenn das Dashboard steht (ein paar Sekunden nach dem Start), nicht über dem Startbildschirm. Pro Kaltstart höchstens einmal. |
| D3 | **Vergleich über die Build-Nummer** (hinter dem `+`). Sie steigt laut AGENTS.md bei jedem Release um genau 1 und geht nie zurück, ist also der verlässliche Zähler. Der Build-Name (`1.4.0`) steht nur im Text. |
| D4 | **„Diese Version überspringen“** speichert die Build-Nummer. Gefragt wird wieder, sobald es eine **höhere** gibt. Das Kästchen wirkt nur mit „Abbrechen“ (oder Wegwischen). Wer „Jetzt updaten“ tippt, will diese Version ja. |
| D5 | Fehler (kein Netz, GitHub nicht erreichbar, Limit erreicht, unerwartete Antwort) bleiben **still**: nur ein Log-Eintrag, kein Toast. Ein Update-Hinweis, der beim Start meckert, nervt mehr, als er nützt. |
| D6 | Das Blatt nennt die **Größe des APK** aus den Release-Daten („ca. 166 MB“), damit niemand es unterwegs über mobile Daten lädt, ohne es zu wissen. |

## 4. Was es dafür auf GitHub gibt (geprüft am 14.10.2026)

- Das Repo `HolzfeallerJoe/joe-todo` ist **öffentlich**. Die API braucht also
  keinen Token. Das Limit ohne Token sind 60 Anfragen je Stunde und IP, für
  eine Anfrage pro Start reicht das.
- Alle Releases sind als **Vorabversion** (`prerelease`) markiert, weil es
  Debug-Builds sind. `GET /releases/latest` **übergeht Vorabversionen** und
  liefert deshalb nichts Brauchbares. Joe fragt stattdessen
  `GET https://api.github.com/repos/HolzfeallerJoe/joe-todo/releases?per_page=10`
  und nimmt daraus:
  - nur Releases mit Tag `joe-todo-v<name>+<build>`, ohne Entwürfe (`draft`),
  - das mit der **höchsten Build-Nummer**,
  - davon das Asset, dessen Name auf `.apk` endet (heute
    `joe-todo-v1.3.0+7-debug.apk`), mit `browser_download_url` und `size`.
- Jedes Release ist mit **demselben Debug-Keystore** signiert (Secret
  `JOE_TODO_DEBUG_KEYSTORE`, siehe README). Ein neues APK lässt sich also über
  das installierte legen, ohne Deinstallation.

## 5. Umsetzung in Joe

### 5.1 Daten (in `joe_data_v1`, gespeicherte Daten ändern sich)

| Feld | Standard | Bedeutung |
| --- | --- | --- |
| `updateCheckEnabled` | `true` | U3 |
| `updateInApp` | `false` | U4: `false` = Browser, `true` = Joe lädt und installiert |
| `skippedUpdateBuild` | `null` | D4 |

### 5.2 Neue Bausteine

- `lib/update_check.dart`, plugin-frei und prüfbar wie `agenda.dart`:
  - Tags parsen (`joe-todo-v1.4.0+8` → Name `1.4.0`, Build `8`), Unbrauchbares
    überspringen.
  - Aus der Release-Liste das neueste nehmen (4).
  - Entscheiden, ob gefragt wird: neuer als die eigene Build-Nummer **und**
    neuer als `skippedUpdateBuild`.
  - Der HTTP-Zugriff kommt von außen herein, damit Tests ihn ersetzen können.
- **Eigene Version** über `package_info_plus` (neue Abhängigkeit). Die
  Alternative wäre, die Version beim Bauen per `--dart-define` hineinzureichen.
  Das wäre eine zweite Quelle neben `pubspec.yaml`, die auseinanderlaufen
  könnte.
- **HTTP** über `http` (neue Abhängigkeit).
- **Blatt** `showUpdateSheet` im Stil der bestehenden Blätter (`showJoeSheet`):
  Überschrift „Neue Version verfügbar“, Text „Joe 1.4.0 ist da, du hast
  1.3.0. Download ca. 166 MB.“, dann die zwei Knöpfe, darunter das Kästchen
  (U2).
- **Einstellungen**: neuer Abschnitt „Updates“ mit
  - Schalter „Nach Updates suchen“ (U3),
  - Schalter „Update in Joe installieren“, Untertitel „Aus: der Browser lädt
    das APK“ (U4). Nur aktiv, wenn der erste an ist.

### 5.3 „Jetzt updaten“, Weg 1: Browser (Standard)

`browser_download_url` des APK im Browser öffnen (`url_launcher`, neue
Abhängigkeit, oder ein kleiner Intent über den vorhandenen Kotlin-Teil). Der
Browser lädt, Android bietet die Installation aus den Downloads an. Keine
zusätzliche Berechtigung.

### 5.4 „Jetzt updaten“, Weg 2: Joe installiert selbst

- Herunterladen in den Cache (`path_provider`, ist schon da), mit
  Fortschrittsanzeige im Blatt und „Abbrechen“.
- Prüfen, dass die Größe zur Angabe aus der Release-Liste passt. Die
  SHA-256-Prüfsumme (`digest` in den Asset-Daten, heute vorhanden) wird
  ebenfalls verglichen. Eine Datei, die nicht passt, wird gelöscht und nicht
  installiert.
- Installation über einen eigenen kleinen **MethodChannel** im Kotlin-Teil
  (Vorbild: `joe/home_widget` in `lib/home_widget.dart`): `FileProvider` +
  `ACTION_VIEW` mit `application/vnd.android.package-archive`, oder
  `PackageInstaller`. Ein Fremd-Plugin wie `ota_update` ginge auch, wäre aber
  eine Abhängigkeit mehr für wenige Zeilen.
- Manifest: `REQUEST_INSTALL_PACKAGES`, `FileProvider` mit Pfad auf den Cache.
- Beim ersten Mal schickt Android den Nutzer in „Unbekannte Apps installieren“
  für Joe. Joe erklärt das vorher in einem Satz und prüft danach
  (`canRequestPackageInstalls`), ob die Erlaubnis da ist.
- Der Download geht verloren, wenn Joe währenddessen beendet wird. Das ist
  hinnehmbar: Beim nächsten Start kommt der Hinweis wieder.

### 5.5 Netz und README

- **INTERNET** gehört dann ins Haupt-Manifest. Der Plan für geteilte Listen
  (`plans/geteilte-einkaufslisten/00-konzept.md`, 6.3) braucht dasselbe. Wer
  zuerst fertig ist, trägt es ein.
- Der README-Grundsatz „Die App spricht nicht ins Netz“ bekommt eine Ausnahme:
  Bei eingeschalteter Update-Prüfung **eine Anfrage an GitHub pro Start**. Es
  werden keine Daten aus Joe gesendet, GitHub sieht nur IP-Adresse und
  User-Agent.
- Das Log nennt Ergebnis und Versionen, sonst nichts.

## 6. Tests

- `update_check_test.dart`: Tags parsen (gültig, fremd, kaputt); neuestes
  Release wählen (Entwürfe, fremde Tags, fehlendes APK); Fragen ja/nein
  (gleich, älter, neuer, übersprungen, neuer als übersprungen); Fehler bleiben
  still.
- Persistenz der drei Felder samt Standardwerten und Unsinn (wie die anderen
  Einstellungen in `persistence_test.dart`).
- Blatt: Knöpfe, Kästchen, Überspringen nur mit „Abbrechen“, Größenangabe.
- Einstellungen: zweiter Schalter nur aktiv, wenn der erste an ist.
- Weg 2 auf dem Emulator von Hand: altes APK installieren, neues als Release,
  Update durchspielen. Maestro kann den System-Installationsdialog nicht
  zuverlässig bedienen.

## 7. Umfang und Version

Weg 1 ist klein: Prüfung, Blatt, zwei Einstellungen. Weg 2 ist der größere
Teil: Download, Prüfsumme, Kotlin-Kanal, Berechtigung, Fehlerfälle. Beides
zusammen ist eine Minor-Version, weil sich gespeicherte Daten ändern
(AGENTS.md: vorher nachfragen).

Gearbeitet wird auf dem Branch `feature/update-pruefung`. Releases entstehen
erst beim Zusammenführen nach `main`.

## 8. Ideen für später

- **Changelog** (U5, vorerst draußen): Die CI schreibt die Commit-Überschriften
  seit dem letzten Release in den Release-Text (heute stehen dort nur Version,
  Build-Art und Commit). Joe zeigt sie im Update-Blatt hinter einem Knopf
  „Was ist neu?“, der sie erst auf Tipp aufklappt. Die Commit-Nachrichten im
  Repo sind ohnehin auf Deutsch und für Menschen geschrieben.
- Prüfung zusätzlich von Hand in den Einstellungen („Jetzt nach Updates
  suchen“).
