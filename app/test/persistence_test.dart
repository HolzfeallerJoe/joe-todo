import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joe_todo/almanac.dart';
import 'package:joe_todo/env.dart';
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

  test('Kalender-Ebenen: Standards und gespeicherte Werte', () async {
    // Ohne gespeicherte Schluessel: Feiertage und Mond an, Geraete-Kalender
    // aus (der braucht eine Berechtigung und wartet auf den Schalter).
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    var state = AppState();
    await state.load();
    expect(state.showHolidays, isTrue);
    expect(state.showMoon, isTrue);
    expect(state.holidayRegion, HolidayRegion.bund);
    expect(state.showDeviceCalendar, isFalse);

    // Gespeicherte Werte kommen wieder, Unlesbares faellt auf den Standard.
    final data = validData();
    data['showHolidays'] = false;
    data['holidayRegion'] = 'by';
    data['showDeviceCalendar'] = true;
    data['showMoon'] = 'ja';
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(data)});
    state = AppState();
    await state.load();
    expect(state.showHolidays, isFalse);
    expect(state.holidayRegion, HolidayRegion.by);
    expect(state.showDeviceCalendar, isTrue);
    expect(state.showMoon, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('Geraete-Kalender-Auswahl: alle, einige, keiner', () async {
    // Die drei Zustaende muessen sich ueber Speichern und Laden hinweg
    // unterscheiden lassen: "nie ausgewaehlt" (null, also alle) ist etwas
    // anderes als "alle abgewaehlt" (leer, also nichts).
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    final state = AppState();
    await state.load();
    expect(state.deviceCalendarIds, isNull, reason: 'Standard ist "alle"');

    Future<AppState> nachNeuladen(Set<String>? ids) async {
      state.setDeviceCalendarIds(ids);
      // Gespeichert wird fire-and-forget; hier auf den Schreibvorgang warten.
      await pumpEventQueue();
      final wieder = AppState();
      await wieder.load();
      return wieder;
    }

    expect((await nachNeuladen({'1', '7'})).deviceCalendarIds, {'1', '7'});
    // Leer bleibt leer und wird nicht zu null zurueckgedeutet.
    expect((await nachNeuladen(<String>{})).deviceCalendarIds, isEmpty);
    expect((await nachNeuladen(null)).deviceCalendarIds, isNull);
  });

  test('unbrauchbare Kalender-Auswahl faellt auf "alle"', () async {
    final data = validData();
    data['deviceCalendarIds'] = 'alle bitte';
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});
    final state = AppState();
    await state.load();
    expect(state.deviceCalendarIds, isNull);

    // Eine Liste mit Fremdkoerpern behaelt, was brauchbar ist.
    final gemischt = validData();
    gemischt['deviceCalendarIds'] = ['1', 2, null, '3'];
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(gemischt)});
    final zweiter = AppState();
    await zweiter.load();
    expect(zweiter.deviceCalendarIds, {'1', '3'});
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

  // Beispieldaten haengen am Schalter JOE_MOCK_DATA (siehe lib/env.dart).
  // Er kommt beim Bauen aus env/.env bzw. env/.env.production und ist damit
  // eine Konstante – ein Test stellt ihn ueber JoeEnv.debugMockData um.
  // Beide Faelle stehen hier: der Schalter ist ueberall aus, aber
  // angeschaltet muss er weiter tun.
  group('erster Start', () {
    tearDown(() => JoeEnv.debugMockData = null);

    test('ohne Schalter: leer, aber gespeichert', () async {
      SharedPreferences.setMockInitialValues({});
      JoeEnv.debugMockData = false;
      final state = AppState();
      await state.load();

      expect(state.tasks, isEmpty);
      expect(state.appointments, isEmpty);
      expect(state.notes, isEmpty);
      // Ohne den geschriebenen Bestand waere der naechste Start wieder der
      // erste – und ein leerer Bestand nicht von "noch nie gestartet" zu
      // unterscheiden.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('joe_data_v1'), isNotNull);
    });

    // Ohne das Flag beim Bauen (IDE-Run, 'flutter test') gilt der Standard
    // aus lib/env.dart – und der ist der ausgelieferte.
    test('ohne Angabe: der Standard gilt, also leer', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();

      expect(JoeEnv.mockData, isFalse);
      expect(state.tasks, isEmpty);
    });

    test('mit Schalter: Beispieldaten', () async {
      SharedPreferences.setMockInitialValues({});
      JoeEnv.debugMockData = true;
      final state = AppState();
      await state.load();

      expect(state.tasks, isNotEmpty);
      expect(state.appointments, isNotEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('joe_data_v1'), isNotNull);
    });
  });
}
