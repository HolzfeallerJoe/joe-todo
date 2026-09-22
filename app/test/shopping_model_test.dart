import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';

/// Die Einkaufsliste im Datenmodell: eine einzige Liste, an keinen Tag
/// gebunden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<String> titles(List<ShoppingItem> items) =>
      [for (final i in items) i.title];

  group('Listen', () {
    test('alles steht in einer Liste, egal wann es angelegt wurde', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot');
      state.addShoppingItem('Käse');

      expect(titles(state.shoppingItems), ['Milch', 'Brot', 'Käse']);
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
      expect(titles(state.shoppingItems), ['B', 'C', 'A', 'D']);

      // Abhaken schiebt nach unten, Zuruecknehmen wieder an seinen Platz.
      final b = state.shopping.firstWhere((i) => i.id == 'b');
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItems), ['C', 'A', 'B', 'D']);
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItems), ['B', 'C', 'A', 'D']);
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
      expect(titles(state.shoppingItems), ['Erst', 'Dann', 'Zuletzt']);

      state.addShoppingItem('Neu');
      expect(titles(state.shoppingItems).last, 'Neu');
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
      expect(titles(state.shoppingItems), ['Brot']);
    });

    test('Umschalten loescht nichts', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot');
      state.setShoppingMode(ShoppingListMode.notes);
      expect(state.shoppingMode, ShoppingListMode.notes);
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
        createdAt: DateTime(2026, 9, 14, 8, 30),
      );
      final back = ShoppingItem.fromJson(item.toJson());
      expect(back.id, '1');
      expect(back.title, 'Brot');
      expect(back.done, isTrue);
      expect(back.createdAt, DateTime(2026, 9, 14, 8, 30));

      final frisch = ShoppingItem.fromJson(
        ShoppingItem(id: '2', title: 'Milch', createdAt: DateTime(2026, 9, 1))
            .toJson(),
      );
      expect(frisch.done, isFalse);
    });

    test('Speichern und Laden', () async {
      final state = AppState();
      await state.load();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot');
      state.setShoppingMode(ShoppingListMode.notes);
      await pumpEventQueue();

      final wieder = AppState();
      await wieder.load();
      expect(titles(wieder.shoppingItems), ['Milch', 'Brot']);
      expect(wieder.shoppingMode, ShoppingListMode.notes);
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
            // 'day' stammt aus einem Vorabstand mit Liste je Tag: Das Feld
            // wird ueberlesen, der Eintrag bleibt.
            'day': '2026-09-14',
            'createdAt': '2026-09-02T10:00:00.000',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
      final state = AppState();
      await state.load();

      expect(titles(state.shoppingItems), ['Milch', 'Brot']);
      final brot = state.shoppingItems.last;
      expect(brot.done, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), raw);
    });
  });
}
