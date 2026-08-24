import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Das Befinden eintragen und ansehen.
///
/// Eingetragen wird als Kategorie im Notiz-Editor ([NoteWellbeingSection]);
/// ein einzelner Eintrag geht in [WellbeingEditScreen] auf. Die Eintraege
/// haengen am Tag, nicht an der Notiz – mehrere je Tag, jeder mit seiner
/// Uhrzeit.

/// Ein einzelner Eintrag: Uhrzeit, Stimmung, Symptome. Speichert beim
/// Verlassen – wie der Notiz-Editor, damit sich beide gleich anfuehlen.
class WellbeingEditScreen extends StatefulWidget {
  /// Der Eintrag, der bearbeitet wird. Ein neuer kommt als Entwurf aus
  /// `AppState.newWellbeingDraft` und wird erst beim Verlassen aufbewahrt –
  /// und auch dann nur, wenn etwas drinsteht.
  final WellbeingEntry entry;

  const WellbeingEditScreen({super.key, required this.entry});

  @override
  State<WellbeingEditScreen> createState() => _WellbeingEditScreenState();
}

class _WellbeingEditScreenState extends State<WellbeingEditScreen> {
  late AppState _state;

  WellbeingEntry get _entry => widget.entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entry.at),
    );
    if (picked == null) return;
    setState(() {
      final d = _entry.day;
      _entry.at =
          DateTime(d.year, d.month, d.day, picked.hour, picked.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    const page = PetPage.wellbeingEdit;
    final theme = joeThemeOf(context);
    final known = _state.wellbeing.any((e) => e.id == _entry.id);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _state.saveWellbeing(_entry);
        Navigator.of(context).pop();
      },
      child: JoeScaffold(
        page: page,
        title: 'Befinden',
        actions: [
          if (known)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.accent),
              tooltip: 'Befinden löschen',
              onPressed: () async {
                final confirmed = await confirmDelete(
                  context,
                  title: 'Befinden löschen?',
                  subject: '${_entry.dayPart}, '
                      '${formatTime(_entry.at)} · ${formatDate(_entry.day)}',
                );
                if (!confirmed || !mounted) return;
                _state.deleteWellbeing(_entry);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
        body: SafeArea(
          child: ListView(
            padding: petPadding(
              context,
              page,
              const EdgeInsets.fromLTRB(16, 4, 16, 32),
            ),
            children: [
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateFull(_entry.day),
                      style: TextStyle(
                        color: theme.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Die Uhrzeit unterscheidet die Eintraege eines Tages –
                    // deshalb steht sie oben und laesst sich aendern.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.schedule,
                            size: 18, color: theme.accent),
                        label: Text(
                          '${_entry.dayPart} · ${formatTime(_entry.at)}',
                          style: TextStyle(color: theme.ink, fontSize: 15),
                        ),
                        onPressed: _pickTime,
                      ),
                    ),
                    const SizedBox(height: 10),
                    WellbeingForm(
                      entry: _entry,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Einen Eintrag im Editor oeffnen.
Future<void> openWellbeing(BuildContext context, WellbeingEntry entry) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WellbeingEditScreen(entry: entry)),
  );
}

/// Bearbeiten/Loeschen wie bei Aufgaben, Terminen und Notizen.
void showWellbeingOptions(BuildContext context, WellbeingEntry entry) {
  final state = AppScope.of(context);
  showEntryOptions(
    context,
    deleteTitle: 'Befinden löschen?',
    subject: '${entry.dayPart}, ${formatTime(entry.at)} · '
        '${formatDate(entry.day)}',
    onEdit: () => openWellbeing(context, entry),
    onDelete: () => state.deleteWellbeing(entry),
  );
}

/// Die Kategorie "Befinden" im Notiz-Editor: die Eintraege *dieser* Notiz
/// und ein Knopf fuer einen weiteren.
///
/// Jeder Eintrag gehoert der Notiz, in der er entstanden ist – zwei Notizen
/// desselben Tages fuehren getrennte Listen. Der Tag kommt von der Notiz:
/// zieht man sie auf einen anderen, bekommen neue Eintraege dessen Datum.
class NoteWellbeingSection extends StatefulWidget {
  final DateTime date;

  /// Die Notiz, solange es sie schon gibt.
  final String? noteId;

  /// Legt die Notiz an, falls noetig, und gibt ihre id zurueck – eine neue,
  /// noch leere Notiz hat noch keine.
  final String Function() ensureNote;

  const NoteWellbeingSection({
    super.key,
    required this.date,
    required this.noteId,
    required this.ensureNote,
  });

  @override
  State<NoteWellbeingSection> createState() => _NoteWellbeingSectionState();
}

class _NoteWellbeingSectionState extends State<NoteWellbeingSection> {
  bool _open = false;

  Future<void> _add(BuildContext context, AppState state) async {
    final noteId = widget.ensureNote();
    await openWellbeing(
      context,
      state.newWellbeingDraft(widget.date, noteId: noteId),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final entries = state.wellbeingOfNote(widget.noteId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: theme.inkSoft.withValues(alpha: 0.4)),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.favorite_outline, size: 18, color: theme.accent),
                const SizedBox(width: 8),
                Text(
                  'Befinden',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries.isEmpty
                        ? 'nichts eingetragen'
                        : '${entries.length} '
                            '${entries.length == 1 ? 'Eintrag' : 'Einträge'}',
                    style: TextStyle(color: theme.inkSoft, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: theme.ink),
                ),
              ],
            ),
          ),
        ),
        // Bewusst eine schlichte Spalte: eine eigene Scroll-Liste hier drin
        // meldete ihre Tippflaechen rund 50 Punkt zu tief (siehe den
        // Kommentar am Koerper des Notiz-Editors). Die Seite scrollt jetzt
        // als Ganzes, also darf die Liste einfach mitwachsen.
        if (_open)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in entries)
                _WellbeingEntryRow(
                  entry: entry,
                  onTap: () async {
                    await openWellbeing(context, entry);
                    if (mounted) setState(() {});
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  // Der Schluessel haengt an der Laenge der Liste, und das
                  // mit Absicht: waechst sie, rutscht der Knopf nach unten –
                  // sein Semantik-Knoten blieb dabei aber auf der alten
                  // Stelle stehen und meldete eine Tippflaeche, die auf der
                  // Zeile darueber lag. Ein neuer Schluessel heisst neues
                  // Element und damit frisch vermessen.
                  key: ValueKey('wellbeing-add-${entries.length}'),
                  icon: Icon(Icons.add, size: 20, color: theme.accent),
                  label: Text(
                    entries.isEmpty
                        ? 'Befinden eintragen'
                        : 'Weiterer Eintrag',
                    style: TextStyle(color: theme.accent),
                  ),
                  onPressed: () => _add(context, state),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Eine Zeile in der Kategorie: Tageszeit und Uhrzeit links, daneben, was
/// eingetragen wurde.
class _WellbeingEntryRow extends StatelessWidget {
  final WellbeingEntry entry;
  final VoidCallback onTap;

  const _WellbeingEntryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      onLongPress: () => showWellbeingOptions(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.dayPart,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatTime(entry.at),
                    style: TextStyle(color: theme.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: WellbeingSummary(entry: entry)),
          ],
        ),
      ),
    );
  }
}

