import 'op.dart';

/// Ein Feld mit Gedaechtnis: der Wert, die Operation, die ihn gesetzt hat,
/// und alle Operationen, deren Sicht auf das Feld noch aktuell ist.
///
/// [seen] ist der Setzer plus jede spaetere Operation, die denselben Wert
/// noch einmal gesetzt hat (G13). Eine Aenderung, deren `base` hier
/// drinsteht, hat den aktuellen Wert gekannt und wird uebernommen.
class SyncField {
  Object? value;
  String setter;
  final List<String> seen;

  SyncField(this.value, this.setter) : seen = [setter];

  SyncField._(this.value, this.setter, this.seen);

  void _set(Object? newValue, String opId) {
    value = newValue;
    setter = opId;
    seen
      ..clear()
      ..add(opId);
  }

  void _absorb(String opId) {
    if (!seen.contains(opId)) seen.add(opId);
  }

  Map<String, Object?> toJson() => {
    'value': value,
    'setter': setter,
    'seen': seen,
  };

  factory SyncField.fromJson(Map<String, Object?> json) => SyncField._(
    json['value'],
    json['setter'] as String,
    [for (final id in json['seen'] as List) id as String],
  );
}

/// Ein Eintrag einer geteilten Liste. Geloescht wird weich: [deleted]
/// bleibt stehen, damit die Zusammenfuehrung „bearbeitet gegen geloescht“
/// erkennt.
class SharedItem {
  final String id;
  final DateTime createdAt;
  final SyncField title;
  final SyncField done;
  final SyncField deleted;

  SharedItem(this.id, this.createdAt, this.title, this.done, this.deleted);

  String get titleValue => title.value as String;
  bool get isDone => done.value == true;
  bool get isDeleted => deleted.value == true;

  SyncField? field(String name) => switch (name) {
    'title' => title,
    'done' => done,
    'deleted' => deleted,
    _ => null,
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'title': title.toJson(),
    'done': done.toJson(),
    'deleted': deleted.toJson(),
  };

  factory SharedItem.fromJson(Map<String, Object?> json) => SharedItem(
    json['id'] as String,
    DateTime.parse(json['createdAt'] as String),
    SyncField.fromJson(json['title'] as Map<String, Object?>),
    SyncField.fromJson(json['done'] as Map<String, Object?>),
    SyncField.fromJson(json['deleted'] as Map<String, Object?>),
  );
}

enum ConflictKind {
  /// Dasselbe Feld, zwei verschiedene Werte.
  field,

  /// Jemand hat den Titel eines Eintrags geaendert, der inzwischen
  /// geloescht war. Der Eintrag bleibt geloescht, bis entschieden ist.
  deleted,

  /// Jemand hat einen Eintrag geloescht, dessen Titel inzwischen geaendert
  /// war. Der Eintrag bleibt stehen, bis entschieden ist.
  edited,
}

/// Ein offener Konflikt (Konzept 5.4). Entscheiden soll [device], das
/// Geraet, dessen Operation zu spaet kam; alle anderen sehen nur, dass
/// etwas geklaert wird.
class SyncConflict {
  /// ID der Operation, die den Konflikt ausgeloest hat.
  final String id;
  final ConflictKind kind;

  /// `null` fuer den Listennamen.
  final String? item;
  final String field;

  /// Der Wert, der nicht durchkam („meins“ aus Sicht von [device]).
  Object? value;
  final String device;

  /// Serverzeit der ausloesenden Operation; `null`, solange sie nur
  /// lokal in der Warteschlange liegt.
  final DateTime? at;

  /// Die Operationen von [device], die in diesen Konflikt gemuendet sind.
  /// Baut eine spaetere Operation desselben Geraets auf einer davon auf,
  /// aendert sie den Konflikt, statt einen neuen anzulegen.
  final List<String> chain;

  SyncConflict({
    required this.id,
    required this.kind,
    required this.item,
    required this.field,
    required this.value,
    required this.device,
    required this.at,
    List<String>? chain,
  }) : chain = chain ?? [id];

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'item': item,
    'field': field,
    'value': value,
    'device': device,
    'at': at?.toIso8601String(),
    'chain': chain,
  };

  factory SyncConflict.fromJson(Map<String, Object?> json) => SyncConflict(
    id: json['id'] as String,
    kind: ConflictKind.values.byName(json['kind'] as String),
    item: json['item'] as String?,
    field: json['field'] as String,
    value: json['value'],
    device: json['device'] as String,
    at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
    chain: [for (final id in json['chain'] as List) id as String],
  );
}

