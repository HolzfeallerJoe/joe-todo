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
              scale: state.petScale,
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

  /// Groesse aus dem Regler in den Einstellungen (siehe [petBox]).
  final double scale;

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
    required this.scale,
    required this.contentTop,
    required this.hasFab,
    required this.scrolled,
  });

  @override
  Widget build(BuildContext context) {
    final box = petBox(pet, spot, scale: scale);
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
  final height = petBox(state.pet, spot, scale: state.petScale).height;
  final overlap = petOverlap(state.pet, spot, page, scale: state.petScale);
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

/// Die Kopfzeile der Heute-Karte: beide Zahlen des Tages in zwei Zeilen.
///
///     3 offene Aufgaben
///     2 Termine heute
///
/// Aufgaben und Termine beantworten dieselbe Frage, also stehen sie in einer
/// Kopfzeile – "heute" steht nur einmal, hinten: zwei Zeilen eines Gedankens,
/// keine zwei Aussagen. Die Zahlen stehen als eigene Spalte rechtsbuendig
/// untereinander (Ziffern gleicher Breite), damit man sie auf einen Blick
/// vergleicht und die Woerter auf derselben Kante beginnen, auch bei "12"
/// ueber "3".
///
/// Eine [Table] statt fester Zeilen, weil die Wortspalte flexibel ist: bei
/// grosser Systemschrift bricht ein Wort innerhalb seiner Zeile um, statt
/// ueber den Kartenrand zu laufen – der Grund fuer den frueheren Fliesstext.
///
/// Die Vorlesehilfe bekommt trotzdem den ganzen Satz mit "und": zwei Zeilen
/// ohne Bindewort klaengen vorgelesen abgehackt.
class TodayHeadline extends StatelessWidget {
  final int tasks;
  final int appointments;

  const TodayHeadline({
    super.key,
    required this.tasks,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final number = TextStyle(
      color: theme.accent,
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w800,
      // Gleich breite Ziffern: sonst stuende eine "1" rechtsbuendig zwar
      // an derselben Kante, wirkte aber schmaler als die "3" darunter.
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final word = TextStyle(
      color: theme.ink,
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );

    TableRow row(int count, String words) => TableRow(
          children: [
            Text('$count', style: number, textAlign: TextAlign.right),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(words, style: word),
            ),
          ],
        );

    return Semantics(
      container: true,
      label: '$tasks ${tasks == 1 ? 'offene Aufgabe' : 'offene Aufgaben'} '
          'und $appointments ${appointments == 1 ? 'Termin' : 'Termine'} heute',
      excludeSemantics: true,
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        // Grosse Zahl und kleineres Wort sitzen auf einer Grundlinie.
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          row(tasks, tasks == 1 ? 'offene Aufgabe' : 'offene Aufgaben'),
          row(appointments,
              appointments == 1 ? 'Termin heute' : 'Termine heute'),
        ],
      ),
    );
  }
}

/// Der Strich zwischen der Zahl und dem Ausklappmenue darunter.
class FoldDivider extends StatelessWidget {
  const FoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Divider(
        height: 1,
        color: theme.inkSoft.withValues(alpha: 0.25),
      ),
    );
  }
}

