import 'dart:convert';

import 'package:joe_sync/joe_sync.dart';
import 'package:joe_sync_server/joe_sync_server.dart';
import 'package:shelf/shelf.dart';

/// Ein Server im Speicher mit verstellbarer Uhr.
class TestServer {
  DateTime now = DateTime.utc(2026, 10, 14, 8);
  final lines = <String>[];
  late Store store;
  late SyncApi api;
  late Handler handler;
  final ServerConfig config;

  /// Ist das „Netz“ weg, wirft der Transport wie bei einem Netzfehler.
  bool offline = false;

  TestServer({this.config = const ServerConfig(web: 'web')}) {
    store = Store.memory();
    _build();
  }

  void _build() {
    api = SyncApi(
      store: store,
      config: config,
      clock: () => now,
      log: lines.add,
    );
    handler = api.handler;
  }

  /// Totalverlust: Datenbank weg, Server neu (Konzept 6.4).
  void wipe() {
    store.close();
    store = Store.memory();
    _build();
  }

  void advance(Duration duration) => now = now.add(duration);

  Future<Response> call(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? json,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://joe.test$path'),
      headers: headers,
      body: json == null ? null : jsonEncode(json),
    ),
  );

  SyncTransport get transport => _Transport(this);
}

class _Transport implements SyncTransport {
  final TestServer server;
  _Transport(this.server);

  @override
  Future<SyncReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
  }) async {
    if (server.offline) throw StateError('offline');
    final response = await server.handler(
      Request(
        method,
        url,
        headers: headers,
        body: json == null ? null : jsonEncode(json),
      ),
    );
    final text = await response.readAsString();
    Map<String, Object?> body = const {};
    if (text.isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, Object?>) body = decoded;
    }
    return SyncReply(response.statusCode, body);
  }
}

Future<Map<String, Object?>> body(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, Object?>;
