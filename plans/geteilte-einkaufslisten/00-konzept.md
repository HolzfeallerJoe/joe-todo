# Geteilte Einkaufslisten – Konzept

Stand: 14.10.2026, nach Version `1.3.0+7` (mehrere Listen, „Liste teilen“ als
Text). Dieses Dokument beschreibt die **gemeinsame Live-Liste**: Mehrere
Personen bearbeiten dieselbe Einkaufsliste, jede auf ihrem Gerät oder im
Browser.

Vor jeder Arbeit lesen: [`AGENTS.md`](../../AGENTS.md) (Versionsregel,
analyze/test grün) und [`README.md`](../../README.md) (wie die App gebaut ist).

---

## 1. Vorgaben des Benutzers

| # | Frage | Antwort |
| --- | --- | --- |
| V1 | Mit wem wird geteilt? | Mit **beliebigen Personen**, je Liste. |
| V2 | Brauchen alle Joe? | Nein, **alle** sollen mitmachen können, auch ohne App. |
| V3 | Server | **Eigener Server**: TrueNAS mit Docker, erreichbar über eine eigene Domain hinter **Pangolin**. Die Datenspeicherung dort ist **nicht redundant**. |
| V4 | Netz | Joe bleibt **so offline wie möglich**. Online geht er nur, wenn eine **geteilte Liste geöffnet** ist: Änderungen holen, eigene hochladen. |
| V5 | Zugang | Ein **Link** reicht. Zusätzlich ein **Code**, als Einstellung beim Teilen. |
| V6 | Verschlüsselung | **Ja**, Ende-zu-Ende. |
| V7 | Plattformen | **Nur Android.** iPhone-Nutzer machen über die Webseite mit, eine iOS-App gibt es nicht. |
| V8 | Sprache des Servers | Egal. |
| V9 | Gleichzeitige Änderungen | **Wie in ABC-Todo**: feldweise zusammenführen, echte Konflikte entscheidet der Nutzer, Löschen ist weich und bei Konflikt ebenfalls eine Nutzerentscheidung (siehe 5.4). |
| V10 | Lange ungenutzte Listen | Werden **nicht gelöscht, sondern entteilt**. Vorher und dann gibt es eine **native Benachrichtigung**, nicht nur einen Hinweis in der App (siehe 6.6). |
| V11 | Docker-Image | Baut der Benutzer **selbst auf TrueNAS**. Kein veröffentlichtes Image, das Dockerfile liegt nur im Repo. |
| V12 | Pangolin | Die Sync-Ressource darf **öffentlich** sein, ohne Pangolin-Anmeldung. |
| V13 | Wer wird benachrichtigt? | **Nur wer geteilt hat** (der Ersteller) bekommt die Benachrichtigungen zum Entteilen. |
| V14 | Benachrichtigung „nicht mehr geteilt“ | **Variante B**: Kurz vor Ablauf fragt Joe einmal beim Server nach und benachrichtigt nur, wenn die Liste wirklich abläuft. |
| V15 | Konflikte | Die Regelung aus 5.4 (entscheiden muss, wessen Änderung später ankam; offene Konflikte blockieren nichts und verfallen nach 30 Tagen) ist **bestätigt**. |

---

## 2. Das Bild im Ganzen

```
 Joe (Android)                Server (TrueNAS, Docker)            Browser
 ─────────────                ────────────────────────            ───────
 Liste lokal, vollständig     speichert nur verschlüsselte        Webseite vom selben
 eigene Änderungen als   ⇄    Änderungen + IDs + Zeitpunkte   ⇄   Server, entschlüsselt
 Operationen (Warteschlange)  liefert die Webseite aus             im Browser
                              Pangolin davor (HTTPS)
```

Grundsätze:

1. **Lokal zuerst.** Jede geteilte Liste liegt in Joe vollständig auf dem Gerät,
   wie heute. Abhaken und Ergänzen gehen ohne Netz. Was offline geändert wird,
   wartet in einer Warteschlange und geht beim nächsten Abgleich hoch.
2. **Änderungen statt Zustände.** Übertragen werden einzelne **Operationen**
   („Eintrag X angelegt“, „X abgehakt“, „X gelöscht“, „Liste umbenannt“), nie
   die ganze Liste. Zwei Personen, die gleichzeitig verschiedene Einträge
   ändern, kommen sich so nicht in die Quere.
3. **Der Server kann nichts lesen.** Der Schlüssel steht im Link hinter dem
   `#`. Diesen Teil schicken Browser und App nie an den Server. Der Server
   sieht nur Listen-ID, Operations-IDs, Zeitpunkte und verschlüsselte Blöcke.
