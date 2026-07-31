import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);

    return JoeScaffold(
      title: 'Einstellungen',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionTitle('Notizbuch-Design'),
            PaperCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (int i = 0; i < joeThemes.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => state.setTheme(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    joeThemes[i].bgTop,
                                    joeThemes[i].bgBottom,
                                  ],
                                ),
                                border: Border.all(
                                  color: state.themeIndex == i
                                      ? theme.accent
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                joeThemes[i].name,
                                style: TextStyle(
                                  color: theme.ink,
                                  fontSize: 16,
                                  fontWeight: state.themeIndex == i
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (state.themeIndex == i)
                              Icon(Icons.check_circle, color: theme.accent),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SectionTitle('Deko'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Kätzchen anzeigen 🐱',
                    style: TextStyle(color: theme.ink, fontSize: 16)),
                subtitle: Text('Kleine Deko auf dem Dashboard',
                    style: TextStyle(color: theme.inkSoft, fontSize: 13)),
                activeThumbColor: theme.accent,
                value: state.showCat,
                onChanged: state.setShowCat,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Joe · dein warmes Notizbuch 🌿',
                style: TextStyle(color: theme.inkSoft, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
