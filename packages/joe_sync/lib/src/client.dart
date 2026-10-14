import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'crypto.dart';
import 'encoding.dart';
import 'link.dart';
import 'merge.dart';
import 'op.dart';
import 'share_state.dart';
import 'wire.dart';

/// Antwort des Servers: Status und JSON (leer, wenn keins kam).
class SyncReply {
  final int status;
  final Map<String, Object?> body;

  const SyncReply(this.status, [this.body = const {}]);
}

/// Der Weg zum Server. In der App HTTP, in Tests direkt der Handler.
abstract interface class SyncTransport {
  /// Wirft bei Netzfehlern; jede Antwort des Servers ist ein [SyncReply].
  Future<SyncReply> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    Object? json,
  });
}

/// [SyncTransport] ueber `package:http`.
class HttpSyncTransport implements SyncTransport {
  final http.Client _client;
  final Duration timeout;

  HttpSyncTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  @override
  Future<SyncReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
  }) async {
    final request = http.Request(method, url)
      ..headers.addAll(headers)
      ..followRedirects = false;
    if (json != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(json);
    }
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(timeout),
    ).timeout(timeout);
    Map<String, Object?> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, Object?>) body = decoded;
      } on FormatException {
        // Kein JSON (etwa eine Fehlerseite des Proxys): nur der Status zaehlt.
      }
    }
    return SyncReply(response.statusCode, body);
  }

  void close() => _client.close();
}

enum SyncStatus {
  ok,

  /// Kein Netz oder Server nicht erreichbar. Aenderungen warten.
  offline,

  /// Token falsch: Code falsch oder Link erneuert.
  unauthorized,

  /// Vom Ersteller geloescht oder abgelaufen; siehe [SyncOutcome.reason].
  gone,

  /// Gebremst (zu viele Fehlversuche).
  rateLimited,

  /// Der Server kennt die Liste nicht (und sie liess sich nicht neu
  /// anlegen), oder er antwortet Unerwartetes.
  failed,
}

class SyncOutcome {
  final SyncStatus status;

  /// Bei [SyncStatus.gone]: `deleted` oder `expired`.
  final String? reason;

  /// Hat sich der sichtbare Stand geaendert?
  final bool changed;

  /// So viele Operationen liessen sich nicht lesen (fremde Version,
  /// kaputt) und wurden uebersprungen.
  final int skipped;

  const SyncOutcome(
    this.status, {
    this.reason,
    this.changed = false,
    this.skipped = 0,
  });

  bool get ok => status == SyncStatus.ok;

  @override
  String toString() =>
      'SyncOutcome(${status.name}${reason == null ? '' : ' $reason'}'
      '${changed ? ', geaendert' : ''}'
      '${skipped == 0 ? '' : ', $skipped uebersprungen'})';
}

/// Ein Abgleich ging schief, wo es kein Weiter gibt (Teilen, Beitreten).
class SyncFailure implements Exception {
  final SyncStatus status;
  final String? reason;

  const SyncFailure(this.status, [this.reason]);

  @override
  String toString() =>
      'SyncFailure(${status.name}${reason == null ? '' : ' $reason'})';
}

/// Was `meta` ueber eine Liste weiss.
class ListMeta {
  final bool code;

  /// Nur mit Ersteller-Token.
  final DateTime? expiresAt;
  final DateTime? now;

  const ListMeta({required this.code, this.expiresAt, this.now});
}

/// Ein Eintrag, wie er beim Teilen hochgeht.
class SnapshotItem {
  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;

  const SnapshotItem({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
  });
}

/// Spricht mit dem Sync-Server (Konzept 5.3). Haelt keine Listen selbst;
/// die liegen als [ShareState] beim Aufrufer und werden hier veraendert.
class SyncClient {
  final SyncTransport transport;

  /// Zufaellige ID dieses Geraets, steht in jeder eigenen Operation.
  final String device;

  SyncClient({required this.transport, required this.device});

  final _keys = <String, ({List<int> key, String access})>{};
  final _running = <String, Future<SyncOutcome>>{};

  Future<({List<int> key, String access})> _keysOf(ShareState s) async {
    final cacheKey = '${s.listId}|${s.secret}|${s.code ?? ''}';
    final cached = _keys[cacheKey];
    if (cached != null) return cached;
    final secret = unb64(s.secret);
    final keys = (
      key: await JoeCrypto.listKey(s.listId, secret),
      access: await JoeCrypto.accessToken(s.listId, secret, s.code),
    );
    return _keys[cacheKey] = keys;
  }

  Uri _url(String server, String path, [Map<String, String>? query]) {
    final base = Uri.parse(server);
    return base.replace(path: '${base.path}$path', queryParameters: query);
  }

