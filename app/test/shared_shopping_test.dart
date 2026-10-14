import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joe_sync/joe_sync.dart';

import 'package:joe_todo/env.dart';
import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/shared_lists.dart';
import 'package:joe_todo/toast.dart';

import 'support/fake_sync_server.dart';

/// Geteilte Einkaufslisten auf dem Bildschirm (Konzept 6.2): Teilen-Blatt,
/// Code, Beitreten ueber einen eingefuegten Link, Statuszeile, Konflikte,
/// Verlassen.
void main() {
  late FakeSyncServer server;
  late SharedLists service;

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() {
    server = FakeSyncServer();
    JoeEnv.debugSyncUrl = 'https://sync.example.org';
  });

  tearDown(() {
    JoeEnv.debugSyncUrl = null;
  });

  /// Was ueber das Teilen-Blatt des Systems ginge.
  List<String> captureShares(WidgetTester tester) {
    final shared = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared.add((call.arguments as Map)['text'] as String);
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
    return shared;
  }

  Future<AppState> pump(
    WidgetTester tester, {
    List<ShoppingList>? lists,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, 1200);
    addTearDown(tester.view.reset);
    final state = AppState()
      ..tasks = []
      ..appointments = []
      ..notes = []
      ..shoppingLists = lists ??
          [
            ShoppingList(id: 'l1', name: 'Baumarkt', items: [
              ShoppingItem(
                id: '1',
                title: 'Schrauben',
                createdAt: DateTime(2026, 10, 14, 9),
              ),
            ]),
          ]
      ..showPet = false;
    service = SharedLists(transport: server);
    SharedLists.instance = service;
    service.attach(state);
    await tester.pumpWidget(JoeApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkaufsliste'));
    await tester.pumpAndSettle();
    return state;
  }

  /// Zum Schluss: Baum abbauen (meldet den Abgleich ab), Takt aus, Toasts
  /// auslaufen lassen.
  Future<void> finish(WidgetTester tester) async {
    // Mehrere Toasts stehen hintereinander an.
    for (var i = 0; i < 4; i++) {
      await tester.pump(JoeToast.showDuration);
    }
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    await tester.pumpAndSettle();
  }

  /// Wartet, bis der Abgleich (echte Futures im Testserver) durch ist.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('gemeinsam bearbeiten mit Code: Link teilen, Code zeigen',
      (tester) async {
    final shared = captureShares(tester);
    final state = await pump(tester);

    await tap(tester, find.byTooltip('Liste teilen'));
    await tap(tester, find.text('Gemeinsam bearbeiten'));
    expect(find.textContaining('sync.example.org'), findsOneWidget);
    await tap(tester, find.text('Zusätzlich Code verlangen'));
    await tester.tap(find.text('Link teilen'));
    await tester.runAsync(() async {
      // Teilen spricht mit dem (Test-)Server: echte Futures.
      for (var i = 0; i < 20 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    final list = state.shoppingLists.single;
    expect(list.isShared, isTrue);
    expect(shared, hasLength(1));
    expect(shared.single, contains(list.share!.link.toString()));
    expect(shared.single, contains('Den Code bekommst du extra.'));
    // Der Code steht nie im Link-Text.
    expect(shared.single, isNot(contains(list.share!.code!)));

    // Danach der Code, gross.
    expect(find.text('Code der Liste'), findsOneWidget);
    final code = list.share!.code!;
    expect(
      find.text('${code.substring(0, 3)} ${code.substring(3)}'),
      findsOneWidget,
    );
    await tap(tester, find.text('Fertig'));

    // Wolke am Chip, Statuszeile.
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.textContaining('Geteilt'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('ohne Sync-Server: Hinweis statt Teilen', (tester) async {
    JoeEnv.debugSyncUrl = '';
    await pump(tester);
    await tap(tester, find.byTooltip('Liste teilen'));
    await tap(tester, find.text('Gemeinsam bearbeiten'));
    expect(find.textContaining('kein Sync-Server'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Link teilen'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    await finish(tester);
  });

  testWidgets('beitreten: Link als neue Liste einfuegen, Code eingeben',
      (tester) async {
    // Jemand anderes hat geteilt, mit Code.
    final owner = SyncClient(transport: server, device: 'anna');
    late ShareState theirs;
    await tester.runAsync(() async {
      theirs = await owner.create(
        server: 'https://sync.example.org',
        name: 'Gartenmarkt',
        withCode: true,
        items: [
          SnapshotItem(
            id: 'g1',
            title: 'Blumenerde',
            done: false,
            createdAt: DateTime.utc(2026, 10, 14, 7),
          ),
        ],
      );
    });
    final state = await pump(tester);

    await tap(tester, find.text('Neue Liste'));
    await tester.enterText(
      find.byType(TextField).last,
      'Hier unsere Liste: ${theirs.link}',
    );
    await tester.tap(find.text('Speichern'));
    for (var i = 0; i < 10 && find.text('Code eingeben').evaluate().isEmpty;
        i++) {
      await settle(tester);
    }
    expect(find.text('Code eingeben'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, theirs.code!);
    await tester.tap(find.text('Speichern'));
    for (var i = 0; i < 10 && state.shoppingLists.length < 2; i++) {
      await settle(tester);
    }

    expect(state.shoppingLists, hasLength(2));
    final joined = state.shoppingLists.last;
    expect(joined.isShared, isTrue);
    expect(joined.name, 'Gartenmarkt');
    expect(state.currentShoppingList.id, joined.id);
    expect(find.text('Blumenerde'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Konflikt: Zeichen am Eintrag, Blatt mit Meins/Das andere',
      (tester) async {
    // Bestaetigt: A hat „Milch“ angelegt, B daraus „Hafermilch“ gemacht.
    // Dieses Geraet hatte offline „Sojamilch“ draus gemacht – noch in der
    // Warteschlange, auf der alten Basis.
    final created = DateTime.utc(2026, 10, 14, 7);
    final confirmed = SharedListState()
      ..apply(Op.rename('a0', 'A', SharedListState(), 'Einkauf'), at: created)
      ..apply(Op.add('a1', 'A', item: 'i1', title: 'Milch',
          createdAt: created), at: created);
    final base = confirmed.copy();
    confirmed.apply(Op.title('b1', 'B', confirmed, 'i1', 'Hafermilch'),
        at: created);
    final share = ShareState(
      server: 'https://sync.example.org',
      listId: newId(),
      secret: b64(newSecret()),
      confirmed: confirmed,
    );
    final list = ShoppingList(id: 'l1', name: 'Einkauf', share: share);
    final state = await pump(tester, lists: [list]);
    share.record(Op.title(newId(), state.syncDevice, base, 'i1', 'Sojamilch'));
    state.sharedShoppingListUpdated(list);
    await tester.pumpAndSettle();

    expect(find.text('Hafermilch'), findsOneWidget);
    expect(find.textContaining('1 Konflikt zu klären'), findsOneWidget);
    await tap(tester, find.byTooltip('Klären'));
    expect(find.text('Gleichzeitig geändert'), findsOneWidget);
    expect(find.textContaining('„Sojamilch“ (von dir)'), findsOneWidget);
    await tap(tester, find.text('Meins'));

    expect(find.text('Sojamilch'), findsOneWidget);
    expect(list.conflictsFor(state.syncDevice), isEmpty);
    await finish(tester);
  });

  testWidgets('Teilen verlassen: die Liste bleibt, die Zeile sagt es',
      (tester) async {
    final share = ShareState(
      server: 'https://sync.example.org',
      listId: newId(),
      secret: b64(newSecret()),
    );
    share.record(Op.rename(newId(), 'x', share.view, 'Baumarkt'));
    share.record(Op.add(newId(), 'x',
        item: 'i1', title: 'Leim', createdAt: DateTime.utc(2026, 10, 14)));
    final list = ShoppingList(id: 'l1', name: 'Baumarkt', share: share)
      ..adoptShareView();
    final state = await pump(tester, lists: [
      ShoppingList(id: 'l0', name: 'Einkaufsliste'),
      list,
    ]);
    state.selectShoppingList(list);
    await tester.pumpAndSettle();

    await tester.longPress(find.widgetWithText(ChoiceChip, 'Baumarkt'));
    await tester.pumpAndSettle();
    // Nicht Ersteller: kein „Für alle löschen“.
    expect(find.text('Für alle löschen'), findsNothing);
    await tap(tester, find.text('Teilen verlassen'));
    expect(find.text('Teilen verlassen?'), findsOneWidget);
    await tap(tester, find.text('Verlassen'));

    expect(list.isShared, isFalse);
    expect(find.text('Leim'), findsOneWidget);
    expect(find.text('Nicht mehr geteilt – die Liste bleibt hier.'),
        findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsNothing);
    await finish(tester);
  });
}
