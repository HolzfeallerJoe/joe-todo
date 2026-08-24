import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_calendar.dart';
import 'models.dart';
import 'pets.dart';
import 'reminders.dart';
import 'theme.dart';
import 'toast.dart';
import 'util.dart';

// Jede Seite sagt JoeScaffold, welche Seite sie ist – dafuer braucht sie
// PetPage, und dafuer soll sie nicht extra pets.dart kennen muessen.
export 'pets.dart' show PetPage;

/// Scaffold wrapper that paints the themed notebook background behind
/// a transparent Material scaffold – und traegt den Begleiter, der auf
/// jeder Seite mitsitzt (siehe [_PetLayer]).
class JoeScaffold extends StatefulWidget {
  final String? title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  /// Welche Seite das hier ist – daran haengt, wo der Begleiter sitzt. Jede
  /// Seite bietet ihre eigenen Plaetze an (siehe [PetPage]).
  final PetPage page;

  const JoeScaffold({
    super.key,
    this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    required this.page,
  });

  @override
  State<JoeScaffold> createState() => _JoeScaffoldState();
}

class _JoeScaffoldState extends State<JoeScaffold> {
  /// Wie weit die Seite gescrollt ist. Der Begleiter sitzt auf der Kante der
  /// ersten Karte – und wenn die wegscrollt, geht er mit. Ein Tierchen, das
  /// beim Scrollen an derselben Stelle klebt, waere kein Aufsitzer mehr,
  /// sondern ein Aufkleber auf dem Bildschirm.
  ///
  /// Bewusst ein Notifier und kein setState: sonst baute jedes Scroll-Bild
  /// die ganze Seite neu, nur damit ein Bild ein paar Pixel wandert.
  final _scrolled = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  /// Nur die Seite selbst zaehlt: `depth == 0` laesst Listen *innerhalb* der
  /// Seite (die Symptomliste im Notiz-Editor etwa) aussen vor.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    _scrolled.value = notification.metrics.pixels.clamp(0.0, double.infinity);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final spot = PetPlacement.spotOn(widget.page);
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
            appBar: widget.title == null
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
                      widget.title!,
                      style: TextStyle(
                        color: theme.onBg,
                        fontWeight: FontWeight.w700,
                        shadows: theme.onBgShadows,
                      ),
                    ),
                    actions: widget.actions,
                  ),
            // Den Platz fuer den Begleiter haelt die Seite selbst frei, in
            // ihrer Liste – siehe [petHeadroom]. Hier wird nur zugehoert,
            // wie weit sie gescrollt ist.
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.body,
            ),
            floatingActionButton: widget.floatingActionButton,
          ),
          if (state.showPet)
            _PetLayer(
              pet: state.pet,
              spot: spot,
              // Ohne Titelleiste faengt der Inhalt unter der Statusleiste an,
              // mit Titelleiste darunter. Der Begleiter sitzt auf der
              // Oberkante des Inhalts – so verdeckt er nie den Seitentitel.
              contentTop: MediaQuery.paddingOf(context).top +
                  (widget.title == null ? 0 : kToolbarHeight),
              hasFab: widget.floatingActionButton != null,
              scrolled: _scrolled,
            ),
        ],
      ),
    );
  }
}

/// Der Begleiter als eigene Ebene ueber der Seite.
///
/// Er liegt bewusst *ueber* dem Inhalt – ein Tierchen, das hinter den Karten
/// verschwindet, waere auf den meisten Seiten gar nicht zu sehen – nimmt aber
/// keine Tipps entgegen ([IgnorePointer]) und traegt keine Semantik: er ist
/// Deko und darf weder einen Knopf schlucken noch die Vorlesehilfe aufhalten.
///
/// Er haengt an dem, worauf er sitzt: die Plaetze auf der Inhaltskante
/// scrollen mit der Seite weg und werden dabei an der Oberkante
/// abgeschnitten; die unteren bleiben stehen – die Navigationsleiste und der
/// Plus-Knopf scrollen ja auch nicht.
class _PetLayer extends StatelessWidget {
  final Pet pet;
  final PetSpot spot;

  /// Oberkante des Seiteninhalts (unter Statusleiste bzw. Titelleiste).
  final double contentTop;

  /// Unten rechts sitzt sonst der Plus-Knopf; dort rueckt der Begleiter zur
  /// Seite, statt ihn zu verdecken.
  final bool hasFab;

  /// Wie weit die Seite gescrollt ist.
  final ValueListenable<double> scrolled;

  const _PetLayer({
    required this.pet,
    required this.spot,
    required this.contentTop,
    required this.hasFab,
    required this.scrolled,
  });

