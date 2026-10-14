import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:joe_sync/joe_sync.dart';

import 'env.dart';
import 'log.dart';
import 'models.dart';
import 'shared_expiry.dart';

/// Was die Statuszeile unter einer geteilten Liste sagt (Konzept 6.2).
enum SharedListStatus {
  /// Noch kein Abgleich in diesem App-Lauf.
  idle,
  syncing,
  ok,
  offline,

  /// Code falsch oder Link erneuert.
  unauthorized,
  rateLimited,
  failed,
}

/// Wie eine Freigabe endete, fuer den Hinweis an der dann lokalen Liste.
enum ShareEnd {
  /// Selbst verlassen.
  left,

  /// Vom Ersteller fuer alle geloescht.
  deleted,

  /// Lange nicht benutzt und deshalb entteilt (G9).
  expired,
}

/// Der Abgleich geteilter Einkaufslisten (Konzept 5.3, G7): nur fuer die
/// Liste, die gerade offen ist – beim Oeffnen, dann alle 15 Sekunden,
/// solange Joe im Vordergrund ist, und kurz nach jeder eigenen Aenderung.
/// Kein Abgleich im Hintergrund, keine Push-Nachrichten.
///
/// Das Log nennt Listen-IDs (die lokalen) und Ergebnisse, nie Links,
/// Geheimnisse oder Codes (Konzept 6.5).
class SharedLists extends ChangeNotifier with WidgetsBindingObserver {
  SharedLists({SyncTransport? transport, this.expiry})
      : _transport = transport;

  static SharedLists _instance = SharedLists(expiry: SharedExpiry.instance);

  static SharedLists get instance => _instance;

  /// Nur fuer Tests: ein Dienst mit eigenem Transport.
  @visibleForTesting
  static set instance(SharedLists value) => _instance = value;

  static const interval = Duration(seconds: 15);
  static const afterEdit = Duration(milliseconds: 1500);

  SyncTransport? _transport;
  SyncTransport get transport => _transport ??= HttpSyncTransport();

  /// Plant die Hinweise vor dem Entteilen (Konzept 6.6); null in Tests.
  final SharedExpiry? expiry;

  AppState? _state;
  SyncClient? _client;

  SyncClient get _sync =>
      _client ??= SyncClient(transport: transport, device: _state!.syncDevice);

  final Map<String, SharedListStatus> _status = {};
  final Map<String, ShareEnd> _ended = {};

  /// Die lokale ID der Liste, die gerade zu sehen ist.
  String? _watched;
  Timer? _timer;
  Timer? _soon;
  bool _foreground = true;

  SharedListStatus statusOf(ShoppingList list) =>
      _status[list.id] ?? SharedListStatus.idle;

  /// Warum eine Liste nicht mehr geteilt ist (nur in diesem App-Lauf).
  ShareEnd? endedOf(ShoppingList list) => _ended[list.id];

  void dismissEnded(ShoppingList list) {
    if (_ended.remove(list.id) != null) notifyListeners();
  }

  /// Bei App-Start einmal: Aenderungen an geteilten Listen melden sich
  /// hier, und der Lebenszyklus haelt den Takt an.
  void attach(AppState state) {
    _state = state;
    state.onSharedEdit = _edited;
    WidgetsBinding.instance.addObserver(this);
    expiry?.refreshAll(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _restart();
    } else {
      _timer?.cancel();
      _soon?.cancel();
    }
  }

  ShoppingList? _list(String? id) {
    final state = _state;
    if (state == null || id == null) return null;
    for (final list in state.shoppingLists) {
      if (list.id == id) return list;
    }
    return null;
  }

