import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../almanac.dart';
import '../device_calendar.dart';
import '../log.dart';
import '../models.dart';
import '../pets.dart';
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
            const SectionTitle('Begleiter'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Begleiter anzeigen',
                    style: TextStyle(color: theme.ink, fontSize: 16)),
                subtitle: Text('Kleine Deko auf dem Dashboard',
                    style: TextStyle(color: theme.inkSoft, fontSize: 13)),
                activeThumbColor: theme.accent,
                value: state.showPet,
                onChanged: state.setShowPet,
              ),
            ),
            // Ohne Begleiter gibt es nichts auszuwaehlen: die Zeile bleibt
            // stehen, damit die Auswahl lesbar bleibt, ist aber ausgegraut
            // und nicht antippbar.
            Opacity(
              opacity: state.showPet ? 1 : 0.45,
              child: PaperCard(
                margin: const EdgeInsets.only(top: 12),
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: state.showPet ? () => _showPetSheet(context) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: _PetOption(pet: state.pet, theme: theme),
                  ),
                ),
              ),
            ),
            const SectionTitle('Kalender'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Feiertage anzeigen',
                        style: TextStyle(color: theme.ink, fontSize: 16)),
                    subtitle: Text('Gesetzliche Feiertage mit Stern im Kalender',
                        style: TextStyle(color: theme.inkSoft, fontSize: 13)),
                    activeThumbColor: theme.accent,
                    value: state.showHolidays,
                    onChanged: state.setShowHolidays,
                  ),
                  // Ohne Feiertage gibt es kein Bundesland zu waehlen: die
                  // Zeile bleibt stehen, ist aber ausgegraut und gesperrt –
                  // dasselbe Muster wie beim Begleiter oben.
                  Opacity(
                    opacity: state.showHolidays ? 1 : 0.45,
                    child: IgnorePointer(
                      ignoring: !state.showHolidays,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HolidayRegion>(
                          value: state.holidayRegion,
                          isExpanded: true,
                          dropdownColor: theme.paper,
                          borderRadius: BorderRadius.circular(14),
                          iconEnabledColor: theme.ink,
                          menuMaxHeight: 420,
                          items: [
                            for (final region in HolidayRegion.values)
                              DropdownMenuItem<HolidayRegion>(
                                value: region,
                                child: Text(
                                  region.label,
                                  style: TextStyle(
                                    color: theme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (region) {
                            if (region != null) state.setHolidayRegion(region);
                          },
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Mondphasen anzeigen',
                        style: TextStyle(color: theme.ink, fontSize: 16)),
                    subtitle: Text('Neumond, Halbmond und Vollmond im Kalender',
                        style: TextStyle(color: theme.inkSoft, fontSize: 13)),
                    activeThumbColor: theme.accent,
                    value: state.showMoon,
                    onChanged: state.setShowMoon,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Geräte-Kalender anzeigen',
                        style: TextStyle(color: theme.ink, fontSize: 16)),
                    subtitle: Text(
                        'Termine aus den Kalendern des Telefons '
                        '(z. B. Google) – nur Anzeige',
                        style: TextStyle(color: theme.inkSoft, fontSize: 13)),
                    activeThumbColor: theme.accent,
                    value: state.showDeviceCalendar,
                    onChanged: (value) =>
                        _toggleDeviceCalendar(context, state, value),
                  ),
                ],
              ),
            ),
            const SectionTitle('Fehlersuche'),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: theme.paper,
                  foregroundColor: theme.ink,
                  side: BorderSide(color: theme.inkSoft.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text(
                  'Logs teilen',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _shareLogs(context),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Joe · dein warmes Notizbuch 🌿',
                // Die Fusszeile steht ohne Karte auf dem Hintergrund, also
                // dieselbe Behandlung wie die Abschnittsueberschriften: die
                // Kontrastfarbe des Designs samt Halo.
                style: TextStyle(
                  color: theme.onBg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: theme.onBgShadows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Der Geraete-Kalender braucht als einziger Schalter eine Berechtigung:
/// erst wenn die da ist, geht er an. Wird sie verweigert, bleibt er aus und
/// eine Snackbar zeigt den Weg in die System-Einstellungen – noetig, falls
/// Android die Anfrage nach zweimaligem Ablehnen gar nicht mehr stellt.
Future<void> _toggleDeviceCalendar(
    BuildContext context, AppState state, bool value) async {
  if (!value) {
    state.setShowDeviceCalendar(false);
    DeviceCalendarFeed.instance.clear();
    return;
  }
  final granted = await DeviceCalendarFeed.instance.ensurePermission();
  if (granted) {
    // Frisch laden, nicht was vor dem Abschalten uebrig war.
    DeviceCalendarFeed.instance.clear();
    state.setShowDeviceCalendar(true);
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Ohne Kalender-Berechtigung geht das nicht.'),
      action: SnackBarAction(
        label: 'Einstellungen',
        onPressed: () => DeviceCalendarFeed.instance.openSystemSettings(),
      ),
    ),
  );
}

/// Reicht die Logdateien an den Share-Intent des Systems weiter; solange
/// noch keine Datei existiert, den Speicherpuffer als Text.
Future<void> _shareLogs(BuildContext context) async {
  final payload = await JoeLog.instance.sharePayload();
  await SharePlus.instance.share(
    payload.paths.isNotEmpty
        ? ShareParams(
            subject: 'Joe – Logs',
            files: [
              for (final path in payload.paths)
                XFile(path, mimeType: 'text/plain'),
            ],
          )
        : ShareParams(subject: 'Joe – Logs', text: payload.text),
  );
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

/// The closed companion picker: the chosen artwork, its name and its group,
/// styled to read like the theme dropdown right above it.
class _PetOption extends StatelessWidget {
  final Pet pet;
  final JoeTheme theme;

  const _PetOption({required this.pet, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            pet.asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            pet.name,
            style: TextStyle(
              color: theme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          pet.group.label,
          style: TextStyle(color: theme.inkSoft, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_drop_down, color: theme.ink),
      ],
    );
  }
}

/// Opens the companion picker: one collapsible section per group, the group of
/// the current companion already open.
void _showPetSheet(BuildContext context) {
  final state = AppScope.of(context);
  final theme = joeThemeOf(context);
  showJoeSheet(
    context,
    expand: true,
    builder: (_) => _PetSheet(state: state, theme: theme),
  );
}

class _PetSheet extends StatefulWidget {
  final AppState state;
  final JoeTheme theme;

  const _PetSheet({required this.state, required this.theme});

  @override
  State<_PetSheet> createState() => _PetSheetState();
}

class _PetSheetState extends State<_PetSheet> {
  /// Only one group is open at a time – with 53 companions across seven
  /// groups, letting them all stand open turns the sheet back into the long
  /// list it is meant to replace.
  late PetGroup _open = widget.state.pet.group;

  final _headerKeys = {
    for (final group in PetGroup.values) group: GlobalKey(),
  };

  static const _foldDuration = Duration(milliseconds: 200);

  void _openGroup(PetGroup group) {
    setState(() => _open = group);
    // Pull the opened header to the top of the sheet – otherwise it stays
    // wherever it happened to sit, often half-clipped under the title, with
    // its grid off-screen below. Only once the fold animation has finished:
    // the group closing above shrinks by several hundred pixels on the way,
    // so scrolling any earlier lands somewhere else entirely.
    Future<void>.delayed(_foldDuration + const Duration(milliseconds: 20), () {
      if (!mounted) return;
      final headerContext = _headerKeys[group]?.currentContext;
      if (headerContext == null || !headerContext.mounted) return;
      Scrollable.ensureVisible(
        headerContext,
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: theme.inkSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Begleiter wählen',
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final group in PetGroup.values)
                    _PetGroupSection(
                      group: group,
                      theme: theme,
                      headerKey: _headerKeys[group]!,
                      selectedId: widget.state.pet.id,
                      expanded: _open == group,
                      foldDuration: _foldDuration,
                      onToggle: () => _openGroup(group),
                      onPick: (pet) {
                        widget.state.setPet(pet.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One accordion section: a tappable group header plus, when open, the group's
/// companions as a grid of thumbnails.
class _PetGroupSection extends StatelessWidget {
  final PetGroup group;
  final JoeTheme theme;

  /// Anchor for scrolling this section's header to the top when it opens.
  final GlobalKey headerKey;
  final String selectedId;
  final bool expanded;
  final Duration foldDuration;
  final VoidCallback onToggle;
  final void Function(Pet) onPick;

  const _PetGroupSection({
    required this.group,
    required this.theme,
    required this.headerKey,
    required this.selectedId,
    required this.expanded,
    required this.foldDuration,
    required this.onToggle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final pets = petsOf(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: headerKey,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${pets.length}',
                  style: TextStyle(color: theme.inkSoft, fontSize: 13),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: theme.ink),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: foldDuration,
          sizeCurve: Curves.easeOut,
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: GridView.count(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            crossAxisCount: 4,
            childAspectRatio: 0.76,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final pet in pets)
                _PetTile(
                  pet: pet,
                  theme: theme,
                  selected: pet.id == selectedId,
                  onTap: () => onPick(pet),
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.inkSoft.withValues(alpha: 0.15),
        ),
      ],
    );
  }
}

class _PetTile extends StatelessWidget {
  final Pet pet;
  final JoeTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _PetTile({
    required this.pet,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: theme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.accent, width: 2),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Image.asset(
                pet.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pet.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? theme.accent : theme.ink,
                fontSize: 11,
                height: 1.15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
