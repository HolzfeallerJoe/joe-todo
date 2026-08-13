import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../almanac.dart';
import '../device_calendar.dart';
import '../models.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'notes.dart';

class CalendarScreen extends StatefulWidget {
  /// Auf welchem Tag der Kalender aufgeht. Standard ist heute; eine
  /// angetippte Erinnerung bringt ihren eigenen Tag mit.
  final DateTime? initialDay;

  const CalendarScreen({super.key, this.initialDay});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first day of shown month
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(widget.initialDay ?? today());
    _month = DateTime(_selected.year, _selected.month);
    // Geraete-Termine kommen asynchron aus dem Calendar Provider; wenn ein
    // Monat fertig geladen ist, malt der Screen sich neu.
    DeviceCalendarFeed.instance.addListener(_onFeedChanged);
    // Dasselbe fuer die Mondphasen: die rechnet [MoonWarmup] haeppchenweise
    // vor, der Kalender fuellt sich dabei sichtbar auf.
    MoonWarmup.instance.addListener(_onFeedChanged);
  }

  @override
  void dispose() {
    DeviceCalendarFeed.instance.removeListener(_onFeedChanged);
    MoonWarmup.instance.removeListener(_onFeedChanged);
    super.dispose();
  }

  void _onFeedChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final t = today();

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday - 1;

    final dayTasks = state.tasksForDay(_selected);
    final dayAppointments = state.appointmentsForDay(_selected);
    final dayNotes = state.notesForDay(_selected);
    final dayHolidays = state.showHolidays
        ? holidaysOn(_selected, state.holidayRegion)
        : const <String>[];
    // Der ausgewaehlte Tag darf rechnen: das ist ein Tag, keine 42, und die
    // Zeile im Tagesdetail soll sofort stehen.
    final dayMoon = state.showMoon ? moonPhaseOnDay(_selected) : null;
    final dayDeviceEvents = state.showDeviceCalendar
        ? DeviceCalendarFeed.instance.eventsForDay(_selected)
        : const <Event>[];

    // Den gezeigten Monat vorrechnen lassen. Aus `build` heraus unbedenklich:
    // der Lauf beginnt erst nach diesem Frame und meldet sich dann selbst.
    if (state.showMoon) MoonWarmup.instance.warm(_month);

    return JoeScaffold(
      title: 'Kalender',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            PaperCard(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: theme.ink),
                        tooltip: 'Voriger Monat',
                        onPressed: () => _shiftMonth(-1),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _month = DateTime(t.year, t.month);
                            _selected = t;
                          }),
                          child: Text(
                            '${monthNames[_month.month - 1]} ${_month.year}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: theme.ink),
                        tooltip: 'Nächster Monat',
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final w in weekdayNamesShort)
                        Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                color: theme.inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: leadingBlanks + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(
                          _month.year, _month.month, index - leadingBlanks + 1);
                      return _DayCell(
                        day: day,
                        isToday: day == t,
                        isSelected: day == _selected,
                        onTap: () => setState(() => _selected = day),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Ein gescheiterter Geraete-Kalender sagt es hier, dauerhaft –
            // der Toast beim Fehler ist nach drei Sekunden weg, die leere
            // Ebene bleibt. Ohne diese Zeile saehe ein Tag ohne Termine
            // genauso aus wie einer, dessen Termine nicht geladen werden
            // konnten.
            if (state.showDeviceCalendar &&
                DeviceCalendarFeed.instance.hasProblem)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _DeviceCalendarNotice(
                  message: DeviceCalendarFeed.instance.lastError!,
                  permissionMissing:
                      DeviceCalendarFeed.instance.permissionMissing,
                ),
              ),
            const SizedBox(height: 14),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDateYear(_selected),
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Ein Plus fuer den Tag: fragt, ob Aufgabe oder Termin.
                      IconButton(
                        icon: Icon(Icons.add_circle_outline,
                            color: theme.accent),
                        tooltip: 'Eintrag hinzufügen',
                        onPressed: () =>
                            showAddChooser(context, initialDate: _selected),
                      ),
                    ],
                  ),
                  // Feiertag und Mondphase zaehlen als Inhalt: neben "Vollmond"
                  // saehe ein "Nichts eingetragen" widerspruechlich aus.
                  if (dayTasks.isEmpty &&
                      dayAppointments.isEmpty &&
                      dayNotes.isEmpty &&
                      dayHolidays.isEmpty &&
                      dayMoon == null &&
                      dayDeviceEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Nichts eingetragen an diesem Tag.',
                        style: TextStyle(color: theme.inkSoft, fontSize: 14),
                      ),
                    ),
                  // Termine, Aufgaben und Notizen stehen als drei Bloecke
                  // untereinander. Der Abstand gehoert zwischen die Bloecke,
                  // nicht in sie hinein – sonst zerfaellt auch die einzelne
                  // Liste. Leere Bloecke zaehlen nicht mit, damit an einem Tag
                  // ohne Termine keine Luecke oben steht.
                  ..._spacedGroups(const SizedBox(height: 16), [
                    // Feiertag und Mondphase stehen ganz oben – sie gehoeren
                    // zum Tag selbst, nicht zu dem, was man sich vorgenommen
                    // hat. Beide sind reine Anzeige, nichts zum Antippen.
                    [
                      for (final name in dayHolidays)
                        _AlmanacRow(
                          icon: Icon(Icons.star_rounded,
                              size: 20, color: theme.accent),
                          label: name,
                        ),
                      if (dayMoon != null)
                        _AlmanacRow(
                          icon: MoonIcon(
                              kind: dayMoon, size: 18, color: theme.accent),
                          label: dayMoon.label,
                        ),
                    ],
                    [
                      for (final a in dayAppointments)
                        _AppointmentRow(appointment: a),
                      // Geraete-Termine stehen bei den Terminen, aber nach
                      // den eigenen: was man selbst eingetragen hat, zuerst.
                      for (final e in dayDeviceEvents)
                        _DeviceEventRow(event: e),
                    ],
                    [
                      for (final task in dayTasks)
                        TaskTile(task: task, day: _selected),
                    ],
                    // Notizen des Tages – im Monatsraster stehen sie als "N".
                    [for (final note in dayNotes) _NoteRow(note: note)],
                  ]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: Icon(Icons.edit_note, size: 20, color: theme.accent),
                      label: Text('Notiz hinzufügen',
                          style: TextStyle(color: theme.accent)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NoteEditScreen(initialDate: _selected),
                        ),
                      ),
                    ),
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

