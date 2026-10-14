import 'dart:async';
import 'dart:io';

import 'package:joe_sync_server/joe_sync_server.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Startet den Sync-Server. Einstellungen ueber Umgebungsvariablen, siehe
/// lib/src/config.dart und compose.yaml.
///
/// `server --health` fragt den laufenden Server und endet mit 0 oder 1; so
/// braucht der Healthcheck im Container weder curl noch wget.
Future<void> main(List<String> args) async {
  final config = ServerConfig.fromEnvironment();
  if (args.contains('--health')) exit(await _health(config.port));
  final dbFile = File(config.database);
  dbFile.parent.createSync(recursive: true);
  final store = Store.open(dbFile.path);

  void log(String line) =>
      stdout.writeln('${DateTime.now().toUtc().toIso8601String()} $line');

  final api = SyncApi(store: store, config: config, log: log);

  // Einmal beim Start, danach taeglich (G9).
  api.maintenance();
  final daily = Timer.periodic(
    const Duration(days: 1),
    (_) => api.maintenance(),
  );

  final server = await io.serve(
    api.handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  server.autoCompress = true;
  log(
    'joe-sync ${SyncApi.version} auf Port ${server.port}, '
    'Aufbewahrung ${config.retention.inDays} Tage, '
    'Proxy ${config.trustProxy ? 'vertraut' : 'nicht vertraut'}, '
    'App Links ${config.androidFingerprints.isEmpty ? 'aus' : 'an'}',
  );

  Future<void> stop(ProcessSignal signal) async {
    log('Beende ($signal)');
    daily.cancel();
    await server.close();
    store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(stop);
}

Future<int> _health(int port) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.get('127.0.0.1', port, '/health');
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode == 200 ? 0 : 1;
  } catch (_) {
    return 1;
  } finally {
    client.close(force: true);
  }
}