4. **Die Geräte sind das Backup.** Weil jedes beteiligte Gerät die ganze Liste
   hat, ist ein Totalausfall des Servers kein Datenverlust. Joe kann eine Liste,
   die der Server nicht mehr kennt, neu hochladen (siehe 6.4). Ein Backup des
   Servers gibt es trotzdem (siehe 7.3).

---

## 3. Entscheidungen – bitte vor dem Start prüfen

Wo die Vorgaben offen sind, habe ich gewählt. Wer etwas anders will, ändert es
**hier**, bevor die Umsetzung beginnt.

| ID | Entscheidung |
| --- | --- |
| G1 | **Server in Dart** (`shelf` + SQLite). App und Server teilen sich dann ein reines Dart-Paket mit Operationen, Zusammenführung und Kryptografie. Eine einzige Implementierung heißt: keine zwei Lesarten desselben Formats. |
| G2 | **Ein Repo**: Paket, Server und Webseite liegen in `joe-todo` neben `app/` (siehe 8). |
| G3 | **Link-Format** `https://<sync-domain>/l/<listen-id>#<geheimnis>`. Listen-ID: 16 Zufallsbytes, Geheimnis: 32 Zufallsbytes, beide base64url. |
| G4 | **Code** (Einstellung beim Teilen): 6 Ziffern, von Joe erzeugt und angezeigt. Er wird getrennt vom Link weitergegeben. Der Server prüft ihn, ohne ihn zu kennen (siehe 4.2), und bremst Rateversuche. |
| G5 | **Ersteller-Rechte**: Nur wer die Liste geteilt hat, kann sie **für alle löschen** und den **Link erneuern**. Alle anderen können sie für sich **verlassen**. |
| G6 | **Verlassen** heißt: Die Liste bleibt als gewöhnliche lokale Liste stehen und gleicht nicht mehr ab. Löschen kann man sie danach wie jede Liste. |
| G7 | **Abgleich nur bei offener Liste** (V4): beim Öffnen, danach alle **15 Sekunden**, solange sie sichtbar ist und Joe im Vordergrund läuft, außerdem 1–2 Sekunden nach einer eigenen Änderung und per Herunterziehen. **Kein** Hintergrund-Abgleich, keine Push-Nachrichten. |
| G8 | **Konflikte nach ABC-Todo** (V9, Einzelheiten in 5.4): Jede Änderung nennt die Version, die sie gesehen hat. Verschiedene Felder werden zusammengeführt. Dasselbe Feld mit **verschiedenem** Wert oder Löschen gegen Bearbeiten ist ein Konflikt. Entscheiden muss, **wessen Änderung später beim Server ankam** (wie die 409-Antwort in ABC-Todo). Bis dahin gilt für alle der Stand, der zuerst ankam. |
| G9 | **Entteilen nach 12 Monaten** (V10, Einzelheiten in 6.6): Hat 12 Monate niemand die Liste abgeglichen (Joe oder Webseite), wird sie entteilt. Der Server verwirft seine verschlüsselten Daten und merkt sich nur „abgelaufen“. In Joe bleibt die Liste als lokale Liste stehen. **Beim Ersteller** (V13) gibt es 14 Tage vorher und beim Entteilen eine native Benachrichtigung, die zweite erst nach einer Nachfrage beim Server (V14). Der Zeitraum ist auf dem Server einstellbar. |
| G10 | **Grenzen**: Operation höchstens 4 KB, höchstens 500 Operationen je Anfrage, höchstens 50 neue Listen je IP und Tag, Fehlversuche beim Code gebremst (z. B. 10 je Stunde und Liste). |
| G11 | **Docker** (V11): Dockerfile und `compose.yaml` liegen im Repo, gebaut wird auf TrueNAS. Die CI testet nur, sie baut und veröffentlicht kein Image. Der Server bekommt eigene Versionsnummern, unabhängig von der App. |
| G13 | **Gleicher Wert ist kein Konflikt**: Haken zwei Personen denselben Eintrag gleichzeitig ab oder geben ihm denselben Titel, gibt es nichts zu entscheiden. |
| G14 | **Keine Uhrzeiten zum Ordnen**: Die Reihenfolge legt allein die laufende Nummer des Servers fest (`seq`). Falsch gehende Geräteuhren spielen keine Rolle. |
| G12 | Geteilt wird weiter auch **als Text** (wie in 1.3.0). Das Teilen-Blatt bietet dann beides an: „Als Text senden“ und „Gemeinsam bearbeiten“. |

---

## 4. Kryptografie

### 4.1 Schlüssel