/// Der zusammengefuehrte Stand einer geteilten Liste:
/// `zustand = merge(operationen in seq-Reihenfolge)` (Konzept 5.1), Schritt
/// fuer Schritt ueber [apply].
///
/// Alle Geraete und die Webseite wenden dieselben Operationen in derselben
/// Reihenfolge an und kommen deshalb zum selben Stand, samt denselben
/// offenen Konflikten. `test/vectors/merge.json` haelt Dart und JS gleich.
class SharedListState implements SharedListBase {
  /// So lange bleibt ein Konflikt offen, gemessen an der Serverzeit.
  static const conflictLifetime = Duration(days: 30);

  SyncField? name;

  /// In der Reihenfolge des Anlegens, geloeschte eingeschlossen.
  final Map<String, SharedItem> items;
  final Map<String, SyncConflict> conflicts;

  /// Spaeteste bekannte Serverzeit; daran verfallen Konflikte.
  DateTime? clock;

  SharedListState() : items = {}, conflicts = {};

  SharedListState._(this.name, this.items, this.conflicts, this.clock);

  String? get nameValue => name?.value as String?;

  /// Die Eintraege, die man sieht.
  Iterable<SharedItem> get visibleItems =>
      items.values.where((item) => !item.isDeleted);

  @override
  String? get nameSetter => name?.setter;

  @override
  Map<String, String> baseOf(String itemId) {
    final item = items[itemId];
    if (item == null) return const {};
    return {
      'title': item.title.setter,
      'done': item.done.setter,
      'deleted': item.deleted.setter,
    };
  }

  /// Offene Konflikte zu einem Eintrag (`null`: zum Listennamen).
  List<SyncConflict> conflictsOf(String? itemId) => [
    for (final c in conflicts.values)
      if (c.item == itemId) c,
  ];

  /// Wendet eine Operation an. [at] ist die Serverzeit der Operation;
  /// `null` fuer Operationen, die erst lokal in der Warteschlange liegen.
  void apply(Op op, {DateTime? at}) {
    if (at != null) advance(at);
    switch (op.type) {
      case Op.listName:
        _name(op, at);
      case Op.itemAdd:
        _add(op);
      case Op.itemTitle:
        _title(op, at);
      case Op.itemDone:
        _done(op, at);
      case Op.itemDelete:
        _delete(op, at);
      case Op.conflictResolve:
        _resolve(op);
    }
  }

  /// Rueckt die Serveruhr vor und laesst Konflikte verfallen, die seit
  /// [conflictLifetime] niemand entschieden hat. Es bleibt der Stand, der
  /// zuerst ankam.
  void advance(DateTime now) {
    final current = clock;
    if (current == null || now.isAfter(current)) clock = now.toUtc();
    final limit = clock!.subtract(conflictLifetime);
    conflicts.removeWhere((_, c) => c.at != null && !c.at!.isAfter(limit));
  }

  void _name(Op op, DateTime? at) {
    final field = name;
    if (field == null) {
      name = SyncField(op.name, op.id);
      return;
    }
    _change(op, at, null, 'name', field, op.name);
  }

  void _add(Op op) {
    // Ein zweites Anlegen derselben ID (etwa nach einer Wiederherstellung,
    // Konzept 6.4) aendert nichts: wer zuerst kam, gilt.
    if (items.containsKey(op.item)) return;
    items[op.item!] = SharedItem(
      op.item!,
      op.createdAt!,
      SyncField(op.title, op.id),
      SyncField(op.done ?? false, op.id),
      SyncField(false, op.id),
    );
  }

  void _title(Op op, DateTime? at) {
    final item = items[op.item];
    if (item == null) return;
    if (!item.isDeleted) {
      _change(op, at, item.id, 'title', item.title, op.title);
      return;
    }
    // Hat der Mensch den Eintrag schon geloescht gesehen, kann er ihn nicht
    // bearbeitet haben – nichts zu tun.
    if (item.deleted.seen.contains(op.base['deleted'])) return;
    final chained = _chained(item.id, 'title', op.base['title']);
    if (chained != null) {
      chained.value = op.title;
      chained.chain.add(op.id);
      return;
    }
    _dropOwn(op.device, item.id, 'title');
    _open(op, at, ConflictKind.deleted, item.id, 'title', op.title);
  }

  void _done(Op op, DateTime? at) {
    final item = items[op.item];
    // Abhaken eines geloeschten Eintrags ist kein Konflikt: beide wollten
    // ihn aus dem Weg haben.
    if (item == null || item.isDeleted) return;
    _change(op, at, item.id, 'done', item.done, op.done);
  }

  void _delete(Op op, DateTime? at) {
    final item = items[op.item];
    if (item == null) return;
    if (item.isDeleted) {
      item.deleted._absorb(op.id);
      _dropOwn(op.device, item.id, 'deleted');
      return;
    }
    // Nur ein geaenderter Titel haelt das Loeschen auf. Einen Haken setzen
    // und loeschen wollen dasselbe: der Eintrag ist erledigt.
    if (item.title.seen.contains(op.base['title'])) {
      item.deleted._set(true, op.id);
      _dropAll(item.id);
      return;
    }
    // Wer loeschen will, hat seine offenen Fragen zu diesem Eintrag damit
    // beantwortet; uebrig bleibt nur die neue.
    conflicts.removeWhere((_, c) => c.device == op.device && c.item == item.id);
    _open(op, at, ConflictKind.edited, item.id, 'deleted', true);
  }

