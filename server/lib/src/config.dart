import 'dart:io';

/// Einstellungen des Servers, alle ueber Umgebungsvariablen (compose.yaml).
class ServerConfig {
  final int port;

  /// Pfad der SQLite-Datei; im Container im Volume unter /data.
  final String database;

  /// Ordner mit der Webseite (index.html, app.js, ...).
  final String web;

  /// Ohne Zugriff so lange, dann wird eine Liste entteilt (G9).
  final Duration retention;

  /// Nur hinter einem Proxy (Pangolin) einschalten: dann gilt die IP aus
  /// `X-Real-IP` bzw. dem letzten Eintrag in `X-Forwarded-For`.
  final bool trustProxy;

  /// SHA-256-Fingerabdruecke der App-Signatur fuer
  /// `/.well-known/assetlinks.json`; leer heisst: keine App Links.
  final List<String> androidFingerprints;
  final String androidPackage;

  /// Grenzen aus G10.
  final int newListsPerDay;
  final int codeFailuresPerHour;

  const ServerConfig({
    this.port = 8080,
    this.database = 'data/joe-sync.db',
    this.web = 'web',
    this.retention = const Duration(days: 365),
    this.trustProxy = false,
    this.androidFingerprints = const [],
    this.androidPackage = 'dev.joe.joe_todo',
    this.newListsPerDay = 50,
    this.codeFailuresPerHour = 10,
  });

  factory ServerConfig.fromEnvironment([Map<String, String>? env]) {
    final e = env ?? Platform.environment;
    int number(String key, int fallback) =>
        int.tryParse(e[key] ?? '') ?? fallback;
    return ServerConfig(
      port: number('JOE_PORT', 8080),
      database: e['JOE_DB'] ?? 'data/joe-sync.db',
      web: e['JOE_WEB'] ?? 'web',
      retention: Duration(days: number('JOE_RETENTION_DAYS', 365)),
      trustProxy: const {
        '1',
        'true',
        'yes',
      }.contains((e['JOE_TRUST_PROXY'] ?? '').toLowerCase()),
      androidFingerprints: [
        for (final part in (e['JOE_ANDROID_FINGERPRINTS'] ?? '').split(','))
          if (part.trim().isNotEmpty) part.trim().toUpperCase(),
      ],
      androidPackage: e['JOE_ANDROID_PACKAGE'] ?? 'dev.joe.joe_todo',
      newListsPerDay: number('JOE_NEW_LISTS_PER_DAY', 50),
      codeFailuresPerHour: number('JOE_CODE_FAILURES_PER_HOUR', 10),
    );
  }
}