  @override
  Widget build(BuildContext context) {
    final box = petBox(pet, spot);
    final sitting = Padding(
      padding: EdgeInsets.only(
        left: 14,
        // Neben dem Plus-Knopf heisst: daneben, nicht darauf.
        right: 14 + (spot == PetSpot.besideFab && hasFab ? _fabWidth : 0),
        bottom: spot.isTop ? 0 : MediaQuery.paddingOf(context).bottom,
      ),
      child: Align(
        alignment: switch ((spot.isTop, spot.side)) {
          (true, -1) => Alignment.topLeft,
          (true, 0) => Alignment.topCenter,
          (true, _) => Alignment.topRight,
          (false, -1) => Alignment.bottomLeft,
          (false, 0) => Alignment.bottomCenter,
          (false, _) => Alignment.bottomRight,
        },
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: Image.asset(
            pet.asset,
            fit: BoxFit.contain,
            // Die Motive sind unten buendig gemalt: so steht jedes auf
            // derselben Linie, egal wie hoch es ist.
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    return Positioned(
      top: contentTop,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: ExcludeSemantics(
          // Abgeschnitten an der Oberkante des Inhalts: beim Hochscrollen
          // soll das Tierchen unter der Titelleiste verschwinden und nicht
          // darueber liegen.
          child: ClipRect(
            child: spot.isTop
                ? ValueListenableBuilder<double>(
                    valueListenable: scrolled,
                    builder: (context, offset, child) => Transform.translate(
                      offset: Offset(0, -offset),
                      child: child,
                    ),
                    child: sitting,
                  )
                : sitting,
          ),
        ),
      ),
    );
  }
}

/// Platz, den der Plus-Knopf unten rechts belegt (56 Knopf + 16 Rand).
const _fabWidth = 72.0;

/// Der Rand einer Seitenliste, mit dem Platz fuer den Begleiter darin.
///
/// [base] ist der Rand, den die Seite ohnehin haette; heraus kommt derselbe,
/// nur oben (bzw. unten) so weit aufgemacht, dass das Tierchen hineinpasst.
/// Bewusst das Groessere von beidem und keine Summe: der Platz *enthaelt*
/// den normalen Rand, sonst schoebe er die erste Karte unter dem Begleiter
/// weg, und der saesse auf nichts mehr.
///
/// Freihalten muss ihn die Seite selbst, und zwar **innerhalb** ihrer
/// scrollenden Liste:
///
/// ```dart
/// padding: petPadding(context, page, const EdgeInsets.fromLTRB(16, 4, 16, 96)),
/// ```
///
/// Warum nicht einfach ein Padding um die Liste herum, von JoeScaffold aus?
/// Dann liegt der Platz ausserhalb des Scroll-Bereichs: der Inhalt
/// verschwindet beim Scrollen an einer Kante weiter unten, waehrend das
/// Tierchen bis zur Titelleiste weiterwandert. Zwei Kanten, zwei Kaesten –
/// und genau so sieht es dann auch aus. Liegt der Platz in der Liste,
/// scrollt er mit dem Tierchen zusammen weg, und beide verschwinden an
/// derselben Linie.
///
/// Bewusst eine Funktion und kein InheritedWidget: die Seite baut ihren
/// Koerper, *bevor* JoeScaffold ihn einhaengt – ein Provider im Scaffold
/// waere von dort aus gar nicht zu sehen.
EdgeInsets petPadding(BuildContext context, PetPage page, EdgeInsets base) {
  final state = AppScope.of(context);
  if (!state.showPet) return base;
  final spot = PetPlacement.spotOn(page);
  final height = petBox(state.pet, spot).height;
  final overlap = petOverlap(state.pet, spot, page);
  return base.copyWith(
    top: spot.isTop ? math.max(base.top, height - overlap) : base.top,
    // Unten die *ganze* Hoehe und nicht nur die Ueberlappung: das Tierchen
    // steht dort fest, waehrend die Liste hinter ihm durchlaeuft. Reserviert
    // man nur einen Teil, bleibt am Ende der Liste Inhalt hinter ihm liegen
    // – im Kalender verschwanden so die Kaestchen zweier Aufgaben hinter
    // einer Katze.
    bottom: spot.isTop ? base.bottom : math.max(base.bottom, height + 8),
  );
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
    final overdue = showOverdue &&
        !task.isRecurring &&
        !done &&
        (task.priority == Priority.niedrig ||
            dateOnly(task.startDate).isBefore(today()));
    final semanticParts = <String>[
      task.title,
      if (task.isRecurring) task.recurrenceLabel,
      if (overdue) 'Offen seit ${formatDate(task.startDate)}',
      if (task.priority != Priority.mittel) 'Priorität ${task.priority.label}',
    ];
    return Semantics(
      container: true,
      button: true,
      checked: done,
      label: semanticParts.join(', '),
      onTap: () => state.toggleTask(task, day),
      onLongPress: () => showTaskOptions(context, task),
      excludeSemantics: true,
      child: InkWell(
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
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: theme.bestOn(task.color),
                      )
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
      ),
    );
  }
}

