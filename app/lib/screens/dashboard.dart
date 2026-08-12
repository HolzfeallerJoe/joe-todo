import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'calendar.dart';
import 'appointments.dart';
import 'notes.dart';
import 'history.dart';
import 'settings.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final t = today();
    final dueTasks = state.tasksDueToday();
    final openCount = state.openTodayCount();
    final nextAppointments = state.upcomingAppointments(limit: 3);

    return JoeScaffold(
      body: SafeArea(
        child: ListView(
          // The companion peeks over the top edge of the header card, so the
          // list needs extra headroom whenever it is switched on.
          padding: EdgeInsets.fromLTRB(16, state.showPet ? 44 : 16, 16, 96),
          children: [
            // Header card: today, open count, the companion peeking over it.
            Stack(
              clipBehavior: Clip.none,
              children: [
                PaperCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDateFull(t),
                        style: TextStyle(
                          color: theme.inkSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$openCount',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              openCount == 1
                                  ? 'offene Aufgabe heute'
                                  : 'offene Aufgaben heute',
                              style: TextStyle(
                                color: theme.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (nextAppointments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: nextAppointments.first.color
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_none,
                                  size: 18, color: nextAppointments.first.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${formatRelativeDay(nextAppointments.first.when)}, '
                                  '${formatTime(nextAppointments.first.when)} – '
                                  '${nextAppointments.first.title}',
                                  style:
                                      TextStyle(color: theme.ink, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.showPet)
                  Positioned(
                    right: 8,
                    top: -40,
                    // Fixed box with the artwork pinned to its bottom edge:
                    // the illustrations range from wide (shark) to tall
                    // (llama), and this keeps every one of them sitting on
                    // the same line on the card without shifting the layout.
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: Image.asset(
                        state.pet.asset,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
              ],
            ),

            const SectionTitle('Heute abhaken'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: dueTasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Alles erledigt – lehn dich zurück 🌿',
                        style: TextStyle(color: theme.inkSoft, fontSize: 15),
                      ),
                    )
                  : Column(
                      children: [
                        for (final task in dueTasks)
                          TaskTile(task: task, day: t, showOverdue: true),
                      ],
                    ),
            ),

            const SectionTitle('Nächste Termine'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: nextAppointments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Keine Termine geplant',
                        style: TextStyle(color: theme.inkSoft, fontSize: 15),
                      ),
                    )
                  : Column(
                      children: [
                        for (final a in nextAppointments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: a.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    formatRelativeDay(a.when),
                                    style: TextStyle(
                                      color: theme.inkSoft,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    a.title,
                                    style: TextStyle(
                                        color: theme.ink, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  formatTime(a.when),
                                  style: TextStyle(
                                      color: theme.inkSoft, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Folder-register navigation, like tabs in a notebook.
            FolderTabButton(
              icon: Icons.calendar_month_outlined,
              label: 'Kalender',
              color: theme.tabColors[0],
              onTap: () => _push(context, const CalendarScreen()),
            ),
            FolderTabButton(
              icon: Icons.access_time,
              label: 'Termine',
              color: theme.tabColors[1],
              onTap: () => _push(context, const AppointmentsScreen()),
            ),
            FolderTabButton(
              icon: Icons.edit_note,
              label: 'Notizen',
              color: theme.tabColors[2],
              onTap: () => _push(context, const NotesScreen()),
            ),
            FolderTabButton(
              icon: Icons.history,
              label: 'Historie',
              color: theme.tabColors[3],
              onTap: () => _push(context, const HistoryScreen()),
            ),
            FolderTabButton(
              icon: Icons.tune,
              label: 'Einstellungen',
              color: theme.tabColors[4],
              onTap: () => _push(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        tooltip: 'Hinzufügen',
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showAddMenu(BuildContext context) {
    final theme = joeThemeOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: theme.ink),
              title: Text('Neue Aufgabe', style: TextStyle(color: theme.ink)),
              onTap: () {
                Navigator.pop(sheetContext);
                showTaskSheet(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.event_outlined, color: theme.ink),
              title: Text('Neuer Termin', style: TextStyle(color: theme.ink)),
              onTap: () {
                Navigator.pop(sheetContext);
                showAppointmentSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