  void _resolve(Op op) {
    final conflict = conflicts.remove(op.conflict);
    if (conflict == null || op.keepMine != true) return;
    if (conflict.item == null) {
      _set(null, 'name', name!, conflict.value, op.id);
      return;
    }
    final item = items[conflict.item]!;
    switch (conflict.kind) {
      case ConflictKind.field:
        _set(
          item.id,
          conflict.field,
          item.field(conflict.field)!,
          conflict.value,
          op.id,
        );
      case ConflictKind.deleted:
        // Wiederherstellen mit der eigenen Aenderung. Andere „geloescht
        // gegen bearbeitet“ zu diesem Eintrag sind damit gegenstandslos.
        item.deleted._set(false, op.id);
        _set(item.id, 'title', item.title, conflict.value, op.id);
        conflicts.removeWhere(
          (_, c) => c.item == item.id && c.kind == ConflictKind.deleted,
        );
      case ConflictKind.edited:
        item.deleted._set(true, op.id);
        _dropAll(item.id);
    }
  }

  /// Die Regeln aus Konzept 5.4 fuer ein einzelnes Feld.
  void _change(
    Op op,
    DateTime? at,
    String? itemId,
    String fieldName,
    SyncField field,
    Object? value,
  ) {
    // Gleicher Wert ist nie ein Konflikt (G13).
    if (value == field.value) {
      field._absorb(op.id);
      _dropOwn(op.device, itemId, fieldName);
      return;
    }
    if (field.seen.contains(op.base[fieldName])) {
      _set(itemId, fieldName, field, value, op.id);
      _dropOwn(op.device, itemId, fieldName);
      return;
    }
    final chained = _chained(itemId, fieldName, op.base[fieldName]);
    if (chained != null) {
      chained.value = value;
      chained.chain.add(op.id);
      return;
    }
    _dropOwn(op.device, itemId, fieldName);
    _open(op, at, ConflictKind.field, itemId, fieldName, value);
  }

  /// Setzt ein Feld. Feldkonflikte, die genau diesen Wert wollten, sind
  /// damit erledigt.
  void _set(
    String? itemId,
    String fieldName,
    SyncField field,
    Object? value,
    String opId,
  ) {
    field._set(value, opId);
    conflicts.removeWhere(
      (_, c) =>
          c.kind == ConflictKind.field &&
          c.item == itemId &&
          c.field == fieldName &&
          c.value == value,
    );
  }

  void _open(
    Op op,
    DateTime? at,
    ConflictKind kind,
    String? itemId,
    String fieldName,
    Object? value,
  ) {
    conflicts[op.id] = SyncConflict(
      id: op.id,
      kind: kind,
      item: itemId,
      field: fieldName,
      value: value,
      device: op.device,
      at: at,
    );
  }

  SyncConflict? _chained(String? itemId, String fieldName, String? base) {
    if (base == null) return null;
    for (final c in conflicts.values) {
      if (c.item == itemId && c.field == fieldName && c.chain.contains(base)) {
        return c;
      }
    }
    return null;
  }

  /// Eine neuere Aenderung desselben Geraets am selben Feld ersetzt seine
  /// alte offene Frage.
  void _dropOwn(String device, String? itemId, String fieldName) =>
      conflicts.removeWhere(
        (_, c) =>
            c.device == device && c.item == itemId && c.field == fieldName,
      );

  void _dropAll(String itemId) =>
      conflicts.removeWhere((_, c) => c.item == itemId);

  SharedListState copy() => SharedListState.fromJson(toJson());

  Map<String, Object?> toJson() => {
    'name': name?.toJson(),
    'items': [for (final item in items.values) item.toJson()],
    'conflicts': [for (final c in conflicts.values) c.toJson()],
    'clock': clock?.toIso8601String(),
  };

  factory SharedListState.fromJson(Map<String, Object?> json) {
    final rawName = json['name'];
    return SharedListState._(
      rawName == null
          ? null
          : SyncField.fromJson(rawName as Map<String, Object?>),
      {
        for (final raw in json['items'] as List)
          (raw as Map<String, Object?>)['id'] as String: SharedItem.fromJson(
            raw,
          ),
      },
      {
        for (final raw in json['conflicts'] as List)
          (raw as Map<String, Object?>)['id'] as String: SyncConflict.fromJson(
            raw,
          ),
      },
      json['clock'] == null ? null : DateTime.parse(json['clock'] as String),
    );
  }
}
