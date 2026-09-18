import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'shopping.dart';
import 'wellbeing.dart';

const noteAutosaveDelay = Duration(milliseconds: 700);

/// Die beiden Teile der Notizen-Seite im Modus [ShoppingListMode.perDay].
enum _NotesTab { notes, shopping }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  /// Bewusst nicht gespeichert: die Notizen oeffnen immer mit "Notizen".
  _NotesTab _tab = _NotesTab.notes;

  /// Der Tag der Einkaufsliste – zuerst heute.
  DateTime _day = today();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    // Im Modus "Eigener Reiter" sieht die Seite genau aus wie vorher: kein
    // Umschalter, die Einkaufsliste hat dann ihren eigenen Reiter.
    final perDay = state.shoppingMode == ShoppingListMode.perDay;
    final shopping = perDay && _tab == _NotesTab.shopping;
    // Auf der Einkaufsseite sitzt der Begleiter nur oben – unten steht das
    // Eingabefeld.
    final page = shopping ? PetPage.shopping : PetPage.notes;

    return JoeScaffold(
      page: page,
      title: 'Notizen',
      body: SafeArea(
        child: shopping
            ? ShoppingList(
                day: _day,
                header: [
                  _header(
                    context,
                    extra: _DaySwitcher(
                      day: _day,
                      onChanged: (day) => setState(() => _day = day),
                    ),
                  ),
                ],
              )
            : _notesList(
                context,
                page,
                header: perDay ? _header(context) : null,
              ),
      ),
      // Kein Plus auf der Einkaufsseite: dort ist das Eingabefeld der Weg.
      floatingActionButton: shopping
          ? null
          : FloatingActionButton(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              tooltip: 'Neue Notiz',
              onPressed: () => _openNote(context, null),
              child: const Icon(Icons.edit_outlined),
            ),
    );
  }

  /// Die Karte oben mit dem Umschalter "Notizen | Einkaufsliste", auf der
  /// Einkaufsseite samt Datumszeile ([extra]). Sie steht in der Liste, damit
  /// der Begleiter auf ihr sitzt und mit ihr wegscrollt.
  Widget _header(BuildContext context, {Widget? extra}) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_NotesTab>(
                segments: const [
                  ButtonSegment(
                    value: _NotesTab.notes,
                    label: Text('Notizen'),
                    icon: Icon(Icons.edit_note),
                  ),
                  ButtonSegment(
                    value: _NotesTab.shopping,
                    label: Text('Einkaufsliste'),
                    icon: Icon(Icons.shopping_basket_outlined),
                  ),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _tab = selection.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: theme.paper,
                  foregroundColor: theme.ink,
                  selectedBackgroundColor: theme.accent,
                  selectedForegroundColor: theme.bestOn(theme.accent),
                  side: BorderSide(color: theme.accent),
                ),
              ),
            ),
            ?extra,
          ],
        ),
      ),
    );
  }

  Widget _notesList(BuildContext context, PetPage page, {Widget? header}) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final notes = state.notes;
    final offset = header == null ? 0 : 1;

    return notes.isEmpty
            // Auf einer Karte, nicht blank auf dem Hintergrund: die
            // Papierfarbe des Designs traegt den Text auf jedem Untergrund,
            // auch auf einem Foto. Frei stehender Text in der Papierfarbe
            // war auf dem Ozean-Design praktisch unsichtbar. So halten es
            // auch Aufgaben und Termine.
            ? ListView(
                padding: petPadding(
                  context,
                  page,
                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                ),
                children: [
                  ?header,
                  PaperCard(
                    child: Text(
                      'Noch keine Notizen. Tippe auf den Stift, um '
                      'loszulegen.',
                      style: TextStyle(color: theme.inkSoft, fontSize: 15),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: petPadding(
                  context,
                  page,
                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                ),
                itemCount: notes.length + offset,
                itemBuilder: (context, index) {
                  if (index < offset) return header!;
                  final note = notes[index - offset];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openNote(context, note),
                      // Wie bei Aufgaben und Terminen: langer Druck fuehrt
                      // auf das Blatt mit Bearbeiten und Loeschen.
                      onLongPress: () => showNoteOptions(context, note),
                      child: PaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              noteTitleOrPlaceholder(note),
                              style: TextStyle(
                                color: theme.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (note.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                note.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: theme.inkSoft, fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  formatDateYear(note.date),
                                  style: TextStyle(
                                    color: theme.inkSoft,
                                    fontSize: 12,
                                  ),
                                ),
                                // Wie viele Befinden-Eintraege an dieser
                                // Notiz haengen. Ohne diesen Hinweis muesste
                                // man jede Notiz oeffnen, um sie zu finden.
                                if (state.wellbeingOfNote(note.id)
                                    case final entries when entries.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 12,
                                          color: theme.accent,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${entries.length}',
                                          style: TextStyle(
                                            color: theme.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
  }

  void _openNote(BuildContext context, Note? note) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditScreen(note: note)),
    );
  }
}

/// Die Datumszeile der Einkaufsliste je Tag: `‹ Freitag, 18. September ›`.
/// Die Pfeile gehen einen Tag vor oder zurueck, ein Tipp aufs Datum oeffnet
/// den Datumsdialog.
class _DaySwitcher extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  const _DaySwitcher({required this.day, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: theme.ink),
            tooltip: 'Voriger Tag',
            onPressed: () => onChanged(addCalendarDays(day, -1)),
          ),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.ink),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) onChanged(dateOnly(picked));
              },
              child: Text(
                formatDateFull(day),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: theme.ink),
            tooltip: 'Nächster Tag',
            onPressed: () => onChanged(addCalendarDays(day, 1)),
          ),
        ],
      ),
    );
  }
}