Aus dem Geheimnis `S` (32 Bytes aus dem Link) leiten App und Webseite mit
**HKDF-SHA256** zwei Werte ab. Als Salt dient die Listen-ID:

| Wert | Ableitung | Wozu |
| --- | --- | --- |
| `K` | HKDF(S, info=`joe-v1-key`) | AES-256-GCM-Schlüssel für die Operationen |
| `A` | HKDF(S ‖ Code oder leer, info=`joe-v1-access`) | Zugangstoken, geht als `Authorization: Bearer` an den Server |

Der Server speichert nur `SHA-256(A)`. Aus `A` lässt sich `K` nicht berechnen,
der Server kann also mit dem, was er sieht, nichts entschlüsseln.

### 4.2 Code

Der Code fließt nur in `A` ein. Wer den Link hat, aber nicht den Code, rechnet
ein falsches `A` aus und bekommt `401`. Raten geht nur über den Server, und
der bremst (G10). Der Server erfährt den Code nie.

### 4.3 Ersteller

Wer teilt, erzeugt zusätzlich ein Ersteller-Geheimnis `O`. Es bleibt nur auf
diesem Gerät, der Server kennt `SHA-256(HKDF(O))`. Damit sind Löschen-für-alle
und Link-erneuern abgesichert (G5).

### 4.4 Operationen

Jede Operation ist JSON und wird mit AES-256-GCM verschlüsselt: zufälliger
96-Bit-Nonce, als zusätzliche Daten (AAD) Listen-ID und Operations-ID. So lässt
sich ein Block nicht in eine andere Liste oder unter eine andere ID schieben.
Gespeichert wird `base64(nonce ‖ ciphertext)`.

### 4.5 Bibliotheken

- Dart (App und Server): Paket `cryptography` (HKDF, AES-GCM).
- Browser: **WebCrypto** (`crypto.subtle`, HKDF und AES-GCM eingebaut, braucht
  HTTPS; Pangolin liefert das).
- **Testvektoren**: eine JSON-Datei mit festen Eingaben und erwarteten
  Ausgaben. Sie wird in den Dart-Tests und in einem kleinen JS-Test (Node, ohne
  Abhängigkeiten) geprüft. Nur so ist sicher, dass App und Webseite dieselben
  Bytes erzeugen.

---

## 5. Protokoll

### 5.1 Operationen (Klartext, vor der Verschlüsselung)

```json
{ "op": "item.add",   "item": "<id>", "title": "Milch", "createdAt": "…" }
{ "op": "item.title", "item": "<id>", "title": "Hafermilch" }
{ "op": "item.done",  "item": "<id>", "done": true }
{ "op": "item.delete","item": "<id>" }
{ "op": "list.name",  "name": "Baumarkt" }
```

Jede trägt zusätzlich `device` (zufällige Geräte-ID) und `base`: für jedes
Feld, das sie ändert, die `seq` der Operation, die dieses Feld zuletzt gesetzt
hatte, als die Änderung gemacht wurde. Beispiel: `{"op": "item.title", "item":
"…", "title": "Hafermilch", "base": {"title": 17}}`. Löschen trägt die Basis
aller Felder, Anlegen keine.

Dazu kommen zwei Operationen für Konflikte (5.4):

```json
{ "op": "conflict.resolve", "conflict": "<op-id>", "keep": "mine" | "theirs" }
{ "op": "item.restore", "item": "<id>", "base": { "deleted": 23 } }
```

Die Zusammenführung ist eine reine Funktion
`zustand = merge(operationen in seq-Reihenfolge)` im gemeinsamen Paket (G1).
Jedes Gerät und die Webseite rechnen damit dasselbe Ergebnis aus,
einschließlich derselben offenen Konflikte.

### 5.2 Schnittstelle

| Methode | Pfad | Zweck |
| --- | --- | --- |
| `PUT` | `/api/lists/<id>` | Liste anlegen: Hash von `A`, Hash des Ersteller-Tokens, ob ein Code nötig ist. Idempotent. Kennt der Server die ID schon, gilt das als Fehler. |
| `GET` | `/api/lists/<id>/meta` | Ohne Token: nur „gibt es“ und „Code nötig“. Damit fragt die Webseite rechtzeitig nach dem Code. Mit Ersteller-Token zusätzlich `expiresAt` (für 6.6). Zählt **nicht** als Zugriff. |
| `GET` | `/api/lists/<id>/ops?after=<seq>` | Neue Operationen seit `seq`, jede mit fortlaufender Server-Nummer. |
| `POST` | `/api/lists/<id>/ops` | Eigene Operationen hochladen. Idempotent über die Operations-ID, sodass ein wiederholter Versuch nach einem Netzfehler nichts verdoppelt. |
| `DELETE` | `/api/lists/<id>` | Für alle löschen (Ersteller-Token). Der Server merkt sich die ID als gelöscht. |
| `GET` | `/l/<id>` | Die Webseite (für jede ID dieselbe statische Datei). |
| `GET` | `/.well-known/assetlinks.json` | Android App Links (siehe 6.3). |
| `GET` | `/health` | Für Docker und TrueNAS. |

