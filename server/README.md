# joe-sync – Server für geteilte Einkaufslisten

Der Server hinter „Gemeinsam bearbeiten“ in Joe. Er speichert nur
**verschlüsselte** Änderungen. Den Schlüssel trägt der Link hinter dem `#`,
und dieser Teil kommt nie beim Server an. Außerdem liefert der Server die
Webseite für alle, die Joe nicht haben.

Das Konzept steht in
[`plans/geteilte-einkaufslisten/00-konzept.md`](../plans/geteilte-einkaufslisten/00-konzept.md).
Den gemeinsamen Kern (Operationen, Zusammenführung, Kryptografie, Client)
enthält [`packages/joe_sync`](../packages/joe_sync).

## Was der Server sieht

| sieht er | sieht er nicht |
| --- | --- |
| Listen-ID, Operations-IDs, Zeitpunkte | Namen, Einträge, Haken |
| verschlüsselte Blöcke (AES-256-GCM) | den Schlüssel, das Geheimnis aus dem Link |
| Hash des Zugangstokens und des Ersteller-Tokens | den Code |
| IP-Adressen (nur im Speicher, für die Bremsen) | – |

Das Log enthält eine Zeile je Anfrage: Methode, Pfad, Status, Dauer.
Tokens stehen in Köpfen und erscheinen dort nie.

## Schnittstelle

| Methode | Pfad | Zweck |
| --- | --- | --- |
| `PUT` | `/api/lists/<id>` | Anlegen (idempotent), auch Neuanlage nach Datenverlust |
| `GET` | `/api/lists/<id>/meta` | Gibt es die Liste, braucht sie einen Code? Mit Ersteller-Token auch die Frist. Zählt nicht als Zugriff. |
| `GET` | `/api/lists/<id>/ops?after=<seq>` | Neue Operationen, je Antwort höchstens 500 |
| `POST` | `/api/lists/<id>/ops` | Eigene Operationen hochladen (idempotent über die ID) |
| `DELETE` | `/api/lists/<id>` | Für alle löschen, nur mit Ersteller-Token |
| `GET` | `/l/<id>` | Die Webseite |
| `GET` | `/.well-known/assetlinks.json` | Android App Links (wenn eingerichtet) |
| `GET` | `/health` | Für Docker, TrueNAS und dich |

Fehler: `401` falscher Token oder Code, `403` kein Ersteller, `404`
unbekannt, `409` ID schon vergeben, `410` gelöscht oder abgelaufen
(`reason`), `429` gebremst.

## Einstellungen

Alle Einstellungen laufen über Umgebungsvariablen und stehen in `compose.yaml`.

| Variable | Standard | Bedeutung |
| --- | --- | --- |
| `JOE_PORT` | `8080` | Port im Container |
| `JOE_DB` | `/data/joe-sync.db` | SQLite-Datei |
| `JOE_RETENTION_DAYS` | `365` | Ohne Zugriff so lange, dann wird die Liste entteilt |
| `JOE_TRUST_PROXY` | `false` | Hinter Pangolin `true`: IP aus `X-Real-IP` / `X-Forwarded-For` |
| `JOE_ANDROID_FINGERPRINTS` | leer | SHA-256 der App-Signatur für App Links, mit Komma getrennt |
| `JOE_NEW_LISTS_PER_DAY` | `50` | Neue Listen je IP und Tag |
| `JOE_CODE_FAILURES_PER_HOUR` | `10` | Fehlversuche je Liste und IP, bevor gebremst wird (je Liste insgesamt das Zehnfache) |

Die Bremse für Fehlversuche gilt nur für Listen mit Code. Ohne Code hat
das Token 256 Bit, Raten ist dort aussichtslos. Ist eine Liste gebremst,
bekommen auch richtige Tokens eine Stunde lang `429`. Sonst könnte man
weiterraten und nur auf die `200` warten.

## Lokal ausprobieren

