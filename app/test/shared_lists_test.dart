import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:joe_sync/joe_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/env.dart';
import 'package:joe_todo/log.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/shared_lists.dart';

import 'support/fake_sync_server.dart';

/// Geteilte Einkaufslisten in Modell und Abgleich (Konzept 5.3, 6.1): zwei
/// Geraete, jedes mit eigenem AppState und Dienst, gegen einen Server im
/// Speicher.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSyncServer server;
  final services = <SharedLists>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = FakeSyncServer();
    JoeEnv.debugSyncUrl = 'https://sync.example.org';
  });

  tearDown(() {
    JoeEnv.debugSyncUrl = null;
    for (final service in services) {
      service.dispose();
    }
    services.clear();
  });

  ShoppingItem item(String id, String title, {bool done = false}) =>
      ShoppingItem(
        id: id,
        title: title,
        done: done,
        createdAt: DateTime(2026, 10, 14, 9, int.parse(id)),
      );

  /// Ein Geraet: AppState mit einer Liste, dazu sein Dienst.
  (AppState, SharedLists) device({List<ShoppingItem> items = const []}) {
    final state = AppState()
      ..shoppingLists = [
        ShoppingList(id: 'l1', name: 'Baumarkt', items: [...items]),
      ];
    final service = SharedLists(transport: server);
    services.add(service);
    service.attach(state);
    // Abgeglichen wird hier nur, wenn der Test es sagt: die Zeitgeber nach
    // Aenderungen und beim Zeigen wuerden sonst mitten hineinfunken.
    state.onSharedEdit = null;
    return (state, service);
  }

  List<String> titles(ShoppingList list) => [
        for (final i in list.sortedItems) '${i.title}${i.done ? ' ✓' : ''}',
      ];

  Future<(ShoppingList, ShoppingList, SharedLists, SharedLists)> pair({
    bool withCode = false,
  }) async {
    final (annaState, anna) = device(
      items: [item('1', 'Schrauben'), item('2', 'Dübel', done: true)],
    );
    final mine = annaState.shoppingLists.single;
    final share = await anna.share(mine, withCode: withCode);
    final (_, ben) = device();
    final theirs = await ben.join(
      ShareLink.tryParse(share.link.toString())!,
      code: share.code,
    );
    // Was das Zeigen schon angestossen hat, abwarten, dann den Takt aus.
    await anna.syncList(mine);
    await ben.syncList(theirs);
    anna.stop();
    ben.stop();
    return (mine, theirs, anna, ben);
  }

  test('teilen: die Liste geht hoch, der Ersteller hat sein Geheimnis',
      () async {
    final (state, service) = device(items: [item('1', 'Schrauben')]);
    final list = state.shoppingLists.single;
    final share = await service.share(list, withCode: false);

    expect(list.isShared, isTrue);
    expect(share.isOwner, isTrue);
    expect(share.unsent, 0);
    expect(share.server, 'https://sync.example.org');
    expect(service.statusOf(list), SharedListStatus.ok);
    // Die Eintraege behalten ihre IDs.
    expect(share.view.items.keys, ['1']);
    expect(server.lists.values.single.ops, hasLength(2));
  });

  test('beitreten: Name und Eintraege kommen mit, die Liste wird gezeigt',
      () async {
    final (mine, theirs, _, ben) = await pair();
    expect(theirs.name, 'Baumarkt');
    expect(titles(theirs), ['Schrauben', 'Dübel ✓']);
    expect(theirs.share!.isOwner, isFalse);
    expect(ben.statusOf(theirs), SharedListStatus.ok);
    expect(theirs.share!.listId, mine.share!.listId);
  });

  test('Aenderungen gehen als Operationen hin und her', () async {
    final (mine, theirs, anna, ben) = await pair();
    final annaState = anna.debugState;
    final benState = ben.debugState;

    // Ben: anlegen, abhaken, umbenennen; alles sofort sichtbar.
    benState.addShoppingItem('Leim');
    benState.toggleShoppingItem(theirs.items.firstWhere((i) => i.id == '1'));
    benState.renameShoppingList(theirs, 'Baumarkt Samstag');
    expect(titles(theirs), ['Leim', 'Schrauben ✓', 'Dübel ✓']);
    expect(theirs.share!.unsent, 3);

    await ben.syncList(theirs);
    await anna.syncList(mine);
    expect(mine.name, 'Baumarkt Samstag');
    expect(titles(mine), ['Leim', 'Schrauben ✓', 'Dübel ✓']);

    // Anna: Titel aendern und loeschen.
    annaState.renameShoppingItem(
        mine.items.firstWhere((i) => i.title == 'Leim'), 'Holzleim');
    annaState.deleteShoppingItem(mine.items.firstWhere((i) => i.id == '2'));
    await anna.syncList(mine);
    await ben.syncList(theirs);
    expect(titles(theirs), ['Holzleim', 'Schrauben ✓']);
  });

  test('offline: Aenderungen warten, der Status sagt es', () async {
    final (mine, _, anna, _) = await pair();
    server.offline = true;
    anna.debugState.addShoppingItem('Silikon');
    await anna.syncList(mine);
    expect(anna.statusOf(mine), SharedListStatus.offline);
    expect(mine.share!.unsent, 1);
    expect(titles(mine), contains('Silikon'));

    server.offline = false;
    await anna.syncList(mine);
    expect(anna.statusOf(mine), SharedListStatus.ok);
    expect(mine.share!.unsent, 0);
  });

  test('Konflikt: der Spaetere entscheidet, dann gilt es fuer beide',
      () async {
    final (mine, theirs, anna, ben) = await pair();
    final annaState = anna.debugState;
    final benState = ben.debugState;
    annaState.renameShoppingItem(mine.items.first, 'Spax 4x40');
    benState.renameShoppingItem(
        theirs.items.firstWhere((i) => i.id == '1'), 'Holzschrauben');
    await anna.syncList(mine);
    await ben.syncList(theirs);

    expect(theirs.items.firstWhere((i) => i.id == '1').title, 'Spax 4x40');
    final conflicts = theirs.conflictsFor(benState.syncDevice);
    expect(conflicts, hasLength(1));
    expect(mine.conflictsFor(annaState.syncDevice), isEmpty);

    benState.resolveShoppingConflict(theirs, conflicts.single, true);
    await ben.syncList(theirs);
    await anna.syncList(mine);
    expect(mine.items.firstWhere((i) => i.id == '1').title, 'Holzschrauben');
    expect(theirs.conflictsFor(benState.syncDevice), isEmpty);
  });

  test('mit Code: ohne Code kein Zutritt', () async {
    final (state, anna) = device(items: [item('1', 'Schrauben')]);
    final share =
        await anna.share(state.shoppingLists.single, withCode: true);
    expect(share.code, matches(RegExp(r'^\d{6}$')));
    final (_, ben) = device();
    final link = ShareLink.tryParse(share.link.toString())!;
    expect((await ben.inspect(link)).code, isTrue);
    await expectLater(
      ben.join(link),
      throwsA(isA<SyncFailure>()
          .having((f) => f.status, 'status', SyncStatus.unauthorized)),
    );
    final list = await ben.join(link, code: share.code);
    expect(titles(list), ['Schrauben']);
  });

  test('zweimal derselbe Link: keine zweite Liste', () async {
    final (mine, theirs, _, ben) = await pair();
    final again = await ben.join(ShareLink.tryParse(
        mine.share!.link.toString())!);
    expect(identical(again, theirs), isTrue);
    expect(ben.debugState.shoppingLists.where((l) => l.isShared), hasLength(1));
  });

  test('fuer alle geloescht: bei den anderen wird es eine lokale Liste',
      () async {
    final (mine, theirs, anna, ben) = await pair();
    await anna.deleteForAll(mine);
    expect(mine.isShared, isFalse);
    expect(anna.endedOf(mine), isNull);

    await ben.syncList(theirs);
    expect(theirs.isShared, isFalse);
    expect(ben.endedOf(theirs), ShareEnd.deleted);
    // Der letzte Stand bleibt.
    expect(titles(theirs), ['Schrauben', 'Dübel ✓']);
  });

  test('nach einem Jahr ohne Zugriff entteilt', () async {
    final (_, theirs, _, ben) = await pair();
    server.now = server.now.add(const Duration(days: 366));
    await ben.syncList(theirs);
    expect(theirs.isShared, isFalse);
    expect(ben.endedOf(theirs), ShareEnd.expired);
  });

  test('verlassen: lokal weiter, ohne Abgleich', () async {
    final (_, theirs, _, ben) = await pair();
    ben.leave(theirs);
    expect(theirs.isShared, isFalse);
    expect(ben.endedOf(theirs), ShareEnd.left);
    final before = server.requests.length;
    await ben.syncList(theirs);
    expect(server.requests.length, before);
  });

  test('Freigabe ueberlebt Speichern und Laden, auch mit Warteschlange',
      () async {
    final (mine, _, anna, _) = await pair(withCode: true);
    server.offline = true;
    anna.debugState.addShoppingItem('Silikon');
    await anna.syncList(mine);
    await Future<void>.delayed(Duration.zero);

    final loaded = AppState();
    await loaded.load();
    final list = loaded.shoppingLists.single;
    expect(list.isShared, isTrue);
    expect(list.share!.code, mine.share!.code);
    expect(list.share!.isOwner, isTrue);
    expect(list.share!.unsent, 1);
    expect(titles(list), titles(mine));
    expect(loaded.syncDevice, anna.debugState.syncDevice);
  });

  test('eine unlesbare Freigabe kostet nur sich: die Liste bleibt lokal',
      () async {
    SharedPreferences.setMockInitialValues({
      'joe_data_v1': jsonEncode({
        'shoppingLists': [
          {
            'id': 'l1',
            'name': 'Baumarkt',
            'items': [item('1', 'Schrauben').toJson()],
            'share': {'kaputt': true},
          },
        ],
      }),
    });
    final state = AppState();
    await state.load();
    final list = state.shoppingLists.single;
    expect(list.isShared, isFalse);
    expect(titles(list), ['Schrauben']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNotNull);
  });

  test('das Log nennt weder Link noch Geheimnis noch Code', () async {
    final (mine, theirs, anna, ben) = await pair(withCode: true);
    ben.debugState.addShoppingItem('Leim');
    await ben.syncList(theirs);
    await anna.syncList(mine);
    final share = mine.share!;
    final log = (await JoeLog.instance.sharePayload()).text;
    expect(log, contains('geteilt'));
    expect(log, isNot(contains(share.secret)));
    expect(log, isNot(contains(share.code!)));
    expect(log, isNot(contains(share.ownerSecret!)));
    expect(log, isNot(contains(share.link.toString())));
    expect(log, isNot(contains(share.listId)));
  });
}
