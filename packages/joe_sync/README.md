# joe_sync

Der gemeinsame Kern der geteilten Einkaufslisten, reines Dart. Ihn benutzen
Joe (`app/`) und der Server (`server/`). Die Webseite (`server/web/`)
rechnet dasselbe in JS nach. Die Testvektoren in `test/vectors/` halten
beide Fassungen auf denselben Bytes und demselben Ergebnis.

Das Konzept steht in
[`plans/geteilte-einkaufslisten/00-konzept.md`](../../plans/geteilte-einkaufslisten/00-konzept.md).

| Datei | Inhalt |
| --- | --- |
| `lib/src/crypto.dart` | HKDF, Zugangstoken, AES-256-GCM (genaue Festlegung im Kopf der Datei) |
| `lib/src/link.dart` | Link `<server>/l/<id>#<geheimnis>` erzeugen und in Text finden |
| `lib/src/op.dart` | Operationen im Klartext |
| `lib/src/merge.dart` | Zusammenführung mit Konflikten (`SharedListState`) |
| `lib/src/share_state.dart` | Was ein Gerät je geteilter Liste aufbewahrt |
| `lib/src/client.dart` | Abgleich mit dem Server: teilen, beitreten, abgleichen, löschen |
| `lib/src/wire.dart` | Hülle auf der Leitung, Grenzen |

## Abweichungen vom Konzept

- **`base` nennt Operations-IDs statt `seq`.** Damit kann eine Änderung auch
  auf einer eigenen, noch nicht hochgeladenen Operation aufbauen (Konzept 5.4,
  „eigene Änderungen gelten als gesehen“). Die Reihenfolge legt weiter allein
  die `seq` des Servers fest.
- **Abhaken hält Löschen nicht auf.** Als Änderung gegen Löschen zählt nur
  ein geänderter Titel. Wer einen Eintrag abhakt, während ihn jemand löscht,
  will dasselbe: Er ist erledigt.
- **`item.restore` gibt es nicht.** „Mit meiner Änderung behalten“ erledigt
  `conflict.resolve` mit `keep: mine`.

## Tests

```sh
dart test
# Kryptografie-Vektoren neu erzeugen (nur bei Formatänderung), mit WebCrypto:
node tool/crypto_vectors.mjs > test/vectors/crypto.json
```
