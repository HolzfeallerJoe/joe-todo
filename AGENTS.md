# AGENTS.md — joe-todo

Was hier steht, gilt für alle Arbeiten in `software/joe-todo`. Wie die App
gebaut ist, steht in [README.md](README.md).

## Vor jedem Push: Versionsnummer anheben

**Regel: Kein Push auf `main`, ohne vorher `version:` in `app/pubspec.yaml`
anzuheben.**

Warum das nicht bloß Kosmetik ist: `.github/workflows/joe-todo-apk.yml` liest
die Version aus der pubspec und baut daraus Tag und Release
(`joe-todo-v1.0.3+4`). Gibt es den Tag schon, **löscht der Workflow das
vorhandene Release samt Tag und legt es neu an** — der alte Stand ist dann
weg, samt seinem APK. Nur eine neue Versionsnummer erzeugt ein Release
*neben* dem alten.

Format ist `version: <build-name>+<build-number>`, zum Beispiel `1.0.3+4`:

- Die **build-number** (hinter dem `+`) steigt bei jedem Push um genau 1.
  Android vergleicht sie beim Update, sie darf nie zurückgehen und nie
  gleich bleiben.
- Der **build-name** (vor dem `+`) folgt semantischer Versionierung:
  Patch für Fehlerbehebungen und Kleinigkeiten, Minor für neue Funktionen,
  Major für einen Bruch.

Eine Erhöhung pro Push genügt — mehrere Commits, die zusammen gepusht
werden, teilen sich eine Version. Die Anhebung gehört in den letzten
Commit vor dem Push, nicht in einen eigenen.

**Bei Unsicherheit den Benutzer fragen, auf welche Version angehoben werden
soll**, statt selbst zu raten. Unsicher heißt zum Beispiel: die Änderung
liegt zwischen Fehlerbehebung und neuer Funktion, sie ändert gespeicherte
Daten, oder es ist nicht klar, ob der letzte Stand schon veröffentlicht ist.
Zwei Zeilen Rückfrage kosten weniger als ein überschriebenes Release.

## Vor dem Push ebenfalls grün

- `flutter analyze` ohne Befund
- `flutter test` vollständig grün

Beides läuft in der CI noch einmal; scheitert dort etwas, entsteht kein
Release, und der letzte veröffentlichte Stand bleibt der alte.
