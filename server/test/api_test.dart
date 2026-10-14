import 'package:joe_sync/joe_sync.dart';
import 'package:joe_sync_server/joe_sync_server.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Zugang zu einer Testliste, wie ihn ein Geraet ausrechnet.
class Access {
  final String id = newId();
  final List<int> secret = newSecret();
  final List<int> ownerSecret = newSecret();
  final String? code;
  late String token;
  late String ownerToken;

  Access({this.code});

  Future<Access> init() async {
    token = await JoeCrypto.accessToken(id, secret, code);
    ownerToken = await JoeCrypto.ownerToken(id, ownerSecret);
    return this;
  }

  Map<String, String> get auth => {'authorization': 'Bearer $token'};
  Map<String, String> get owner => {'x-joe-owner': ownerToken};

  Future<Map<String, Object?>> createBody() async => {
    'accessHash': await JoeCrypto.tokenHash(token),
    'ownerHash': await JoeCrypto.tokenHash(ownerToken),
    'code': code != null,
  };
}

void main() {
  late TestServer server;
  late Access list;

  setUp(() async {
    server = TestServer();
    list = await Access().init();
  });

  Future<int> create(Access a, {Map<String, String>? headers}) async =>
      (await server.call(
        'PUT',
        '/api/lists/${a.id}',
        headers: headers ?? a.auth,
        json: await a.createBody(),
      )).statusCode;

  Future<Map<String, Object?>> upload(Access a, List<String> ids) async {
    final response = await server.call(
      'POST',
      '/api/lists/${a.id}/ops',
      headers: a.auth,
      json: {
        'ops': [
          for (final id in ids) {'id': id, 'blob': 'AAAA$id'},
        ],
      },
    );
    expect(response.statusCode, 200);
    return body(response);
  }

  Future<Map<String, Object?>> fetch(Access a, [int after = 0]) async {
    final response = await server.call(
      'GET',
      '/api/lists/${a.id}/ops?after=$after',
      headers: a.auth,
    );
    expect(response.statusCode, 200);
    return body(response);
  }

  Future<int> status(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? json,
  }) async => (await server.call(
    method,
    path,
    headers: headers,
    json: json,
  )).statusCode;

  group('Anlegen', () {
    test('neu, dann idempotent, mit fremden Hashes Konflikt', () async {
      expect(await create(list), 201);
      expect(await create(list), 200);
      final other = await Access().init();
      final json = {
        ...await list.createBody(),
        'ownerHash': (await other.createBody())['ownerHash'],
      };
      expect(
        await status(
          'PUT',
          '/api/lists/${list.id}',
          headers: list.auth,
          json: json,
        ),
        409,
      );
    });

    test('nur wer das Token hat, legt an', () async {
      final other = await Access().init();
      expect(await create(list, headers: other.auth), 401);
      expect(await create(list, headers: {}), 401);
    });

    test('Unsinn wird abgelehnt', () async {
      expect(
        await status(
          'PUT',
          '/api/lists/${list.id}',
          headers: list.auth,
          json: {'accessHash': 'x', 'ownerHash': 'y', 'code': false},
        ),
        400,
      );
      expect(
        await status('PUT', '/api/lists/kurz', headers: list.auth, json: {}),
        400,
      );
    });

    test('hoechstens 50 neue Listen je Adresse und Tag', () async {
      for (var i = 0; i < 50; i++) {
        expect(await create(await Access().init()), 201);
      }
      expect(await create(await Access().init()), 429);
      server.advance(const Duration(days: 1, minutes: 1));
      expect(await create(await Access().init()), 201);
    });
  });

  group('Operationen', () {
    setUp(() async => expect(await create(list), 201));

    test('hoch und runter, in Reihenfolge, mit seq und Zeit', () async {
      final ids = [newId(), newId(), newId()];
      final up = await upload(list, ids);
      final accepted = (up['accepted'] as List).cast<Map>();
      expect(accepted.map((a) => a['id']), ids);
      final seqs = accepted.map((a) => a['seq'] as int).toList();
      expect(seqs, orderedEquals([...seqs]..sort()));
      expect(up['expiresAt'], '2027-10-14T08:00:00.000Z');

      final down = await fetch(list);
      final ops = (down['ops'] as List)
          .cast<Map<String, Object?>>()
          .map(WireOp.fromJson)
          .toList();
      expect(ops.map((o) => o.id), ids);
      expect(ops.first.blob, 'AAAA${ids.first}');
      expect(ops.first.at, server.now);
      expect(down['more'], false);
      expect(down['head'], seqs.last);
      expect(down['epoch'], up['epoch']);
      expect(down['ownerHash'], await JoeCrypto.tokenHash(list.ownerToken));

      final later = await fetch(list, seqs[1]);
      expect((later['ops'] as List).single['id'], ids.last);
    });

    test('ein Wiederholungsversuch verdoppelt nichts', () async {
      final ids = [newId(), newId()];
      final first = await upload(list, ids);
      final again = await upload(list, [ids[1], newId()]);
      expect(
        (again['accepted'] as List).first['seq'],
        (first['accepted'] as List)[1]['seq'],
      );
      expect((await fetch(list))['ops'] as List, hasLength(3));
    });

    test('in Seiten zu 500', () async {
      final ids = [for (var i = 0; i < 501; i++) newId()];
      await upload(list, ids.take(500).toList());
      await upload(list, ids.skip(500).toList());
      final first = await fetch(list);
      expect(first['ops'] as List, hasLength(500));
      expect(first['more'], true);
      final last = (first['ops'] as List).last['seq'] as int;
      final second = await fetch(list, last);
      expect((second['ops'] as List).single['id'], ids.last);
      expect(second['more'], false);
    });

    test('Grenzen: Anzahl, Groesse, IDs', () async {
      Future<int> post(Object json) => status(
        'POST',
        '/api/lists/${list.id}/ops',
        headers: list.auth,
        json: json,
      );
      expect(await post({'ops': []}), 400);
      expect(
        await post({
          'ops': [
            for (var i = 0; i < 501; i++) {'id': newId(), 'blob': 'A'},
          ],
        }),
        400,
      );
      expect(
        await post({
          'ops': [
            {'id': newId(), 'blob': 'A' * (SyncLimits.maxBlob + 1)},
          ],
        }),
        400,
      );
      expect(
        await post({
          'ops': [
            {'id': 'kurz', 'blob': 'A'},
          ],
        }),
        400,
      );
      expect(await post({'nix': 1}), 400);
    });

    test('ohne oder mit falschem Token: 401, unbekannt: 404', () async {
      final other = await Access().init();
      expect(
        await status('GET', '/api/lists/${list.id}/ops', headers: other.auth),
        401,
      );
      expect(await status('GET', '/api/lists/${list.id}/ops'), 401);
      expect(
        await status('GET', '/api/lists/${other.id}/ops', headers: other.auth),
        404,
      );
    });
  });

  group('Code', () {
    late Access coded;

    setUp(() async {
      coded = await Access(code: '123456').init();
      expect(await create(coded), 201);
    });

    test('meta verraet, dass ein Code noetig ist', () async {
      final meta = await body(
        await server.call('GET', '/api/lists/${coded.id}/meta'),
      );
      expect(meta, {'exists': true, 'code': true});
    });

    test('nach 10 Fehlversuchen je Stunde gebremst, auch richtige', () async {
      final guess = await JoeCrypto.accessToken(
        coded.id,
        coded.secret,
        '000000',
      );
      final path = '/api/lists/${coded.id}/ops';
      for (var i = 0; i < 10; i++) {
        expect(
          await status(
            'GET',
            path,
            headers: {'authorization': 'Bearer $guess'},
          ),
          401,
        );
      }
      expect(await status('GET', path, headers: coded.auth), 429);
      server.advance(const Duration(hours: 1, minutes: 1));
      expect(await status('GET', path, headers: coded.auth), 200);
    });

    test('ohne Code wird nicht gebremst', () async {
      expect(await create(list), 201);
      final other = await Access().init();
      final path = '/api/lists/${list.id}/ops';
      for (var i = 0; i < 15; i++) {
        expect(await status('GET', path, headers: other.auth), 401);
      }
      expect(await status('GET', path, headers: list.auth), 200);
    });
  });

  group('Ersteller, Frist, Loeschen', () {
    setUp(() async => expect(await create(list), 201));

    Future<Map<String, Object?>> meta(Map<String, String> headers) async =>
        body(
          await server.call(
            'GET',
            '/api/lists/${list.id}/meta',
            headers: headers,
          ),
        );

    test('meta mit Ersteller-Token nennt die Frist, zaehlt nicht', () async {
      server.advance(const Duration(days: 10));
      final first = await meta(list.owner);
      expect(first['expiresAt'], '2027-10-14T08:00:00.000Z');
      expect(first['now'], '2026-10-24T08:00:00.000Z');
      // Ein Abruf verlaengert.
      await fetch(list);
      expect((await meta(list.owner))['expiresAt'], '2027-10-24T08:00:00.000Z');
      // Fremdes Ersteller-Token: nur das Oeffentliche.
      final other = await Access().init();
      expect((await meta(other.owner)).containsKey('expiresAt'), isFalse);
    });

    test('nur der Ersteller loescht fuer alle; danach 410 deleted', () async {
      await upload(list, [newId()]);
      final path = '/api/lists/${list.id}';
      expect(await status('DELETE', path, headers: list.auth), 403);
      expect(await status('DELETE', path, headers: list.owner), 204);
      final gone = await server.call('GET', '$path/ops', headers: list.auth);
      expect(gone.statusCode, 410);
      expect((await body(gone))['reason'], 'deleted');
      // Nicht wiederzubeleben.
      expect(await create(list), 410);
      expect(server.store.counts().ops, 0);
    });

    test('ab expiresAt sofort 410 expired, ohne den taeglichen Lauf', () async {
      server.advance(const Duration(days: 365));
      final meta = await server.call(
        'GET',
        '/api/lists/${list.id}/meta',
        headers: list.owner,
      );
      expect(meta.statusCode, 410);
      expect((await body(meta))['reason'], 'expired');
      // Ein spaeter Zugriff holt sie nicht zurueck.
      final ops = await server.call(
        'GET',
        '/api/lists/${list.id}/ops',
        headers: list.auth,
      );
      expect(ops.statusCode, 410);
    });

    test('nach 12 Monaten ohne Zugriff entteilt; 410 expired', () async {
      await upload(list, [newId()]);
      server.advance(const Duration(days: 364));
      server.api.maintenance();
      expect(await status('GET', '/api/lists/${list.id}/meta'), 200);
      server.advance(const Duration(days: 1));
      server.api.maintenance();
      final gone = await server.call(
        'GET',
        '/api/lists/${list.id}/ops',
        headers: list.auth,
      );
      expect(gone.statusCode, 410);
      expect((await body(gone))['reason'], 'expired');
      expect(server.store.counts().ops, 0);
      expect(server.lines, contains(endsWith('1 Liste(n) entteilt')));
    });
  });

  group('Drumherum', () {
    test('health', () async {
      final health = await body(await server.call('GET', '/health'));
      expect(health['status'], 'ok');
      expect(health['version'], SyncApi.version);
    });

    test('assetlinks nur, wenn Fingerabdruecke gesetzt sind', () async {
      expect(await status('GET', '/.well-known/assetlinks.json'), 404);
      final withLinks = TestServer(
        config: const ServerConfig(androidFingerprints: ['AB:CD']),
      );
      final response = await withLinks.call(
        'GET',
        '/.well-known/assetlinks.json',
      );
      expect(response.statusCode, 200);
      final text = await response.readAsString();
      expect(text, contains('"dev.joe.joe_todo"'));
      expect(text, contains('"AB:CD"'));
    });

    test('Webseite unter /l/<id> mit strengen Koepfen', () async {
      final response = await server.call('GET', '/l/${list.id}');
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('text/html'));
      expect(
        response.headers['content-security-policy'],
        contains("script-src 'self'"),
      );
      expect(response.headers['referrer-policy'], 'no-referrer');
      expect(await status('GET', '/assets/app.js'), 200);
      expect(await status('GET', '/assets/geheim.txt'), 404);
      expect(await status('GET', '/assets/..%2Fpubspec.yaml'), 404);
    });

    test('das Log enthaelt keine Tokens', () async {
      expect(await create(list), 201);
      await upload(list, [newId()]);
      await fetch(list);
      final log = server.lines.join('\n');
      expect(log, isNot(contains(list.token)));
      expect(log, isNot(contains(list.ownerToken)));
      expect(log, contains('GET /api/lists/${list.id}/ops 200'));
    });

    test('Konfiguration aus der Umgebung', () {
      final config = ServerConfig.fromEnvironment({
        'JOE_PORT': '9000',
        'JOE_DB': '/data/x.db',
        'JOE_RETENTION_DAYS': '30',
        'JOE_TRUST_PROXY': 'true',
        'JOE_ANDROID_FINGERPRINTS': 'ab:cd, ef:01',
      });
      expect(config.port, 9000);
      expect(config.database, '/data/x.db');
      expect(config.retention, const Duration(days: 30));
      expect(config.trustProxy, isTrue);
      expect(config.androidFingerprints, ['AB:CD', 'EF:01']);
      expect(ServerConfig.fromEnvironment({}).trustProxy, isFalse);
    });
  });
}
