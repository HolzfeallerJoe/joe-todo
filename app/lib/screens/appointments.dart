import 'package:flutter/material.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const page = PetPage.appointments;
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final upcoming = state.upcomingAppointments();
    final past = state.pastAppointments();

    return JoeScaffold(
      page: page,
      title: 'Termine',
      body: SafeArea(
        child: ListView(
          padding: petPadding(
            context,
            page,
            const EdgeInsets.fromLTRB(16, 4, 16, 96),
          ),
          children: [
            if (upcoming.isEmpty && past.isEmpty)
              PaperCard(
                child: Text(
                  'Noch keine Termine. Tippe auf +, um einen anzulegen.',
                  style: TextStyle(color: theme.inkSoft, fontSize: 15),
                ),
              ),
            for (final a in upcoming)
              _AppointmentCard(appointment: a),
            if (past.isNotEmpty) ...[
              const SectionTitle('Vergangen'),
              for (final a in past)
                Opacity(
                  opacity: 0.6,
                  child: _AppointmentCard(appointment: a),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        tooltip: 'Neuer Termin',
        onPressed: () => showAppointmentSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showAppointmentSheet(context, appointment: appointment),
        // Langer Druck fuehrt auf dasselbe Blatt wie bei einer Aufgabe:
        // Bearbeiten oder Loeschen, statt sofort zu fragen, ob geloescht
        // werden soll.
        onLongPress: () => showAppointmentOptions(context, appointment),
        child: PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                  color: appointment.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.title,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatRelativeDay(appointment.when)} · ${formatTime(appointment.when)}',
                      style: TextStyle(color: theme.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PriorityMark(
                priority: appointment.priority,
                color: appointment.priority == Priority.hoch
                    ? theme.accent
                    : theme.inkSoft,
              ),
              Icon(Icons.chevron_right, color: theme.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