/// Haengt die nicht leeren Gruppen mit [gap] dazwischen zu einer Liste
/// zusammen. Leere Gruppen fallen weg, damit kein Abstand ohne Inhalt bleibt.
List<Widget> _spacedGroups(Widget gap, List<List<Widget>> groups) {
  final out = <Widget>[];
  for (final group in groups.where((group) => group.isNotEmpty)) {
    if (out.isNotEmpty) out.add(gap);
    out.addAll(group);
  }
  return out;
}

/// Ein Termin in der Tageskarte.
class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;
  const _AppointmentRow({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showAppointmentSheet(context, appointment: appointment),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: appointment.color),
            const SizedBox(width: 10),
            Text(
              formatTime(appointment.when),
              style: TextStyle(
                color: theme.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appointment.title,
                style: TextStyle(color: theme.ink, fontSize: 15),
              ),
            ),
            PriorityMark(
              priority: appointment.priority,
              color: appointment.priority == Priority.hoch
                  ? theme.accent
                  : theme.inkSoft,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Notiz in der Tageskarte.
class _NoteRow extends StatelessWidget {
  final Note note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NoteEditScreen(note: note)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _NoteBadge(theme: theme),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note.title.isEmpty ? 'Ohne Titel' : note.title,
                style: TextStyle(color: theme.ink, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final tasks = state.tasksForDay(day);
    final appointments = state.appointmentsForDay(day);
    final hasNotes = state.notesForDay(day).isNotEmpty;
    final holidays = state.showHolidays
        ? holidaysOn(day, state.holidayRegion)
        : const <String>[];
    // Nur, was schon gerechnet ist: 42 Zellen, die alle selbst rechnen,
    // waeren ein spuerbarer Ruckler beim Monatswechsel. [MoonWarmup] fuellt
    // nach und meldet sich, dann steht der Mond da.
    final moon = state.showMoon ? cachedMoonPhaseOnDay(day) : null;

    final markers = <Widget>[];
    for (final a in appointments) {
      markers.add(_marker(a.color, done: false));
    }
    for (final task in tasks) {
      markers.add(_marker(task.color, done: task.isCompletedOn(day)));
    }
    // Geraete-Termine als letzte Punkte, in der Farbe ihres Kalenders –
    // die eigenen Eintraege behalten den Vortritt im Sechs-Punkte-Budget.
    if (state.showDeviceCalendar) {
      for (final e in DeviceCalendarFeed.instance.eventsForDay(day)) {
        markers.add(_marker(e.color ?? theme.accent, done: false));
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? theme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: isToday
              ? Border.all(color: theme.accent, width: 1.6)
              : null,
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? theme.accent : theme.ink,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: markers.take(6).toList(),
              ),
            ),
            // Die untere Badge-Zeile: Stern (Feiertag) links, "N" (Notiz) in
            // der Mitte, Mond (Hauptphase) rechts. Keins davon bekommt einen
            // Farbpunkt – sie haben keine eigene Farbe und sollen die
            // Punktreihe der Aufgaben nicht verwaessern.
            if (holidays.isNotEmpty || hasNotes || moon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    if (holidays.isNotEmpty)
                      Semantics(
                        label: holidays.join(', '),
                        child: Icon(Icons.star_rounded,
                            size: 14, color: theme.accent),
                      ),
                    if (hasNotes) _NoteBadge(theme: theme, size: 12),
                    if (moon != null)
                      MoonIcon(kind: moon, size: 11, color: theme.accent),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Completed tasks stay visible: filled dot for open, ring for done.
  Widget _marker(Color color, {required bool done}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: done ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: done ? Border.all(color: color, width: 1.4) : null,
      ),
    );
  }
}

/// Ein Termin aus einem Geraete-Kalender in der Tageskarte: nur Anzeige,
/// gepflegt wird er in seiner Kalender-App. Ganztaegige zeigen "ganztägig"
/// statt einer Uhrzeit.
class _DeviceEventRow extends StatelessWidget {
  final Event event;
  const _DeviceEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.event, size: 18, color: event.color ?? theme.accent),
          const SizedBox(width: 10),
          Text(
            deviceEventTimeLabel(event),
            style: TextStyle(
              color: theme.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(color: theme.ink, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Hinweiszeile, wenn die Geraete-Kalender-Ebene nicht laden konnte.
/// Sie steht so lange, wie das Problem besteht – und bietet den einen
/// Handgriff an, der weiterhilft: den Weg in die System-Einstellungen, wenn
/// die Berechtigung fehlt, sonst einen zweiten Versuch.
class _DeviceCalendarNotice extends StatelessWidget {
  final String message;
  final bool permissionMissing;

  const _DeviceCalendarNotice({
    required this.message,
    required this.permissionMissing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final feed = DeviceCalendarFeed.instance;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 20, color: theme.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.ink, fontSize: 13, height: 1.3),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed:
                permissionMissing ? feed.openSystemSettings : feed.retry,
            child: Text(
              permissionMissing ? 'Einstellungen' : 'Erneut',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Feiertags- oder Mondphasen-Zeile in der Tageskarte: nur Anzeige,
/// nichts zum Antippen – der Tag bringt sie mit, nicht der Nutzer.
class _AlmanacRow extends StatelessWidget {
  final Widget icon;
  final String label;
  const _AlmanacRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 20, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der kleine gemalte Mond: Ring fuer Neumond, gefuellter Kreis fuer
/// Vollmond, halb gefuellt fuer die Halbmonde – rechte Haelfte zunehmend,
/// linke abnehmend (Nordhalbkugel).
class MoonIcon extends StatelessWidget {
  final MoonPhaseKind kind;
  final double size;
  final Color color;

  const MoonIcon({
    super.key,
    required this.kind,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kind.label,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MoonPainter(kind, color),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final MoonPhaseKind kind;
  final Color color;
  _MoonPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    final fill = Paint()..color = color;

    switch (kind) {
      case MoonPhaseKind.newMoon:
        break; // nur der Ring
      case MoonPhaseKind.fullMoon:
        canvas.drawOval(rect, fill);
      case MoonPhaseKind.firstQuarter:
        // Bogen von oben ueber rechts nach unten; die Fuellung schliesst
        // ihn als Sehne – die rechte Haelfte.
        canvas.drawPath(Path()..addArc(rect, -math.pi / 2, math.pi), fill);
      case MoonPhaseKind.lastQuarter:
        canvas.drawPath(Path()..addArc(rect, math.pi / 2, math.pi), fill);
    }
    canvas.drawOval(rect, ring);
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.kind != kind || old.color != color;
}

/// Das "N", mit dem Notizen im Kalender markiert sind.
class _NoteBadge extends StatelessWidget {
  final JoeTheme theme;
  final double size;

  const _NoteBadge({required this.theme, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Notiz',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: theme.accent, width: 1),
        ),
        child: Text(
          'N',
          style: TextStyle(
            color: theme.accent,
            fontSize: size * 0.62,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
