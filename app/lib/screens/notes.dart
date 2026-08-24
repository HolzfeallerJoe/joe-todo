import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

const noteAutosaveDelay = Duration(milliseconds: 700);

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final notes = state.notes;

    return JoeScaffold(
      title: 'Notizen',
      body: SafeArea(
        child: notes.isEmpty
            ? Center(
                child: Text(
                  'Noch keine Notizen.\nTippe auf den Stift, um loszulegen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.inkSoft, fontSize: 15),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
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
                            Text(
                              formatDateYear(note.date),
                              style:
                                  TextStyle(color: theme.inkSoft, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        tooltip: 'Neue Notiz',
        onPressed: () => _openNote(context, null),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  void _openNote(BuildContext context, Note? note) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditScreen(note: note)),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                  Expanded(
                    child: TextField(
                      controller: _body,
                      maxLines: null,
                      expands: true,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
