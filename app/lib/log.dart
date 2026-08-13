import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Schlichtes App-Log, damit „Logs teilen" in den Einstellungen etwas zum
/// Teilen hat: Zeilen mit Zeitstempel, angehaengt an eine Datei im
/// Support-Verzeichnis der App, gedeckelt durch eine einfache Rotation
/// (joe.log wird zu joe.log.1, geteilt werden beide).
///
/// Zwei Grundsaetze:
///
/// * **Loggen darf nie stoeren.** Jeder Dateifehler wird geschluckt; wo es
///   kein Dateisystem gibt (Unit-Tests), bleibt der Puffer im Speicher und
///   die App laeuft unveraendert.
/// * **Inhalte bleiben draussen.** Geloggt werden Ereignisse, Anzahlen und
///   IDs – nie Titel oder Notiztexte, denn geteilte Logs gehen an Dritte.
class JoeLog {
  JoeLog._();

  /// Eigene Instanz fuer Tests, damit der Singleton-Zustand nicht von Test
  /// zu Test durchsickert.
  @visibleForTesting
  JoeLog.forTest();

  static final JoeLog instance = JoeLog._();

  /// Zum Umbiegen im Test; die App nutzt das Support-Verzeichnis.
  @visibleForTesting
  static Future<Directory> Function() resolveDirectory =
      getApplicationSupportDirectory;

  /// Ab dieser Groesse rueckt joe.log zu joe.log.1 (im Test kleiner).
  @visibleForTesting
  static int maxBytes = 256 * 1024;

  /// So viele Zeilen haelt der Speicherpuffer als Ersatz fuer die Datei.
  static const _recentCap = 400;

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
      final file = await _logFile();
      await file.writeAsString('$line\n', mode: FileMode.append);
      if (await file.length() > maxBytes) {
        final previous = File('${file.path}.1');
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }
    } catch (_) {
      // Loggen darf nie stoeren – ab jetzt traegt der Speicherpuffer.
      _fileBroken = true;
    }
  }

  Future<File> _logFile() async {
    final dir = await resolveDirectory();
    return File('${dir.path}${Platform.pathSeparator}joe.log');
  }

  /// Alles fuers Teilen: erst ausschreiben, was noch aussteht, dann die
  /// Logdateien – oder, solange keine existiert, der Puffer als Text.
  Future<({List<String> paths, String text})> sharePayload() async {
    await _writing;
    final paths = <String>[];
    if (!_fileBroken) {
      try {
        final file = await _logFile();
        final previous = File('${file.path}.1');
        if (await previous.exists()) paths.add(previous.path);
        if (await file.exists()) paths.add(file.path);
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
