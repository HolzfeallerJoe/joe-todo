import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'theme.dart';
import 'util.dart';

/// Scaffold wrapper that paints the themed notebook background behind
/// a transparent Material scaffold.
class JoeScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const JoeScaffold({
    super.key,
    this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemes[state.themeIndex % joeThemes.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.systemOverlayStyle,
      child: Stack(
        children: [
          Positioned.fill(
            child: theme.backgroundAsset != null
                ? Image.asset(theme.backgroundAsset!, fit: BoxFit.cover)
                : CustomPaint(painter: TexturePainter(theme)),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: title == null
                ? null
                : AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    foregroundColor: theme.onBg,
                    centerTitle: true,
                    // Sonst setzt die AppBar ihren eigenen Leistenstil und
                    // ueberschreibt den der AnnotatedRegion.
                    systemOverlayStyle: theme.systemOverlayStyle,
                    title: Text(
                      title!,
                      style: TextStyle(
                        color: theme.onBg,
                        fontWeight: FontWeight.w700,
                        shadows: theme.onBgShadows,
                      ),
                    ),
                    actions: actions,
                  ),
            body: body,
            floatingActionButton: floatingActionButton,
          ),
        ],
      ),
    );
  }
}

JoeTheme joeThemeOf(BuildContext context) {
  final state = AppScope.of(context);
  return joeThemes[state.themeIndex % joeThemes.length];
}

/// Cream paper card with a soft shadow, like a note pinned on the board.
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33513A1F),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: theme.onBg,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          shadows: theme.onBgShadows,
        ),
      ),
    );
  }
}