/// Rueckfrage vor dem Loeschen – liefert nur die Entscheidung, loescht
/// nichts selbst. Jeder Loeschweg der App fragt hierueber nach: es gibt
/// kein Undo, ein verrutschter Tipper waere sonst endgueltig.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String subject,
}) async {
  final theme = joeThemeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: theme.paper,
      title: Text(title, style: TextStyle(color: theme.ink)),
      content: Text(subject, style: TextStyle(color: theme.inkSoft)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Abbrechen', style: TextStyle(color: theme.ink)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Löschen', style: TextStyle(color: theme.accent)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// showModalBottomSheet im Joe-Gewand: Papierfarbe, oben gerundet.
///
/// [expand] ist fuer Blaetter, die mit Tastatur oder Hoehenbegrenzung
/// arbeiten: isScrollControlled hebt die Halbe-Hoehe-Grenze auf, und
/// useSafeArea haelt das Blatt unter der Statusleiste – ohne das nimmt
/// showModalBottomSheet padding.top heraus und der Titel rutscht bei
/// offener Tastatur hinter die Uhr.
Future<void> showJoeSheet(
  BuildContext context, {
  bool expand = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: expand,
    useSafeArea: expand,
    backgroundColor: joeThemeOf(context).paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}

void showTaskOptions(BuildContext context, Task task) {
  final state = AppScope.of(context);
  final theme = joeThemeOf(context);
  showJoeSheet(
    context,
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
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await confirmDelete(
                context,
                title: 'Aufgabe löschen?',
                subject: task.title,
              );
              if (confirmed) state.deleteTask(task);
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

/// Holt vor der ersten Erinnerung die Benachrichtigungs-Berechtigung ein
/// und sagt, ob die Erinnerung gesetzt werden darf. Ohne sie kaeme nichts
/// an – das stumm hinzunehmen waere das Schlimmste, was die App hier tun
/// koennte; die Absage samt Weg in die System-Einstellungen meldet
/// [JoeReminders.ensurePermission] selbst als Toast.
Future<bool> confirmReminderPermission() =>
    JoeReminders.instance.ensurePermission();

/// Die Erinnerung eines Termins: eine Klappliste mit den Vorlaufzeiten,
/// von "Keine" bis "1 Tag vorher".
class ReminderLeadPicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;

  const ReminderLeadPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.inkSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: reminderLeadChoices.contains(selected) ? selected : null,
          isExpanded: true,
          dropdownColor: theme.paper,
          borderRadius: BorderRadius.circular(14),
          iconEnabledColor: theme.ink,
          items: [
            for (final choice in reminderLeadChoices)
              DropdownMenuItem<int?>(
                value: choice,
                child: Row(
                  children: [
                    Icon(
                      choice == null
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_active_outlined,
                      size: 18,
                      color: choice == null ? theme.inkSoft : theme.accent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      reminderLeadLabel(choice),
                      style: TextStyle(color: theme.ink, fontSize: 15),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (value) async {
            // Erst fragen, dann setzen: eine Erinnerung, die nie ankaeme,
            // soll gar nicht erst im Blatt stehen.
            if (value != null && !await confirmReminderPermission()) return;
            onChanged(value);
          },
        ),
      ),
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
                          fontWeight:
                              p == selected ? FontWeight.w700 : FontWeight.w500,
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

/// Traegt Zustand *und* Titel-Controller eines Eingabeblatts, solange das
/// Blatt im Baum steht.
///
/// Warum nicht `StatefulBuilder` plus `whenComplete(controller.dispose)`:
/// `Navigator.pop` schliesst den Future der Route sofort, das Blatt animiert
/// danach aber noch heraus. Der Controller waere dann schon weg, waehrend das
/// `TextField` ihn noch liest – "A TextEditingController was used after being
/// disposed", und im Anschluss faellt der Abbau des Elementbaums mit
/// '_dependents.isEmpty' auf den roten Bildschirm. Ein eigener State raeumt
/// erst auf, wenn das Blatt wirklich aus dem Baum ist.
class SheetHost extends StatefulWidget {
  final String initialText;
  final Widget Function(
    BuildContext context,
    TextEditingController controller,
    StateSetter setSheetState,
  )
  builder;

  const SheetHost({
    super.key,
    required this.initialText,
    required this.builder,
  });

  @override
  State<SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<SheetHost> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller, setState);
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

/// Das Titelfeld, mit dem beide Eingabeblaetter beginnen.
class SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  const SheetTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: TextStyle(color: theme.ink),
      decoration: InputDecoration(
        hintText: hint,
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
  var recurrence = task?.recurrence ?? RecurrenceType.none;
  var intervalDays = task?.intervalDays ?? 2;
  var colorIndex = task?.colorIndex ?? 0;
  var priority = task?.priority ?? Priority.mittel;
  var date = task != null ? dateOnly(task.startDate) : (initialDate ?? today());
  // Aufgaben haben keine Uhrzeit, die Erinnerung bringt ihre eigene mit.
  var reminderMinute = task?.reminderMinuteOfDay;

  void save(BuildContext sheetContext, TextEditingController titleController) {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      JoeToast.error('Bitte gib einen Titel ein.');
      return;
    }
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
          reminderMinuteOfDay: reminderMinute,
        ),
      );
    } else {
      task.title = title;
      task.recurrence = recurrence;
      task.intervalDays = intervalDays;
      task.startDate = date;
      task.colorIndex = colorIndex;
      task.priority = priority;
      task.reminderMinuteOfDay = reminderMinute;
      state.updateTask(task);
    }
    Navigator.pop(sheetContext);
  }

  return showJoeSheet(
    context,
    expand: true,
    builder: (sheetContext) => SheetHost(
      initialText: task?.title ?? '',
      builder: (sheetContext, titleController, setSheetState) => SheetFrame(
        title: task == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten',
        footer: SheetSaveButton(
          onPressed: () => save(sheetContext, titleController),
        ),
        children: [
          SheetTextField(
            controller: titleController,
            hint: 'Was ist zu tun?',
            autofocus: task == null,
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
                      () => intervalDays =
                          intervalDays > 2 ? intervalDays - 1 : 2,
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
          const SheetLabel('Erinnerung'),
          // Die Uhrzeit gilt am Faelligkeitstag; bei einer wiederkehrenden
          // Aufgabe also an jedem ihrer Tage.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    reminderMinute == null
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    size: 18,
                    color:
                        reminderMinute == null ? theme.inkSoft : theme.accent,
                  ),
                  label: Text(
                    reminderTimeLabel(reminderMinute),
                    style: TextStyle(color: theme.ink),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: sheetContext,
                      initialTime: reminderMinute == null
                          ? const TimeOfDay(hour: 9, minute: 0)
                          : TimeOfDay(
                              hour: reminderMinute! ~/ 60,
                              minute: reminderMinute! % 60,
                            ),
                    );
                    if (picked == null) return;
                    if (!await confirmReminderPermission()) return;
                    if (!sheetContext.mounted) return;
                    setSheetState(
                      () => reminderMinute = picked.hour * 60 + picked.minute,
                    );
                  },
                ),
              ),
              if (reminderMinute != null)
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: theme.inkSoft),
                  tooltip: 'Erinnerung entfernen',
                  onPressed: () => setSheetState(() => reminderMinute = null),
                ),
            ],
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
  var date = appointment != null
      ? dateOnly(appointment.when)
      : (initialDate ?? today());
  var time = appointment != null
      ? TimeOfDay.fromDateTime(appointment.when)
      : const TimeOfDay(hour: 12, minute: 0);
  var colorIndex = appointment?.colorIndex ?? 4;
  var priority = appointment?.priority ?? Priority.mittel;
  // Ein neuer Termin startet mit dem Standard aus den Einstellungen; ein
  // bestehender behaelt, was an ihm steht – auch die bewusste Null.
  var lead = appointment != null
      ? appointment.reminderLeadMinutes
      : state.defaultAppointmentLead;

  void save(BuildContext sheetContext, TextEditingController titleController) {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      JoeToast.error('Bitte gib einen Titel ein.');
      return;
    }
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
          reminderLeadMinutes: lead,
        ),
      );
    } else {
      appointment.title = title;
      appointment.when = when;
      appointment.colorIndex = colorIndex;
      appointment.priority = priority;
      appointment.reminderLeadMinutes = lead;
      state.updateAppointment(appointment);
    }
    Navigator.pop(sheetContext);
  }

  return showJoeSheet(
    context,
    expand: true,
    builder: (sheetContext) => SheetHost(
      initialText: appointment?.title ?? '',
      builder: (sheetContext, titleController, setSheetState) => SheetFrame(
        title: appointment == null ? 'Neuer Termin' : 'Termin bearbeiten',
        footer: SheetSaveButton(
          onPressed: () => save(sheetContext, titleController),
        ),
        children: [
          SheetTextField(
            controller: titleController,
            hint: 'Worum geht es?',
            autofocus: appointment == null,
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
          const SheetLabel('Erinnerung'),
          ReminderLeadPicker(
            selected: lead,
            onChanged: (value) => setSheetState(() => lead = value),
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
  showJoeSheet(
    context,
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
