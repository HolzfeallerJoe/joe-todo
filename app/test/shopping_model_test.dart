import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';

/// Die Einkaufsliste im Datenmodell: eine Liste fuer den Reiter und je Tag
/// eine, alle in einem Speicher.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final montag = DateTime(2026, 9, 14);
  final dienstag = DateTime(2026, 9, 15);

  List<String> titles(List<ShoppingItem> items) =>
      [for (final i in items) i.title];

  group('Listen', () {
    test('Reiter- und Tageslisten sind getrennt, zwei Tage auch', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot', day: montag);
      // Die Uhrzeit spielt keine Rolle, nur der Tag.
      state.addShoppingItem('Käse', day: montag.add(const Duration(hours: 17)));
      state.addShoppingItem('Eier', day: dienstag);

      expect(titles(state.shoppingItemsFor(null)), ['Milch']);
      expect(titles(state.shoppingItemsFor(montag)), ['Brot', 'Käse']);
      expect(
        titles(state.shoppingItemsFor(dienstag.add(const Duration(hours: 8)))),
        ['Eier'],
      );
      expect(state.shoppingItemsFor(DateTime(2026, 9, 16)), isEmpty);
      expect(state.shopping.firstWhere((i) => i.title == 'Käse').day, montag);
    });

    test('offene vor erledigten, darin nach Anlegezeit', () {
      final state = AppState()
        ..shopping = [
          ShoppingItem(id: 'c', title: 'C', createdAt: DateTime(2026, 9, 3)),
          ShoppingItem(
            id: 'a',
            title: 'A',
            createdAt: DateTime(2026, 9, 1),
            done: true,
          ),
          ShoppingItem(id: 'b', title: 'B', createdAt: DateTime(2026, 9, 2)),
          ShoppingItem(
            id: 'd',
            title: 'D',
            createdAt: DateTime(2026, 9, 4),
            done: true,
          ),
        ];
      expect(titles(state.shoppingItemsFor(null)), ['B', 'C', 'A', 'D']);

      // Abhaken schiebt nach unten, Zuruecknehmen wieder an seinen Platz.
      final b = state.shopping.firstWhere((i) => i.id == 'b');
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItemsFor(null)), ['C', 'A', 'B', 'D']);
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItemsFor(null)), ['B', 'C', 'A', 'D']);
    });

    test('neue Eintraege landen unten bei den offenen, auch bei gleicher Zeit',
        () {
      final gleich = DateTime(2026, 9, 1, 12);
      final state = AppState()
        ..shopping = [
          ShoppingItem(id: '1', title: 'Erst', createdAt: gleich),
          ShoppingItem(id: '2', title: 'Dann', createdAt: gleich),
          ShoppingItem(id: '3', title: 'Zuletzt', createdAt: gleich),
        ];
      expect(titles(state.shoppingItemsFor(null)), ['Erst', 'Dann', 'Zuletzt']);

      state.addShoppingItem('Neu');
      expect(titles(state.shoppingItemsFor(null)).last, 'Neu');
    });

    test('ein leerer Titel legt nichts an und benennt nichts um', () {
      final state = AppState();
      expect(state.addShoppingItem(''), isNull);
      expect(state.addShoppingItem('   '), isNull);
      expect(state.shopping, isEmpty);

      final item = state.addShoppingItem('  Milch  ')!;
      expect(item.title, 'Milch');
      state.renameShoppingItem(item, '  ');
      expect(item.title, 'Milch');
      state.renameShoppingItem(item, ' Hafermilch ');
      expect(item.title, 'Hafermilch');
    });

    test('Loeschen nimmt genau den einen Eintrag', () {
      final state = AppState();
      final milch = state.addShoppingItem('Milch')!;
      state.addShoppingItem('Brot');
      state.deleteShoppingItem(milch);
      expect(titles(state.shoppingItemsFor(null)), ['Brot']);
    });

    test('Umschalten loescht nichts', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot', day: montag);
      state.setShoppingMode(ShoppingListMode.perDay);
      expect(state.shoppingMode, ShoppingListMode.perDay);
      state.setShoppingMode(ShoppingListMode.tab);
      expect(state.shopping, hasLength(2));
    });
  });

  group('Bestand', () {
    test('JSON-Rundreise', () {
      final item = ShoppingItem(
        id: '1',
        title: 'Brot',
        done: true,
        day: montag,
        createdAt: DateTime(2026, 9, 14, 8, 30),
      );
      final back = ShoppingItem.fromJson(item.toJson());
      expect(back.id, '1');
      expect(back.title, 'Brot');
      expect(back.done, isTrue);
      expect(back.day, montag);
      expect(back.createdAt, DateTime(2026, 9, 14, 8, 30));

      final reiter = ShoppingItem.fromJson(
        ShoppingItem(id: '2', title: 'Milch', createdAt: DateTime(2026, 9, 1))
            .toJson(),
      );
      expect(reiter.day, isNull);
      expect(reiter.done, isFalse);
    });

    test('Speichern und Laden', () async {
      final state = AppState();
      await state.load();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot', day: montag);
      state.setShoppingMode(ShoppingListMode.perDay);
      await pumpEventQueue();

      final wieder = AppState();
      await wieder.load();
      expect(titles(wieder.shoppingItemsFor(null)), ['Milch']);
      expect(titles(wieder.shoppingItemsFor(montag)), ['Brot']);
      expect(wieder.shoppingMode, ShoppingListMode.perDay);
    });

    test('ein kaputter Eintrag kostet nur sich selbst', () async {
      final raw = jsonEncode({
        'tasks': [],
        'shopping': [
          ShoppingItem(id: '1', title: 'Milch', createdAt: DateTime(2026, 9, 1))
              .toJson(),
          {'id': '2', 'title': null, 'createdAt': 'gestern'}, // kaputt
          {
            'id': '3',
            'title': 'Brot',
            'done': 'ja', // falscher Typ: nur nicht abgehakt
            'day': '2026-09-14',
            'createdAt': '2026-09-02T10:00:00.000',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
      final state = AppState();
      await state.load();

      expect(titles(state.shoppingItemsFor(null)), ['Milch']);
      final brot = state.shoppingItemsFor(montag).single;
      expect(brot.title, 'Brot');
      expect(brot.done, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), raw);
    });
  });
}
