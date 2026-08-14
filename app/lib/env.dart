import 'package:flutter/foundation.dart';

/// Die Schalter aus den env-Dateien – eine Stelle, an der man nachsieht, was
/// dieser Build anders macht als der naechste.
///
/// Sie liegen in `app/env/`: `.env` fuer die Entwicklung, `.env.production`
/// fuer das Release. Keine der beiden ist im Repo (sie duerfen Geheimnisse
/// enthalten); im Repo liegt `.env.example` als Vorlage, in der CI kommt der
/// Inhalt aus einem Secret. Gelesen werden sie nicht zur Laufzeit, sondern
/// beim Bauen mitgegeben:
///
/// ```
/// flutter build apk --release --dart-define-from-file=env/.env.production
/// ```
///
/// Daraus werden Konstanten (`bool.fromEnvironment`), die der Uebersetzer
/// einsetzt – die Dateien selbst wandern nirgendwohin. Ohne das Flag (etwa
/// beim "Run" aus der IDE) gilt das, was hier als Standard steht, und das ist
/// das, womit die App beim Nutzer laeuft.
///
/// Was aus einer env-Datei ueberhaupt ins APK kommt, haengt daran, was hier
/// steht: ein Schluessel, den kein `fromEnvironment` liest, geht nirgendwohin.
/// Ein `bool` verschwindet ebenfalls – der Uebersetzer setzt ihn ein und wirft
/// den toten Zweig weg. Ein `String.fromEnvironment` dagegen steht als Text im
/// uebersetzten Kode und ist mit `strings` zu finden: was die App *benutzt*,
/// kennt auch der Nutzer. Ein Geheimnis, das wirklich eines bleiben muss,
/// gehoert hinter einen Server, der es fuer die App benutzt.
abstract final class JoeEnv {
  /// Beispieldaten beim allerersten Start (`AppState._seed`): Aufgaben,
  /// Termine, Willkommensnotiz. Aus heisst: Joe startet mit leeren Listen.
  static const _mockData = bool.fromEnvironment(
    'JOE_MOCK_DATA',
    defaultValue: false,
  );

  static bool get mockData => debugMockData ?? _mockData;

  /// Nur fuer Tests: die Schalter sind Konstanten, ein Test kann sie also
  /// nicht ueber eine Datei umstellen. In [tearDown] wieder auf null setzen.
  @visibleForTesting
  static bool? debugMockData;

  /// Fuer das Log beim Start – damit in einem eingeschickten Log steht, mit
  /// welchen Schaltern der Build lief.
  static String get summary => 'Env: JOE_MOCK_DATA=$mockData';
}