  Future<SyncReply?> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
  }) async {
    try {
      return await transport.send(method, url, headers: headers, json: json);
    } catch (_) {
      // Netzfehler, Zeitueberschreitung: still, die Liste bleibt lokal
      // benutzbar. Die URL steht bewusst in keiner Meldung.
      return null;
    }
  }

  static SyncOutcome? _problem(SyncReply? reply) {
    if (reply == null) return const SyncOutcome(SyncStatus.offline);
    switch (reply.status) {
      case >= 200 && < 300:
        return null;
      case 401:
        return const SyncOutcome(SyncStatus.unauthorized);
      case 410:
        return SyncOutcome(
          SyncStatus.gone,
          reason: reply.body['reason'] as String? ?? 'deleted',
        );
      case 429:
        return const SyncOutcome(SyncStatus.rateLimited);
      // Proxy ohne Verbindung zum Container (Pangolin, Docker gestoppt).
      case 502 || 503 || 504:
        return const SyncOutcome(SyncStatus.offline);
      default:
        return const SyncOutcome(SyncStatus.failed);
    }
  }

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  void _times(ShareState s, SyncReply reply) {
    s.expiresAt = _time(reply.body['expiresAt']) ?? s.expiresAt;
  }

  // ---------------------------------------------------------------- Teilen

  /// Teilt eine Liste neu (Konzept 6.2): legt sie auf [server] an und laedt
  /// Name und Eintraege hoch. Wirft [SyncFailure], wenn das nicht geht.
  Future<ShareState> create({
    required String server,
    required String name,
    required Iterable<SnapshotItem> items,
    bool withCode = false,
  }) async {
    final listId = newId();
    final secret = newSecret();
    final ownerSecret = newSecret();
    final code = withCode ? newCode() : null;
    final s = ShareState(
      server: ShareLink(server: server, listId: listId, secret: secret).server,
      listId: listId,
      secret: b64(secret),
      code: code,
      ownerSecret: b64(ownerSecret),
    );
    final ownerToken = await JoeCrypto.ownerToken(listId, ownerSecret);
    s.ownerHash = await JoeCrypto.tokenHash(ownerToken);
    final problem = await _put(s);
    if (problem != null) throw SyncFailure(problem.status, problem.reason);

    s.record(Op.rename(newId(), device, s.view, name));
    for (final item in items) {
      s.record(
        Op.add(
          newId(),
          device,
          item: item.id,
          title: item.title,
          done: item.done,
          createdAt: item.createdAt,
        ),
      );
    }
    // Geht das Hochladen schief, ist die Liste trotzdem geteilt; der Rest
    // kommt beim naechsten Abgleich.
    await sync(s);
    return s;
  }

  /// Legt die Liste an (oder neu an, Konzept 6.4). `null` bei Erfolg.
  Future<SyncOutcome?> _put(ShareState s) async {
    final ownerHash = s.ownerHash;
    if (ownerHash == null) return const SyncOutcome(SyncStatus.failed);
    final keys = await _keysOf(s);
    final reply = await _send(
      'PUT',
      _url(s.server, '/api/lists/${s.listId}'),
      headers: {'authorization': 'Bearer ${keys.access}'},
      json: {
        'accessHash': await JoeCrypto.tokenHash(keys.access),
        'ownerHash': ownerHash,
        'code': s.hasCode,
      },
    );
    final problem = _problem(reply);
    if (problem != null) return problem;
    // Die neue Epoche merkt sich erst der Abruf: sieht er eine andere als
    // die gemerkte, baut er neu auf.
    s.epoch ??= reply!.body['epoch'] as String?;
    _times(s, reply!);
    return null;
  }

  // -------------------------------------------------------------- Beitreten

  /// Fragt, ob es die Liste gibt und ob sie einen Code braucht. Wirft
  /// [SyncFailure] (offline, unbekannt, geloescht ...).
  Future<ListMeta> inspect(ShareLink link) async {
    final reply = await _send(
      'GET',
      _url(link.server, '/api/lists/${link.listId}/meta'),
    );
    if (reply?.status == 404) {
      throw const SyncFailure(SyncStatus.failed, 'unknown');
    }
    final problem = _problem(reply);
    if (problem != null) throw SyncFailure(problem.status, problem.reason);
    return ListMeta(code: reply!.body['code'] == true);
  }

  /// Tritt einer geteilten Liste bei und holt ihren Stand. Wirft
  /// [SyncFailure], z. B. [SyncStatus.unauthorized] bei falschem Code.
  Future<ShareState> join(ShareLink link, {String? code}) async {
    final normalized = normalizeCode(code);
    final s = ShareState(
      server: link.server,
      listId: link.listId,
      secret: b64(link.secret),
      code: normalized.isEmpty ? null : normalized,
    );
    final outcome = await sync(s, heal: false);
    if (!outcome.ok) throw SyncFailure(outcome.status, outcome.reason);
    return s;
  }

  // -------------------------------------------------------------- Abgleich

  /// Ein Abgleich (Konzept 5.3): Warteschlange hoch, Neues runter. Laeuft
  /// fuer dieselbe Liste nie doppelt; ein zweiter Aufruf waehrend des ersten
  /// bekommt dessen Ergebnis.
  Future<SyncOutcome> sync(ShareState s, {bool heal = true}) {
    final running = _running[s.listId];
    if (running != null) return running;
    // Block statt Pfeil: remove liefert den Future selbst zurueck, und
    // whenComplete wuerde auf ihn warten – auf sich selbst.
    final future = _sync(s, heal).whenComplete(() {
      _running.remove(s.listId);
    });
    return _running[s.listId] = future;
  }

  Future<SyncOutcome> _sync(ShareState s, bool heal) async {
    final keys = await _keysOf(s);
    final before = jsonEncode(_visible(s.view));
    var skipped = 0;
    var healed = false;

    Future<SyncOutcome?> handle404(SyncReply? reply) async {
      if (reply?.status != 404) return null;
      // Der Server hat die Liste verloren (Konzept 6.4): neu anlegen, dann
      // baut der Abruf auf der neuen Epoche auf.
      if (!heal || healed) {
        return const SyncOutcome(SyncStatus.failed, reason: 'unknown');
      }
      healed = true;
      return await _put(s);
    }

    // 1. Hochladen.
    final upload = await _upload(s, keys);
    if (upload != null) {
      if (upload.reply?.status != 404) return upload.outcome!;
      final problem = await handle404(upload.reply);
      if (problem != null) return problem;
      // Neu angelegt: der Abruf sieht die neue Epoche und baut neu auf.
    }

    // 2. Abrufen; bei neuer Epoche neu aufbauen und Fehlendes nachreichen.
    for (var round = 0; round < 3; round++) {
      final fetched = await _fetch(s, keys);
      if (fetched.reply?.status == 404) {
        final problem = await handle404(fetched.reply);
        if (problem != null) return problem;
        continue;
      }
      if (fetched.outcome != null) return fetched.outcome!;
      skipped += fetched.skipped;
      if (fetched.rebased == null) break;
      // Was dieses Geraet hatte und der neue Stand nicht kennt, wieder
      // anlegen. Geloeschtes bleibt geloescht, Vorhandenes unangetastet.
      _restore(s, fetched.rebased!);
      final again = await _upload(s, keys);
      if (again != null) {
        return again.outcome ?? const SyncOutcome(SyncStatus.failed);
      }
    }

    s.lastSync = DateTime.now();
    final after = jsonEncode(_visible(s.view));
    return SyncOutcome(
      SyncStatus.ok,
      changed: before != after,
      skipped: skipped,
    );
  }

  /// Laedt alles aus der Warteschlange hoch, was noch nicht bestaetigt
  /// ist. `null` bei Erfolg (oder wenn nichts zu tun war).
  Future<({SyncReply? reply, SyncOutcome? outcome})?> _upload(
    ShareState s,
    ({List<int> key, String access}) keys,
  ) async {
    final open = [
      for (final op in s.outbox)
        if (!s.acked.contains(op.id)) op,
    ];
    for (var i = 0; i < open.length; i += SyncLimits.maxOpsPerRequest) {
      final chunk = open.skip(i).take(SyncLimits.maxOpsPerRequest).toList();
      final reply = await _send(
        'POST',
        _url(s.server, '/api/lists/${s.listId}/ops'),
        headers: {'authorization': 'Bearer ${keys.access}'},
        json: {
          'ops': [
            for (final op in chunk)
              {
                'id': op.id,
                'blob': await JoeCrypto.seal(
                  keys.key,
                  s.listId,
                  op.id,
                  op.toBody(),
                ),
              },
          ],
        },
      );
      final problem = _problem(reply);
      if (problem != null) return (reply: reply, outcome: problem);
      s.acked.addAll(chunk.map((op) => op.id));
      _times(s, reply!);
    }
    return null;
  }

  /// Holt alle neuen Operationen. Bei neuer Epoche (oder wenn der Server
  /// weniger hat, als dieses Geraet schon gelesen hat: Wiederherstellung
  /// aus einem Backup) wird von vorn aufgebaut; [rebased] ist dann der
  /// alte sichtbare Stand.
  Future<
    ({
      SyncReply? reply,
      SyncOutcome? outcome,
      int skipped,
      SharedListState? rebased,
    })
  >
  _fetch(ShareState s, ({List<int> key, String access}) keys) async {
    var skipped = 0;
    SharedListState? rebased;
    while (true) {
      final reply = await _send(
        'GET',
        _url(s.server, '/api/lists/${s.listId}/ops', {'after': '${s.lastSeq}'}),
        headers: {'authorization': 'Bearer ${keys.access}'},
      );
      final problem = _problem(reply);
      if (problem != null) {
        return (
          reply: reply,
          outcome: problem,
          skipped: skipped,
          rebased: rebased,
        );
      }
      final body = reply!.body;
      final epoch = body['epoch'] as String?;
      final head = body['head'] as int? ?? 0;
      if (rebased == null &&
          s.lastSeq > 0 &&
          (epoch != s.epoch || head < s.lastSeq)) {
        rebased = s.view;
        s.confirmed = SharedListState();
        s.lastSeq = 0;
        s.outbox.clear();
        s.acked.clear();
        s.invalidate();
        s.epoch = epoch;
        continue;
      }
      s.epoch = epoch;
      s.ownerHash = body['ownerHash'] as String? ?? s.ownerHash;
      _times(s, reply);

      final ops = [
        for (final raw in body['ops'] as List? ?? const [])
          WireOp.fromJson((raw as Map).cast<String, Object?>()),
      ];
      for (final wire in ops) {
        try {
          final clear = await JoeCrypto.open(
            keys.key,
            s.listId,
            wire.id,
            wire.blob,
          );
          s.confirmed.apply(Op.fromBody(wire.id, clear), at: wire.at);
        } on SyncCryptoException {
          skipped++;
        } on FormatException {
          skipped++;
        } on UnsupportedOpException {
          skipped++;
        }
        s.lastSeq = wire.seq;
        // Eigene Operation zurueck: sie gilt jetzt als bestaetigt.
        s.acked.remove(wire.id);
        s.outbox.removeWhere((op) => op.id == wire.id);
      }
      final now = _time(body['now']);
      if (now != null) s.confirmed.advance(now);
      s.invalidate();
      if (body['more'] != true) {
        return (
          reply: reply,
          outcome: null,
          skipped: skipped,
          rebased: rebased,
        );
      }
    }
  }

  /// Nach einem Neuaufbau: Name und Eintraege aus [old], die der neue Stand
  /// nicht kennt, als neue Operationen einreihen.
  void _restore(ShareState s, SharedListState old) {
    final current = s.view;
    final name = old.nameValue;
    if (current.name == null && name != null) {
      s.record(Op.rename(newId(), device, current, name));
    }
    for (final item in old.visibleItems) {
      if (current.items.containsKey(item.id)) continue;
      s.record(
        Op.add(
          newId(),
          device,
          item: item.id,
          title: item.titleValue,
          done: item.isDone,
          createdAt: item.createdAt,
        ),
      );
    }
  }

  static List<Object?> _visible(SharedListState view) => [
    view.nameValue,
    for (final item in view.visibleItems)
      [item.id, item.titleValue, item.isDone],
    for (final c in view.conflicts.values) [c.id, c.value],
  ];

  // -------------------------------------------------------------- Ersteller

  Future<String> _ownerToken(ShareState s) =>
      JoeCrypto.ownerToken(s.listId, unb64(s.ownerSecret!));

  /// Fuer alle loeschen (G5). Nur mit Ersteller-Geheimnis. Wirft
  /// [SyncFailure], wenn es nicht geht; eine schon geloeschte oder
  /// abgelaufene Liste gilt als erledigt.
  Future<void> deleteForAll(ShareState s) async {
    if (!s.isOwner) throw const SyncFailure(SyncStatus.unauthorized);
    final reply = await _send(
      'DELETE',
      _url(s.server, '/api/lists/${s.listId}'),
      headers: {'x-joe-owner': await _ownerToken(s)},
    );
    if (reply?.status == 404 || reply?.status == 410) return;
    final problem = _problem(reply);
    if (problem != null) throw SyncFailure(problem.status, problem.reason);
  }

  /// Fragt als Ersteller nach der Frist (Konzept 6.6, Variante B). Zaehlt
  /// nicht als Zugriff. Wirft [SyncFailure].
  Future<ListMeta> ownerMeta(ShareState s) async {
    if (!s.isOwner) throw const SyncFailure(SyncStatus.unauthorized);
    final reply = await _send(
      'GET',
      _url(s.server, '/api/lists/${s.listId}/meta'),
      headers: {'x-joe-owner': await _ownerToken(s)},
    );
    if (reply?.status == 404) {
      throw const SyncFailure(SyncStatus.failed, 'unknown');
    }
    final problem = _problem(reply);
    if (problem != null) throw SyncFailure(problem.status, problem.reason);
    final meta = ListMeta(
      code: reply!.body['code'] == true,
      expiresAt: _time(reply.body['expiresAt']),
      now: _time(reply.body['now']),
    );
    if (meta.expiresAt != null) s.expiresAt = meta.expiresAt;
    return meta;
  }
}
