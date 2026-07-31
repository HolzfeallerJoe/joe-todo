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
                              formatDateYear(note.updatedAt),
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
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
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
          updatedAt: DateTime.now(),
        ));
      }
    } else {
      existing.title = title;
      existing.body = body;
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
