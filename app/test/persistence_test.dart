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

  test('Befinden und eigene Symptome kommen zurueck', () async {
    final data = validData()
      ..['wellbeing'] = [
        WellbeingEntry(
          id: 'w1',
          noteId: 'n1',
          at: DateTime(2026, 8, 20, 8, 30),
          mood: Mood.naja,
          symptoms: {'kopfschmerzen': 3, 'eigen_1': 5},
          updatedAt: DateTime(2026, 8, 20, 21),
        ).toJson(),
        WellbeingEntry(
          id: 'w2',
          noteId: 'n1',
          at: DateTime(2026, 8, 20, 20, 0),
          mood: Mood.gut,
          updatedAt: DateTime(2026, 8, 20, 21),
        ).toJson(),
      ]
      ..['customSymptoms'] = [const Symptom('eigen_1', 'Migräne').toJson()];
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});

    final state = AppState();
    await state.load();

    expect(state.symptomById('eigen_1')!.name, 'Migräne');
    final entries = state.wellbeingOfNote('n1');
    expect(entries, hasLength(2));
    // Nach Uhrzeit, morgens zuerst.
    expect(entries.first.mood, Mood.naja);
    expect(entries.first.symptoms, {'kopfschmerzen': 3, 'eigen_1': 5});
    expect(entries.last.dayPart, 'Abends');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('ein Eintrag aus der ersten Fassung findet seine Notiz', () async {
    // Damals gab es einen Eintrag je Tag, ohne Uhrzeit ('date' statt 'at')
    // und ohne Notiz. Beim Laden bekommt er die Notiz seines Tages.
    final day = DateTime(2026, 8, 20);
    final data = validData()
      ..['notes'] = [
        Note(
          id: 'n-alt',
          title: 'Der Tag',
          body: '',
          date: day,
          updatedAt: day,
        ).toJson(),
      ]
      ..['wellbeing'] = [
        {
          'id': 'alt',
          'date': '2026-08-20',
          'mood': 'gut',
          'symptoms': {'koliken': 1},
          'updatedAt': '2026-08-20T21:00:00.000',
        },
      ];
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});

    final state = AppState();
    await state.load();

    final entry = state.wellbeingOfNote('n-alt').single;
    expect(entry.mood, Mood.gut);
    expect(entry.at, day);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('ein Eintrag ohne Notiz an seinem Tag bleibt trotzdem liegen',
      () async {
    // Wegwerfen waere schlimmer als unsichtbar: Aufzeichnungen ueber die
    // eigene Gesundheit loescht die App nicht im Vorbeigehen.
    final data = validData()
      ..['wellbeing'] = [
        {
          'id': 'heimatlos',
          'at': '2026-08-20T08:00:00.000',
          'mood': 'gut',
          'symptoms': <String, int>{},
          'updatedAt': '2026-08-20T21:00:00.000',
        },
      ];
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});

    final state = AppState();
    await state.load();

    expect(state.wellbeing, hasLength(1));
    expect(state.wellbeing.single.noteId, isNull);
  });

  test('ohne Angabe bleibt das Befinden leer', () async {
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    final state = AppState();
    await state.load();

    expect(state.wellbeing, isEmpty);
    expect(state.customSymptoms, isEmpty);
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

  test('eine taegliche Aufgabe von vorher laedt als alle sieben Tage',
      () async {
    // "daily" gibt es als eigene Art nicht mehr (Wochenskala). Das
    // Umschreiben ist kein Verlust, also auch keine Rettungskopie.
    final data = validData()
      ..['tasks'] = [
        {
          'id': 'alt',
          'title': 'Blumen gießen',
          'recurrence': 'daily',
          'intervalDays': 2,
          'startDate': '2026-07-01',
          'colorIndex': 2,
          'completedDates': ['2026-07-02'],
        },
      ];
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});
    final state = AppState();
    await state.load();

    final task = state.tasks.single;
    expect(task.recurrence, RecurrenceType.weekly);
    expect(task.weekdays, allWeekdays);
    expect(task.isCompletedOn(DateTime(2026, 7, 2)), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  test('die Dauer ueberlebt Speichern und Laden', () async {
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    final state = AppState();
    await state.load();
    state.addTask(Task(
      id: 'dauer',
      title: 'Mo bis Do',
      startDate: DateTime(2026, 9, 14),
      spanDays: 3,
      startMinute: 12 * 60,
      endMinute: 18 * 60,
    ));
    state.addAppointment(Appointment(
      id: 'lang',
      title: 'Messe',
      when: DateTime(2026, 9, 14, 12),
      end: DateTime(2026, 9, 17, 18),
    ));
    await pumpEventQueue();

    final wieder = AppState();
    await wieder.load();
    final task = wieder.tasks.firstWhere((t) => t.id == 'dauer');
    expect(task.spanDays, 3);
    expect(task.startMinute, 720);
    expect(task.endMinute, 1080);
    final termin = wieder.appointments.firstWhere((a) => a.id == 'lang');
    expect(termin.end, DateTime(2026, 9, 17, 18));
  });

  test('eine unbrauchbare Dauer kostet nur die Dauer', () async {
    final data = validData()
      ..['tasks'] = [
        {
          'id': 'minus',
          'title': 'Negativ',
          'recurrence': 'none',
          'startDate': '2026-09-14',
          'spanDays': -2,
        },
        {
          'id': 'halb',
          'title': 'Nur Anfang',
          'recurrence': 'none',
          'startDate': '2026-09-14',
          'startMinute': 720,
        },
      ]
      ..['appointments'] = [
        {
          'id': 'rueckwaerts',
          'title': 'Ende vor Start',
          'when': '2026-09-14T12:00:00.000',
          'end': '2026-09-13T12:00:00.000',
        },
      ];
    SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});
    final state = AppState();
    await state.load();

    expect(state.tasks, hasLength(2));
    expect(state.tasks.every((t) => !t.hasDuration), isTrue);
    expect(state.appointments.single.end, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppState.rescueKey), isNull);
  });

  group('Prioritaetsfarben', () {
    tearDown(PriorityColors.reset);

    test('kommen nach Speichern und Laden zurueck', () async {
      SharedPreferences.setMockInitialValues(
          {'joe_data_v1': jsonEncode(validData())});
      final state = AppState();
      await state.load();
      expect(state.priorityColors, isEmpty, reason: 'Standard: keine Farbe');

      state.setPriorityColor(Priority.hoch, 20);
      state.setPriorityColor(Priority.niedrig, 14);
      await pumpEventQueue();
      // Die Tabelle ist statisch – leeren, damit das Laden sie beweisen muss.
      PriorityColors.reset();

      final wieder = AppState();
      await wieder.load();
      expect(wieder.priorityColors, {Priority.hoch: 20, Priority.niedrig: 14});
      expect(PriorityColors.of(Priority.hoch), 20);
      expect(PriorityColors.of(Priority.mittel), isNull);
    });

    test('Unsinn heisst "keine Farbe", ohne Verlust', () async {
      final data = validData()
        ..['priorityColors'] = {'hoch': 99, 'egal': 3, 'mittel': 'x'};
      SharedPreferences.setMockInitialValues({'joe_data_v1': jsonEncode(data)});
      final state = AppState();
      await state.load();

      expect(state.priorityColors, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), isNull);

      // Kein Map-Typ: ebenso.
      final liste = validData()..['priorityColors'] = [20];
      SharedPreferences.setMockInitialValues(
          {'joe_data_v1': jsonEncode(liste)});
      final zweiter = AppState();
      await zweiter.load();
      expect(zweiter.priorityColors, isEmpty);
    });

    test('ein erster Start nimmt keine alten Farben mit', () async {
      PriorityColors.use({Priority.hoch: 20});
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      expect(PriorityColors.of(Priority.hoch), isNull);
    });
  });

  test('die Groesse des Begleiters kommt zurueck', () async {
    SharedPreferences.setMockInitialValues(
        {'joe_data_v1': jsonEncode(validData())});
    final state = AppState();
    await state.load();
    expect(state.petScale, 1.0, reason: 'Standard: 100 %');

    // Gerundet auf Zehnerschritte, wie der Regler sie liefert.
    state.setPetScale(1.3000000001);
    expect(state.petScale, 1.3);
    await pumpEventQueue();
    final wieder = AppState();
    await wieder.load();
    expect(wieder.petScale, 1.3);

    // Ausserhalb des Reglers wird geklemmt.
    state.setPetScale(0.1);
    expect(state.petScale, minPetScale);
  });

  test('eine unbrauchbare Begleitergroesse faellt auf 100 %', () async {
    Future<double> geladen(Object? value) async {
      final data = validData()..['petScale'] = value;
      SharedPreferences.setMockInitialValues(
          {'joe_data_v1': jsonEncode(data)});
      final state = AppState();
      await state.load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.rescueKey), isNull);
      return state.petScale;
    }

    expect(await geladen('gross'), 1.0);
    expect(await geladen(9), maxPetScale);
    expect(await geladen(0.2), minPetScale);
    expect(await geladen(null), 1.0);
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