Antworten bei Fehlern: `401` falscher Token oder Code, `404` unbekannte
Liste, `410` gelöscht, `429` gebremst.

### 5.3 Abgleich aus Sicht der App

1. Warteschlange hochladen (`POST`), bei Erfolg leeren.
2. `GET …/ops?after=<letzte seq>`, entschlüsseln, mit dem lokalen Bestand
   zusammenführen, `letzte seq` merken.
3. Bei `404`: Die Liste ist auf dem Server verloren gegangen (Ausfall). Joe
   legt sie mit derselben ID neu an und lädt den vollen Stand hoch (6.4).
4. Bei `410`: Der Ersteller hat sie gelöscht, oder sie ist abgelaufen (G9;
   die Antwort sagt, was von beidem). Joe zeigt das an und macht daraus eine
   lokale Liste (wie bei G6).
5. Jede erfolgreiche Antwort trägt `expiresAt`, den Zeitpunkt, an dem die
   Liste ohne weiteren Zugriff entteilt würde. Joe plant damit die
   Benachrichtigungen neu (6.6).

### 5.4 Konflikte (nach ABC-Todo)

Der Gedanke aus ABC-Todo (`abc-todo-app/docs/Thoughts.md`,
`abc-todo-backend/docs/API_CONTRACT.md`): **feldweise zusammenführen**; nur wo
wirklich zwei Leute dasselbe geändert haben, **entscheidet ein Mensch**;
**Löschen ist weich**. Dort erkennt der Server die Konflikte. Hier kann er das
nicht, weil er die Inhalte nicht lesen kann (V6). Deshalb rechnen die Geräte
selbst, und zwar alle gleich, weil die Reihenfolge vom Server kommt (G14).

**Felder** eines Eintrags: `title`, `done`, `deleted`. Der Liste: `name`.
Jedes Feld merkt sich die `seq` der Operation, die es zuletzt gesetzt hat.

`merge` geht die Operationen in `seq`-Reihenfolge durch. Für jedes Feld, das
eine Operation ändern will:

| Fall | Ergebnis |
| --- | --- |
| `base` = aktuelle `seq` des Feldes | Normale Änderung, wird übernommen. |
| Seit der Basis hat jemand **andere** Felder geändert (z. B. du den Titel, jemand anderes den Haken) | Kein Konflikt, weil `base` je Feld gilt: **zusammengeführt**. |
| `base` veraltet, Feld wurde seitdem geändert, **gleicher Wert** | Kein Konflikt (G13), nichts zu tun. |
| `base` veraltet, Feld wurde seitdem auf einen **anderen Wert** geändert | **Konflikt.** Der bisherige Wert bleibt stehen, die Änderung wird als offener Konflikt gemerkt. |
| Bearbeiten eines Eintrags, der seit `base` **gelöscht** wurde | **Konflikt** „gelöscht gegen bearbeitet“. Der Eintrag bleibt gelöscht, bis entschieden ist. |
| Löschen eines Eintrags, der seit `base` **bearbeitet** wurde | **Konflikt** „bearbeitet gegen gelöscht“. Der Eintrag bleibt stehen, bis entschieden ist. |

**Eigene Änderungen gelten als gesehen**: Ändert ein Gerät offline zweimal
denselben Titel, ist das kein Konflikt mit sich selbst. Die Basis zeigt dann
auf die eigene noch nicht hochgeladene Operation, und `merge` behandelt
Operationen desselben Geräts in ihrer Reihenfolge.

**Wer entscheidet** (G8): das Gerät, dessen Operation den Konflikt ausgelöst
hat, also die später angekommene. Das entspricht der 409-Antwort in ABC-Todo,
die auch der bekommt, der zu spät kam. Die anderen sehen den gültigen Stand
und ein kleines Zeichen „wird gerade geklärt“, aber keine Frage. Wer
entscheidet, lädt `conflict.resolve` hoch, und damit gilt das Ergebnis für
alle.