```sh
# aus der Wurzel des Repos; JOE_SYNC_PORT, falls 8080 belegt ist
JOE_SYNC_PORT=8787 docker compose -f server/compose.yaml up --build -d
curl http://localhost:8787/health

# ein ganzer Durchgang mit zwei „Geräten“ (teilen, beitreten, Konflikt,
# löschen); mit --keep bleibt die Liste stehen und der Link wird ausgegeben
cd server && dart run tool/smoke.dart http://localhost:8787
```

Ohne Docker geht es auch: `cd server && dart run bin/server.dart`. Die
Datenbank landet dann in `server/data/`.

Für den Android-Emulator ist der Rechner unter `http://10.0.2.2:8787`
erreichbar. Mit `adb reverse tcp:8787 tcp:8787` erreicht ihn der Emulator
auch als `http://localhost:8787`. Das braucht die Webseite im Browser des
Emulators: WebCrypto gibt es nur über HTTPS oder auf `localhost`.

Tests: `cd server && dart test` (Schnittstelle und Abgleich Ende zu Ende,
ohne Netz).

## Auf TrueNAS

1. **Dataset** anlegen, z. B. `tank/apps/joe-sync`. Eigentümer ist der
   Benutzer `apps` (568), weil der Container als 568 läuft.
2. **Repo** auf den NAS holen (z. B. nach `/mnt/tank/apps/src/joe-todo`).
3. In `server/compose.yaml` das Volume auf den Host-Pfad stellen:
   `- /mnt/tank/apps/joe-sync:/data`, `JOE_TRUST_PROXY: "true"` setzen
   und den Port nach Bedarf anpassen.
4. Als **Custom App** (YAML) einspielen oder per Shell aus der Wurzel des
   Repos: `docker compose -f server/compose.yaml up --build -d`. Gebaut
   wird auf dem NAS. Die Tests laufen beim Bauen mit, und ein rotes Image
   entsteht gar nicht erst.
5. **Update**: `git pull`, dann derselbe Befehl.

### Pangolin

- Eine **öffentliche** Ressource für die Sync-Domain, ohne Pangolin-Anmeldung.
  Sonst landen Empfänger des Links auf einer Login-Seite, und Android kann
  die App Links nicht prüfen. Frei sein müssen mindestens `/l/*`, `/api/*`,
  `/assets/*` und `/.well-known/*`.
- Ziel: der Container auf dem gewählten Port.
- HTTPS übernimmt Pangolin. Die Webseite braucht es, weil WebCrypto nur dort
  läuft.

### App Links (später, sobald die Domain feststeht)

Der Fingerabdruck des Debug-Keystores, mit dem CI und `build-debug-apk.ps1`
signieren:

```sh
keytool -list -v -keystore <debug.keystore> -alias androiddebugkey -storepass android
```

Die Zeile `SHA256:` kommt in `JOE_ANDROID_FINGERPRINTS`. Danach prüfen:
`curl https://<sync-domain>/.well-known/assetlinks.json`.

### Backup

Die Speicherung ist nicht redundant. Deshalb:

- **ZFS-Snapshots** des Datasets, z. B. stündlich, 7 Tage aufbewahren.
- Zusätzlich eine Kopie **woandershin**: Cloud-Sync-Task oder Replikation auf
  ein zweites Gerät.
- Die SQLite-Datei läuft im WAL-Modus. Ein Snapshot ist absturzsicher, bei
  der Wiederherstellung kommen `joe-sync.db`, `-wal` und `-shm` zusammen
  zurück.

Geht trotzdem alles verloren, legt das erste Joe, das abgleicht, die Liste
neu an und lädt seinen Stand hoch. Die anderen ergänzen, was ihm fehlte
(Selbstheilung, Konzept 6.4). Wird ein älteres Backup eingespielt, merken
die Geräte das am Stand und gleichen neu ab.

## Version

Der Server zählt eigene Versionen (`pubspec.yaml`, `SyncApi.version`),
unabhängig von der App. `/health` nennt die laufende.
