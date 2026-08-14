import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/screens/notes.dart';

Future<AppState> pumpEditor(
  WidgetTester tester, {
  Note? note,
  bool onOwnRoute = false,
  bool rebuildOnStateChange = false,
}) async {
  final state = AppState()
    ..tasks = []
    ..appointments = []
    ..notes = note == null ? [] : [note]
    ..showPet = false;

  Widget app() => MaterialApp(
        home: onOwnRoute
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditScreen(note: note),
                    ),
                  ),
                  child: const Text('Öffnen'),
                ),
              )
            : NoteEditScreen(note: note),
      );
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: rebuildOnStateChange
          ? ListenableBuilder(listenable: state, builder: (_, _) => app())
          : app(),
    ),
  );
  if (onOwnRoute) {
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }
  return state;
}

void main() {
  testWidgets('bestehende Notiz speichert nach der Schreibpause',
      (tester) async {
    final note = Note(
      id: 'n1',
      title: 'Alt',
      body: 'Text',
      updatedAt: DateTime(2026, 8, 14),
    );
    await pumpEditor(tester, note: note);

    await tester.enterText(find.byType(TextField).first, 'Neu');
    await tester.pump(noteAutosaveDelay - const Duration(milliseconds: 1));
    expect(note.title, 'Alt');

    await tester.pump(const Duration(milliseconds: 1));
    expect(note.title, 'Neu');
  });

  testWidgets('neue Notiz entsteht erst mit echtem Inhalt', (tester) async {
    final state = await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump(noteAutosaveDelay);
    expect(state.notes, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'Ein Gedanke');
    await tester.pump(noteAutosaveDelay);
    expect(state.notes, hasLength(1));
    expect(state.notes.single.body, 'Ein Gedanke');
  });

  testWidgets('Autosave unterbricht Fokus und Texteingabe nicht',
      (tester) async {
    await pumpEditor(tester, rebuildOnStateChange: true);

    await tester.enterText(find.byType(TextField).first, 'Einkaufsliste');
    await tester.pump(noteAutosaveDelay);

    final editable =
        tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(find.text('Einkaufsliste'), findsOneWidget);
    expect(find.text('Schreib etwas auf …'), findsOneWidget);
  });

  testWidgets('Hintergrundwechsel speichert ohne Debounce abzuwarten',
      (tester) async {
    final note = Note(
      id: 'n1',
      title: 'Alt',
      body: '',
      updatedAt: DateTime(2026, 8, 14),
    );
    await pumpEditor(tester, note: note);

    await tester.enterText(find.byType(TextField).first, 'Vor Hintergrund');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(note.title, 'Vor Hintergrund');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('Zurück speichert sofort und schließt den Editor',
      (tester) async {
    final note = Note(
      id: 'n1',
      title: 'Alt',
      body: '',
      updatedAt: DateTime(2026, 8, 14),
    );
    await pumpEditor(tester, note: note, onOwnRoute: true);

    await tester.enterText(find.byType(TextField).first, 'Beim Verlassen');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(note.title, 'Beim Verlassen');
    expect(find.text('Öffnen'), findsOneWidget);
  });
}
