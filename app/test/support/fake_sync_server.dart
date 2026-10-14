import 'dart:convert';

import 'package:joe_sync/joe_sync.dart';

/// Ein Sync-Server im Speicher fuer die App-Tests, mit dem Verhalten von
/// server/lib/src/api.dart (Konzept 5.2): Tokens als Hash, Operationen mit
/// fortlaufender seq, idempotentes Hochladen, 410 fuer geloescht und
/// abgelaufen. Den echten Server (SQLite) bindet die App nicht ein; seine
/// eigenen Tests pruefen dasselbe Ende zu Ende mit dem echten Client.
class FakeSyncServer implements SyncTransport {
  DateTime now = DateTime.utc(2026, 10, 14, 8);
  Duration retention = const Duration(days: 365);

  /// Wie ein Netzfehler: jede Anfrage wirft.
  bool offline = false;

  final Map<String, FakeList> lists = {};
  int _seq = 0;

  /// Mitgeschrieben, was die App anfragt (Methode und Pfad).
  final List<String> requests = [];

  @override
  Future<SyncReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
  }) async {
    if (offline) throw StateError('offline');
    requests.add('$method ${url.path}');
    // Wie auf der Leitung: einmal durch JSON.
    final body = json == null
        ? null
        : jsonDecode(jsonEncode(json)) as Map<String, Object?>;
    final match = RegExp(r'/api/lists/([^/]+)(/meta|/ops)?$')
        .firstMatch(url.path);
    if (match == null) return const SyncReply(404);
    final id = match.group(1)!;
    final tail = match.group(2) ?? '';
    final bearer = headers['authorization']?.replaceFirst('Bearer ', '');
    final owner = headers['x-joe-owner'];

    Future<bool> matches(String? token, String hash) async =>
        token != null && await JoeCrypto.tokenHash(token) == hash;

    final list = lists[id];
    if (list != null && list.gone == null && !list.expires.isAfter(now)) {
      list
        ..gone = 'expired'
        ..ops.clear();
    }
    Map<String, Object?> times(FakeList l) => {
          'expiresAt': l.expires.toIso8601String(),
          'now': now.toIso8601String(),
        };

    if (method == 'PUT' && tail.isEmpty) {
      if (!await matches(bearer, body!['accessHash'] as String)) {
        return const SyncReply(401);
      }
      if (list != null) {
        if (list.gone != null) return SyncReply(410, {'reason': list.gone});
        return SyncReply(200, {'epoch': list.epoch, ...times(list)});
      }
      final created = lists[id] = FakeList(
        accessHash: body['accessHash'] as String,
        ownerHash: body['ownerHash'] as String,
        code: body['code'] as bool,
        epoch: newId(),
        lastAccess: now,
        retention: retention,
      );
      return SyncReply(201, {'epoch': created.epoch, ...times(created)});
    }

    if (list == null) return const SyncReply(404, {'error': 'unknown'});
    if (list.gone != null) return SyncReply(410, {'reason': list.gone});

    if (method == 'GET' && tail == '/meta') {
      final isOwner = await matches(owner, list.ownerHash);
      return SyncReply(200, {
        'exists': true,
        'code': list.code,
        if (isOwner) ...times(list),
      });
    }
    if (method == 'DELETE' && tail.isEmpty) {
      if (!await matches(owner, list.ownerHash)) return const SyncReply(403);
      list
        ..gone = 'deleted'
        ..ops.clear();
      return const SyncReply(204);
    }
    if (!await matches(bearer, list.accessHash)) {
      return const SyncReply(401, {'error': 'unauthorized'});
    }
    list.lastAccess = now;
    if (method == 'GET' && tail == '/ops') {
      final after = int.parse(url.queryParameters['after'] ?? '0');
      return SyncReply(200, {
        'ops': [
          for (final op in list.ops)
            if (op.seq > after) op.toJson(),
        ],
        'more': false,
        'head': list.ops.isEmpty ? 0 : list.ops.last.seq,
        'epoch': list.epoch,
        'ownerHash': list.ownerHash,
        ...times(list),
      });
    }
    if (method == 'POST' && tail == '/ops') {
      final accepted = <Map<String, Object?>>[];
      for (final raw in body!['ops'] as List) {
        final entry = raw as Map<String, Object?>;
        final opId = entry['id'] as String;
        final known = list.ops.where((o) => o.id == opId);
        final seq = known.isNotEmpty ? known.first.seq : ++_seq;
        if (known.isEmpty) {
          list.ops.add(
            WireOp(seq: seq, id: opId, blob: entry['blob'] as String, at: now),
          );
        }
        accepted.add({'id': opId, 'seq': seq});
      }
      return SyncReply(200, {
        'accepted': accepted,
        'epoch': list.epoch,
        ...times(list),
      });
    }
    return const SyncReply(404);
  }
}

class FakeList {
  final String accessHash;
  final String ownerHash;
  final bool code;
  final String epoch;
  final Duration retention;
  DateTime lastAccess;
  String? gone;
  final List<WireOp> ops = [];

  FakeList({
    required this.accessHash,
    required this.ownerHash,
    required this.code,
    required this.epoch,
    required this.lastAccess,
    required this.retention,
  });

  DateTime get expires => lastAccess.add(retention);
}
