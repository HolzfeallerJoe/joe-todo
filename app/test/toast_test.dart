import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/toast.dart';

/// Der Toast ist der einzige Weg, auf dem ein Fehler beim Nutzer ankommt –
/// also gehoert er selbst geprueft: dass er auftaucht, dass er wieder geht,
/// und dass keine Meldung im Gedraenge verlorengeht.
void main() {
  setUp(JoeToast.instance.reset);
  tearDown(JoeToast.instance.reset);

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: MaterialApp(
          home: const Scaffold(body: SizedBox.expand()),
          builder: (context, child) =>
              ToastHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }

  testWidgets('eine Meldung kommt und geht von allein', (tester) async {
    await pumpHost(tester);
    expect(find.text('Etwas ging schief'), findsNothing);

    JoeToast.error('Etwas ging schief');
    await tester.pumpAndSettle();
    expect(find.text('Etwas ging schief'), findsOneWidget);

    // Nach der Standzeit verschwindet sie wieder, ohne Zutun.
    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Etwas ging schief'), findsNothing);
  });

  testWidgets('dieselbe Meldung staut sich nicht', (tester) async {
    await pumpHost(tester);
    // Ein Fehler, der pro Monatszelle einmal auftritt, soll den Bildschirm
    // nicht 42-mal belegen.
    for (var i = 0; i < 5; i++) {
      JoeToast.error('Kalender nicht erreichbar');
    }
    await tester.pumpAndSettle();
    expect(find.text('Kalender nicht erreichbar'), findsOneWidget);

    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Kalender nicht erreichbar'), findsNothing);
  });

  testWidgets('zwei Meldungen kommen nacheinander dran', (tester) async {
    await pumpHost(tester);
    JoeToast.success('Ist an');
    JoeToast.info('Und noch etwas');
    await tester.pumpAndSettle();
    expect(find.text('Ist an'), findsOneWidget);
    expect(find.text('Und noch etwas'), findsNothing);

    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Und noch etwas'), findsOneWidget);

    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Und noch etwas'), findsNothing);
  });

  testWidgets('ein Fehler draengelt sich vor eine harmlose Meldung',
      (tester) async {
    await pumpHost(tester);
    JoeToast.success('Ist an');
    JoeToast.info('Nebensache');
    JoeToast.error('Geht nicht');
    await tester.pumpAndSettle();

    // Der Erfolg steht schon, aber der Fehler kommt vor der Nebensache.
    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Geht nicht'), findsOneWidget);

    // Die Nebensache kommt danach trotzdem noch dran – vorgedraengelt
    // heisst nicht verschluckt.
    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Nebensache'), findsOneWidget);

    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Nebensache'), findsNothing);
  });

  testWidgets('Antippen wischt weg', (tester) async {
    await pumpHost(tester);
    JoeToast.info('Kurz gesagt');
    await tester.pumpAndSettle();
    expect(find.text('Kurz gesagt'), findsOneWidget);

    await tester.tap(find.text('Kurz gesagt'));
    await tester.pumpAndSettle();
    expect(find.text('Kurz gesagt'), findsNothing);
  });

  testWidgets('die Aktion laeuft und raeumt die Meldung ab', (tester) async {
    await pumpHost(tester);
    var getippt = 0;
    JoeToast.error(
      'Berechtigung fehlt',
      action: ToastAction('Einstellungen', () => getippt++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    expect(getippt, 1);
    expect(find.text('Berechtigung fehlt'), findsNothing);
  });

  testWidgets('mit Aktion steht die Meldung laenger', (tester) async {
    await pumpHost(tester);
    JoeToast.error(
      'Bitte nachsehen',
      action: ToastAction('Einstellungen', () {}),
    );
    await tester.pumpAndSettle();

    // Drei Sekunden reichen nicht, um zu lesen *und* zu tippen.
    await tester.pump(JoeToast.showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Bitte nachsehen'), findsOneWidget);

    await tester.pump(JoeToast.actionDuration);
    await tester.pumpAndSettle();
    expect(find.text('Bitte nachsehen'), findsNothing);
  });
}
