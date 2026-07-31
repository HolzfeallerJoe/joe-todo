import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'screens/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