  /// Die Einkaufsliste zeigt [list] (oder nichts mehr: null). Nur eine
  /// geteilte Liste gleicht ab.
  void watch(ShoppingList? list) {
    final id = list?.isShared == true ? list!.id : null;
    if (id == _watched) return;
    _watched = id;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_watched == null || !_foreground) return;
    unawaited(syncWatched());
    _timer = Timer.periodic(interval, (_) => syncWatched());
  }

  void _edited(ShoppingList list) {
    _soon?.cancel();
    _soon = Timer(afterEdit, () => syncList(list));
  }

  Future<void> syncWatched() async {
    final list = _list(_watched);
    if (list != null) await syncList(list);
  }

  void _setStatus(ShoppingList list, SharedListStatus status) {
    if (_status[list.id] == status) return;
    _status[list.id] = status;
    notifyListeners();
  }

  final Map<String, Future<void>> _running = {};

  /// Ein Abgleich dieser Liste; auch fuer Herunterziehen. Laeuft schon
  /// einer, kommt danach ein frischer: der laufende kennt die Aenderung
  /// womoeglich noch nicht, wegen der jemand herunterzieht.
  Future<void> syncList(ShoppingList list) async {
    final running = _running[list.id];
    if (running != null) await running;
    final future = _syncOnce(list);
    _running[list.id] = future;
    try {
      await future;
    } finally {
      if (identical(_running[list.id], future)) _running.remove(list.id);
    }
  }

  Future<void> _syncOnce(ShoppingList list) async {
    final share = list.share;
    final state = _state;
    if (share == null || state == null) return;
    if (statusOf(list) == SharedListStatus.idle) {
      _setStatus(list, SharedListStatus.syncing);
    }
    final outcome = await _sync.sync(share);
    // Waehrend des Abgleichs kann die Liste verlassen oder geloescht worden
    // sein; dann gilt das Ergebnis nicht mehr.
    if (!identical(list.share, share) || !state.shoppingLists.contains(list)) {
      return;
    }
    switch (outcome.status) {
      case SyncStatus.ok:
        if (outcome.skipped > 0) {
          JoeLog.log('Geteilte Liste ${list.id}: ${outcome.skipped} '
              'Operation(en) uebersprungen');
        }
        state.sharedShoppingListUpdated(list);
        _setStatus(list, SharedListStatus.ok);
        unawaited(expiry?.plan(list));
      case SyncStatus.gone:
        final reason = outcome.reason == 'expired'
            ? ShareEnd.expired
            : ShareEnd.deleted;
        JoeLog.log('Geteilte Liste ${list.id}: ${reason.name}');
        _end(list, reason);
      case SyncStatus.offline:
        // Gespeichert wird trotzdem: der Stand der Warteschlange zaehlt.
        state.sharedShoppingListUpdated(list);
        _setStatus(list, SharedListStatus.offline);
      case SyncStatus.unauthorized:
        JoeLog.log('Geteilte Liste ${list.id}: kein Zugriff');
        _setStatus(list, SharedListStatus.unauthorized);
      case SyncStatus.rateLimited:
        _setStatus(list, SharedListStatus.rateLimited);
      case SyncStatus.failed:
        JoeLog.log('Geteilte Liste ${list.id}: Abgleich fehlgeschlagen '
            '(${outcome.reason ?? 'unbekannt'})');
        _setStatus(list, SharedListStatus.failed);
    }
  }

  void _end(ShoppingList list, ShareEnd reason) {
    final share = list.share;
    _state?.detachShare(list, reason: reason.name);
    _status.remove(list.id);
    _ended[list.id] = reason;
    if (share != null) unawaited(expiry?.cancel(share));
    if (_watched == list.id) watch(null);
    notifyListeners();
  }

  // -------------------------------------------------------------- Teilen

  /// Teilt [list] neu auf dem Server aus [JoeEnv.syncUrl]. Wirft
  /// [SyncFailure], wenn es nicht geht.
  Future<ShareState> share(ShoppingList list, {required bool withCode}) async {
    final state = _state!;
    final server = JoeEnv.syncUrl;
    if (server.isEmpty) throw const SyncFailure(SyncStatus.failed, 'no-server');
    final share = await _sync.create(
      server: server,
      name: list.name,
      withCode: withCode,
      items: [
        for (final item in list.items)
          SnapshotItem(
            id: item.id,
            title: item.title,
            done: item.done,
            createdAt: item.createdAt,
          ),
      ],
    );
    state.attachShare(list, share);
    _status[list.id] = share.unsent == 0
        ? SharedListStatus.ok
        : SharedListStatus.offline;
    _ended.remove(list.id);
    notifyListeners();
    unawaited(expiry?.plan(list));
    if (state.currentShoppingList.id == list.id) watch(list);
    return share;
  }

  /// Fragt, ob es die Liste hinter [link] gibt und ob sie einen Code
  /// braucht. Wirft [SyncFailure].
  Future<ListMeta> inspect(ShareLink link) => _sync.inspect(link);

  /// Tritt bei und zeigt die Liste. Wirft [SyncFailure], etwa
  /// [SyncStatus.unauthorized] bei falschem Code.
  Future<ShoppingList> join(ShareLink link, {String? code}) async {
    final state = _state!;
    for (final list in state.shoppingLists) {
      if (list.share?.listId == link.listId) {
        state.selectShoppingList(list);
        return list;
      }
    }
    final share = await _sync.join(link, code: code);
    final list = state.addSharedShoppingList(share);
    _status[list.id] = SharedListStatus.ok;
    notifyListeners();
    watch(list);
    return list;
  }

  /// Teilen verlassen (G6): die Liste bleibt lokal stehen.
  void leave(ShoppingList list) {
    final share = list.share;
    if (share == null) return;
    _end(list, ShareEnd.left);
  }

  /// Fuer alle loeschen (G5, nur Ersteller). Danach ist die Liste hier
  /// eine lokale. Wirft [SyncFailure].
  Future<void> deleteForAll(ShoppingList list) async {
    final share = list.share;
    if (share == null) return;
    await _sync.deleteForAll(share);
    JoeLog.log('Geteilte Liste ${list.id}: fuer alle geloescht');
    _end(list, ShareEnd.deleted);
    // Wer selbst geloescht hat, braucht den Hinweis nicht.
    _ended.remove(list.id);
    notifyListeners();
  }

  /// Eine lokal geloeschte geteilte Liste plant keine Hinweise mehr.
  void forget(ShoppingList list) {
    final share = list.share;
    if (share != null) unawaited(expiry?.cancel(share));
    _status.remove(list.id);
    _ended.remove(list.id);
    if (_watched == list.id) watch(null);
  }

  @visibleForTesting
  AppState get debugState => _state!;

  /// Fuer Tests: Zeitgeber anhalten.
  @visibleForTesting
  void stop() {
    _timer?.cancel();
    _soon?.cancel();
    _timer = null;
    _soon = null;
    _watched = null;
  }

  @override
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
