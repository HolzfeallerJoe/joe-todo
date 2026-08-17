import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/main.dart';
import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

/// Dashboard mit festem Datenstand, ohne Persistenz und ohne Begleiterbild
/// (Assets werden im Widget-Test nicht ausgeliefert). [height] ist die
/// logische Fensterhoehe – hoch genug gesetzt sieht der Test die ganze
/// Reiterleiste, ohne scrollen zu muessen.
Future<AppState> pumpDashboard(
  WidgetTester tester, {
  List<Task> tasks = const [],
  double height = 800,
}) async {
  // Die Testschrift setzt jedes Zeichen auf ein volles Quadrat, deshalb ist
  // das Fenster deutlich breiter als ein echtes Telefon.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(560, height);
  addTearDown(tester.view.reset);

  final state = AppState()
    ..tasks = [...tasks]
    ..appointments = []
    ..notes = []
    ..showPet = false;
  await tester.pumpWidget(JoeApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Sichtbare Hoehe des Ausklappmenues – zugeklappt ist sie 0, der Inhalt
/// bleibt aber (unsichtbar und ohne Semantik) im Baum.
double foldHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedCrossFade)).height;

/// Ob die Zeile [label] Tipps annimmt. Zugeklappt liegt der Inhalt des
/// Ausklappmenues hinter einem IgnorePointer von AnimatedCrossFade und ist
/// damit nicht mehr bedienbar, auch wenn er im Baum stehen bleibt.
bool takesTaps(WidgetTester tester, String label) => !tester
    .widgetList<IgnorePointer>(
      find.ancestor(of: find.text(label), matching: find.byType(IgnorePointer)),
    )
    .any((widget) => widget.ignoring);

void main() {
  testWidgets('Heute-Karte zaehlt auch Stufe 3 mit', (tester) async {
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

    // Die leise Aufgabe steht weiter unten unter "Kann warten", ist heute
    // aber genauso faellig – also zaehlt sie in der Kopfzahl mit.
    // Die Zahl steht auch in der Kopfzeile des Ausklappmenues, darum wird
    // hier gezielt die Zeile der grossen Zahl geprueft.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('offene Aufgaben heute'),
          matching: find.byType(Row),
        ),
        matching: find.text('3'),
      ),
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

    // Standardmaessig offen: beide Aufgaben stehen da, die Stufe-3-Aufgabe
    // unter "Kann warten" mit ihrem Offen-seit-Datum.
    expect(state.todayExpanded, isTrue);
    expect(find.text('Heute abhaken'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Kann warten'), findsOneWidget);
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
}