**In Joe**: Der Eintrag trägt ein Konfliktzeichen. Ein Tipp öffnet ein Blatt
wie in ABC-Todo:
- Feldkonflikt: „‚Sojamilch‘ (von dir) oder ‚Hafermilch‘ (geändert, während du
  offline warst)?“ mit **Meins** / **Das andere**.
- Gelöscht gegen bearbeitet: „Jemand hat ‚Milch‘ gelöscht, du hattest ihn
  geändert.“ mit **Löschen lassen** / **Mit meiner Änderung behalten**
  (`item.restore` + Änderung).
- Bearbeitet gegen gelöscht: „‚Milch‘ wurde inzwischen zu ‚Hafermilch‘
  geändert. Trotzdem löschen?“ mit **Löschen** / **Behalten**.

Zusätzlich zeigt die Statuszeile „1 Konflikt zu klären“. Eine native
Benachrichtigung gibt es dafür **nicht**: Konflikte entstehen nur beim
Abgleich, und der läuft nur bei offener Liste.

**In der Webseite**: dieselben Fragen. Wer die Seite schließt, ohne zu
entscheiden, lässt den Konflikt offen. Weil die Webseite nichts dauerhaft
speichert, gehört er dann niemandem mehr. Deshalb gilt: **Ein offener
Konflikt blockiert nichts.** Der zuerst angekommene Stand bleibt gültig, und
nach 30 Tagen ohne Entscheidung verfällt der Konflikt in der Zusammenführung
(Tage nach `seq`-Zeitpunkt des Servers, nicht nach Geräteuhr).

**Weiches Löschen**: Ein gelöschter Eintrag bleibt als Markierung im Bestand
(`deleted` mit `seq`) und wird nicht angezeigt. Das braucht `merge`, um
„bearbeitet gegen gelöscht“ zu erkennen und `item.restore` zu erlauben.
Aufgeräumt wird erst mit der Kompaktierung (Etappe 5), und dort nur, was älter
ist als die letzte `seq`, die alle bekannten Geräte bestätigt haben. Das ist
derselbe Gedanke wie die Aufbewahrungsregel für Tombstones in ABC-Todo.

---

## 6. Die App

### 6.1 Daten

- `ShoppingList` bekommt ein optionales `share`: Server-Adresse, Listen-ID,
  Geheimnis, Code (falls gesetzt), Ersteller-Geheimnis (nur beim Ersteller),
  letzte `seq`, Warteschlange, Lamport-Zähler.
- Global: eine Geräte-ID.
- Alles in `joe_data_v1`. **Gespeicherte Daten ändern sich**, also Minor-Sprung
  und Rückfrage nach AGENTS.md.
- Eine lokale Änderung an einer geteilten Liste läuft über denselben Weg wie
  eine fremde: Operation erzeugen, mit `merge` anwenden, in die Warteschlange.

### 6.2 Oberfläche

- **Teilen-Knopf** → Blatt mit „Als Text senden“ und „Gemeinsam bearbeiten“.
  - „Gemeinsam bearbeiten“ (Liste noch nicht geteilt) erklärt in zwei Sätzen,
    was passiert („Die Liste wird verschlüsselt auf <domain> abgelegt. Wer den
    Link hat, kann sie sehen und ändern.“). Schalter **„Zusätzlich Code
    verlangen“**, dann „Link teilen“. Bei Code: Der Code wird groß angezeigt
    und lässt sich kopieren.
  - Ist die Liste schon geteilt: Link noch einmal senden, Code anzeigen.
- **Chip**: Eine geteilte Liste trägt ein kleines Wolken-Symbol.
- **Statuszeile** unter der Listenkarte, nur bei geteilten Listen: „Abgeglichen
  vor 2 Min.“, „Offline – Änderungen gehen später raus“, „Code falsch“, „Vom
  Ersteller gelöscht“.
- **Langes Drücken** auf den Chip: zusätzlich „Teilen verlassen“, beim
  Ersteller auch „Für alle löschen“ und „Link erneuern“.
- **Beitreten**:
  1. Ein Link öffnet Joe direkt (App Links, 6.3). Ein Blatt fragt „Liste
     ‚Baumarkt‘ hinzufügen?“, bei Bedarf vorher nach dem Code.
  2. Ohne App-Link-Unterstützung: Im Blatt „Neue Liste“ gibt es „Geteilten Link
     einfügen“.

### 6.3 Android

- **INTERNET-Berechtigung** im Haupt-Manifest. Bisher stand sie nur in den
  Debug- und Profile-Manifesten. Weil die CI ohnehin Debug-APKs veröffentlicht,
  hatten die ausgelieferten Builds sie schon, ab jetzt ist es Absicht.
