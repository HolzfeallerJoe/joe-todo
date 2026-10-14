import 'dart:convert';
import 'dart:io';

import 'package:joe_sync/joe_sync.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'limits.dart';
import 'store.dart';

/// Die Schnittstelle aus Konzept 5.2 plus Webseite, App Links und Health.
///
/// Der Server sieht Listen-IDs, Operations-IDs, Zeiten und verschluesselte
/// Bloecke. Tokens vergleicht er nur als Hash, geloggt wird nichts davon.
class SyncApi {
  final Store store;
  final ServerConfig config;
  final DateTime Function() clock;
  final void Function(String line) log;

  final RateLimiter _newLists;
  final RateLimiter _failuresByIp;
  final RateLimiter _failuresByList;

  SyncApi({
    required this.store,
    required this.config,
    DateTime Function()? clock,
    void Function(String line)? log,
  }) : clock = clock ?? (() => DateTime.now().toUtc()),
       log = log ?? print,
       _newLists = RateLimiter(
         limit: config.newListsPerDay,
         window: const Duration(days: 1),
       ),
       _failuresByIp = RateLimiter(
         limit: config.codeFailuresPerHour,
         window: const Duration(hours: 1),
       ),
       // Mit vielen Adressen kommt man weiter, aber nicht beliebig weit.
       _failuresByList = RateLimiter(
         limit: config.codeFailuresPerHour * 10,
         window: const Duration(hours: 1),
       );

  static const version = '0.1.0';

  Handler get handler {
    final router = Router()
      ..get('/health', _health)
      ..get('/.well-known/assetlinks.json', _assetLinks)
      ..put('/api/lists/<id>', _create)
      ..get('/api/lists/<id>/meta', _meta)
      ..get('/api/lists/<id>/ops', _fetch)
      ..post('/api/lists/<id>/ops', _upload)
      ..delete('/api/lists/<id>', _delete)
      ..get('/l/<id>', _page)
      ..get('/assets/<file>', _asset);
    return const Pipeline()
        .addMiddleware(_logging)
        .addMiddleware(_headers)
        .addHandler(router.call);
  }

  // ---------------------------------------------------------------- Hilfen

