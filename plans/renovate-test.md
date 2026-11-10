# Renovate ausprobieren

Dieser Versuch liegt auf `test/renovate`, ausgehend vom vorhandenen Stand
von `feature/geteilte-einkaufslisten`. `renovate.json` ist die eigentliche
Bot-Konfiguration. `test-renovate.ps1` startet lokale Pruefungen mit der
festen Renovate-Version `44.226.2`.

## Lokal starten

Voraussetzung ist Node.js mit npm/npx. Fuer die verwendete Renovate-Version
gilt Node `^24.11.0 || ^26.13.0`. npx laedt Renovate beim ersten Aufruf in
seinen Cache. Eine Installation als Projekt-Abhaengigkeit ist nicht noetig.

Im Repository in PowerShell ausfuehren:

```powershell
# Konfiguration einschliesslich veralteter Optionen pruefen.
.\test-renovate.ps1

# Nur Paketdateien und vorhandene Abhaengigkeiten erkennen.
.\test-renovate.ps1 -Mode extract

# Zusaetzlich verfuegbare Versionen bei den Registries abfragen.
$env:LOG_LEVEL = 'debug'
try {
    .\test-renovate.ps1 -Mode lookup
}
finally {
    Remove-Item Env:LOG_LEVEL -ErrorAction SilentlyContinue
}
```

Die lokale Plattform erstellt keine Branches, Commits, Issues oder PRs.
Sie ignoriert `baseBranchPatterns` und untersucht den aktuellen Checkout.
In Git-Repositories werden nur getrackte Dateien erfasst. Neu angelegte
Dateien muessen vor dem Test mindestens mit `git add` aufgenommen werden.
`extract` prueft keine verfuegbaren Updates; `lookup` prueft keine Builds
und erzeugt keine neuen Lockfiles. Fuer manche Quellen, darunter
GitHub-Actions und Flutter-Releases, verlangt Renovate einen GitHub-Token
und ueberspringt die Versionsabfrage ohne ihn. Ein optionaler Token gehoert
in die Prozessumgebung `RENOVATE_TOKEN`, niemals in die Konfiguration.

## Ergebnis des lokalen Versuchs

Am 10.11.2026 unter Windows mit Node 24.12.0 und Renovate 44.226.2 geprueft:

- Die Repository-Konfiguration besteht `renovate-config-validator --strict --no-global`.
- `extract` und `lookup` laufen mit Exitcode 0 durch. Renovate erkennt
  47 Abhaengigkeitseintraege in 11 Dateien. Dazu gehoeren auch lokale
  oder uebersprungene Eintraege, nicht 47 aktualisierbare Pakete.
- Die Versionssuche findet unter anderem Updates fuer Dart-Pakete, AGP,
  Kotlin und Gradle. Es wurden keine Abhaengigkeiten aktualisiert.
- GitHub-Quellen werden ohne Token teilweise uebersprungen.
- Das optionale native Modul `re2` ist hier nicht verfuegbar. Renovate
  meldet den Rueckfall auf JavaScript-RegExp. Die Regex-Pruefung kann damit
  vom Verhalten auf einem Linux-Runner mit RE2 abweichen.

Builds, die Erstellung neuer Lockfiles und echte GitHub-PRs waren nicht
Teil dieser lokalen Pruefung. Bestehende App- und Serverdateien sowie
die Release-Workflows bleiben unveraendert.

## Was erfasst wird

| Manager | Dateien und Zweck |
| --- | --- |
| `pub` | `app/pubspec.yaml`, `server/pubspec.yaml`, `packages/joe_sync/pubspec.yaml`, samt vorhandenen Lockfiles bei echten Updates |
| `gradle` | Android-Plugins, unter anderem AGP und Kotlin in `app/android/settings.gradle.kts` |
| `gradle-wrapper` | Gradle-Version in `app/android/gradle/wrapper/gradle-wrapper.properties` |
| `github-actions` | Action-Referenzen und unterstuetzte Runtime-Eingaben in `.github/workflows/` |
| `dockerfile` | Dart- und Debian-Basisimages in `server/Dockerfile` |

Lokale `path`-Abhaengigkeiten wie `joe_sync` haben keine Registry-Version.
Der Gradle-Plugin-Loader `dev.flutter.flutter-plugin-loader` kommt per
`includeBuild` aus dem Flutter-SDK. Seine eigenstaendige Aktualisierung
ist deshalb ausdruecklich deaktiviert.
`server/web/package.json` enthaelt derzeit keine npm-Abhaengigkeiten.
Der npm-Manager ist deshalb nicht aktiviert. `server/compose.yaml` benutzt
das lokal gebaute Image `joe-sync:local`; dafuer ist ebenfalls kein
Update-Manager aktiviert.

