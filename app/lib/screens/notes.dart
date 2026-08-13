import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

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
                      child: PaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title.isEmpty ? 'Ohne Titel' : note.title,
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
                              style: TextStyle(
                                  color: theme.inkSoft, fontSize: 12),
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

class NoteEditScreen extends StatefulWidget {
  final Note? note;

  /// Tag, unter dem eine neue Notiz abgelegt wird – der Kalender legt hier
  /// den ausgewaehlten Tag hinein.
  final DateTime? initialDate;

  const NoteEditScreen({super.key, this.note, this.initialDate});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _date = dateOnly(widget.note?.date ?? widget.initialDate ?? DateTime.now());
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final state = AppScope.of(context);
    final title = _title.text.trim();
    final body = _body.text.trim();
    final existing = widget.note;
    if (existing == null) {
      if (title.isNotEmpty || body.isNotEmpty) {
        state.addNote(Note(
          id: state.nextId(),
          title: title,
          body: body,
          date: _date,
          updatedAt: DateTime.now(),
        ));
      }
    } else {
      existing.title = title;
      existing.body = body;
      existing.date = _date;
      state.updateNote(existing);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: JoeScaffold(
        title: widget.note == null ? 'Neue Notiz' : 'Notiz',
        actions: [
          if (widget.note != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.accent),
              tooltip: 'Notiz löschen',
              onPressed: () {
                state.deleteNote(widget.note!);
                Navigator.of(context).pop();
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
