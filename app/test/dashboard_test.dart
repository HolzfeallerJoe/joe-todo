import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';
import 'package:joe_todo/widgets.dart';

/// Dashboard mit festem Datenstand, ohne Persistenz und ohne Begleiterbild
/// (Assets werden im Widget-Test nicht ausgeliefert). [height] ist die
/// logische Fensterhoehe – hoch genug gesetzt sieht der Test die ganze
/// Reiterleiste, ohne scrollen zu muessen.
Future<AppState> pumpDashboard(
  WidgetTester tester, {
  List<Task> tasks = const [],
  List<Appointment> appointments = const [],
  double height = 800,
}) async {
  // Die Testschrift setzt jedes Zeichen auf ein volles Quadrat, deshalb ist
  // das Fenster deutlich breiter als ein echtes Telefon.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(560, height);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = [...tasks]
    ..appointments = [...appointments]
    ..notes = []
    ..showPet = false;
  await tester.pumpWidget(JoeApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Sichtbare Hoehe des Ausklappmenues unter [title] – zugeklappt ist sie 0,
/// der Inhalt bleibt aber (unsichtbar und ohne Semantik) im Baum. Seit dem
/// Termin-Block gibt es zwei davon, deshalb ueber den Titel gesucht.
double foldHeight(WidgetTester tester, [String title = 'Heute abhaken']) =>
    tester
        .getSize(find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(FoldSection),
          ),
          matching: find.byType(AnimatedCrossFade),
        ))
        .height;

/// Ob die Zeile [label] Tipps annimmt. Zugeklappt liegt der Inhalt des
/// Ausklappmenues hinter einem IgnorePointer von AnimatedCrossFade und ist
/// damit nicht mehr bedienbar, auch wenn er im Baum stehen bleibt.
bool takesTaps(WidgetTester tester, String label) => !tester
    .widgetList<IgnorePointer>(
      find.ancestor(of: find.text(label), matching: find.byType(IgnorePointer)),
    )
    .any((widget) => widget.ignoring);

