import 'dart:io';

import 'package:joe_sync/joe_sync.dart';

/// Rauchtest gegen einen laufenden Server: teilen, beitreten, aendern,
/// Konflikt, loeschen. Zwei „Geraete“ in einem Prozess.
///
///   dart run tool/smoke.dart http://localhost:8787
///   dart run tool/smoke.dart https://sync.example.org
///
/// Mit `--keep` bleibt die Liste stehen, und der Link wird ausgegeben, etwa
/// um sie im Browser oder in Joe zu oeffnen. `--code` teilt mit Code.
Future<void> main(List<String> args) async {
  final server = args.firstWhere(
    (a) => !a.startsWith('--'),
    orElse: () => 'http://localhost:8787',
  );
  final keep = args.contains('--keep');
  final withCode = args.contains('--code');
  final transport = HttpSyncTransport();
  final anna = SyncClient(transport: transport, device: 'smoke-anna');
  final ben = SyncClient(transport: transport, device: 'smoke-ben');
  final now = DateTime.now();

  void check(bool ok, String what) {
    stdout.writeln('${ok ? 'ok    ' : 'FEHLER'} $what');
    if (!ok) exitCode = 1;
  }

  try {
    final mine = await anna.create(
      server: server,
      name: 'Rauchtest',
      withCode: withCode,
      items: [
        SnapshotItem(id: newId(), title: 'Milch', done: false, createdAt: now),
        SnapshotItem(id: newId(), title: 'Brot', done: true, createdAt: now),
      ],
    );
    check(mine.outbox.isEmpty, 'geteilt, alles hochgeladen');

    final theirs = await ben.join(mine.link, code: mine.code);
    check(theirs.view.nameValue == 'Rauchtest', 'beigetreten, Name stimmt');
    check(theirs.view.visibleItems.length == 2, 'beide Eintraege da');

    final milk = theirs.view.visibleItems.first.id;
    theirs.record(Op.done(newId(), ben.device, theirs.view, milk, true));
    await ben.sync(theirs);
    await anna.sync(mine);
    check(mine.view.items[milk]!.isDone, 'Haken kommt beim anderen an');

    mine.record(Op.title(newId(), anna.device, mine.view, milk, 'Hafermilch'));
    theirs.record(
      Op.title(newId(), ben.device, theirs.view, milk, 'Sojamilch'),
    );
    await anna.sync(mine);
    await ben.sync(theirs);
    final conflict = theirs.view.conflicts.values.firstOrNull;
    check(conflict?.device == ben.device, 'Konflikt beim Spaeteren');
    theirs.record(Op.resolve(newId(), ben.device, conflict!.id, true));
    await ben.sync(theirs);
    await anna.sync(mine);
    check(
      mine.view.items[milk]!.titleValue == 'Sojamilch',
      'Entscheidung gilt fuer beide',
    );

    if (keep) {
      stdout.writeln('\nLink: ${mine.link}');
      if (mine.hasCode) stdout.writeln('Code: ${mine.code}');
    } else {
      await anna.deleteForAll(mine);
      final gone = await ben.sync(theirs);
      check(gone.status == SyncStatus.gone, 'fuer alle geloescht');
    }
  } on SyncFailure catch (e) {
    check(false, 'Abbruch: $e');
  } finally {
    transport.close();
  }
}
