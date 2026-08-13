import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Log-Backend fuer Plattformen mit Dateisystem (Android als Hauptplattform,
/// genauso Desktop und iOS): haengt Zeilen an joe.log im Support-Verzeichnis
/// an und rotiert ab [maxBytes] nach joe.log.1.
///
/// Gegenstueck zu log_sink_stub.dart, ausgewaehlt ueber den bedingten Import
/// in log.dart – nur so bleibt dart:io aus dem Web-Build heraus.
class LogSink {
  /// Zum Umbiegen im Test; die App nutzt das Support-Verzeichnis.
  @visibleForTesting
  static Future<Directory> Function() resolveDirectory =
      getApplicationSupportDirectory;

  /// Ab dieser Groesse rueckt joe.log zu joe.log.1 (im Test kleiner).
  @visibleForTesting
  static int maxBytes = 256 * 1024;

  Future<void> append(String line) async {
    final file = await _logFile();
    await file.writeAsString('$line\n', mode: FileMode.append);
    if (await file.length() > maxBytes) {
      final previous = File('${file.path}.1');
      if (await previous.exists()) await previous.delete();
      await file.rename(previous.path);
    }
  }

  /// Die vorhandenen Logdateien, aelteste zuerst – das ist die Lesereihenfolge.
  Future<List<String>> existingPaths() async {
    final file = await _logFile();
    final previous = File('${file.path}.1');
    return [
      if (await previous.exists()) previous.path,
      if (await file.exists()) file.path,
    ];
  }

  Future<File> _logFile() async {
    final dir = await resolveDirectory();
    return File('${dir.path}${Platform.pathSeparator}joe.log');
  }
}