/// Das Formular selbst: Stimmung, darunter die Symptome mit ihrer Skala.
///
/// Es aendert [entry] an Ort und Stelle und meldet sich ueber [onChanged];
/// wann gespeichert wird, entscheidet der Aufrufer – der eigene Editor beim
/// Verlassen, der Notiz-Abschnitt bei jeder Aenderung.
class WellbeingForm extends StatelessWidget {
  final WellbeingEntry entry;
  final VoidCallback onChanged;

  const WellbeingForm({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final catalog = state.symptomCatalog;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetLabel('Stimmung'),
        _MoodPicker(
          selected: entry.mood,
          onChanged: (mood) {
            // Noch einmal auf dieselbe tippen nimmt die Angabe zurueck –
            // sonst liesse sich ein Fehlgriff nicht mehr geradebiegen.
            entry.mood = entry.mood == mood ? null : mood;
            onChanged();
          },
        ),
        const SizedBox(height: 18),
        const SheetLabel('Symptome'),
        for (final symptom in catalog)
          _SymptomRow(
            symptom: symptom,
            value: entry.strengthOf(symptom.id),
            onChanged: (value) {
              entry.setStrength(symptom.id, value);
              onChanged();
            },
            onDelete: symptom.custom
                ? () => _deleteSymptom(context, state, symptom)
                : null,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(Icons.add, size: 20, color: theme.accent),
            label: Text(
              'Eigenes Symptom',
              style: TextStyle(color: theme.accent),
            ),
            onPressed: () => _addSymptom(context, state),
          ),
        ),
      ],
    );
  }

  Future<void> _addSymptom(BuildContext context, AppState state) async {
    final name = await showTextEntrySheet(
      context,
      title: 'Eigenes Symptom',
      hint: 'Wie heißt es?',
    );
    if (name == null || name.isEmpty) return;
    state.addCustomSymptom(name);
    onChanged();
  }

  Future<void> _deleteSymptom(
    BuildContext context,
    AppState state,
    Symptom symptom,
  ) async {
    final used = state.wellbeingUsageOf(symptom.id);
    final confirmed = await confirmDelete(
      context,
      title: 'Symptom löschen?',
      subject: used == 0
          ? symptom.name
          : '${symptom.name} – die Werte in '
              '$used ${used == 1 ? 'Eintrag' : 'Einträgen'} gehen mit.',
    );
    if (!confirmed) return;
    state.deleteCustomSymptom(symptom.id);
    onChanged();
  }
}

