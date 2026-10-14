import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';

/// Die Einkaufslisten im Datenmodell: beliebig viele, mindestens eine, an
/// keinen Tag gebunden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<String> titles(List<ShoppingItem> items) =>
      [for (final i in items) i.title];

  /// Ein Zustand mit genau einer Liste, die [items] traegt.
  AppState withItems(List<ShoppingItem> items) => AppState()
    ..shoppingLists = [
      ShoppingList(id: 'l1', name: defaultShoppingListName, items: items),
    ];

  group('Eintraege', () {
    test('alles steht in einer Liste, egal wann es angelegt wurde', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.addShoppingItem('Brot');
      state.addShoppingItem('Käse');

      expect(titles(state.shoppingItems), ['Milch', 'Brot', 'Käse']);
    });

    test('offene vor erledigten, darin nach Anlegezeit', () {
      final state = withItems([
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
      ]);
      expect(titles(state.shoppingItems), ['B', 'C', 'A', 'D']);

      // Abhaken schiebt nach unten, Zuruecknehmen wieder an seinen Platz.
      final b = state.currentShoppingList.items.firstWhere((i) => i.id == 'b');
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItems), ['C', 'A', 'B', 'D']);
      state.toggleShoppingItem(b);
      expect(titles(state.shoppingItems), ['B', 'C', 'A', 'D']);
    });

    test('neue Eintraege landen unten bei den offenen, auch bei gleicher Zeit',
        () {
      final gleich = DateTime(2026, 9, 1, 12);
      final state = withItems([
        ShoppingItem(id: '1', title: 'Erst', createdAt: gleich),
        ShoppingItem(id: '2', title: 'Dann', createdAt: gleich),
        ShoppingItem(id: '3', title: 'Zuletzt', createdAt: gleich),
      ]);
      expect(titles(state.shoppingItems), ['Erst', 'Dann', 'Zuletzt']);

      state.addShoppingItem('Neu');
      expect(titles(state.shoppingItems).last, 'Neu');
    });

    test('ein leerer Titel legt nichts an und benennt nichts um', () {
      final state = AppState();
      expect(state.addShoppingItem(''), isNull);
      expect(state.addShoppingItem('   '), isNull);
      expect(state.currentShoppingList.items, isEmpty);

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
      expect(state.currentShoppingList.items, hasLength(2));
    });
  });

  group('Mehrere Listen', () {
    test('am Anfang gibt es genau eine, die "Einkaufsliste"', () {
      final state = AppState();
      expect(state.shoppingLists, hasLength(1));
      expect(state.currentShoppingList.name, defaultShoppingListName);
    });

    test('eine neue Liste wird gleich gezeigt, Eintraege landen dort', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      final baumarkt = state.addShoppingList('  Baumarkt ')!;
      expect(baumarkt.name, 'Baumarkt');
      expect(state.currentShoppingList, same(baumarkt));
      expect(state.shoppingItems, isEmpty);

      state.addShoppingItem('Schrauben');
      expect(titles(state.shoppingItems), ['Schrauben']);

      state.selectShoppingList(state.shoppingLists.first);
      expect(titles(state.shoppingItems), ['Milch']);
    });

    test('ein leerer Name legt nichts an und benennt nichts um', () {
      final state = AppState();
      expect(state.addShoppingList('   '), isNull);
      expect(state.shoppingLists, hasLength(1));

      final list = state.currentShoppingList;
      state.renameShoppingList(list, ' ');
      expect(list.name, defaultShoppingListName);
      state.renameShoppingList(list, ' Wocheneinkauf ');
      expect(list.name, 'Wocheneinkauf');
    });

    test('Loeschen nimmt die Liste samt Eintraegen, die erste rueckt nach',
        () {
      final state = AppState();
      final erste = state.currentShoppingList;
      final drogerie = state.addShoppingList('Drogerie')!;
      state.addShoppingItem('Zahnpasta');

      state.deleteShoppingList(drogerie);
      expect(state.shoppingLists, [erste]);
      expect(state.currentShoppingList, same(erste));
      expect(state.shoppingItems, isEmpty);
    });

    test('die letzte Liste bleibt stehen', () {
      final state = AppState();
      state.addShoppingItem('Milch');
      state.deleteShoppingList(state.currentShoppingList);
      expect(state.shoppingLists, hasLength(1));
      expect(titles(state.shoppingItems), ['Milch']);
    });

    test('Eintrag loeschen findet ihn auch in einer anderen Liste', () {
      final state = AppState();
      final milch = state.addShoppingItem('Milch')!;
      state.addShoppingList('Baumarkt');
      state.deleteShoppingItem(milch);
      expect(state.shoppingLists.first.items, isEmpty);
    });
  });

  group('Teilen', () {
    test('Name, darunter die offenen Eintraege in Anzeigereihenfolge', () {
      final state = withItems([
        ShoppingItem(id: '2', title: 'Brot', createdAt: DateTime(2026, 9, 2)),
        ShoppingItem(
          id: '1',
          title: 'Käse',
          createdAt: DateTime(2026, 9, 1),
          done: true,
        ),
        ShoppingItem(id: '3', title: 'Eier', createdAt: DateTime(2026, 9, 3)),
        ShoppingItem(id: '0', title: 'Milch', createdAt: DateTime(2026, 9, 1)),
      ]);
      expect(
        state.currentShoppingList.shareText,
        'Einkaufsliste\n- Milch\n- Brot\n- Eier',
      );
    });

    test('nichts Offenes heisst: nichts zu teilen', () {
      final state = AppState();
      expect(state.currentShoppingList.shareText, isNull);
      state.toggleShoppingItem(state.addShoppingItem('Milch')!);
      expect(state.currentShoppingList.shareText, isNull);
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

    test('mehrere Listen und die gezeigte kommen zurueck', () async {
      final state = AppState();
      await state.load();
      state.addShoppingItem('Milch');
      state.addShoppingList('Baumarkt');
      state.addShoppingItem('Schrauben');
      await pumpEventQueue();

      final wieder = AppState();
      await wieder.load();
      expect(
        [for (final l in wieder.shoppingLists) l.name],
        [defaultShoppingListName, 'Baumarkt'],
      );
      expect(wieder.currentShoppingList.name, 'Baumarkt');
      expect(titles(wieder.shoppingItems), ['Schrauben']);
      expect(titles(wieder.shoppingLists.first.items), ['Milch']);
    });

    test('die eine Liste bis 1.2.0 wird zur ersten der Listen', () async {
      final raw = jsonEncode({
        'tasks': [],
        'shopping': [
          ShoppingItem(id: '1', title: 'Milch', createdAt: DateTime(2026, 9, 1))
              .toJson(),
          ShoppingItem(
            id: '2',
            title: 'Brot',
            createdAt: DateTime(2026, 9, 2),
            done: true,
          ).toJson(),
        ],
      });
      SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
      final state = AppState();
      await state.load();

      expect(state.shoppingLists, hasLength(1));
      expect(state.currentShoppingList.name, defaultShoppingListName);
      expect(titles(state.shoppingItems), ['Milch', 'Brot']);
      expect(state.shoppingItems.last.done, isTrue);
      // Uebernehmen ist kein Verlust.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), isNull);

      // Gespeichert wird nur noch die neue Form.
      state.addShoppingItem('Käse');
      await pumpEventQueue();
      final saved =
          jsonDecode(prefs.getString('joe_data_v1')!) as Map<String, dynamic>;
      expect(saved.containsKey('shopping'), isFalse);
      expect(saved['shoppingLists'], hasLength(1));
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

    test('eine kaputte Liste kostet nur sich selbst, ein kaputter Name nichts',
        () async {
      final raw = jsonEncode({
        'shoppingLists': [
          {'id': 1, 'name': 'Kaputt', 'items': []}, // kaputt: Zahl als ID
          {
            'id': 'b',
            'name': 42, // falscher Typ: Standardname, Eintraege bleiben
            'items': [
              ShoppingItem(
                id: '1',
                title: 'Milch',
                createdAt: DateTime(2026, 9, 1),
              ).toJson(),
            ],
          },
        ],
      });
      SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
      final state = AppState();
      await state.load();

      expect(state.shoppingLists, hasLength(1));
      expect(state.currentShoppingList.name, defaultShoppingListName);
      expect(titles(state.shoppingItems), ['Milch']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), raw);
    });

    test('eine verschwundene gezeigte Liste heisst: die erste', () async {
      final raw = jsonEncode({
        'shoppingLists': [
          ShoppingList(id: 'a', name: 'Eins').toJson(),
          ShoppingList(id: 'b', name: 'Zwei').toJson(),
        ],
        'shoppingListId': 'weg',
      });
      SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
      final state = AppState();
      await state.load();
      expect(state.currentShoppingList.name, 'Eins');
    });

    test('ohne jede lesbare Liste steht wieder eine leere da', () async {
      SharedPreferences.setMockInitialValues({
        'joe_data_v1': jsonEncode({'shoppingLists': 'Unsinn'}),
      });
      final state = AppState();
      await state.load();
      expect(state.shoppingLists, hasLength(1));
      expect(state.shoppingItems, isEmpty);
    });
  });
}
