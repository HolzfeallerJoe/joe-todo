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
    // Stored index can outlive a shrinking theme list, so wrap it the same way
    // the rest of the app does before handing it to the dropdown.
    final selected = state.themeIndex % joeThemes.length;

    return JoeScaffold(
      title: 'Einstellungen',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionTitle('Design'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selected,
                  isExpanded: true,
                  dropdownColor: theme.paper,
                  borderRadius: BorderRadius.circular(14),
                  iconEnabledColor: theme.ink,
                  itemHeight: 56,
                  menuMaxHeight: 420,
                  items: [
                    for (int i = 0; i < joeThemes.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: _ThemeOption(
                          entry: joeThemes[i],
                          labelColor: theme.ink,
                        ),
                      ),
                  ],
                  onChanged: (i) {
                    if (i != null) state.setTheme(i);
                  },
                ),
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

/// One row in the theme dropdown: preview swatch plus name. Photo themes show
/// the image itself, procedural ones their background gradient.
class _ThemeOption extends StatelessWidget {
  final JoeTheme entry;
  final Color labelColor;

  const _ThemeOption({required this.entry, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0x33513A1F),
              width: 1,
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
              color: labelColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
