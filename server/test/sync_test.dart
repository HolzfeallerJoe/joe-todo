import 'package:joe_sync/joe_sync.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Abgleich Ende zu Ende: mehrere Geraete mit dem echten Client gegen den
/// echten Handler (Konzept 5.3, 5.4, 6.4).
void main() {
  late TestServer server;
  late SyncClient anna;
  late SyncClient ben;
  final created = DateTime.utc(2026, 10, 14, 7);

  setUp(() {
    server = TestServer();
    anna = SyncClient(transport: server.transport, device: 'anna');
    ben = SyncClient(transport: server.transport, device: 'ben');
  });

  List<String> titles(ShareState s) => [
    for (final item in s.view.visibleItems)
      '${item.titleValue}${item.isDone ? ' ✓' : ''}',
  ];

  Future<ShareState> share({bool withCode = false}) => anna.create(
    server: 'http://joe.test',
    name: 'Baumarkt',
    withCode: withCode,
    items: [
      SnapshotItem(
        id: 'i1',
        title: 'Schrauben',
        done: false,
        createdAt: created,
      ),
      SnapshotItem(id: 'i2', title: 'Duebel', done: true, createdAt: created),
    ],
  );

  test('teilen und beitreten', () async {
    final mine = await share();
    expect(mine.isOwner, isTrue);
    expect(mine.outbox, isEmpty);
    expect(mine.expiresAt, DateTime.utc(2027, 10, 14, 8));

    final link = ShareLink.tryParse('Hier: ${mine.link}')!;
    expect((await ben.inspect(link)).code, isFalse);
    final theirs = await ben.join(link);
    expect(theirs.isOwner, isFalse);
    expect(theirs.view.nameValue, 'Baumarkt');
    expect(titles(theirs), ['Schrauben', 'Duebel ✓']);
    expect(theirs.ownerHash, mine.ownerHash);
  });

  test('Aenderungen gehen hin und her, auch offline gesammelt', () async {
    final mine = await share();
    final theirs = await ben.join(mine.link);

    theirs.record(
      Op.add(newId(), 'ben', item: 'i3', title: 'Leim', createdAt: created),
    );
    theirs.record(Op.done(newId(), 'ben', theirs.view, 'i1', true));
    expect(titles(theirs), ['Schrauben ✓', 'Duebel ✓', 'Leim']);
    expect(theirs.unsent, 2);
    expect((await ben.sync(theirs)).ok, isTrue);
    expect(theirs.unsent, 0);
    expect(theirs.outbox, isEmpty);

    // Offline: zwei Aenderungen warten, dann geht beides raus.
    server.offline = true;
    mine.record(Op.title(newId(), 'anna', mine.view, 'i2', 'Duebel 6mm'));
    mine.record(Op.delete(newId(), 'anna', mine.view, 'i2'));
    expect((await anna.sync(mine)).status, SyncStatus.offline);
    expect(mine.unsent, 2);
    server.offline = false;

    final outcome = await anna.sync(mine);
    expect(outcome.ok, isTrue);
    expect(outcome.changed, isTrue);
    expect(titles(mine), ['Schrauben ✓', 'Leim']);
    await ben.sync(theirs);
    expect(titles(theirs), ['Schrauben ✓', 'Leim']);
  });

  test(
    'Konflikt: wer spaeter kommt, entscheidet; danach gilt es fuer alle',
    () async {
      final mine = await share();
      final theirs = await ben.join(mine.link);

      // Beide benennen „Schrauben“ um, Anna zuerst.
      mine.record(Op.title(newId(), 'anna', mine.view, 'i1', 'Schrauben 4x40'));
      theirs.record(Op.title(newId(), 'ben', theirs.view, 'i1', 'Spax'));
      await anna.sync(mine);
      await ben.sync(theirs);

      expect(titles(theirs).first, 'Schrauben 4x40');
      final conflict = theirs.view.conflicts.values.single;
      expect(conflict.device, 'ben');
      expect(conflict.value, 'Spax');

      // Anna sieht den Konflikt auch, aber er gehoert Ben.
      await anna.sync(mine);
      expect(mine.view.conflicts.values.single.device, 'ben');

      theirs.record(Op.resolve(newId(), 'ben', conflict.id, true));
      await ben.sync(theirs);
      await anna.sync(mine);
      expect(titles(mine).first, 'Spax');
      expect(mine.view.conflicts, isEmpty);
      expect(theirs.view.conflicts, isEmpty);
    },
  );

  test('mit Code: ohne oder mit falschem Code kein Zutritt', () async {
    final mine = await share(withCode: true);
    expect(mine.code, matches(RegExp(r'^\d{6}$')));
    expect(mine.link.toString(), isNot(contains(mine.code!)));
    expect((await ben.inspect(mine.link)).code, isTrue);

    await expectLater(
      ben.join(mine.link),
      throwsA(
        isA<SyncFailure>().having(
          (f) => f.status,
          'status',
          SyncStatus.unauthorized,
        ),
      ),
    );
    final wrong = mine.code == '000000' ? '111111' : '000000';
    await expectLater(
      ben.join(mine.link, code: wrong),
      throwsA(
        isA<SyncFailure>().having(
          (f) => f.status,
          'status',
          SyncStatus.unauthorized,
        ),
      ),
    );
    final theirs = await ben.join(mine.link, code: mine.code);
    expect(titles(theirs), ['Schrauben', 'Duebel ✓']);
  });

  test('Loeschen fuer alle: die anderen bekommen gone/deleted', () async {
    final mine = await share();
    final theirs = await ben.join(mine.link);
    await expectLater(ben.deleteForAll(theirs), throwsA(isA<SyncFailure>()));
    await anna.deleteForAll(mine);
    final outcome = await ben.sync(theirs);
    expect(outcome.status, SyncStatus.gone);
    expect(outcome.reason, 'deleted');
    // Die lokale Kopie bleibt.
    expect(titles(theirs), ['Schrauben', 'Duebel ✓']);
    await expectLater(
      ben.join(mine.link),
      throwsA(isA<SyncFailure>().having((f) => f.reason, 'reason', 'deleted')),
    );
  });

  test(
    'Frist: Abgleich verlaengert, Ersteller fragt ohne zu verlaengern',
    () async {
      final mine = await share();
      final theirs = await ben.join(mine.link);
      server.advance(const Duration(days: 100));
      final meta = await anna.ownerMeta(mine);
      expect(meta.expiresAt, DateTime.utc(2027, 10, 14, 8));
      await ben.sync(theirs);
      expect(theirs.expiresAt, DateTime.utc(2028, 1, 22, 8));
      expect(
        (await anna.ownerMeta(mine)).expiresAt,
        DateTime.utc(2028, 1, 22, 8),
      );
      await expectLater(ben.ownerMeta(theirs), throwsA(isA<SyncFailure>()));

      server.advance(const Duration(days: 400));
      server.api.maintenance();
      await expectLater(
        anna.ownerMeta(mine),
        throwsA(
          isA<SyncFailure>().having((f) => f.reason, 'reason', 'expired'),
        ),
      );
      final outcome = await ben.sync(theirs);
      expect(outcome.status, SyncStatus.gone);
      expect(outcome.reason, 'expired');
    },
  );

  test(
    'Selbstheilung: Server verliert alles, das erste Geraet stellt her',
    () async {
      final mine = await share();
      final theirs = await ben.join(mine.link);
      theirs.record(
        Op.add(newId(), 'ben', item: 'i3', title: 'Leim', createdAt: created),
      );
      await ben.sync(theirs);
      await anna.sync(mine);

      server.wipe();

      // Ben ist zuerst wieder da und hat noch eine offene Aenderung.
      theirs.record(Op.done(newId(), 'ben', theirs.view, 'i3', true));
      final healed = await ben.sync(theirs);
      expect(healed.ok, isTrue);
      expect(titles(theirs), ['Schrauben', 'Duebel ✓', 'Leim ✓']);
      expect(theirs.view.nameValue, 'Baumarkt');

      // Anna gleicht danach ab und bekommt denselben Stand, ohne Doppelte.
      mine.record(
        Op.add(
          newId(),
          'anna',
          item: 'i4',
          title: 'Silikon',
          createdAt: created,
        ),
      );
      final rebuilt = await anna.sync(mine);
      expect(rebuilt.ok, isTrue);
      expect(titles(mine), ['Schrauben', 'Duebel ✓', 'Leim ✓', 'Silikon']);
      await ben.sync(theirs);
      expect(titles(theirs), titles(mine));

      // Annas Ersteller-Rechte gelten auf der neuen Liste weiter.
      await anna.deleteForAll(mine);
      expect((await ben.sync(theirs)).status, SyncStatus.gone);
    },
  );

  test('ein zweiter Abgleich waehrend des ersten laeuft nicht doppelt', () async {
    final mine = await share();
    mine.record(
      Op.add(newId(), 'anna', item: 'i3', title: 'Leim', createdAt: created),
    );
    final a = anna.sync(mine);
    final b = anna.sync(mine);
    expect(identical(a, b), isTrue);
    await a;
    final ops = await server.call(
      'GET',
      '/api/lists/${mine.listId}/ops',
      headers: {
        'authorization':
            'Bearer ${await JoeCrypto.accessToken(mine.listId, unb64(mine.secret), null)}',
      },
    );
    expect((await body(ops))['ops'] as List, hasLength(4));
  });

  test('Speichern und Laden der Freigabe verliert nichts', () async {
    final mine = await share(withCode: true);
    server.offline = true;
    mine.record(Op.title(newId(), 'anna', mine.view, 'i1', 'Spax'));
    await anna.sync(mine);
    final back = ShareState.fromJson(mine.toJson());
    expect(back.code, mine.code);
    expect(back.ownerSecret, mine.ownerSecret);
    expect(back.unsent, 1);
    expect(titles(back), titles(mine));
    server.offline = false;
    expect((await anna.sync(back)).ok, isTrue);
    expect(back.unsent, 0);
  });
}