Flutter, Dart, AGP, Kotlin, Gradle und Java muessen weiterhin zusammenpassen.
Eine Gruppierung prueft diese Kompatibilitaet nicht. Bei SDK-Updates auch
die lokal installierten SDKs, Workflow-Eingaben und das Dockerfile abgleichen.

## Einstellungen im Versuch

| Option | Aktuell | Zum Ausprobieren |
| --- | --- | --- |
| `baseBranchPatterns` | Nur `test/renovate` | Spaeter bewusst auf den gewuenschten Zielbranch umstellen |
| `branchPrefix` | `renovate-test/` | Trennt Test-Updatebranches von normalen Renovate-Branches |
| `dependencyDashboardApproval` | `true` | Im Dashboard einzelne Updates freigeben; `false` erlaubt automatische PR-Erstellung |
| `automerge` | `false` | Updates von Hand pruefen und mergen |
| `prConcurrentLimit` | `3` | Maximale Zahl gleichzeitig offener regulaerer PRs |
| `prHourlyLimit` | `2` | Hoechstens zwei neue regulaere PRs pro Stunde |
| `packageRules` | Minor/Patch nach Bereich gruppiert | `groupName` entfernen fuer einzelne PRs; Major-Updates bleiben separat |
| `rangeStrategy` fuer Dart-Pakete | `bump` | Hebt auch Untergrenzen wie `^1.2.0` auf die neue Version an |
| `lockFileMaintenance.enabled` | `false` | Spaeter `true` fuer eigene PRs zur regelmaessigen Lockfile-Erneuerung |
| `vulnerabilityAlerts.enabled` | `false` | Im Versuch aus, da Sicherheits-PRs sonst die Dashboard-Freigabe umgehen koennen |

Es gibt absichtlich kein Zeitfenster, damit der Versuch nicht auf den
naechsten geplanten Termin warten muss. Ein moeglicher spaeterer Zusatz
auf oberster Ebene ist `"schedule": ["* 8-10 * * 1"]`, montags von
08:00 bis 11:00 Uhr in `Europe/Berlin`. Der Bot muss innerhalb dieses
Fensters laufen; `schedule` startet ihn nicht selbst.

## Echte GitHub-PRs als naechster Schritt

Die Dateien im lokalen Branch allein aktivieren keinen Bot. Ein Push und
eine Renovate-Installation beziehungsweise ein eigener Runner fehlen noch.

Der einfachste gehostete Weg ist die
[Renovate GitHub App](https://github.com/apps/renovate), auf das Repository
`HolzfeallerJoe/joe-todo` beschraenkt. Renovate liest die Konfiguration
normalerweise vom Standardbranch. Nur `test/renovate` zu pushen reicht
deshalb fuer diesen Weg nicht aus.

Fuer einen spaeter autorisierten Test mit der App:

1. Den Testbranch pushen und die App fuer dieses Repository installieren.
2. Im Onboarding-PR die Konfiguration aus `renovate.json` verwenden und
   `baseBranchPatterns: ["test/renovate"]` beibehalten. Beim Uebernehmen
   auf den Standardbranch die dortigen Versions- und Release-Regeln beachten.
3. Nach dem Onboarding sollte Renovate ein Dependency-Dashboard als
   GitHub-Issue anlegen. GitHub Issues muessen dafuer aktiviert sein.
4. Im Dashboard ein kleines Update freigeben. Dessen PR muss
   `test/renovate` als Ziel haben. CI pruefen und von Hand mergen.

Wer auch die Konfiguration auf dem Standardbranch vermeiden will, kann
stattdessen Renovate selbst betreiben und die Testkonfiguration als
Runner-Konfiguration laden. Dafuer sind zusaetzlich ein GitHub-Token oder
eine eigene GitHub App und eine explizite Repository-Auswahl erforderlich.
Dieser Versuch richtet keinen schreibenden Runner ein.

Vor jedem spaeteren Merge nach `main` gelten die Release-Regeln aus
`AGENTS.md`. Der APK-Workflow veroeffentlicht bei Pushes auf `main`;
App-Version und Buildnummer muessen vorher erhoeht werden. Renovate
uebernimmt diese projektspezifische Versionierung hier nicht.

## Quellen

- [Konfigurationsoptionen](https://docs.renovatebot.com/configuration-options/)
- [Lokale Plattform und ihre Grenzen](https://docs.renovatebot.com/modules/platform/local/)
- [Konfiguration validieren](https://docs.renovatebot.com/config-validation/)
- [Installation und Onboarding](https://docs.renovatebot.com/getting-started/installing-onboarding/)
- [Dart/pub-Unterstuetzung](https://docs.renovatebot.com/modules/manager/pub/)