- **App Links**: Intent-Filter mit `autoVerify` für `https://<sync-domain>/l/*`.
  Der Server liefert `assetlinks.json` mit dem SHA-256 des Signaturschlüssels
  aus. Die CI signiert mit dem festen Debug-Keystore aus dem Secret
  `JOE_TODO_DEBUG_KEYSTORE`, und `build-debug-apk.ps1` lokal mit demselben,
  also passt **ein** Fingerabdruck für beide.
- **Server-Adresse** für neue geteilte Listen über `env/.env`
  (`JOE_SYNC_URL`, wie `JOE_MOCK_DATA`). Beim Beitreten gilt die Adresse aus
  dem Link.

### 6.4 Selbstheilung nach Serververlust

Meldet der Server `404` für eine Liste, die Joe kennt, legt Joe sie mit
derselben ID und demselben Token neu an. Danach lädt er den vollen Stand als
Operationen hoch. Wer zuerst kommt, stellt die Liste wieder her, die anderen
gleichen danach normal ab. Die ID ist zufällig (16 Bytes), eine fremde Liste
kann man so nicht kapern. Eine absichtlich gelöschte Liste (`410`) wird nicht
wiederbelebt. Diese Sperre liegt auf dem Server und geht bei einem Totalverlust
mit verloren; das ist hinnehmbar.

### 6.5 Datenschutz in Joe

- Das Log nennt weiter nur IDs und Anzahlen. **Nie Links, Geheimnisse oder
  Codes**, auch nicht in Fehlermeldungen (HTTP-Fehler ohne URL-Fragment
  loggen). Dafür kommt ein Test in `log_test.dart`.
- Die Geheimnisse liegen in `joe_data_v1` und gehen damit ins Android-Auto-Backup
  (Google-Konto). Das gehört in die README, wie beim Befinden.
- Der README-Grundsatz „Die App spricht nicht ins Netz“ wird neu gefasst: Joe
  spricht **nur für geteilte Listen**, **nur mit dem Server aus dem Link**,
  **nur verschlüsselt** und **nur solange die Liste offen ist**.

---

### 6.6 Entteilen nach langer Pause, mit Benachrichtigung (V10, G9)

- Der Server führt je Liste `lastAccess`. Jede Anfrage mit gültigem Token
  zählt, egal ob aus Joe oder der Webseite. `expiresAt = lastAccess + 12
  Monate` geht mit jeder Antwort zurück.
- **Nur beim Ersteller** (V13): Die Benachrichtigungen bekommt nur das Gerät,
  das die Liste geteilt hat, erkennbar am Ersteller-Geheimnis (4.3). Alle
  anderen erfahren es erst beim nächsten Öffnen (`410` mit „abgelaufen“), dann
  mit einem Hinweis in der App und ohne native Benachrichtigung.
- **Erste Benachrichtigung, rein lokal**: 14 Tage vor `expiresAt` „‚Baumarkt‘
  wird in 14 Tagen nicht mehr geteilt. Öffne die Liste, damit sie geteilt
  bleibt.“ Geplant über `flutter_local_notifications` (dieselbe Kapsel wie die
  Erinnerungen, `lib/reminders.dart`) und nach jedem Abgleich neu gesetzt, also
  ohne Netz im Hintergrund. Ein Tipp öffnet die Liste, und das Öffnen gleicht
  ab und verlängert damit. Hat inzwischen jemand anderes die Liste benutzt,
  kann diese Warnung unnötig sein. Sie ist so formuliert, dass sie auch dann
  stimmt.
- **Zweite Benachrichtigung, mit Nachfrage** (V14, Variante B): Kurz vor
  `expiresAt` (z. B. 1 Tag vorher) startet ein Android-**WorkManager**-Auftrag
  und fragt einmal `GET /api/lists/<id>/meta` mit Ersteller-Token.
  - Ist die Frist inzwischen verlängert (jemand hat die Liste benutzt): beide
    Benachrichtigungen mit dem neuen `expiresAt` neu planen, sonst nichts.
  - Läuft sie wirklich ab: native Benachrichtigung „‚Baumarkt‘ wird nicht mehr
    geteilt. Sie bleibt auf deinem Gerät.“ Danach macht Joe daraus eine lokale
    Liste.
  - Kein Netz: Der Auftrag wiederholt sich mit Wartezeit (WorkManager-
    Bedingung „verbunden“). Ist die Frist darüber verstrichen, kommt die
    Meldung beim nächsten Netzkontakt.
  Diese eine Anfrage ist die **einzige Ausnahme** von V4. Sie geht nur an den
  Server der Liste und nur mit dem Ersteller-Token. Die Abfrage selbst
  verlängert die Frist **nicht** (`meta` zählt nicht als Zugriff), sonst liefe
  eine vergessene Liste nie ab.