/// Das Bearbeiten/Loeschen-Blatt einer Notiz. Es steht hier und nicht in
/// widgets.dart, weil "Bearbeiten" den Notiz-Editor oeffnet – widgets.dart
/// darf die Bildschirme nicht kennen, sonst zeigen die Importe im Kreis.
void showNoteOptions(BuildContext context, Note note) {
  final state = AppScope.of(context);
  showEntryOptions(
    context,
    deleteTitle: 'Notiz löschen?',
    subject: noteDeleteSubject(state, note),
    onEdit: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditScreen(note: note)),
    ),
    onDelete: () => state.deleteNote(note),
  );
}

/// Der Titel einer Notiz, wie er ueberall in der App steht – auch wenn
/// keiner eingegeben wurde.
String noteTitleOrPlaceholder(Note note) =>
    note.title.isEmpty ? 'Ohne Titel' : note.title;

/// Was auf der Loeschkarte einer Notiz steht. Haengt Befinden daran, sagt
/// sie es dazu: es geht mit der Notiz, und niemand soll seine
/// Aufzeichnungen ueber sich selbst verlieren, ohne es vorher zu lesen.
String noteDeleteSubject(AppState state, Note note) {
  final entries = state.wellbeingOfNote(note.id).length;
  if (entries == 0) return noteTitleOrPlaceholder(note);
  return '${noteTitleOrPlaceholder(note)} – '
      '$entries ${entries == 1 ? 'Befinden-Eintrag geht' : 'Befinden-Einträge gehen'} mit.';
}

class NoteEditScreen extends StatefulWidget {
  final Note? note;

  /// Tag, unter dem eine neue Notiz abgelegt wird – der Kalender legt hier
  /// den ausgewaehlten Tag hinein.
  final DateTime? initialDate;

  const NoteEditScreen({super.key, this.note, this.initialDate});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late DateTime _date;
  late AppState _state;
  late Note? _savedNote;
  Timer? _autosave;
  bool _dirty = false;
  bool _unpublished = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _date = dateOnly(widget.note?.date ?? widget.initialDate ?? DateTime.now());
    _savedNote = widget.note;
    _title.addListener(_markDirty);
    _body.addListener(_markDirty);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _saveNow();
    _publishChanges();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _title.removeListener(_markDirty);
    _body.removeListener(_markDirty);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _markDirty() {
    _dirty = true;
    _autosave?.cancel();
    _autosave = Timer(noteAutosaveDelay, _saveNow);
  }

