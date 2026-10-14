import 'package:joe_sync/joe_sync.dart';
import 'package:sqlite3/sqlite3.dart';

/// Eine Liste, wie der Server sie kennt: Hashes, Zeiten, keine Inhalte.
class ListRecord {
  final String id;
  final String accessHash;
  final String ownerHash;
  final bool code;
  final String epoch;
  final DateTime createdAt;
  final DateTime lastAccess;
  final DateTime? deletedAt;
  final DateTime? expiredAt;

  const ListRecord({
    required this.id,
    required this.accessHash,
    required this.ownerHash,
    required this.code,
    required this.epoch,
    required this.createdAt,
    required this.lastAccess,
    this.deletedAt,
    this.expiredAt,
  });

  /// Geloescht oder abgelaufen: die ID bleibt gesperrt (`410`).
  bool get gone => deletedAt != null || expiredAt != null;
}

/// SQLite-Ablage (Konzept 7.1). Eine Datei im Volume, WAL-Modus.
///
/// `seq` ist eine fortlaufende Nummer ueber alle Listen. Fuer die
/// Reihenfolge innerhalb einer Liste reicht das (G14); Luecken stoeren
/// niemanden.
class Store {
  final Database _db;

  Store._(this._db) {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA busy_timeout = 5000');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS lists (
        id TEXT PRIMARY KEY,
        access_hash TEXT NOT NULL,
        owner_hash TEXT NOT NULL,
        code INTEGER NOT NULL,
        epoch TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_access INTEGER NOT NULL,
        deleted_at INTEGER,
        expired_at INTEGER
      )''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS ops (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id TEXT NOT NULL REFERENCES lists(id),
        op_id TEXT NOT NULL,
        blob TEXT NOT NULL,
        at INTEGER NOT NULL,
        UNIQUE (list_id, op_id)
      )''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS ops_list_seq ON ops (list_id, seq)',
    );
  }

  factory Store.open(String path) => Store._(sqlite3.open(path));

  factory Store.memory() => Store._(sqlite3.openInMemory());

  void close() => _db.close();

  static int _ms(DateTime time) => time.millisecondsSinceEpoch;
  static DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
  static DateTime? _maybe(Object? ms) => ms == null ? null : _time(ms);

  ListRecord? list(String id) {
    final rows = _db.select('SELECT * FROM lists WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ListRecord(
      id: row['id'] as String,
      accessHash: row['access_hash'] as String,
      ownerHash: row['owner_hash'] as String,
      code: row['code'] == 1,
      epoch: row['epoch'] as String,
      createdAt: _time(row['created_at']),
      lastAccess: _time(row['last_access']),
      deletedAt: _maybe(row['deleted_at']),
      expiredAt: _maybe(row['expired_at']),
    );
  }

  ListRecord create({
    required String id,
    required String accessHash,
    required String ownerHash,
    required bool code,
    required DateTime now,
  }) {
    _db.execute(
      'INSERT INTO lists (id, access_hash, owner_hash, code, epoch, '
      'created_at, last_access) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, accessHash, ownerHash, code ? 1 : 0, newId(), _ms(now), _ms(now)],
    );
    return list(id)!;
  }

  void touch(String id, DateTime now) => _db.execute(
    'UPDATE lists SET last_access = ? WHERE id = ?',
    [_ms(now), id],
  );

  /// Hoechste `seq` der Liste, 0 ohne Operationen.
  int head(String listId) {
    final rows = _db.select(
      'SELECT MAX(seq) AS head FROM ops WHERE list_id = ?',
      [listId],
    );
    return (rows.first['head'] as int?) ?? 0;
  }

  List<WireOp> ops(String listId, int after, int limit) => [
    for (final row in _db.select(
      'SELECT seq, op_id, blob, at FROM ops '
      'WHERE list_id = ? AND seq > ? ORDER BY seq LIMIT ?',
      [listId, after, limit],
    ))
      WireOp(
        seq: row['seq'] as int,
        id: row['op_id'] as String,
        blob: row['blob'] as String,
        at: _time(row['at']),
      ),
  ];

  /// Legt Operationen in der gegebenen Reihenfolge ab. Eine schon bekannte
  /// ID behaelt ihre erste `seq` (ein Wiederholungsversuch verdoppelt
  /// nichts). Liefert ID → `seq`.
  Map<String, int> append(
    String listId,
    List<({String id, String blob})> ops,
    DateTime now,
  ) {
    final result = <String, int>{};
    _db.execute('BEGIN IMMEDIATE');
    try {
      final find = _db.prepare(
        'SELECT seq FROM ops WHERE list_id = ? AND op_id = ?',
      );
      final insert = _db.prepare(
        'INSERT INTO ops (list_id, op_id, blob, at) VALUES (?, ?, ?, ?)',
      );
      try {
        for (final op in ops) {
          final known = find.select([listId, op.id]);
          if (known.isNotEmpty) {
            result[op.id] = known.first['seq'] as int;
            continue;
          }
          insert.execute([listId, op.id, op.blob, _ms(now)]);
          result[op.id] = _db.lastInsertRowId;
        }
      } finally {
        find.close();
        insert.close();
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return result;
  }

  /// Fuer alle loeschen (G5): Inhalte weg, die ID bleibt gesperrt.
  void delete(String id, DateTime now) {
    _db.execute('BEGIN IMMEDIATE');
    _db.execute('DELETE FROM ops WHERE list_id = ?', [id]);
    _db.execute('UPDATE lists SET deleted_at = ? WHERE id = ?', [_ms(now), id]);
    _db.execute('COMMIT');
  }

  /// Taeglicher Lauf (G9): Listen ohne Zugriff seit [retention] werden
  /// entteilt. Liefert, wie viele es waren.
  int expire(DateTime now, Duration retention) {
    final limit = _ms(now.subtract(retention));
    _db.execute('BEGIN IMMEDIATE');
    final ids = [
      for (final row in _db.select(
        'SELECT id FROM lists WHERE last_access <= ? '
        'AND deleted_at IS NULL AND expired_at IS NULL',
        [limit],
      ))
        row['id'] as String,
    ];
    for (final id in ids) {
      _db.execute('DELETE FROM ops WHERE list_id = ?', [id]);
      _db.execute('UPDATE lists SET expired_at = ? WHERE id = ?', [
        _ms(now),
        id,
      ]);
    }
    _db.execute('COMMIT');
    return ids.length;
  }

  /// Entteilt eine einzelne Liste, wie [expire] es taeglich fuer alle tut.
  void expireOne(String id, DateTime now) {
    _db.execute('BEGIN IMMEDIATE');
    _db.execute('DELETE FROM ops WHERE list_id = ?', [id]);
    _db.execute('UPDATE lists SET expired_at = ? WHERE id = ?', [_ms(now), id]);
    _db.execute('COMMIT');
  }

  /// Fuer /health und das Log: nur Anzahlen.
  ({int lists, int ops}) counts() {
    final lists =
        _db
                .select(
                  'SELECT COUNT(*) AS n FROM lists WHERE deleted_at IS NULL '
                  'AND expired_at IS NULL',
                )
                .first['n']
            as int;
    final ops = _db.select('SELECT COUNT(*) AS n FROM ops').first['n'] as int;
    return (lists: lists, ops: ops);
  }
}
