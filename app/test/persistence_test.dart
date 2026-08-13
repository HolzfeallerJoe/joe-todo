import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/pets.dart';
import 'package:joe_todo/util.dart';

/// Das Fangnetz beim Laden: nichts darf den Start verhindern, und nie wird
/// ueber die einzige Kopie der Daten geschrieben, ohne sie vorher unter
/// [AppState.rescueKey] beiseitezulegen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> validData() => {
        'tasks': [Task(id: '1', title: 'Gut', startDate: today()).toJson()],
        'appointments': [
          Appointment(id: '2', title: 'Termin', when: DateTime(2026, 8, 20, 15))
              .toJson(),
        ],
        'notes': [],
        'themeIndex': 3,
      };

  test('heiler Bestand laedt ohne Rettungskopie', () async {
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    final state = AppState();
    await state.load();

    expect(state.tasks.map((t) => t.title), ['Gut']);
    expect(state.appointments, hasLength(1));
    expect(state.themeIndex, 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('unlesbares JSON: App startet, Original liegt unter rescue', () async {
    SharedPreferences.setMockInitialValues({'joe_data_v1': '{kaputt'});
    final state = AppState();
    await state.load(); // darf nicht werfen – main() wartet darauf

    expect(state.tasks, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), '{kaputt');
    // und der neu geschriebene Bestand ist wieder lesbar
    final healed = prefs.getString('joe_data_v1');
    expect(jsonDecode(healed!), isA<Map<String, dynamic>>());
  });

  test('ein kaputter Eintrag kostet nur sich selbst', () async {
    final data = validData();
    (data['tasks'] as List).add({'id': 99, 'title': null}); // kaputt
    final raw = jsonEncode(data);
    SharedPreferences.setMockInitialValues({'joe_data_v1': raw});
    final state = AppState();
    await state.load();

    // Der heile Rest ist da, der alte Bestand liegt unangetastet daneben.
    expect(state.tasks.map((t) => t.title), ['Gut']);
    expect(state.appointments, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), raw);
  });

  test('falsch getypte Einstellungen fallen auf ihren Standard', () async {
    final data = validData();
    data['themeIndex'] = 'drei';
    data['petId'] = 7;
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});
    final state = AppState();
    await state.load();

    expect(state.themeIndex, 0);
    expect(state.petId, defaultPetId);
    // Kein Datenverlust, also auch keine Rettungskopie.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('erster Start saet Beispieldaten', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();

    expect(state.tasks, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('joe_data_v1'), isNotNull);
  });
}