/// Das Ausklappmenue unter einer [CountHeadline]: eine antippbare Zeile mit
/// Titel, Anzahl und Pfeil, darunter der Inhalt.
///
/// Zugeklappt bleibt der Inhalt im Baum, wird aber nicht angezeigt und nimmt
/// keine Tipps mehr an (das erledigt [AnimatedCrossFade]) – so bleibt die
/// Hoehenanimation weich, ohne dass man versehentlich etwas Unsichtbares
/// abhakt. Ob es offen steht, merkt sich der [AppState]: das Dashboard soll
/// so wiederkommen, wie man es verlassen hat.
class FoldSection extends StatelessWidget {
  final String title;
  final int count;
  final String unitSingular;
  final String unitPlural;
  final bool open;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const FoldSection({
    super.key,
    required this.title,
    required this.count,
    required this.unitSingular,
    required this.unitPlural,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: open,
          label: '$title, $count ${count == 1 ? unitSingular : unitPlural}',
          onTap: () => onToggle(!open),
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onToggle(!open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(color: theme.inkSoft, fontSize: 13),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: theme.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOut,
          crossFadeState:
              open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Die Hinweiszeile, wenn die Geraete-Kalender-Ebene nicht laden konnte.
/// Sie steht so lange, wie das Problem besteht – und bietet den einen
/// Handgriff an, der weiterhilft: den Weg in die System-Einstellungen, wenn
/// die Berechtigung fehlt, sonst einen zweiten Versuch.
///
/// Sie steht an beiden Stellen, an denen Geraete-Termine auftauchen: im
/// Kalender als eigene Karte ([card]) und im Termin-Block des Dashboards als
/// blosse Zeile, weil sie dort schon in einer Karte sitzt.
class DeviceCalendarNotice extends StatelessWidget {
  final String message;
  final bool permissionMissing;
  final bool card;

  const DeviceCalendarNotice({
    super.key,
    required this.message,
    required this.permissionMissing,
    this.card = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final feed = DeviceCalendarFeed.instance;
    final row = Row(
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
          onPressed: permissionMissing ? feed.openSystemSettings : feed.retry,
          child: Text(
            permissionMissing ? 'Einstellungen' : 'Erneut',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    if (!card) return row;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: row,
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

/// Die Spanne der Wiederholung von [task], die [day] abdeckt: mit Uhrzeit
/// "12:00 – 18:00 Uhr" bzw. "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00", ohne
/// Uhrzeit nur die Tage ("14. September – 17. September"). Liegt [day] in
/// keiner Wiederholung (eine liegengebliebene Aufgabe), gilt die erste.
String taskSpanLabel(Task task, DateTime day) {
  final start = task.occurrenceStartFor(day) ?? dateOnly(task.startDate);
  if (task.startMinute == null) {
    return '${formatDate(start)} – '
        '${formatDate(addCalendarDays(start, task.spanDays))}';
  }
  final span = task.spanOf(start);
  return formatSpan(span.start, span.end);
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
    // Ueberfaellig ist eine Aufgabe mit Dauer erst nach ihrem letzten Tag.
    final overdue = showOverdue &&
        !task.isRecurring &&
        !done &&
        (task.priority == Priority.niedrig || task.lastDay.isBefore(today()));
    final span = task.hasDuration ? taskSpanLabel(task, day) : null;
    final semanticParts = <String>[
      task.title,
      if (task.isRecurring) task.recurrenceLabel,
      ?span,
      if (overdue) 'Offen seit ${formatDate(task.lastDay)}',
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
                    if (task.isRecurring || span != null || overdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        // Wrap statt Row: mit der Spanne sind es bis zu drei
                        // Angaben, die liefen auf einem schmalen Telefon
                        // ueber den Rand.
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (task.isRecurring)
                              Text(
                                '🔁 ${task.recurrenceLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.inkSoft,
                                ),
                              ),
                            if (span != null)
                              Text(
                                span,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.inkSoft,
                                ),
                              ),
                            if (overdue)
                              Text(
                                'offen seit ${formatDate(task.lastDay)}',
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
///
/// Sie kommt als Karte von unten, im unteren Drittel des Bildschirms: dort
/// ist der Daumen, und dort stehen in dieser App ohnehin alle Rueckfragen
/// (Eingabeblaetter, das Bearbeiten/Loeschen-Blatt). Ein Dialog mitten auf
/// dem Bild war der einzige Ort, an dem Joe anders gefragt hat.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String subject,
}) async {
  final confirmed = await showJoeSheet<bool>(
    context,
    expand: true,
    builder: (sheetContext) => _DeleteCard(title: title, subject: subject),
  );
  return confirmed ?? false;
}

/// Die Loeschkarte selbst: Zeichen, Frage, Gegenstand, dann die beiden
/// Knoepfe. Sie fuellt mindestens das untere Drittel – kuerzer waere sie ein
/// Streifen, in dem "Löschen" direkt unter dem Daumen laege, der eben noch
/// lange gedrueckt hat.
class _DeleteCard extends StatelessWidget {
  final String title;
  final String subject;

  const _DeleteCard({required this.title, required this.subject});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height / 3,
        ),
        // mainAxisSize.min mit einer Mindesthoehe: die Karte ist so hoch wie
        // das Drittel, und was uebrig bleibt, verteilt spaceBetween zwischen
        // Frage und Knoepfen. Ein langer Titel macht sie laenger, statt zu
        // ueberlaufen.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 18),
                    decoration: BoxDecoration(
                      color: theme.inkSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 30,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    subject,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.inkSoft, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Das lässt sich nicht rückgängig machen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.inkSoft, fontSize: 13),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.ink,
                        side: BorderSide(color: theme.inkSoft),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Abbrechen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Löschen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

/// showModalBottomSheet im Joe-Gewand: Papierfarbe, oben gerundet.
///
/// [expand] ist fuer Blaetter, die mit Tastatur oder Hoehenbegrenzung
/// arbeiten: isScrollControlled hebt die Halbe-Hoehe-Grenze auf, und
/// useSafeArea haelt das Blatt unter der Statusleiste – ohne das nimmt
/// showModalBottomSheet padding.top heraus und der Titel rutscht bei
/// offener Tastatur hinter die Uhr.
Future<T?> showJoeSheet<T>(
  BuildContext context, {
  bool expand = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
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

/// Ein Blatt von unten, das nach einem einzelnen Text fragt – zum Beispiel
/// nach dem Namen eines eigenen Symptoms. Gibt den Text zurueck, oder null,
/// wenn abgebrochen wurde.
Future<String?> showTextEntrySheet(
  BuildContext context, {
  required String title,
  required String hint,
  String initialText = '',
}) {
  return showJoeSheet<String>(
    context,
    expand: true,
    builder: (sheetContext) => SheetHost(
      initialText: initialText,
      builder: (sheetContext, controller, setSheetState) => SheetFrame(
        title: title,
        footer: SheetSaveButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              JoeToast.error('Bitte gib einen Namen ein.');
              return;
            }
            Navigator.pop(sheetContext, text);
          },
        ),
        children: [
          SheetTextField(
            controller: controller,
            hint: hint,
            autofocus: true,
          ),
        ],
      ),
    ),
  );
}

/// Das Blatt hinter dem langen Druck – fuer Aufgaben, Termine und Notizen
/// dasselbe: Bearbeiten oben, Loeschen darunter, und die Rueckfrage vor dem
/// Loeschen ([confirmDelete]) gehoert dazu.
///
/// Vorher hatte jede der drei Arten ihren eigenen Weg: die Aufgabe dieses
/// Blatt, der Termin loeschte auf langen Druck sofort nach einer Rueckfrage,
/// die Notiz nur ueber den Papierkorb im Editor. Jetzt fuehrt ueberall
/// derselbe Griff zum selben Blatt.
void showEntryOptions(
  BuildContext context, {
  required String deleteTitle,
  required String subject,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
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
              onEdit();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.accent),
            title: Text('Löschen', style: TextStyle(color: theme.accent)),
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await confirmDelete(
                context,
                title: deleteTitle,
                subject: subject,
              );
              if (confirmed) onDelete();
            },
          ),
        ],
      ),
    ),
  );
}

void showTaskOptions(BuildContext context, Task task) {
  final state = AppScope.of(context);
  showEntryOptions(
    context,
    deleteTitle: 'Aufgabe löschen?',
    subject: task.title,
    onEdit: () => showTaskSheet(context, task: task),
    onDelete: () => state.deleteTask(task),
  );
}

void showAppointmentOptions(BuildContext context, Appointment appointment) {
  final state = AppScope.of(context);
  showEntryOptions(
    context,
    deleteTitle: 'Termin löschen?',
    subject: appointment.title,
    onEdit: () => showAppointmentSheet(context, appointment: appointment),
    onDelete: () => state.deleteAppointment(appointment),
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

/// Die Wochenskala im Aufgabenblatt: sieben runde Umschalter Mo bis So.
/// Markierte Tage heissen "woechentlich an genau diesen Tagen", alle sieben
/// heisst taeglich (siehe [allWeekdays]).
///
/// Dieselbe Formensprache wie [PriorityPicker]: gewaehlt ist gefuellt in der
/// Akzentfarbe, offen nur ein zarter Rand.
class WeekdayPicker extends StatelessWidget {
  /// 1 = Montag wie bei [DateTime.weekday].
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Row(
      children: [
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Semantics(
              label: weekdayNames[day - 1],
              selected: selected.contains(day),
              button: true,
              excludeSemantics: true,
              onTap: () => onToggle(day),
              child: InkResponse(
                onTap: () => onToggle(day),
                radius: 24,
                // Mindestens 40 px Tippflaeche – auf einem schmalen Telefon
                // bleiben je Tag gut 45 px Breite, das reicht.
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected.contains(day)
                            ? theme.accent
                            : Colors.transparent,
                        border: Border.all(
                          color: selected.contains(day)
                              ? theme.accent
                              : theme.inkSoft.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        weekdayNamesShort[day - 1],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected.contains(day)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected.contains(day)
                              ? theme.bestOn(theme.accent)
                              : theme.ink,
                        ),
                      ),
                    ),
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

/// Die Uhrzeiten, mit denen die Dauer einer Aufgabe beim Einschalten
/// beginnt: ein Nachmittag, 12:00 bis 18:00.
const _defaultStartMinute = 12 * 60;
const _defaultEndMinute = 18 * 60;

/// "Mo, 14. Sep" – kurz genug fuer einen Knopf neben der Uhrzeit.
String _shortDay(DateTime d) => '${weekdayNamesShort[d.weekday - 1]}, '
    '${d.day}. ${monthNamesShort[d.month - 1]}';

/// Minuten seit Mitternacht als "12:00".
String _hm(int minute) => '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  return picked == null ? null : dateOnly(picked);
}

Future<int?> _pickMinute(BuildContext context, int initial) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

/// Ein Knopf im Blatt, der Datum oder Uhrzeit zeigt und beim Tippen den
/// passenden Waehler oeffnet – dieselbe Form wie im Terminblatt.
class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PickButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18, color: theme.ink),
      label: Text(label, style: TextStyle(color: theme.ink)),
      onPressed: onPressed,
    );
  }
}

/// Die Zeile "Dauer" mit ihrem Schalter, in beiden Blaettern. Ein
/// Zeitpunkt bleibt der Normalfall, deshalb steht sie anfangs aus.
class _DurationSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DurationSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    // Vorgelesen als ein Knoten: "Dauer, Schalter, aus".
    return MergeSemantics(
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, size: 20, color: theme.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dauer',
              style: TextStyle(color: theme.ink, fontSize: 15),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: theme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Eine Zeile "Von"/"Bis" der Dauer einer einmaligen Aufgabe: Datum und
/// Uhrzeit nebeneinander.
class _SpanRow extends StatelessWidget {
  final String label;
  final Key dateKey;
  final Key timeKey;
  final DateTime day;
  final int minute;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<int> onMinute;

  const _SpanRow({
    required this.label,
    required this.dateKey,
    required this.timeKey,
    required this.day,
    required this.minute,
    required this.onDay,
    required this.onMinute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: TextStyle(color: theme.inkSoft)),
          ),
          Expanded(
            flex: 3,
            child: _PickButton(
              key: dateKey,
              icon: Icons.event_outlined,
              label: _shortDay(day),
              onPressed: () async {
                final picked = await _pickDate(context, day);
                if (picked != null) onDay(picked);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _PickButton(
              key: timeKey,
              icon: Icons.schedule,
              label: _hm(minute),
              onPressed: () async {
                final picked = await _pickMinute(context, minute);
                if (picked != null) onMinute(picked);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Dauer einer wiederkehrenden Aufgabe. Ein Enddatum gaebe es nur fuer
/// die erste Wiederholung, und die faellt bei der Wochenskala nicht
/// zwingend auf das "Ab"-Datum – deshalb zaehlt hier ein Abstand in Tagen
/// ab jedem Wiederholungstag.
///
/// Der Zaehler hoert bei [maxSpanDays] auf: laenger, und die naechste
/// Wiederholung finge an, bevor diese vorbei ist (siehe [Task.maxSpanDays]).
class _RecurringSpanEditor extends StatelessWidget {
  final int spanDays;
  final int maxSpanDays;
  final int startMinute;
  final int endMinute;
  final ValueChanged<int> onSpanDays;
  final ValueChanged<int> onStartMinute;
  final ValueChanged<int> onEndMinute;

  const _RecurringSpanEditor({
    required this.spanDays,
    required this.maxSpanDays,
    required this.startMinute,
    required this.endMinute,
    required this.onSpanDays,
    required this.onStartMinute,
    required this.onEndMinute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final ink = TextStyle(color: theme.ink);
    final spanLabel = switch (spanDays) {
      0 => 'am selben Tag',
      1 => '+1 Tag',
      _ => '+$spanDays Tage',
    };
    // Wrap statt Row: auf einem schmalen Telefon rutscht die Uhrzeit in die
    // naechste Zeile, statt ueber den Rand zu laufen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Beginn', style: TextStyle(color: theme.inkSoft)),
            Text('an jedem Wiederholungstag um', style: ink),
            _PickButton(
              key: const ValueKey('task-start-time'),
              icon: Icons.schedule,
              label: _hm(startMinute),
              onPressed: () async {
                final picked = await _pickMinute(context, startMinute);
                if (picked != null) onStartMinute(picked);
              },
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Ende', style: TextStyle(color: theme.inkSoft)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: theme.ink),
                  tooltip: 'Einen Tag kürzer',
                  onPressed:
                      spanDays > 0 ? () => onSpanDays(spanDays - 1) : null,
                ),
                Text(
                  spanLabel,
                  style: ink.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: theme.ink),
                  tooltip: 'Einen Tag länger',
                  onPressed: spanDays < maxSpanDays
                      ? () => onSpanDays(spanDays + 1)
                      : null,
                ),
              ],
            ),
            Text('um', style: ink),
            _PickButton(
              key: const ValueKey('task-end-time'),
              icon: Icons.schedule,
              label: _hm(endMinute),
              onPressed: () async {
                final picked = await _pickMinute(context, endMinute);
                if (picked != null) onEndMinute(picked);
              },
            ),
          ],
        ),
        if (spanDays >= maxSpanDays)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(
              spanDays > maxSpanDays
                  ? 'Zu lang: die nächste Wiederholung finge vorher an.'
                  : 'Länger würde die nächste Wiederholung überlappen.',
              style: TextStyle(color: theme.inkSoft, fontSize: 12),
            ),
          ),
      ],
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
  // Genau eins ist aktiv: ein Chip (Einmalig, Monatlich, …) oder mindestens
  // ein Tag der Wochenskala – dann ist die Aufgabe woechentlich.
  var weekdays = task != null && task.recurrence == RecurrenceType.weekly
      ? {...task.weekdays}
      : <int>{};
  var intervalDays = task?.intervalDays ?? 2;
  var colorIndex = task?.colorIndex ?? 0;
  var priority = task?.priority ?? Priority.mittel;
  var date = task != null ? dateOnly(task.startDate) : (initialDate ?? today());
  // Aufgaben haben keine Uhrzeit, die Erinnerung bringt ihre eigene mit.
  var reminderMinute = task?.reminderMinuteOfDay;
  // Die Dauer ist optional (Schalter "Dauer"). Eine Zahl fuer beide Arten:
  // bei einer einmaligen Aufgabe ist das Enddatum [date] + [spanDays] – so
  // wandert das Ende mit, wenn man den Anfang verschiebt, und die Dauer
  // bleibt. Bei einer wiederkehrenden steuert der Zaehler sie direkt.
  var withDuration = task?.hasDuration ?? false;
  var spanDays = task?.spanDays ?? 0;
  var startMinute = task?.startMinute ?? _defaultStartMinute;
  var endMinute = task?.endMinute ?? _defaultEndMinute;

  void save(BuildContext sheetContext, TextEditingController titleController) {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      JoeToast.error('Bitte gib einen Titel ein.');
      return;
    }
    if (withDuration) {
      // Ende nicht nach dem Anfang: bei einmaligen ein Enddatum vor dem
      // Start oder am selben Tag zu frueh, bei wiederkehrenden nur Letzteres.
      if (spanDays < 0 || (spanDays == 0 && endMinute <= startMinute)) {
        JoeToast.error('Das Ende liegt vor dem Anfang.');
        return;
      }
      // Wer die Wiederholung nach der Dauer umstellt (etwa auf Mo+Mi bei
      // drei Tagen Dauer), bekaeme sich ueberlappende Wiederholungen – dann
      // waere unklar, welche man abhakt.
      if (recurrence != RecurrenceType.none &&
          spanDays > Task.maxSpanDays(recurrence, weekdays, intervalDays)) {
        JoeToast.error(
          'Die Dauer ist länger als der Abstand zwischen zwei Wiederholungen.',
        );
        return;
      }
      // Laenger nimmt das Modell beim Laden nicht an.
      if (spanDays > Task.maxStoredSpanDays) {
        JoeToast.error('Eine Aufgabe kann höchstens ein Jahr dauern.');
        return;
      }
    }
    final days =
        recurrence == RecurrenceType.weekly ? {...weekdays} : <int>{};
    final span = withDuration ? spanDays : 0;
    final from = withDuration ? startMinute : null;
    final to = withDuration ? endMinute : null;
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
          weekdays: days,
          spanDays: span,
          startMinute: from,
          endMinute: to,
        ),
      );
    } else {
      task.title = title;
      task.recurrence = recurrence;
      task.weekdays = days;
      task.intervalDays = intervalDays;
      task.startDate = date;
      task.spanDays = span;
      task.startMinute = from;
      task.endMinute = to;
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
          // "Woechentlich" ist kein Chip: das macht die Wochenskala darunter.
          // Ein Chip loescht die markierten Tage, ein Tag nimmt dem Chip die
          // Markierung – so ist immer genau eine Wahl sichtbar.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (r, label) in const [
                (RecurrenceType.none, 'Einmalig'),
                (RecurrenceType.monthly, 'Monatlich'),
                (RecurrenceType.yearly, 'Jährlich'),
                (RecurrenceType.everyXDays, 'Alle X Tage'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: recurrence == r,
                  selectedColor: theme.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(color: theme.ink),
                  onSelected: (_) => setSheetState(() {
                    recurrence = r;
                    weekdays = {};
                  }),
                ),
            ],
          ),
          if (recurrence == RecurrenceType.monthly ||
              recurrence == RecurrenceType.yearly)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                recurrence == RecurrenceType.monthly
                    ? 'am ${date.day}. jedes Monats'
                        // Wie im Modell: Monate ohne diesen Tag fallen aus.
                        '${date.day > 28 ? ' (Monate ohne den ${date.day}. fallen aus)' : ''}'
                    : 'jedes Jahr am ${formatDate(date)}'
                        '${date.month == 2 && date.day == 29 ? ' (sonst am 28.)' : ''}',
                style: TextStyle(color: theme.inkSoft, fontSize: 13),
              ),
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
          const SizedBox(height: 10),
          const SheetLabel('Wöchentlich an'),
          WeekdayPicker(
            selected: recurrence == RecurrenceType.weekly ? weekdays : const {},
            onToggle: (day) => setSheetState(() {
              if (recurrence != RecurrenceType.weekly) {
                recurrence = RecurrenceType.weekly;
                weekdays = {day};
              } else if (!weekdays.remove(day)) {
                weekdays.add(day);
              } else if (weekdays.isEmpty) {
                // Kein Tag markiert heisst keine Wochenwiederholung.
                recurrence = RecurrenceType.none;
              }
            }),
          ),
          const SizedBox(height: 6),
          // Mit Dauer ersetzt bei einer einmaligen Aufgabe die Von-Zeile das
          // Datum; eine wiederkehrende behaelt ihr "Ab".
          if (!withDuration || recurrence != RecurrenceType.none)
            InkWell(
              onTap: () async {
                final picked = await _pickDate(sheetContext, date);
                if (picked != null) setSheetState(() => date = picked);
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
          _DurationSwitch(
            value: withDuration,
            onChanged: (on) => setSheetState(() => withDuration = on),
          ),
          if (withDuration && recurrence == RecurrenceType.none) ...[
            _SpanRow(
              label: 'Von',
              dateKey: const ValueKey('task-start-date'),
              timeKey: const ValueKey('task-start-time'),
              day: date,
              minute: startMinute,
              // Das Enddatum haengt als Abstand am Anfang: es wandert mit,
              // die Dauer bleibt.
              onDay: (d) => setSheetState(() => date = d),
              onMinute: (m) => setSheetState(() => startMinute = m),
            ),
            _SpanRow(
              label: 'Bis',
              dateKey: const ValueKey('task-end-date'),
              timeKey: const ValueKey('task-end-time'),
              day: addCalendarDays(date, spanDays),
              minute: endMinute,
              onDay: (d) =>
                  setSheetState(() => spanDays = calendarDaysBetween(date, d)),
              onMinute: (m) => setSheetState(() => endMinute = m),
            ),
          ],
          if (withDuration && recurrence != RecurrenceType.none)
            _RecurringSpanEditor(
              spanDays: spanDays,
              maxSpanDays:
                  Task.maxSpanDays(recurrence, weekdays, intervalDays),
              startMinute: startMinute,
              endMinute: endMinute,
              onSpanDays: (n) => setSheetState(() => spanDays = n),
              onStartMinute: (m) => setSheetState(() => startMinute = m),
              onEndMinute: (m) => setSheetState(() => endMinute = m),
            ),
          const SizedBox(height: 10),
          const SheetLabel('Erinnerung'),
          // Die Uhrzeit gilt am Faelligkeitstag; bei einer wiederkehrenden
          // Aufgabe also an jedem ihrer Tage. Mit Dauer nur am ersten Tag der
          // Spanne – sonst kaeme dieselbe Erinnerung mehrmals.
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

  DateTime start() =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  // Die Dauer ist optional; ein neuer Termin ist weiter ein Zeitpunkt. Ein
  // bestehender mit Ende oeffnet mit eingeschaltetem Schalter.
  var withEnd = appointment?.end != null;
  var end = appointment?.end ?? start().add(const Duration(hours: 1));

  /// Start-Datum oder -Uhrzeit aendern: das Ende wandert mit, die Dauer
  /// bleibt – wer einen Termin verschiebt, verschiebt ihn ganz.
  void moveStart(void Function() change) {
    final before = start();
    change();
    end = end.add(start().difference(before));
  }

  void save(BuildContext sheetContext, TextEditingController titleController) {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      JoeToast.error('Bitte gib einen Titel ein.');
      return;
    }
    final when = start();
    if (withEnd && !end.isAfter(when)) {
      JoeToast.error('Das Ende liegt vor dem Anfang.');
      return;
    }
    if (appointment == null) {
      state.addAppointment(
        Appointment(
          id: state.nextId(),
          title: title,
          when: when,
          end: withEnd ? end : null,
          colorIndex: colorIndex,
          priority: priority,
          reminderLeadMinutes: lead,
        ),
      );
    } else {
      appointment.title = title;
      appointment.when = when;
      appointment.end = withEnd ? end : null;
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
                      setSheetState(
                        () => moveStart(() => date = dateOnly(picked)),
                      );
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
                    if (picked != null) {
                      setSheetState(() => moveStart(() => time = picked));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _DurationSwitch(
            value: withEnd,
            onChanged: (on) => setSheetState(() {
              withEnd = on;
              // Eingeschaltet beginnt die Dauer bei einer Stunde.
              if (on) end = start().add(const Duration(hours: 1));
            }),
          ),
          if (withEnd)
            _SpanRow(
              label: 'Bis',
              dateKey: const ValueKey('appointment-end-date'),
              timeKey: const ValueKey('appointment-end-time'),
              day: dateOnly(end),
              minute: end.hour * 60 + end.minute,
              onDay: (d) => setSheetState(
                () => end = DateTime(d.year, d.month, d.day, end.hour,
                    end.minute),
              ),
              onMinute: (m) => setSheetState(
                () => end = DateTime(end.year, end.month, end.day, 0, m),
              ),
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
