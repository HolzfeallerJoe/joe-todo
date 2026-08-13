import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'log.dart';
import 'models.dart';
import 'theme.dart';
import 'screens/dashboard.dart';

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
  runApp(JoeApp(state: state));
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
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.accent,
                surface: theme.paper,
              ),
              splashFactory: InkRipple.splashFactory,
            ),
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}
