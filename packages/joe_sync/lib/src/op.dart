/// Eine Operation auf einer geteilten Liste (Konzept 5.1), im Klartext.
///
/// Jede Operation aendert genau ein Feld: `list.name` den Namen,
/// `item.title`/`item.done`/`item.delete` ein Feld eines Eintrags.
/// Ausnahmen sind `item.add` (legt alle Felder an) und `conflict.resolve`.
///
/// `base` nennt je Feld die ID der Operation, die dieses Feld zuletzt
/// gesetzt hatte, als die Aenderung gemacht wurde. Das Konzept sprach von
/// der `seq`; die ID leistet dasselbe, kennt aber auch Operationen, die noch
/// in der Warteschlange liegen und vom Server noch keine `seq` haben.
class Op {
  /// Version des Klartexts. Operationen einer hoeheren Version ueberspringt
  /// [SharedListState.apply], statt sie falsch zu lesen.
  static const version = 1;

  /// Laengste erlaubte Zeichenkette fuer Titel und Namen.
  static const maxText = 500;

  static const listName = 'list.name';
  static const itemAdd = 'item.add';
  static const itemTitle = 'item.title';
  static const itemDone = 'item.done';
  static const itemDelete = 'item.delete';
  static const conflictResolve = 'conflict.resolve';

  static const _types = {
    listName,
    itemAdd,
    itemTitle,
    itemDone,
    itemDelete,
    conflictResolve,
  };

  /// Operations-ID: liegt auf der Leitung neben dem Block und ist ueber die
  /// AAD an ihn gebunden; im Klartext steht sie nicht.
  final String id;
  final String type;

  /// Zufaellige ID des Geraets (oder des Browser-Tabs), das sie erzeugt hat.
  final String device;
  final String? item;
  final String? title;
  final bool? done;
  final String? name;
  final DateTime? createdAt;
  final String? conflict;
  final bool? keepMine;
  final Map<String, String> base;

  const Op._({
    required this.id,
    required this.type,
    required this.device,
    this.item,
    this.title,
    this.done,
    this.name,
    this.createdAt,
    this.conflict,
    this.keepMine,
    this.base = const {},
  });

  /// Liste umbenennen; [view] ist der Stand, den der Mensch gerade sieht.
  factory Op.rename(
    String id,
    String device,
    SharedListBase view,
    String name,
  ) => Op._(
    id: id,
    type: listName,
    device: device,
    name: _cap(name),
    base: {if (view.nameSetter != null) 'name': view.nameSetter!},
  );

  factory Op.add(
    String id,
    String device, {
    required String item,
    required String title,
    bool done = false,
    required DateTime createdAt,
  }) => Op._(
    id: id,
    type: itemAdd,
    device: device,
    item: item,
    title: _cap(title),
    done: done,
    createdAt: createdAt.toUtc(),
  );

  factory Op.title(
    String id,
    String device,
    SharedListBase view,
    String item,
    String title,
  ) => Op._(
    id: id,
    type: itemTitle,
    device: device,
    item: item,
    title: _cap(title),
    base: view.baseOf(item),
  );

  factory Op.done(
    String id,
    String device,
    SharedListBase view,
    String item,
    bool done,
  ) => Op._(
    id: id,
    type: itemDone,
    device: device,
    item: item,
    done: done,
    base: view.baseOf(item),
  );

  factory Op.delete(
    String id,
    String device,
    SharedListBase view,
    String item,
  ) => Op._(
    id: id,
    type: itemDelete,
    device: device,
    item: item,
    base: view.baseOf(item),
  );

  factory Op.resolve(
    String id,
    String device,
    String conflict,
    bool keepMine,
  ) => Op._(
    id: id,
    type: conflictResolve,
    device: device,
    conflict: conflict,
    keepMine: keepMine,
  );

  static String _cap(String text) =>
      text.length > maxText ? text.substring(0, maxText) : text;

  /// Der Klartext, der verschluesselt wird.
  Map<String, Object?> toBody() => {
    'v': version,
    'op': type,
    'device': device,
    if (item != null) 'item': item,
    if (title != null) 'title': title,
    if (done != null) 'done': done,
    if (name != null) 'name': name,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (conflict != null) 'conflict': conflict,
    if (keepMine != null) 'keep': keepMine! ? 'mine' : 'theirs',
    if (base.isNotEmpty) 'base': base,
  };

  /// Fuer die Warteschlange auf dem Geraet: Klartext plus ID.
  Map<String, Object?> toJson() => {'id': id, ...toBody()};

  factory Op.fromJson(Map<String, Object?> json) =>
      Op.fromBody(json['id'] as String, json);

  /// Liest einen entschluesselten Klartext. Wirft [FormatException], wenn
  /// etwas fehlt oder nicht passt, und [UnsupportedOpException] bei einer
  /// neueren Version oder einer unbekannten Art; beides ueberspringt der
  /// Abgleich.
  factory Op.fromBody(String id, Map<String, Object?> body) {
    final v = body['v'];
    if (v is! int) throw const FormatException('v fehlt');
    final type = body['op'];
    if (v > version || !_types.contains(type)) {
      throw const UnsupportedOpException();
    }
    String? text(String key, {bool required = false}) {
      final value = body[key];
      if (value == null && !required) return null;
      if (value is! String || value.length > maxText) {
        throw FormatException('$key ungueltig');
      }
      return value;
    }

    final device = text('device', required: true)!;
    final base = <String, String>{};
    final rawBase = body['base'];
    if (rawBase != null) {
      if (rawBase is! Map) throw const FormatException('base ungueltig');
      rawBase.forEach((key, value) {
        if (key is String && value is String) base[key] = value;
      });
    }
    final done = body['done'];
    if (done != null && done is! bool) {
      throw const FormatException('done ungueltig');
    }
    final created = text('createdAt');
    final keep = text('keep');
    final op = Op._(
      id: id,
      type: type as String,
      device: device,
      item: text('item'),
      title: text('title'),
      done: done as bool?,
      name: text('name'),
      createdAt: created == null ? null : DateTime.parse(created),
      conflict: text('conflict'),
      keepMine: keep == null ? null : keep == 'mine',
      base: base,
    );
    op._check();
    return op;
  }

  void _check() {
    bool ok;
    switch (type) {
      case listName:
        ok = name != null;
      case itemAdd:
        ok = item != null && title != null && createdAt != null;
      case itemTitle:
        ok = item != null && title != null;
      case itemDone:
        ok = item != null && done != null;
      case itemDelete:
        ok = item != null;
      case conflictResolve:
        ok = conflict != null && keepMine != null;
      default:
        ok = false;
    }
    if (!ok) throw FormatException('$type unvollstaendig');
  }
}

/// Eine Operation, die ein neueres Joe geschrieben hat.
class UnsupportedOpException implements Exception {
  const UnsupportedOpException();
}

/// Was [Op] braucht, um `base` zu fuellen: der gerade sichtbare Stand.
abstract class SharedListBase {
  String? get nameSetter;
  Map<String, String> baseOf(String item);
}