- **Ersteller nicht mehr da**: Hat der Ersteller Joe gelöscht oder die Liste
  verlassen, bekommt niemand eine native Benachrichtigung. Die anderen sehen
  es beim nächsten Öffnen. Das ist eine bewusste Folge von V13.
- Der Hauptschalter „Erinnerungen“ in den Einstellungen gilt auch hier **nicht**:
  Diese Benachrichtigung betrifft Daten, keine Termine. Fehlt die Berechtigung
  für Benachrichtigungen, sagt es die Statuszeile der Liste.
- **Auf dem Server**: Ist `expiresAt` vorbei, löscht der tägliche Lauf die
  verschlüsselten Operationen und lässt nur `id` und `abgelaufen am` stehen.
  Joe-Nutzer behalten ihre lokale Kopie. Wer nur die Webseite benutzt hat,
  sieht dort „Diese Liste wird nicht mehr geteilt“. Er hat keine Kopie, das
  steht so auch in der Warnung.
- **Wieder teilen**: Eine entteilte Liste kann man in Joe ganz normal neu
  teilen. Sie bekommt einen neuen Link.

## 7. Server und Betrieb

### 7.1 Server

- Dart, `shelf` + `shelf_router`, `sqlite3`. Eine Datenbankdatei im Volume,
  WAL-Modus.
- Tabellen: `lists` (ID, Token-Hash, Ersteller-Hash, Code nötig, angelegt,
  letzter Zugriff, gelöscht), `ops` (Listen-ID, `seq`, Operations-ID eindeutig,
  Block, Zeitpunkt).
- Bremsen (G10) im Speicher. Die IP kommt aus `X-Forwarded-For` bzw.
  `X-Real-IP`, die Pangolin setzt. Dem Kopf wird nur vertraut, wenn die
  Anfrage vom Proxy kommt.
- Täglicher Lauf (G9): abgelaufene Listen entteilen (Operationen löschen,
  `abgelaufen am` setzen).
- Logs ohne Token und ohne Inhalt.

### 7.2 Webseite

- Eine statische Seite (HTML, CSS, JS ohne Build-Schritt und ohne fremde
  Skripte oder CDNs), ausgeliefert vom Server unter `/l/<id>`.
- Strenge `Content-Security-Policy` (nur eigene Quelle) und
  `Referrer-Policy: no-referrer`. Kein fremdes Skript kann so an den Schlüssel
  im `#` kommen.
- Ablauf: Fragment lesen, `meta` abfragen, bei Bedarf Code abfragen, Schlüssel
  ableiten, Operationen laden, Liste zeigen. Abhaken, ergänzen und umbenennen
  wie in Joe. Abgleich alle 10 Sekunden, solange der Tab sichtbar ist.
- Das gemeinsame Dart-Paket wird hier **nicht** benutzt: Die Zusammenführung
  ist klein und wird in JS nachgebaut. Gemeinsame Testfälle (Operationen rein,
  erwarteter Zustand raus) sichern ab, dass beide gleich rechnen.
- Aussehen: warm und schlicht wie Joe (Papierkarte auf ruhigem Hintergrund),
  gut lesbar auf dem Handy.

### 7.3 TrueNAS, Pangolin, Backup

- **Dockerfile und Compose-Datei** im Repo (`server/Dockerfile`,
  `server/compose.yaml`) für eine TrueNAS Custom App: wird auf TrueNAS gebaut
  (V11), ein Volume auf einem eigenen Dataset, Healthcheck.
- **Pangolin**: Die Ressource für die Sync-Domain ist **öffentlich**, ohne
  Pangolin-Anmeldung (V12). Sonst landen Empfänger des Links auf einer
  Login-Seite, und die App-Link-Prüfung von Android scheitert. Mindestens
  `/l/*`, `/api/*` und `/.well-known/*` müssen frei sein.
- **Backup**: ZFS-Snapshots des Datasets (z. B. stündlich, 7 Tage
  aufbewahren). Weil das Speichern auf dem Server nicht redundant ist,
  zusätzlich eine Kopie **woandershin**: Cloud-Sync-Task oder Replikation auf
  ein zweites Gerät. Die Selbstheilung (6.4) ist die letzte Sicherung, nicht
  die einzige.

---

## 8. Aufbau im Repo

