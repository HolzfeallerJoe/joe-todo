import 'package:flutter/material.dart';

import '../agenda.dart';
import '../device_calendar.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'calendar.dart';
import 'appointments.dart';
import 'notes.dart';
import 'history.dart';
import 'settings.dart';
import 'tasks.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);

    const page = PetPage.dashboard;
    return JoeScaffold(
      page: page,
      body: SafeArea(
        child: ListView(
          // Der Begleiter sitzt als eigene Ebene ueber der ganzen Seite
          // (siehe JoeScaffold), nicht mehr nur auf dieser Karte.
          padding: petPadding(
            context,
            page,
            const EdgeInsets.fromLTRB(16, 16, 16, 96),
          ),
          children: [
            // Alles von heute auf einer Karte: die Zahlen oben, darunter
            // zwei Ausklappmenues – zum Abhaken und zum Nachsehen.
            const _TodayCard(),

            const SizedBox(height: 24),

            // Folder-register navigation, like tabs in a notebook.
            FolderTabButton(
              icon: Icons.check_circle_outline,
              label: 'Aufgaben',
              color: theme.tabColors[0],
              onTap: () => _push(context, const TasksScreen()),
            ),
            FolderTabButton(
              icon: Icons.access_time,
              label: 'Termine',
              color: theme.tabColors[1],
              onTap: () => _push(context, const AppointmentsScreen()),
            ),
            FolderTabButton(
              icon: Icons.calendar_month_outlined,
              label: 'Kalender',
              color: theme.tabColors[2],
              onTap: () => _push(context, const CalendarScreen()),
            ),
            FolderTabButton(
              icon: Icons.edit_note,
              label: 'Notizen',
              color: theme.tabColors[3],
              onTap: () => _push(context, const NotesScreen()),
            ),
            FolderTabButton(
              icon: Icons.history,
              label: 'Historie',
              color: theme.tabColors[4],
              onTap: () => _push(context, const HistoryScreen()),
            ),
            FolderTabButton(
              icon: Icons.tune,
              label: 'Einstellungen',
              color: theme.tabColors[5],
              onTap: () => _push(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        tooltip: 'Hinzufügen',
        onPressed: () => showAddChooser(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

/// Die Heute-Karte: Datum, die beiden Zahlen des Tages in einem Satz, und
/// darunter die zwei Ausklappmenues "Heute abhaken" und "Heutige Termine".
///
/// Aufgaben und Termine teilen sich eine Karte, weil sie dieselbe Frage
/// beantworten – was ist heute? Zwei Karten liessen den Tag in zwei Haelften
/// zerfallen, und die Kopfzeile sagte zweimal "heute".
///
/// Die Geraete-Termine kommen monatsweise und asynchron herein, deshalb
/// haengt die Karte am [DeviceCalendarFeed] – ohne das bliebe sie bis zum
/// naechsten Antippen auf dem Stand von vorhin.
class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final feed = DeviceCalendarFeed.instance;
    final t = today();

    final dueTasks = state.tasksDueToday();
    final lowTasks = state.lowLeftoverTasks();
    final openCount = state.openTodayCount();

    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final todayEntries = agendaForDay(
          t,
          appointments: state.appointments,
          deviceEvents:
              state.showDeviceCalendar ? feed.eventsForDay(t) : const [],
          deviceColor: theme.accent,
        );

        return PaperCard(
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
              const SizedBox(height: 8),
              TodayHeadline(
                tasks: openCount,
                appointments: todayEntries.length,
              ),
              const FoldDivider(),
              FoldSection(
                title: 'Heute abhaken',
                count: dueTasks.length + lowTasks.length,
                unitSingular: 'Aufgabe',
                unitPlural: 'Aufgaben',
                open: state.todayExpanded,
                onToggle: state.setTodayExpanded,
                children: [
                  if (dueTasks.isEmpty && lowTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Alles erledigt – lehn dich zurück 🌿',
                        style: TextStyle(color: theme.inkSoft, fontSize: 15),
                      ),
                    ),
                  for (final task in dueTasks)
                    TaskTile(task: task, day: t, showOverdue: true),
                  if (lowTasks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Text(
                        'Hat Zeit',
                        style: TextStyle(
                          color: theme.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final task in lowTasks)
                      TaskTile(task: task, day: t, showOverdue: true),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
              const FoldDivider(),
              FoldSection(
                title: 'Heutige Termine',
                count: todayEntries.length,
                unitSingular: 'Termin',
                unitPlural: 'Termine',
                open: state.appointmentsExpanded,
                onToggle: state.setAppointmentsExpanded,
                children: [
                  // Ein gescheiterter Geraete-Kalender sagt es auch hier:
                  // sonst saehe eine halbe Terminliste aus wie eine ganze.
                  if (state.showDeviceCalendar && feed.hasProblem)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DeviceCalendarNotice(
                        message: feed.lastError!,
                        permissionMissing: feed.permissionMissing,
                        card: false,
                      ),
                    ),
                  if (todayEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Heute keine Termine',
                        style: TextStyle(color: theme.inkSoft, fontSize: 15),
                      ),
                    ),
                  for (final entry in todayEntries) _AgendaRow(entry: entry),
                  const SizedBox(height: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Eine Zeile im Ausklappmenue "Heutige Termine": Uhrzeit, Titel.
///
/// Ein eigener Termin geht auf Tipp zum Bearbeiten auf; ein Geraete-Termin
/// traegt statt des Farbpunkts das Kalender-Zeichen und ist reine Anzeige –
/// gepflegt wird er in der App, aus der er kommt.
class _AgendaRow extends StatelessWidget {
  final AgendaEntry entry;

  const _AgendaRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Center(
              child: entry.fromDevice
                  ? Icon(Icons.event, size: 14, color: entry.color)
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.color,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              agendaTimeLabel(entry),
              style: TextStyle(
                color: theme.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(color: theme.ink, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.priority != null)
            PriorityMark(
              priority: entry.priority!,
              color: entry.priority == Priority.hoch
                  ? theme.accent
                  : theme.inkSoft,
              size: 16,
            ),
        ],
      ),
    );

    final appointment = entry.appointment;
    if (appointment == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showAppointmentSheet(context, appointment: appointment),
      onLongPress: () => showAppointmentOptions(context, appointment),
      child: row,
    );
  }
}