  void _saveNow() {
    if (!_dirty) return;
    _autosave?.cancel();
    _autosave = null;
    _dirty = false;

    final title = _title.text.trim();
    final body = _body.text.trim();
    final existing = _savedNote;
    if (existing == null) {
      if (title.isEmpty && body.isEmpty) return;
      final note = Note(
        id: _state.nextId(),
        title: title,
        body: body,
        date: _date,
        updatedAt: DateTime.now(),
      );
      _savedNote = note;
      _state.autosaveNote(note, isNew: true);
      _unpublished = true;
      return;
    }

    existing.title = title;
    existing.body = body;
    existing.date = _date;
    _state.autosaveNote(existing, isNew: false);
    _unpublished = true;
  }

  /// Die Notiz, an der ein Befinden haengen kann – und wenn es sie noch
  /// nicht gibt, entsteht sie hier.
  ///
  /// Ein Befinden gehoert genau einer Notiz. In einer nagelneuen, noch
  /// leeren Notiz gibt es aber noch nichts, woran es haengen koennte:
  /// [_saveNow] legt sie erst an, wenn Titel oder Text etwas enthalten. Ein
  /// Befinden ist selbst Inhalt genug, also legt der erste Eintrag die Notiz
  /// mit an – sonst haetten die Eintraege kein Zuhause.
  Note _ensureNote() {
    final existing = _savedNote;
    if (existing != null) return existing;
    final note = Note(
      id: _state.nextId(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      date: _date,
      updatedAt: DateTime.now(),
    );
    _savedNote = note;
    _state.autosaveNote(note, isNew: true);
    _unpublished = true;
    return note;
  }

  void _publishChanges() {
    if (!_unpublished) return;
    _unpublished = false;
    final note = _savedNote;
    if (note != null) _state.updateNote(note);
  }

  void _saveAndClose() {
    _saveNow();
    _publishChanges();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const page = PetPage.noteEdit;
    final theme = joeThemeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: JoeScaffold(
        page: page,
        title: widget.note == null ? 'Neue Notiz' : 'Notiz',
        actions: [
          if (widget.note != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.accent),
              tooltip: 'Notiz löschen',
              onPressed: () async {
                final note = widget.note!;
                final confirmed = await confirmDelete(
                  context,
                  title: 'Notiz löschen?',
                  subject: noteDeleteSubject(_state, note),
                );
                if (!confirmed || !mounted) return;
                _state.deleteNote(note);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
        body: SafeArea(
          // Die Seite scrollt als Ganzes. Vorher fuellte die Karte fest den
          // Bildschirm und die Befinden-Kategorie scrollte fuer sich – eine
          // Liste in einer Liste. Das ging schief: die Tippflaechen darin
          // wurden rund 50 Punkt zu tief gemeldet, sodass ein Tipp auf
          // "Weiterer Eintrag" ins Leere ging (und die Vorlesehilfe
          // danebengezielt haette). Eine Ebene weniger, und alles sitzt.
          child: SingleChildScrollView(
            padding: petPadding(
              context,
              page,
              const EdgeInsets.fromLTRB(16, 4, 16, 16),
            ),
            child: PaperCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Titel',
                      hintStyle: TextStyle(color: theme.inkSoft),
                      border: InputBorder.none,
                    ),
                  ),
                  // Der Tag, an dem die Notiz im Kalender als "N" auftaucht.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.event_outlined,
                          size: 18, color: theme.inkSoft),
                      label: Text(
                        formatDateYear(_date),
                        style: TextStyle(color: theme.inkSoft, fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _date = dateOnly(picked));
                          _markDirty();
                        }
                      },
                    ),
                  ),
                  Divider(color: theme.inkSoft.withValues(alpha: 0.4)),
                  // [minLines] haelt die Schreibflaeche gross, auch wenn erst
                  // ein Wort darin steht; laenger wird sie mit dem Text. Kein
                  // `expands` mehr – das braucht eine feste Hoehe, und die
                  // gibt es in einer scrollenden Seite nicht.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextField(
                      controller: _body,
                      minLines: 14,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                          color: theme.ink, fontSize: 16, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Schreib etwas auf …',
                        hintStyle: TextStyle(color: theme.inkSoft),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  // Die zweite Kategorie der Notiz: das Befinden des Tages,
                  // an dem sie haengt – beliebig viele Eintraege mit
                  // Uhrzeit.
                  NoteWellbeingSection(
                    date: _date,
                    noteId: _savedNote?.id,
                    ensureNote: () => _ensureNote().id,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
