import 'dart:convert';
import 'dart:io';

import 'package:joe_sync/joe_sync.dart';
import 'package:test/test.dart';

/// Wendet Operationen an wie der Abgleich: was sich nicht lesen laesst,
/// faellt weg.
SharedListState replay(List<Map<String, dynamic>> ops, {String? now}) {
  final state = SharedListState();
  for (final raw in ops) {
    Op op;
    try {
      op = Op.fromBody(
        raw['id'] as String,
        (raw['op'] as Map).cast<String, Object?>(),
      );
    } on FormatException {
      continue;
    } on UnsupportedOpException {
      continue;
    }
    state.apply(op, at: DateTime.parse(raw['at'] as String));
  }
  if (now != null) state.advance(DateTime.parse(now));
  return state;
}

Map<String, Object?> summary(SharedListState state) => {
  'name': state.nameValue,
  'items': [
    for (final item in state.visibleItems)
      {'id': item.id, 'title': item.titleValue, 'done': item.isDone},
  ],
  'conflicts': [
    for (final c in state.conflicts.values)
      {
        'id': c.id,
        'kind': c.kind.name,
        'item': c.item,
        'field': c.field,
        'value': c.value,
        'device': c.device,
      },
  ],
};

void main() {
  // Dieselben Faelle prueft die Webseite (server/web) mit ihrer
  // JS-Fassung der Zusammenfuehrung.
  final cases =
      (jsonDecode(File('test/vectors/merge.json').readAsStringSync())['cases']
              as List)
          .cast<Map<String, dynamic>>();

  group('Gemeinsame Faelle', () {
    for (final c in cases) {
      test(c['name'], () {
        final ops = (c['ops'] as List).cast<Map<String, dynamic>>();
        final state = replay(ops, now: c['now'] as String?);
        expect(summary(state), c['expect']);
        // Ueberlebt den Weg durch die Speicherung unveraendert.
        expect(
          summary(
            SharedListState.fromJson(jsonDecode(jsonEncode(state.toJson()))),
          ),
          c['expect'],
        );
      });
    }
  });

  group('Operationen aus dem sichtbaren Stand', () {
    final created = DateTime.utc(2026, 10, 14, 8);

    test('base zeigt auf die letzte Aenderung, auch eine lokale', () {
      final view = SharedListState()
        ..apply(
          Op.add('a1', 'A', item: 'i1', title: 'Milch', createdAt: created),
        );
      final first = Op.title('b1', 'B', view, 'i1', 'Hafer');
      expect(first.base, {'title': 'a1', 'done': 'a1', 'deleted': 'a1'});
      view.apply(first);
      final second = Op.title('b2', 'B', view, 'i1', 'Hafermilch');
      expect(second.base['title'], 'b1');
      view.apply(second);
      expect(view.items['i1']!.titleValue, 'Hafermilch');
      expect(view.conflicts, isEmpty);
    });

    test('lokale Warteschlange ueber dem bestaetigten Stand', () {
      // Bestaetigt: A hat Milch angelegt. B ist offline und benennt um;
      // inzwischen hat C umbenannt.
      final confirmed = SharedListState()
        ..apply(
          Op.add('a1', 'A', item: 'i1', title: 'Milch', createdAt: created),
          at: created,
        );
      final pending = [Op.title('b1', 'B', confirmed, 'i1', 'Hafermilch')];
      final c1 = Op.title('c1', 'C', confirmed, 'i1', 'Sojamilch');
      confirmed.apply(c1, at: created.add(const Duration(minutes: 1)));

      final view = confirmed.copy();
      for (final op in pending) {
        view.apply(op);
      }
      expect(view.items['i1']!.titleValue, 'Sojamilch');
      final conflict = view.conflicts.values.single;
      expect(conflict.device, 'B');
      expect(conflict.value, 'Hafermilch');
      expect(conflict.at, isNull);
      // Der bestaetigte Stand bleibt davon unberuehrt.
      expect(confirmed.conflicts, isEmpty);
    });

    test('Klartext hin und zurueck', () {
      final view = SharedListState()
        ..apply(Op.rename('a0', 'A', SharedListState(), 'Einkauf'))
        ..apply(
          Op.add('a1', 'A', item: 'i1', title: 'Milch', createdAt: created),
        );
      final ops = [
        Op.rename('x1', 'A', view, 'Baumarkt'),
        Op.add(
          'x2',
          'A',
          item: 'i2',
          title: 'Schrauben',
          done: true,
          createdAt: created,
        ),
        Op.title('x3', 'A', view, 'i1', 'Hafermilch'),
        Op.done('x4', 'A', view, 'i1', true),
        Op.delete('x5', 'A', view, 'i1'),
        Op.resolve('x6', 'A', 'x3', false),
      ];
      for (final op in ops) {
        final back = Op.fromJson(
          (jsonDecode(jsonEncode(op.toJson())) as Map).cast(),
        );
        expect(back.toJson(), op.toJson());
      }
      expect(ops.first.base, {'name': 'a0'});
    });

    test('zu lange Texte werden gekuerzt', () {
      final op = Op.add(
        'a1',
        'A',
        item: 'i1',
        title: 'x' * 900,
        createdAt: created,
      );
      expect(op.title, hasLength(Op.maxText));
    });
  });
}