/// Die fuenf Stimmungen als Reihe von Gesichtern.
class _MoodPicker extends StatelessWidget {
  final Mood? selected;
  final ValueChanged<Mood> onChanged;

  const _MoodPicker({required this.selected, required this.onChanged});

  static const _faces = [
    Icons.sentiment_very_satisfied,
    Icons.sentiment_satisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_very_dissatisfied,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Row(
      children: [
        for (final mood in Mood.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: mood == Mood.values.last ? 0 : 6,
              ),
              child: Semantics(
                button: true,
                selected: mood == selected,
                label: mood.label,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(mood),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: mood == selected
                          ? theme.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: mood == selected
                            ? theme.accent
                            : theme.inkSoft.withValues(alpha: 0.5),
                        width: mood == selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _faces[mood.index],
                          size: 24,
                          color: mood == selected ? theme.accent : theme.inkSoft,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mood.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 11,
                            fontWeight: mood == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Eine Symptom-Zeile: Name links, die Fuenf-Punkte-Skala rechts.
class _SymptomRow extends StatelessWidget {
  final Symptom symptom;
  final int value;
  final ValueChanged<int> onChanged;

  /// Nur eigene Symptome lassen sich loeschen (langer Druck).
  final VoidCallback? onDelete;

  const _SymptomRow({
    required this.symptom,
    required this.value,
    required this.onChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Semantics(
      container: true,
      label: value == 0
          ? symptom.name
          : '${symptom.name}, ${symptomStrengthLabel(value)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symptom.name,
                      style: TextStyle(
                        color: value == 0 ? theme.inkSoft : theme.ink,
                        fontSize: 15,
                        fontWeight:
                            value == 0 ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    if (value > 0)
                      Text(
                        symptomStrengthLabel(value),
                        style: TextStyle(color: theme.inkSoft, fontSize: 12),
                      ),
                  ],
                ),
              ),
              SymptomScale(
                value: value,
                // Noch einmal auf denselben Punkt nimmt das Symptom wieder
                // heraus: eine Skala ohne Rueckweg zwaenge dazu, den Tag
                // schlimmer zu lassen, als er war.
                onChanged: (picked) => onChanged(picked == value ? 0 : picked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die fuenf Punkte. Ohne [onChanged] ist sie reine Anzeige.
class SymptomScale extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double dotSize;

  const SymptomScale({
    super.key,
    required this.value,
    this.onChanged,
    this.dotSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= symptomScale; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Der Tippbereich ist groesser als der Punkt: fuenf Punkte
              // nebeneinander sind sonst nicht zu treffen.
              padding: EdgeInsets.symmetric(
                horizontal: onChanged == null ? 2 : 5,
                vertical: onChanged == null ? 0 : 6,
              ),
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: i <= value ? theme.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= value
                        ? theme.accent
                        : theme.inkSoft.withValues(alpha: 0.6),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ein fertiger Eintrag in Kurzform: Stimmung und die Symptome, die an dem
/// Tag ueberhaupt vorkamen. Ein Symptom, dessen Schluessel es nicht mehr
/// gibt, faellt weg – geloescht wird es samt seiner Werte, das hier ist nur
/// der Gurt.
class WellbeingSummary extends StatelessWidget {
  final WellbeingEntry entry;

  const WellbeingSummary({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final named = <(Symptom, int)>[
      for (final id in entry.symptoms.keys)
        if (state.symptomById(id) case final s?) (s, entry.symptoms[id]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.mood != null)
          Text(
            entry.mood!.label,
            style: TextStyle(
              color: theme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        for (final (symptom, value) in named)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    symptom.name,
                    style: TextStyle(color: theme.ink, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SymptomScale(value: value, dotSize: 10),
              ],
            ),
          ),
      ],
    );
  }
}
