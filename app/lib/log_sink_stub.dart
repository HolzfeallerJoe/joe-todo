/// Log-Backend fuer Plattformen ohne Dateisystem (Web).
///
/// Gegenstueck zu log_sink_io.dart, ausgewaehlt ueber den bedingten Import
/// in log.dart. [append] wirft beim ersten Aufruf; JoeLog faengt das und
/// laesst ab da den Speicherpuffer tragen – "Logs teilen" teilt dann Text
/// statt Dateien.
class LogSink {
  Future<void> append(String line) async {
    throw UnsupportedError('Kein Dateisystem auf dieser Plattform');
  }

  Future<List<String>> existingPaths() async => const [];
}