```
packages/joe_sync/   reines Dart: Operationen, merge, Kryptografie, Link-Format,
                     Testvektoren (test/vectors.json)
server/              Dart-Server, Dockerfile, compose.yaml, Tests
server/web/          die Webseite (index.html, app.js, style.css) + JS-Tests
app/                 Joe; bindet packages/joe_sync als path-Abhängigkeit ein
```

CI (`.github/workflows/`): Tests für Paket, Server und Webseite laufen bei
jedem Pull Request und auf `main`. Ein Image baut die CI nicht (G11). Der
APK-Workflow bleibt, wie er ist.

**Arbeitsweise**: Die ganze Arbeit an diesem Plan läuft auf dem Branch
`feature/geteilte-einkaufslisten`. Der APK-Workflow startet nur bei Pushes auf
`main` (und bei Pull Requests), Pushes auf den Branch erzeugen also kein
Release. Die Versionsregel aus AGENTS.md greift erst beim Zusammenführen nach
`main`.

---

## 9. Etappen

Jede Etappe endet mit grünem `flutter analyze` / `flutter test` bzw.
`dart test`. Was die App betrifft, bekommt eine Versionsanhebung nach AGENTS.md.

| # | Etappe | Inhalt | Ergebnis |
| --- | --- | --- | --- |
| 1 | **Fundament** | `packages/joe_sync`: Operationen, `merge` mit Konflikterkennung (5.4), Kryptografie, Link-Format, Testvektoren für Kryptografie **und** Zusammenführung. Viele Tests, gerade für Konflikte, Löschen gegen Bearbeiten und Offline-Folgen eines Geräts. | Prüfbares Herzstück, noch nichts sichtbar. |
| 2 | **Server** | API, SQLite, Bremsen, `lastAccess`/`expiresAt`, täglicher Lauf (Entteilen), `assetlinks.json`, Dockerfile, Compose. Auf TrueNAS hinter Pangolin in Betrieb nehmen. | Server läuft, mit `curl` prüfbar. |
| 3 | **Joe teilt** | Datenmodell, Abgleich, Teilen-Blatt, Beitreten per eingefügtem Link, Status, Konflikt-Blatt, Verlassen, Löschen für alle, Benachrichtigungen zum Entteilen, INTERNET, App Links, README-Grundsatz neu. Minor-Version. | Zwei Android-Geräte teilen eine Liste. |
| 4 | **Webseite** | Seite unter `/l/<id>` mit Konfliktfragen, samt JS-Tests gegen die Testvektoren. | Alle ohne Joe machen mit, auch auf dem iPhone. |
| 5 | **Später** | „Link erneuern“ (neue ID und neues Geheimnis, aktueller Stand umgezogen, alter Link gelöscht). Kompaktierung langer Operationslisten (Schnappschuss als Operation). Maestro-Flow mit zwei Emulatoren. | Pflege. |

Etappe 4 hängt nur an 1 und 2 und kann parallel zu 3 laufen.

---

## 10. Offene Fragen an den Benutzer

1. **Sync-Domain**: noch offen, der Benutzer entscheidet selbst. Sie steht in
   jedem geteilten Link und lässt sich später nur mit neuen Links ändern.
   **Muss vor Etappe 3 feststehen**, Etappen 1 und 2 brauchen sie nicht.

Erledigt (14.10.2026): Pangolin öffentlich (V12), Image selbst auf TrueNAS
(V11), Benachrichtigungen nur beim Ersteller (V13) und mit Nachfrage
(Variante B, V14), Konfliktregelung (V15). Zu G1–G14 gab es keine Einwände.

---

## 11. Risiken

- **Link weitergeleitet** = Zugang weitergegeben. Abhilfe: Code (V5) und später
  „Link erneuern“.
- **Server-Ausfall**: Listen gleichen nicht ab, bleiben aber benutzbar
  (lokal zuerst). Bei Datenverlust greifen Backup und Selbstheilung.
- **Uhren**: Die Reihenfolge kommt allein vom Server (G14). Eine falsch
  gehende Geräteuhr bringt nichts durcheinander.
- **Unbeantwortete Konflikte**: Sie blockieren nichts und verfallen nach 30
  Tagen (5.4). Schlimmstenfalls bleibt also der zuerst angekommene Stand
  stehen, wie bei „die frühere gewinnt“.
- **Zwei Implementierungen der Zusammenführung** (Dart und JS): durch gemeinsame
  Testfälle abgesichert (7.2). Weicht eine ab, schlägt der Test fehl, nicht
  erst die Liste beim Benutzer.
- **Offenes Internet**: Der Server ist öffentlich erreichbar. Deshalb gibt es
  Grenzen und Bremsen (G10), keine Inhalte im Klartext und Logs ohne
  Geheimnisse.
