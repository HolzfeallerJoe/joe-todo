import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final entries = state.history();

    // Group by day, newest first.
    final groups = <DateTime, List<HistoryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.day, () => []).add(e);
    }

    const page = PetPage.history;
    return JoeScaffold(
      page: page,
      title: 'Historie',
      body: SafeArea(
        child: entries.isEmpty
            // Auf einer Karte, nicht blank auf dem Hintergrund – siehe den
            // Kommentar in notes.dart: frei stehender Text in der
            // Papierfarbe verschwindet auf den Foto-Designs.
            ? ListView(
                padding: petPadding(
                  context,
                  page,
                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                ),
                children: [
                  PaperCard(
                    child: Text(
                      'Noch nichts erledigt. Abgehakte Aufgaben erscheinen '
                      'hier.',
                      style: TextStyle(color: theme.inkSoft, fontSize: 15),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: petPadding(
                  context,
                  page,
                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                ),
                children: [
                  for (final day in groups.keys) ...[
                    SectionTitle(dateOnly(day) == today()
                        ? 'Heute'
                        : formatDateFull(day)),
                    PaperCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Column(
                        children: [
                          for (final e in groups[day]!)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: e.task.color,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 15, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      e.task.title,
                                      style: TextStyle(
                                          color: theme.ink, fontSize: 15),
                                    ),
                                  ),
                                  if (e.task.isRecurring)
                                    Text(
                                      e.task.recurrenceLabel,
                                      style: TextStyle(
                                          color: theme.inkSoft, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
