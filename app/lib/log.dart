import 'package:flutter/foundation.dart';

import 'log_sink_stub.dart' if (dart.library.io) 'log_sink_io.dart';

/// Schlichtes App-Log, damit „Logs teilen" in den Einstellungen etwas zum
/// Teilen hat: Zeilen mit Zeitstempel, angehaengt an joe.log (Rotation ab
/// 256 KB nach joe.log.1, geteilt werden beide). Das Dateihandwerk liegt in
/// [LogSink], per bedingtem Import: Android ist die Hauptplattform, aber der
/// Code hier bleibt plattformneutral – auf dem Web gibt es kein dart:io,
/// dort traegt der Speicherpuffer.
///
/// Zwei Grundsaetze:
///
/// * **Loggen darf nie stoeren.** Jeder Dateifehler wird geschluckt; wo es
///   kein Dateisystem gibt (Web, Unit-Tests), bleibt der Puffer im Speicher
///   und die App laeuft unveraendert.
/// * **Inhalte bleiben draussen.** Geloggt werden Ereignisse, Anzahlen und
///   IDs – nie Titel oder Notiztexte, denn geteilte Logs gehen an Dritte.
class JoeLog {
  JoeLog._();

  /// Eigene Instanz fuer Tests, damit der Singleton-Zustand nicht von Test
  /// zu Test durchsickert.
  @visibleForTesting
  JoeLog.forTest();

  static final JoeLog instance = JoeLog._();

  /// So viele Zeilen haelt der Speicherpuffer als Ersatz fuer die Datei.
  static const _recentCap = 400;

  final LogSink _sink = LogSink();
  final List<String> _recent = [];
  Future<void> _writing = Future.value();
  bool _fileBroken = false;

  /// Haengt eine Zeile an. Bequemer Einstieg: `JoeLog.log('...')`.
  static void log(String message) => instance.add(message);

  void add(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    debugPrint('[joe] $line');
    _recent.add(line);
    if (_recent.length > _recentCap) _recent.removeAt(0);
    // Schreibvorgaenge hintereinander haengen, damit sich zwei Zeilen nicht
    // in die Quere kommen.
    _writing = _writing.then((_) => _append(line));
  }

  Future<void> _append(String line) async {
    if (_fileBroken) return;
    try {
      await _sink.append(line);
    } catch (_) {
      // Loggen darf nie stoeren – ab jetzt traegt der Speicherpuffer.
      _fileBroken = true;
    }
  }

  /// Alles fuers Teilen: erst ausschreiben, was noch aussteht, dann die
  /// Logdateien – oder, solange keine existiert, der Puffer als Text.
  Future<({List<String> paths, String text})> sharePayload() async {
    await _writing;
    var paths = const <String>[];
    if (!_fileBroken) {
      try {
        paths = await _sink.existingPaths();
      } catch (_) {
        // Dann eben der Puffer.
      }
    }
    return (paths: paths, text: _recent.join('\n'));
  }

  /// Wartet alle angestossenen Schreibvorgaenge ab.
  @visibleForTesting
  Future<void> get flushed => _writing;
}