/// Folder-register shape: rounded card with a raised tab at the top left.
class _FolderTabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 16.0;
    const th = 12.0; // tab height
    final tw = size.width * 0.30; // tab width
    final path = Path()
      ..moveTo(0, size.height - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(tw - 14, 0)
      ..quadraticBezierTo(tw, 0, tw + th * 1.4, th)
      ..lineTo(size.width - r, th)
      ..quadraticBezierTo(size.width, th, size.width, th + r)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class FolderTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const FolderTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final onTab = theme.onTab(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhysicalShape(
        clipper: _FolderTabClipper(),
        color: color,
        elevation: 3,
        shadowColor: const Color(0x66513A1F),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 14, 12),
              child: Row(
                children: [
                  Icon(icon, color: onTab.withValues(alpha: 0.75), size: 26),
                  const Spacer(),
                  Text(
                    label,
                    style: TextStyle(
                      color: onTab,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: onTab.withValues(alpha: 0.75),
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

/// Small marker for the priority of a task or appointment. Level 2 is the
/// normal case and stays unmarked, so the row only gains ink when it says
/// something.
class PriorityMark extends StatelessWidget {
  final Priority priority;
  final Color color;
  final double size;

  const PriorityMark({
    super.key,
    required this.priority,
    required this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (priority == Priority.mittel) return const SizedBox.shrink();
    return Semantics(
      label: 'Priorität ${priority.label}',
      child: Icon(
        priority == Priority.hoch
            ? Icons.keyboard_double_arrow_up
            : Icons.keyboard_arrow_down,
        size: size,
        color: color,
      ),
    );
  }
}

/// Checkable task row. [day] is the occurrence day being toggled.
class TaskTile extends StatelessWidget {
  final Task task;
  final DateTime day;

  /// Adds the "offen seit …" line for one-offs that are past their date and
  /// for level-3 tasks, which are only ever shown as leftovers.
  final bool showOverdue;

  const TaskTile({
    super.key,
    required this.task,
    required this.day,
    this.showOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final done = task.isCompletedOn(day);
    final overdue =
        showOverdue &&
        !task.isRecurring &&
        !done &&
        (task.priority == Priority.niedrig ||
            dateOnly(task.startDate).isBefore(today()));
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => state.toggleTask(task, day),
      onLongPress: () => showTaskOptions(context, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: done ? task.color : Colors.transparent,
                border: Border.all(color: task.color, width: 2.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: done
                  ? Icon(Icons.check, size: 18, color: theme.bestOn(task.color))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: done ? theme.inkSoft : theme.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: theme.inkSoft,
                    ),
                  ),
                  if (task.isRecurring || overdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          if (task.isRecurring)
                            Text(
                              '🔁 ${task.recurrenceLabel}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.inkSoft,
                              ),
                            ),
                          if (overdue)
                            Text(
                              'offen seit ${formatDate(task.startDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                // A level-3 leftover is not an alarm; only
                                // the important ones get the accent.
                                color: task.priority == Priority.niedrig
                                    ? theme.inkSoft
                                    : theme.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!done)
              PriorityMark(
                priority: task.priority,
                color: task.priority == Priority.hoch
                    ? theme.accent
                    : theme.inkSoft,
              ),
          ],
        ),
      ),
    );
  }
}

void showTaskOptions(BuildContext context, Task task) {
  final state = AppScope.of(context);
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
            leading: Icon(Icons.edit_outlined, color: theme.ink),
            title: Text('Bearbeiten', style: TextStyle(color: theme.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              showTaskSheet(context, task: task);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.accent),
            title: Text('Löschen', style: TextStyle(color: theme.accent)),
            onTap: () {
              state.deleteTask(task);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    ),
  );
}

/// The 20 warm colors as dots. At this count the dots are deliberately small
/// so the whole palette stays on two rows inside an input sheet.
class ColorDotPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const ColorDotPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < taskPalette.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Semantics(
              label: 'Farbe ${taskPaletteNames[i]}',
              selected: i == selected,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: taskPalette[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: i == selected
                      ? const [
                          BoxShadow(color: Color(0x66000000), blurRadius: 4),
                        ]
                      : null,
                ),
                child: i == selected
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// The three priority levels as a segmented row, used by both input sheets.
class PriorityPicker extends StatelessWidget {
  final Priority selected;
  final ValueChanged<Priority> onChanged;

  const PriorityPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Row(
      children: [
        for (final p in Priority.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == Priority.niedrig ? 0 : 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: p == selected
                        ? theme.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: p == selected
                          ? theme.accent
                          : theme.inkSoft.withValues(alpha: 0.5),
                      width: p == selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Stufe ${p.level}',
                        style: TextStyle(color: theme.inkSoft, fontSize: 11),
                      ),
                      Text(
                        p.label,
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 14,
                          fontWeight: p == selected
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
      ],
    );
  }
}

/// Shared chrome for the input sheets: drag handle, title, and a body that
/// scrolls inside a height cap instead of pushing the save button off-screen
/// once the keyboard, the date row and 20 color dots are all in play.
class SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Bleibt unter dem scrollenden Teil stehen – der Speichern-Knopf soll nie
  /// weggescrollt oder halb von der Tastatur abgeschnitten sein.
  final Widget footer;

  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final media = MediaQuery.of(context);
    // Der Platz, der wirklich frei ist: ohne Tastatur. Ein fester Anteil der
    // Bildschirmhoehe reicht nicht – bei offener Tastatur ist er groesser als
    // der Rest des Bildschirms, dann schiebt sich das Blatt unter die
    // Tastatur. Die Statusleiste haelt useSafeArea beim Oeffnen frei;
    // showModalBottomSheet nimmt padding.top hier sonst heraus.
    final available = media.size.height - media.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // Ohne Tastatur bleibt es bei knapp drei Vierteln, damit die Seite
          // dahinter sichtbar bleibt; mit Tastatur zaehlt der freie Platz.
          constraints: BoxConstraints(
            maxHeight: math.min(available, media.size.height * 0.72),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.inkSoft.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.ink,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small caption above a block inside an input sheet.
class SheetLabel extends StatelessWidget {
  final String text;
  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: theme.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The save button both sheets end with.
class SheetSaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const SheetSaveButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: const Text(
          'Speichern',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Bottom sheet for creating or editing a task.
Future<void> showTaskSheet(
  BuildContext context, {
  Task? task,
  DateTime? initialDate,
}) {
  final state = AppScope.of(context);
  final theme = joeThemeOf(context);
  final titleController = TextEditingController(text: task?.title ?? '');
  var recurrence = task?.recurrence ?? RecurrenceType.none;
  var intervalDays = task?.intervalDays ?? 2;
  var colorIndex = task?.colorIndex ?? 0;
  var priority = task?.priority ?? Priority.mittel;
  var date = task != null ? dateOnly(task.startDate) : (initialDate ?? today());

  void save(BuildContext sheetContext) {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    if (task == null) {
      state.addTask(
        Task(
          id: state.nextId(),
          title: title,
          recurrence: recurrence,
          intervalDays: intervalDays,
          startDate: date,
          colorIndex: colorIndex,
          priority: priority,
        ),
      );
    } else {
      task.title = title;
      task.recurrence = recurrence;
      task.intervalDays = intervalDays;
      task.startDate = date;
      task.colorIndex = colorIndex;
      task.priority = priority;
      state.updateTask(task);
    }
    Navigator.pop(sheetContext);
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Haelt das Blatt unter der Statusleiste; ohne das nimmt
    // showModalBottomSheet padding.top heraus und der Titel rutscht
    // bei offener Tastatur hinter die Uhr.
    useSafeArea: true,
    backgroundColor: theme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SheetFrame(
        title: task == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten',
        footer: SheetSaveButton(onPressed: () => save(sheetContext)),
        children: [
          TextField(
            controller: titleController,
            autofocus: task == null,
            style: TextStyle(color: theme.ink),
            decoration: InputDecoration(
              hintText: 'Was ist zu tun?',
              hintStyle: TextStyle(color: theme.inkSoft),
              filled: true,
              fillColor: theme.paper,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.inkSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SheetLabel('Wiederholung'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in RecurrenceType.values)
                ChoiceChip(
                  label: Text(switch (r) {
                    RecurrenceType.none => 'Einmalig',
                    RecurrenceType.daily => 'Täglich',
                    RecurrenceType.weekly => 'Wöchentlich',
                    RecurrenceType.monthly => 'Monatlich',
                    RecurrenceType.everyXDays => 'Alle X Tage',
                  }),
                  selected: recurrence == r,
                  selectedColor: theme.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(color: theme.ink),
                  onSelected: (_) => setSheetState(() => recurrence = r),
                ),
            ],
          ),
          if (recurrence == RecurrenceType.everyXDays)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text('Alle', style: TextStyle(color: theme.ink)),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: theme.ink),
                    onPressed: () => setSheetState(
                      () => intervalDays = intervalDays > 2
                          ? intervalDays - 1
                          : 2,
                    ),
                  ),
                  Text(
                    '$intervalDays',
                    style: TextStyle(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: theme.ink),
                    onPressed: () =>
                        setSheetState(() => intervalDays = intervalDays + 1),
                  ),
                  Text('Tage', style: TextStyle(color: theme.ink)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: sheetContext,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setSheetState(() => date = dateOnly(picked));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 20, color: theme.inkSoft),
                  const SizedBox(width: 8),
                  Text(
                    recurrence == RecurrenceType.none
                        ? 'Datum: ${formatDateYear(date)}'
                        : 'Ab: ${formatDateYear(date)}',
                    style: TextStyle(color: theme.ink, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const SheetLabel('Priorität'),
          PriorityPicker(
            selected: priority,
            onChanged: (p) => setSheetState(() => priority = p),
          ),
          const SizedBox(height: 14),
          const SheetLabel('Farbe'),
          ColorDotPicker(
            selected: colorIndex,
            onChanged: (i) => setSheetState(() => colorIndex = i),
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet for creating or editing an appointment.
Future<void> showAppointmentSheet(
  BuildContext context, {
  Appointment? appointment,
  DateTime? initialDate,
}) {
  final state = AppScope.of(context);
  final theme = joeThemeOf(context);
  final titleController = TextEditingController(text: appointment?.title ?? '');
  var date = appointment != null
      ? dateOnly(appointment.when)
      : (initialDate ?? today());
  var time = appointment != null
      ? TimeOfDay.fromDateTime(appointment.when)
      : const TimeOfDay(hour: 12, minute: 0);
  var colorIndex = appointment?.colorIndex ?? 4;
  var priority = appointment?.priority ?? Priority.mittel;

  void save(BuildContext sheetContext) {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    final when = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (appointment == null) {
      state.addAppointment(
        Appointment(
          id: state.nextId(),
          title: title,
          when: when,
          colorIndex: colorIndex,
          priority: priority,
        ),
      );
    } else {
      appointment.title = title;
      appointment.when = when;
      appointment.colorIndex = colorIndex;
      appointment.priority = priority;
      state.updateAppointment(appointment);
    }
    Navigator.pop(sheetContext);
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Haelt das Blatt unter der Statusleiste; ohne das nimmt
    // showModalBottomSheet padding.top heraus und der Titel rutscht
    // bei offener Tastatur hinter die Uhr.
    useSafeArea: true,
    backgroundColor: theme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SheetFrame(
        title: appointment == null ? 'Neuer Termin' : 'Termin bearbeiten',
        footer: SheetSaveButton(onPressed: () => save(sheetContext)),
        children: [
          TextField(
            controller: titleController,
            autofocus: appointment == null,
            style: TextStyle(color: theme.ink),
            decoration: InputDecoration(
              hintText: 'Worum geht es?',
              hintStyle: TextStyle(color: theme.inkSoft),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.inkSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.event_outlined, size: 18, color: theme.ink),
                  label: Text(
                    formatDate(date),
                    style: TextStyle(color: theme.ink),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSheetState(() => date = dateOnly(picked));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.schedule, size: 18, color: theme.ink),
                  label: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: theme.ink),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: sheetContext,
                      initialTime: time,
                    );
                    if (picked != null) setSheetState(() => time = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SheetLabel('Priorität'),
          PriorityPicker(
            selected: priority,
            onChanged: (p) => setSheetState(() => priority = p),
          ),
          const SizedBox(height: 14),
          const SheetLabel('Farbe'),
          ColorDotPicker(
            selected: colorIndex,
            onChanged: (i) => setSheetState(() => colorIndex = i),
          ),
        ],
      ),
    ),
  );
}

/// Ask whether the new entry is a task or an appointment, then open the
/// matching sheet. [initialDate] pre-fills the day, used by the calendar.
void showAddChooser(BuildContext context, {DateTime? initialDate}) {
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
          if (initialDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Für ${formatDateYear(initialDate)}',
                    style: TextStyle(color: theme.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
          ListTile(
            leading: Icon(Icons.check_circle_outline, color: theme.ink),
            title: Text('Neue Aufgabe', style: TextStyle(color: theme.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              showTaskSheet(context, initialDate: initialDate);
            },
          ),
          ListTile(
            leading: Icon(Icons.event_outlined, color: theme.ink),
            title: Text('Neuer Termin', style: TextStyle(color: theme.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              showAppointmentSheet(context, initialDate: initialDate);
            },
          ),
        ],
      ),
    ),
  );
}