  Response _json(int status, Map<String, Object?> body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _error(int status, String error, [Map<String, Object?>? extra]) =>
      _json(status, {'error': error, ...?extra});

  Response _gone(ListRecord list) => _error(410, 'gone', {
    'reason': list.deletedAt != null ? 'deleted' : 'expired',
  });

  DateTime _expiresAt(DateTime lastAccess) => lastAccess.add(config.retention);

  Map<String, Object?> _times(DateTime lastAccess) => {
    'expiresAt': _expiresAt(lastAccess).toIso8601String(),
    'now': clock().toIso8601String(),
  };

  String _ip(Request request) {
    if (config.trustProxy) {
      final real = request.headers['x-real-ip'];
      if (real != null && real.trim().isNotEmpty) return real.trim();
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.trim().isNotEmpty) {
        // Der letzte Eintrag stammt vom Proxy selbst; die vorderen kann
        // jeder mitschicken.
        return forwarded.split(',').last.trim();
      }
    }
    final info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) return info.remoteAddress.address;
    return 'unbekannt';
  }

  static String? _bearer(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring(7).trim();
  }

  /// Hash eines Tokens aus einem Kopf; `null` bei Unsinn.
  static Future<String?> _hashOf(String? token) async {
    if (token == null) return null;
    try {
      if (unb64(token).length != 32) return null;
      return await JoeCrypto.tokenHash(token);
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, Object?>?> _body(Request request) async {
    try {
      final text = await request.readAsString();
      if (text.length >
          SyncLimits.maxBlob * (SyncLimits.maxOpsPerRequest + 1)) {
        return null;
      }
      final body = jsonDecode(text);
      return body is Map<String, Object?> ? body : null;
    } on FormatException {
      return null;
    }
  }

  /// Prueft Liste und Zugangstoken. Liefert entweder die Liste oder die
  /// Fehlerantwort.
  Future<(ListRecord?, Response?)> _authorize(
    Request request,
    String id,
  ) async {
    if (!isValidId(id)) return (null, _error(404, 'unknown'));
    final list = store.list(id);
    if (list == null) return (null, _error(404, 'unknown'));
    if (list.gone) return (null, _gone(list));

    final now = clock();
    final ip = _ip(request);
    final byIp = '$id|$ip';
    // Raten lohnt nur, wo ein Code im Spiel ist; ein Token ohne Code hat
    // 256 Bit.
    if (list.code &&
        (_failuresByIp.blocked(byIp, now) ||
            _failuresByList.blocked(id, now))) {
      return (null, _error(429, 'rate-limited'));
    }
    final hash = await _hashOf(_bearer(request));
    if (hash != list.accessHash) {
      if (list.code) {
        _failuresByIp.hit(byIp, now);
        _failuresByList.hit(id, now);
      }
      return (null, _error(401, 'unauthorized'));
    }
    return (list, null);
  }

  // ------------------------------------------------------------- Endpunkte

  Response _health(Request request) {
    final counts = store.counts();
    return _json(200, {
      'status': 'ok',
      'version': version,
      'lists': counts.lists,
      'ops': counts.ops,
    });
  }

  Response _assetLinks(Request request) {
    if (config.androidFingerprints.isEmpty) return _error(404, 'not-found');
    return Response.ok(
      jsonEncode([
        {
          'relation': ['delegate_permission/common.handle_all_urls'],
          'target': {
            'namespace': 'android_app',
            'package_name': config.androidPackage,
            'sha256_cert_fingerprints': config.androidFingerprints,
          },
        },
      ]),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Anlegen, idempotent. Mit denselben Hashes noch einmal: wie neu
  /// angelegt (ein Wiederholungsversuch). Kennt der Server die ID nicht
  /// mehr (Ausfall, Konzept 6.4), legt er sie neu an, mit neuer Epoche.
  Future<Response> _create(Request request, String id) async {
    if (!isValidId(id)) return _error(400, 'bad-id');
    final body = await _body(request);
    final accessHash = body?['accessHash'];
    final ownerHash = body?['ownerHash'];
    final code = body?['code'];
    if (accessHash is! String ||
        ownerHash is! String ||
        code is! bool ||
        unb64Safe(accessHash)?.length != 32 ||
        unb64Safe(ownerHash)?.length != 32) {
      return _error(400, 'bad-request');
    }
    // Wer anlegt, muss das Token auch haben: so kann niemand eine Liste
    // mit einem Hash anlegen, dessen Token er nicht kennt.
    if (await _hashOf(_bearer(request)) != accessHash) {
      return _error(401, 'unauthorized');
    }
    final now = clock();
    final existing = store.list(id);
    if (existing != null) {
      if (existing.gone) return _gone(existing);
      if (existing.accessHash != accessHash ||
          existing.ownerHash != ownerHash) {
        return _error(409, 'exists');
      }
      store.touch(id, now);
      return _json(200, {'epoch': existing.epoch, ..._times(now)});
    }
    final ip = _ip(request);
    if (_newLists.blocked(ip, now)) return _error(429, 'rate-limited');
    _newLists.hit(ip, now);
    final list = store.create(
      id: id,
      accessHash: accessHash,
      ownerHash: ownerHash,
      code: code,
      now: now,
    );
    return _json(201, {'epoch': list.epoch, ..._times(now)});
  }

  /// Ohne Token: gibt es die Liste, braucht sie einen Code? Mit
  /// Ersteller-Token zusaetzlich `expiresAt`. Zaehlt nicht als Zugriff.
  Future<Response> _meta(Request request, String id) async {
    if (!isValidId(id)) return _error(404, 'unknown');
    final list = store.list(id);
    if (list == null) return _error(404, 'unknown');
    if (list.gone) return _gone(list);
    final owner = await _hashOf(request.headers['x-joe-owner']);
    return _json(200, {
      'exists': true,
      'code': list.code,
      if (owner != null && owner == list.ownerHash) ..._times(list.lastAccess),
    });
  }

  Future<Response> _fetch(Request request, String id) async {
    final (list, error) = await _authorize(request, id);
    if (error != null) return error;
    final after = int.tryParse(request.url.queryParameters['after'] ?? '0');
    if (after == null || after < 0) return _error(400, 'bad-after');
    final now = clock();
    store.touch(id, now);
    const limit = SyncLimits.maxOpsPerRequest;
    final ops = store.ops(id, after, limit + 1);
    final more = ops.length > limit;
    return _json(200, {
      'ops': [for (final op in ops.take(limit)) op.toJson()],
      'more': more,
      'head': store.head(id),
      'epoch': list!.epoch,
      'ownerHash': list.ownerHash,
      ..._times(now),
    });
  }

  Future<Response> _upload(Request request, String id) async {
    final (list, error) = await _authorize(request, id);
    if (error != null) return error;
    final body = await _body(request);
    final raw = body?['ops'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > SyncLimits.maxOpsPerRequest) {
      return _error(400, 'bad-request');
    }
    final ops = <({String id, String blob})>[];
    for (final entry in raw) {
      if (entry is! Map) return _error(400, 'bad-request');
      final opId = entry['id'];
      final blob = entry['blob'];
      if (opId is! String ||
          !isValidId(opId) ||
          blob is! String ||
          blob.isEmpty ||
          blob.length > SyncLimits.maxBlob) {
        return _error(400, 'bad-op');
      }
      ops.add((id: opId, blob: blob));
    }
    final now = clock();
    store.touch(id, now);
    final seqs = store.append(id, ops, now);
    return _json(200, {
      'accepted': [
        for (final op in ops) {'id': op.id, 'seq': seqs[op.id]},
      ],
      'epoch': list!.epoch,
      ..._times(now),
    });
  }

  Future<Response> _delete(Request request, String id) async {
    if (!isValidId(id)) return _error(404, 'unknown');
    final list = store.list(id);
    if (list == null) return _error(404, 'unknown');
    if (list.gone) return _gone(list);
    final owner = await _hashOf(request.headers['x-joe-owner']);
    if (owner == null || owner != list.ownerHash) {
      return _error(403, 'not-owner');
    }
    store.delete(id, clock());
    log('Liste geloescht');
    return Response(204);
  }

  // --------------------------------------------------------------- Webseite

  static const _assets = {
    'app.js': 'text/javascript; charset=utf-8',
    'merge.js': 'text/javascript; charset=utf-8',
    'crypto.js': 'text/javascript; charset=utf-8',
    'style.css': 'text/css; charset=utf-8',
    'icon.svg': 'image/svg+xml',
  };

  Response _file(String name, String type) {
    final file = File('${config.web}/$name');
    if (!file.existsSync()) return _error(404, 'not-found');
    return Response.ok(
      file.readAsBytesSync(),
      headers: {'content-type': type, 'cache-control': 'no-cache'},
    );
  }

  /// Fuer jede ID dieselbe Seite; die ID liest das Skript aus der Adresse.
  Response _page(Request request, String id) =>
      _file('index.html', 'text/html; charset=utf-8');

  Response _asset(Request request, String file) {
    final type = _assets[file];
    if (type == null) return _error(404, 'not-found');
    return _file(file, type);
  }

  // ------------------------------------------------------------ Middleware

  /// Strenge Koepfe fuer alles (Konzept 7.2): nur eigene Quelle, kein
  /// Referrer, kein Einbetten. So kommt kein fremdes Skript an den
  /// Schluessel im `#`.
  Handler _headers(Handler inner) => (request) async {
    final response = await inner(request);
    return response.change(
      headers: {
        'content-security-policy':
            "default-src 'none'; script-src 'self'; style-src 'self'; "
            "connect-src 'self'; img-src 'self' data:; manifest-src 'self'; "
            "base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        'referrer-policy': 'no-referrer',
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        if (request.url.path.startsWith('api/')) 'cache-control': 'no-store',
      },
    );
  };

  /// Eine Zeile je Anfrage: Methode, Pfad ohne Query, Status, Dauer.
  /// Tokens stehen in Koepfen, Geheimnisse hinter dem `#` – beides landet
  /// hier nie.
  Handler _logging(Handler inner) => (request) async {
    final watch = Stopwatch()..start();
    final response = await inner(request);
    log(
      '${request.method} /${request.url.path} ${response.statusCode} '
      '${watch.elapsedMilliseconds}ms',
    );
    return response;
  };

  // ---------------------------------------------------------------- Pflege

  /// Taeglicher Lauf: abgelaufene Listen entteilen, Bremsen aufraeumen.
  void maintenance() {
    final now = clock();
    final expired = store.expire(now, config.retention);
    _newLists.sweep(now);
    _failuresByIp.sweep(now);
    _failuresByList.sweep(now);
    log('Pflege: $expired Liste(n) entteilt');
  }
}

/// [unb64] ohne Ausnahme.
List<int>? unb64Safe(String text) {
  try {
    return unb64(text);
  } on FormatException {
    return null;
  }
}