void main() {
  /// Die Kopfzeile der Heute-Karte steht in zwei Zeilen da, vorgelesen wird
  /// sie aber als ein Satz – gesucht wird deshalb ueber die Vorlesehilfe.
  Finder headline(int tasks, int appointments) => find.bySemanticsLabel(
        '$tasks ${tasks == 1 ? 'offene Aufgabe' : 'offene Aufgaben'} '
        'und $appointments ${appointments == 1 ? 'Termin' : 'Termine'} heute',
      );

  /// Ein sichtbarer Text innerhalb der Kopfzeile – die Zahlen stehen auch in
  /// den Ausklappmenues darunter.
  Finder inHeadline(String text) => find.descendant(
        of: find.byType(TodayHeadline),
        matching: find.text(text),
      );

  List<Task> openTasks(int n) => [
        for (var i = 0; i < n; i++)
          Task(id: 't$i', title: 'Aufgabe $i', startDate: today()),
      ];

  List<Appointment> todayAppointments(int n) => [
        for (var i = 0; i < n; i++)
          Appointment(
            id: 'a$i',
            title: 'Termin $i',
            when: today().add(Duration(hours: 9 + i)),
          ),
      ];

  testWidgets('Stufe 3 zaehlt am Faelligkeitstag mit', (tester) async {
    final t = today();
    await pumpDashboard(
      tester,
      tasks: [
        Task(id: '1', title: 'Wichtig', startDate: t, priority: Priority.hoch),
        Task(id: '2', title: 'Normal', startDate: t),
        Task(id: '3', title: 'Leise', startDate: t, priority: Priority.niedrig),
      ],
    );

    expect(headline(3, 0), findsOneWidget);
    // Heute steht sie in derselben Liste wie der Rest, kein eigener Block.
    expect(find.text('Hat Zeit'), findsNothing);
  });

  testWidgets('danach faellt Stufe 3 aus der Zahl und steht unter "Hat Zeit"',
      (tester) async {
    final t = today();
    await pumpDashboard(
      tester,
      tasks: [
        Task(id: '1', title: 'Wichtig', startDate: t, priority: Priority.hoch),
        Task(id: '2', title: 'Normal', startDate: t),
        Task(
          id: '3',
          title: 'Unwichtig',
          startDate: t.subtract(const Duration(days: 4)),
          priority: Priority.niedrig,
        ),
      ],
    );

    // Die Zahl nennt nur noch die beiden von heute …
    expect(headline(2, 0), findsOneWidget);
    // … das Ausklappmenue zeigt aber weiter alle drei.
    expect(find.text('Hat Zeit'), findsOneWidget);
    expect(find.text('Unwichtig'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Heute abhaken'),
          matching: find.byType(Row),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    // Eine ueberfaellige Aufgabe anderer Stufen zaehlt dagegen weiter mit –
    // "Hat Zeit" ist der Prioritaet geschuldet, nicht dem Datum.
    expect(
      find.text('offen seit ${formatDate(t.subtract(const Duration(days: 4)))}'),
      findsOneWidget,
    );
  });

  testWidgets('Ausklappmenue zeigt und verbirgt die Aufgaben', (tester) async {
    final t = today();
    final state = await pumpDashboard(
      tester,
      tasks: [
        Task(id: '1', title: 'Normal', startDate: t),
        Task(
          id: '3',
          title: 'Unwichtig',
          startDate: t.subtract(const Duration(days: 4)),
          priority: Priority.niedrig,
        ),
      ],
    );

    // Standardmaessig offen: beide Aufgaben stehen da, die liegengebliebene
    // Stufe-3-Aufgabe unter "Hat Zeit" mit ihrem Offen-seit-Datum.
    expect(state.todayExpanded, isTrue);
    expect(find.text('Heute abhaken'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Hat Zeit'), findsOneWidget);
    expect(find.text('Unwichtig'), findsOneWidget);
    expect(
      find.text(
        'offen seit ${formatDate(t.subtract(const Duration(days: 4)))}',
      ),
      findsOneWidget,
    );

    expect(foldHeight(tester), greaterThan(0));

    await tester.tap(find.text('Heute abhaken'));
    await tester.pumpAndSettle();

    // Zugeklappt: Kopfzeile bleibt, der Inhalt ist auf Hoehe 0 geklappt und
    // aus der Semantik genommen.
    expect(state.todayExpanded, isFalse);
    expect(find.text('Heute abhaken'), findsOneWidget);
    expect(foldHeight(tester), 0);
  });

  testWidgets('zugeklappte Aufgaben sind nicht mehr antippbar', (tester) async {
    final state = await pumpDashboard(
      tester,
      tasks: [Task(id: '1', title: 'Normal', startDate: today())],
    );

    expect(takesTaps(tester, 'Normal'), isTrue);

    state.setTodayExpanded(false);
    await tester.pumpAndSettle();

    expect(takesTaps(tester, 'Normal'), isFalse);
  });

  testWidgets('Aufgaben und Ausklappkopf melden ihren Zustand', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDashboard(
      tester,
      tasks: [Task(id: '1', title: 'Normal', startDate: today())],
    );

    var taskData =
        tester.getSemantics(find.bySemanticsLabel('Normal')).getSemanticsData();
    expect(taskData.flagsCollection.isChecked, ui.CheckedState.isFalse);

    var foldData = tester
        .getSemantics(find.bySemanticsLabel('Heute abhaken, 1 Aufgabe'))
        .getSemanticsData();
    expect(foldData.flagsCollection.isExpanded, ui.Tristate.isTrue);

    await tester.tap(find.bySemanticsLabel('Normal'));
    await tester.pumpAndSettle();
    taskData =
        tester.getSemantics(find.bySemanticsLabel('Normal')).getSemanticsData();
    expect(taskData.flagsCollection.isChecked, ui.CheckedState.isTrue);

    await tester.tap(find.bySemanticsLabel('Heute abhaken, 1 Aufgabe'));
    await tester.pumpAndSettle();
    foldData = tester
        .getSemantics(find.bySemanticsLabel('Heute abhaken, 1 Aufgabe'))
        .getSemanticsData();
    expect(foldData.flagsCollection.isExpanded, ui.Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('die Kopfzeile nennt Aufgaben und Termine in zwei Zeilen',
      (tester) async {
    final t = today();
    await pumpDashboard(
      tester,
      tasks: [Task(id: '1', title: 'Normal', startDate: t)],
      appointments: [
        Appointment(
            id: 'a', title: 'Zahnarzt', when: t.add(const Duration(hours: 9))),
        Appointment(
            id: 'b', title: 'Kaffee', when: t.add(const Duration(hours: 15))),
        // Morgen gehoert nicht zu heute.
        Appointment(
          id: 'c',
          title: 'Sport',
          when: t.add(const Duration(days: 1, hours: 18)),
        ),
      ],
    );

    expect(headline(1, 2), findsOneWidget);
    // Beide Ausklappmenues stehen auf derselben Karte.
    expect(find.byType(PaperCard).evaluate().length, greaterThan(0));
    expect(find.text('Heute abhaken'), findsOneWidget);
    expect(find.text('Heutige Termine'), findsOneWidget);
    // Nur das von heute steht in der Liste.
    expect(find.text('Zahnarzt'), findsOneWidget);
    expect(find.text('Kaffee'), findsOneWidget);
    expect(find.text('Sport'), findsNothing);
  });

  testWidgets('die Zahlen der Kopfzeile stehen rechtsbuendig untereinander',
      (tester) async {
    await pumpDashboard(
      tester,
      tasks: openTasks(12),
      appointments: todayAppointments(3),
      height: 1600,
    );

    expect(headline(12, 3), findsOneWidget);
    final twelve = tester.getTopRight(inHeadline('12'));
    final three = tester.getTopRight(inHeadline('3'));
    // Rechte Kanten buendig, "12" steht ueber "3".
    expect(twelve.dx, moreOrLessEquals(three.dx, epsilon: 0.5));
    expect(twelve.dy, lessThan(three.dy));
    // Die Woerter beginnen auf derselben Kante.
    expect(
      tester.getTopLeft(inHeadline('offene Aufgaben')).dx,
      moreOrLessEquals(
        tester.getTopLeft(inHeadline('Termine heute')).dx,
        epsilon: 0.5,
      ),
    );
  });

  testWidgets('die Kopfzeile zeigt kein "und" mehr, liest es aber vor',
      (tester) async {
    await pumpDashboard(
      tester,
      tasks: openTasks(1),
      appointments: todayAppointments(1),
    );

    // Einzahl wie bisher.
    expect(inHeadline('offene Aufgabe'), findsOneWidget);
    expect(inHeadline('Termin heute'), findsOneWidget);
    // Sichtbar steht nirgends in der Kopfzeile ein "und" …
    expect(
      find.descendant(
        of: find.byType(TodayHeadline),
        matching: find.textContaining(' und '),
      ),
      findsNothing,
    );
    expect(find.textContaining('offene Aufgabe und'), findsNothing);
    // … vorgelesen wird es als ein Satz.
    expect(headline(1, 1), findsOneWidget);
  });

  testWidgets('die Kopfzeile laeuft bei grosser Systemschrift nicht ueber',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final state = AppState()..showPet = false;

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    TodayHeadline(tasks: 12, appointments: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Das Wort bricht innerhalb seiner Zeile um und bleibt in der Karte.
    expect(
      tester.getTopRight(inHeadline('offene Aufgaben')).dx,
      lessThanOrEqualTo(360 - 34 + 0.5),
    );
  });

  testWidgets('Aufgaben und Termine teilen sich eine Karte', (tester) async {
    final t = today();
    await pumpDashboard(
      tester,
      tasks: [Task(id: '1', title: 'Normal', startDate: t)],
      appointments: [
        Appointment(
            id: 'a', title: 'Zahnarzt', when: t.add(const Duration(hours: 9))),
      ],
    );

    // Dieselbe Karte traegt beide Ausklappmenues – der Tag zerfaellt nicht
    // in zwei Haelften.
    final card = find
        .ancestor(
          of: find.text('Heute abhaken'),
          matching: find.byType(PaperCard),
        )
        .first;
    expect(
      find.descendant(of: card, matching: find.text('Heutige Termine')),
      findsOneWidget,
    );
  });

  testWidgets('ohne Termine steht der Block leer da', (tester) async {
    await pumpDashboard(tester);

    expect(headline(0, 0), findsOneWidget);
    expect(find.text('Heute keine Termine'), findsOneWidget);
  });

  testWidgets('das Termin-Ausklappmenue klappt fuer sich', (tester) async {
    final t = today();
    final state = await pumpDashboard(
      tester,
      tasks: [Task(id: '1', title: 'Normal', startDate: t)],
      appointments: [
        Appointment(id: 'a', title: 'Zahnarzt', when: t.add(const Duration(hours: 9))),
      ],
    );

    expect(state.appointmentsExpanded, isTrue);
    expect(foldHeight(tester, 'Heutige Termine'), greaterThan(0));

    await tester.tap(find.text('Heutige Termine'));
    await tester.pumpAndSettle();

    // Nur der Termin-Block klappt zu, die Aufgaben bleiben offen.
    expect(state.appointmentsExpanded, isFalse);
    expect(state.todayExpanded, isTrue);
    expect(foldHeight(tester, 'Heutige Termine'), 0);
    expect(foldHeight(tester), greaterThan(0));
  });

  testWidgets('Reiter stehen in der vorgegebenen Reihenfolge', (tester) async {
    await pumpDashboard(tester, height: 1600);

    const order = [
      'Aufgaben',
      'Termine',
      'Kalender',
      'Notizen',
      'Historie',
      'Einstellungen',
    ];
    final tops = [
      for (final label in order) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('ein langer Reitername aendert nichts an Schrift und Symbolen',
      (tester) async {
    final state = await pumpDashboard(tester, height: 1600);
    double fontOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.fontSize!;
    List<double> iconSizes() => [
          for (final icon in tester.widgetList<Icon>(find.descendant(
            of: find.byType(FolderTabButton),
            matching: find.byType(Icon),
          )))
            icon.size ?? 24,
        ];

    final vorher = fontOf('Aufgaben');
    final symboleVorher = iconSizes();

    state.setShoppingMode(ShoppingListMode.notes);
    await tester.pumpAndSettle();

    // Der lange Name wird nicht kleiner gesetzt als die kurzen – und die
    // anderen Reiter merken von ihm ueberhaupt nichts.
    expect(fontOf('Notizen/Einkaufsliste'), vorher);
    expect(fontOf('Aufgaben'), vorher);
    expect(fontOf('Historie'), vorher);
    // Auch die Symbole bleiben, wie sie waren (der Einkaufs-Reiter faellt
    // in diesem Modus weg, seine zwei Symbole also auch).
    expect(iconSizes(), symboleVorher.sublist(2));
  });
}
