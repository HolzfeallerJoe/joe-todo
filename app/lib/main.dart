import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_calendar.dart';
import 'home_widget.dart';
import 'log.dart';
import 'models.dart';
import 'reminders.dart';
import 'theme.dart';
import 'toast.dart';
import 'screens/appointments.dart';
import 'screens/calendar.dart';
import 'screens/dashboard.dart';
import 'screens/tasks.dart';

/// Damit eine angetippte Erinnerung navigieren kann – die kommt vom System
/// und hat keinen `BuildContext`.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Fehler landen im Log – dafuer ist "Logs teilen" in den Einstellungen da.
  // Das Standardverhalten (Ausgabe bzw. Absturz) bleibt unveraendert.
  FlutterError.onError = (details) {
    JoeLog.log('FEHLER Flutter: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  binding.platformDispatcher.onError = (error, stack) {
    JoeLog.log('FEHLER unbehandelt: $error');
    return false;
  };
  JoeLog.log('App-Start');
  // Ab Android 15 laeuft die App ohnehin randlos: der Hintergrund liegt schon
  // hinter Status- und Navigationsleiste. Ohne diesen Aufruf legt das System
  // unten aber einen schwarzen Kontrastbalken darueber, waehrend oben die
  // Textur durchscheint – die Leisten werden in JoeScaffold eingefaerbt.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  await state.load();

  DeviceCalendarFeed.instance.setCalendarIds(state.deviceCalendarIds);
  // Der Schalter kann seit dem letzten Start an geblieben sein, waehrend die
  // Berechtigung im System entzogen wurde. Ohne diese Pruefung bliebe die
  // Ebene einfach leer und niemand wuesste, warum.
  if (state.showDeviceCalendar) {
    unawaited(DeviceCalendarFeed.instance.checkPermission());
  }

  // Erinnerungen werden bei jeder Aenderung neu gestellt – Termine
  // verschieben sich, Aufgaben werden abgehakt. Verglichen wird dabei pro
  // Erinnerung, ein Designwechsel kostet also nichts.
  state.addListener(() {
    DeviceCalendarFeed.instance.setCalendarIds(state.deviceCalendarIds);
    JoeReminders.instance.sync(state);
    // Die Widgets auf dem Startbildschirm lesen einen Schnappschuss, den nur
    // die App schreiben kann – ohne das blieben sie auf dem Stand des
    // letzten Starts stehen.
    JoeHomeWidgets.instance.schedule(state);
  });
  JoeHomeWidgets.instance.onOpen = _openWidgetTarget;
  JoeHomeWidgets.instance.listen();
  unawaited(JoeHomeWidgets.instance.push(state));
  // Bewusst ohne await: nichts davon darf den Start aufhalten.
  unawaited(JoeReminders.instance.init().then((_) {
    JoeReminders.instance.tapHandler = _openReminder;
    unawaited(JoeReminders.instance.checkDelivery(state.remindersEnabled));
    unawaited(JoeReminders.instance.sync(state));
  }));

  runApp(JoeApp(state: state));
}

/// Eine angetippte Erinnerung fuehrt in den Kalender auf ihren Tag – dort
/// steht die Aufgabe bzw. der Termin mit allem, was sonst noch ansteht.
void _openReminder(ReminderTarget target) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  JoeLog.log('Erinnerung angetippt: ${target.isTask ? 'Aufgabe' : 'Termin'}');
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => CalendarScreen(initialDay: target.day),
    ),
  );
}

/// Ein angetipptes Widget fuehrt dorthin, wo das Angetippte auch in der App
/// steht: der Aufgaben-Block in die Aufgaben, der Termin-Block in die
/// Termine, das Monatsraster in den Kalender.
///
/// Beim Kaltstart kommt das Ziel schon an, bevor der Navigator steht – dann
/// wartet der Sprung auf das erste Bild, statt lautlos zu verfallen.
void _openWidgetTarget(WidgetTarget target) {
  void go() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => switch (target) {
          WidgetTarget.tasks => const TasksScreen(),
          WidgetTarget.appointments => const AppointmentsScreen(),
          WidgetTarget.calendar => const CalendarScreen(),
        },
      ),
    );
  }

  if (navigatorKey.currentState == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  } else {
    go();
  }
}

class JoeApp extends StatelessWidget {
  final AppState state;
  const JoeApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final theme = joeThemes[state.themeIndex % joeThemes.length];
          return MaterialApp(
            title: 'Joe',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.accent,
                surface: theme.paper,
              ),
              splashFactory: InkRipple.splashFactory,
            ),
            // Die Meldungen haengen ueber dem Navigator, damit ein Toast auch
            // ueber einem offenen Blatt oder Dialog steht.
            builder: (context, child) =>
                ToastHost(child: child ?? const SizedBox.shrink()),
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}
