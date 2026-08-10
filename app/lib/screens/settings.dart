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
                    if (joeThemes[i].backgroundAsset == null)
                      _ThemeRow(index: i, theme: theme),
                ],
              ),
            ),
            const SectionTitle('Hintergrundbilder'),
            PaperCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (int i = 0; i < joeThemes.length; i++)
                    if (joeThemes[i].backgroundAsset != null)
                      _ThemeRow(index: i, theme: theme),
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

class _ThemeRow extends StatelessWidget {
  final int index;
  final JoeTheme theme;

  const _ThemeRow({required this.index, required this.theme});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final entry = joeThemes[index];
    final selected = state.themeIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => state.setTheme(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? theme.accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: entry.backgroundAsset != null
                  ? Image.asset(entry.backgroundAsset!, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [entry.bgTop, entry.bgBottom],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: theme.accent),
          ],
        ),
      ),
    );
  }
}
