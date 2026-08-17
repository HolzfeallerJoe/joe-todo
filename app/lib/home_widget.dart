import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'almanac.dart';
import 'log.dart';
import 'models.dart';
import 'theme.dart';
import 'util.dart';

/// Der Schnappschuss fuer die Startbildschirm-Widgets.
///
/// Die Widgets sind reines Android (RemoteViews) und laufen ohne Flutter:
/// wenn das Telefon sie zeichnet, ist die App fast immer tot. Sie koennen
/// deshalb nichts ausrechnen – kein Wiederholungsmuster, keinen Feiertag,
/// keine Sortierung nach Prioritaet. Was sie zeigen, rechnet die App im
/// Voraus und legt es als JSON neben die Widgets; dort sucht sich das Widget
/// nur noch den Tag heraus, den die Uhr des Telefons gerade zeigt.
///
/// Deshalb ist der Schnappschuss **nach Tagen** geordnet und nicht nach
/// "heute": um Mitternacht wechselt der Tag, und um Mitternacht laeuft die
/// App nicht. Ein Schnappschuss mit einer fertigen Heute-Liste waere jeden
/// Morgen falsch, bis jemand die App oeffnet.

/// Wie weit voraus die Tage gerechnet werden.
///
/// Genug, dass ein Widget auch nach Wochen ohne App-Start noch stimmt, und
/// wenig genug, dass der Schnappschuss klein bleibt. Wer die App laenger
/// nicht oeffnet, sieht danach den Hinweis statt falscher Eintraege.
const widgetHorizonDays = 45;

/// Wie viele Eintraege ein Tag hoechstens mitbringt. Mehr passt in kein
/// Widget; die volle Zahl steht als `taskCount`/`appointmentCount` daneben,
/// damit die letzte Zeile "+3 weitere" sagen kann.
const widgetEntriesPerDay = 12;

/// Die Fassung des Formats. Kotlin liest nur, was es kennt – ein aelteres
/// Widget nach einem App-Update zeigt lieber den Hinweis als Unsinn.
const widgetSnapshotVersion = 1;

/// Wohin ein angetipptes Widget fuehrt.
enum WidgetTarget {
  tasks,
  appointments,
  calendar;

  static WidgetTarget? fromName(String? name) {
    for (final t in WidgetTarget.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

String _hex(int argb) => '#${argb.toRadixString(16).padLeft(8, '0')}';

/// Die Aufgaben, die an [day] auf dem Teller liegen – dieselbe Regel wie im
/// Dashboard, nur fuer einen beliebigen Tag statt fuer heute: was an dem Tag
/// faellig ist, dazu die einmaligen Aufgaben, die bis dahin offen geblieben
/// sind.
///
/// Offene zuerst, danach nach Prioritaet, und den Gleichstand bricht der
/// Titel: `List.sort` ist nicht stabil, sonst wackelte die Reihenfolge von
/// Schnappschuss zu Schnappschuss.
List<Task> widgetTasksForDay(AppState state, DateTime day) {
  final d = dateOnly(day);
  final list = state.tasks.where((task) {
    if (task.occursOn(d)) return true;
    return !task.isRecurring &&
        task.completedDates.isEmpty &&
        dateOnly(task.startDate).isBefore(d);
  }).toList();
  list.sort((a, b) {
    final done = (a.isCompletedOn(d) ? 1 : 0) - (b.isCompletedOn(d) ? 1 : 0);
    if (done != 0) return done;
    final prio = a.priority.level - b.priority.level;
    if (prio != 0) return prio;
    return a.title.compareTo(b.title);
  });
  return list;
}

/// Alles, was die Widgets brauchen, in einer Karte pro Tag.
///
/// Leere Tage stehen nicht drin (das spart den Grossteil des Platzes); dass
/// ein Tag wirklich leer ist und nicht bloss ausserhalb des Schnappschusses
/// liegt, sagen `from` und `to`.
Map<String, dynamic> buildWidgetSnapshot(AppState state, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  // Ab dem Monatsersten, damit das Monatsraster auch die schon vergangenen
  // Tage des laufenden Monats markieren kann.
  final from = DateTime(today.year, today.month, 1);
  final to = DateTime(today.year, today.month, today.day + widgetHorizonDays);
  final theme = joeThemes[state.themeIndex % joeThemes.length];

  final days = <String, dynamic>{};
  // Bewusst ueber die Kalenderfelder gezaehlt und nicht per Duration: an den
  // beiden Zeitumstellungstagen im Jahr sind 24 Stunden nicht ein Tag, und
  // dateOnly(tag + 24h) faellt im Herbst auf denselben Tag zurueck.
  for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final tasks = widgetTasksForDay(state, d);
    final appointments = state.appointmentsForDay(d);
    final hasNote = state.notesForDay(d).isNotEmpty;
    final holidays = state.showHolidays
        ? holidaysOn(d, state.holidayRegion)
        : const <String>[];
    if (tasks.isEmpty && appointments.isEmpty && !hasNote && holidays.isEmpty) {
      continue;
    }

    // Der Punkt im Monatsraster kommt **nicht** aus [tasks]: die Liste traegt
    // Liegengebliebenes von Tag zu Tag weiter (so steht es auch im
    // Dashboard), und damit waere jeder kommende Tag markiert, nur weil
    // heute etwas offen ist. Das Raster zeigt, was an dem Tag faellig ist –
    // genau wie der Kalender der App, Termine vor Aufgaben.
    final due = state.tasksForDay(d);
    final markColor = appointments.isNotEmpty
        ? appointments.first.color
        : (due.isEmpty ? null : due.first.color);
    final markDone = appointments.isEmpty &&
        due.isNotEmpty &&
        due.every((t) => t.isCompletedOn(d));

    days[dateKey(d)] = {
      if (markColor != null)
        'mark': {'color': _hex(markColor.toARGB32()), 'done': markDone},
      'tasks': [
        for (final t in tasks.take(widgetEntriesPerDay))
          {
            'title': t.title,
            'color': _hex(t.color.toARGB32()),
            'done': t.isCompletedOn(d),
            'low': t.priority == Priority.niedrig,
            // Ob die Aufgabe an diesem Tag faellig ist oder nur von frueher
            // mitgeschleppt wird. Fuer die Heute-Liste ist das einerlei –
            // beides liegt auf dem Teller. Der Blick nach vorn ("Demnaechst"
            // im Widget) braucht den Unterschied aber: sonst stuende jede
            // heute offene Aufgabe auch morgen und uebermorgen da.
            'over': !t.occursOn(d),
          },
      ],
      'taskCount': tasks.length,
      // Die Kopfzeile zaehlt wie das Dashboard: alles, was an dem Tag offen
      // ist – Stufe 3 eingeschlossen.
      'open': tasks.where((t) => !t.isCompletedOn(d)).length,
      'appointments': [
        for (final a in appointments.take(widgetEntriesPerDay))
          {
            'title': a.title,
            'color': _hex(a.color.toARGB32()),
            'minute': a.when.hour * 60 + a.when.minute,
          },
      ],
      'appointmentCount': appointments.length,
      'note': hasNote,
      if (holidays.isNotEmpty) 'holiday': holidays.first,
    };
  }

  return {
    'version': widgetSnapshotVersion,
    'from': dateKey(from),
    'to': dateKey(to),
    'theme': {
      'name': theme.name,
      'paper': _hex(theme.paper.toARGB32()),
      'ink': _hex(theme.ink.toARGB32()),
      'inkSoft': _hex(theme.inkSoft.toARGB32()),
      'accent': _hex(theme.accent.toARGB32()),
    },
    'days': days,
  };
}

/// Der Draht zu den Widgets: eine Kapsel um den Methodenkanal, wie
/// `JoeReminders` einer um sein Plugin ist.
class JoeHomeWidgets {
  JoeHomeWidgets._();
  static final JoeHomeWidgets instance = JoeHomeWidgets._();

  static const _channel = MethodChannel('joe/home_widget');

  /// Was ein angetipptes Widget oeffnen soll. Wird von `main()` gesetzt.
  void Function(WidgetTarget)? onOpen;

  Timer? _debounce;
  bool _listening = false;

  /// Nur einmal melden, wenn es keine Widgets gibt (Web, Desktop, Tests):
  /// jeder Speichervorgang liefe sonst in dieselbe Zeile im Log.
  bool _unavailable = false;

  /// Der uebliche Weg: die Widgets bekommen den neuen Stand gleich, aber
  /// erst, wenn die Aenderung durch ist.
  ///
  /// Ein Zug an einer Aufgabe loest mehrere `notifyListeners` aus, und jeder
  /// Schnappschuss weckt vier Widget-Empfaenger im System. Gebraucht wird
  /// davon nur der letzte.
  void schedule(AppState state) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(push(state));
    });
  }

  /// Sofort schreiben – beim App-Start und wenn ein Test nicht warten will.
  Future<void> push(AppState state) async {
    _debounce?.cancel();
    if (_unavailable) return;
    try {
      await _channel.invokeMethod<void>(
        'push',
        jsonEncode(buildWidgetSnapshot(state)),
      );
    } on MissingPluginException {
      // Kein Android, keine Widgets. Das ist kein Fehler, sondern der
      // Normalfall auf jeder anderen Plattform.
      _unavailable = true;
      JoeLog.log('Widgets: keine auf dieser Plattform');
    } catch (e) {
      // Bewusst ohne Toast: ein Widget ist Beiwerk am Rand des Bildschirms.
      // Ein Fehler dort darf nicht mitten in der App aufpoppen – ins Log
      // gehoert er trotzdem.
      JoeLog.log('FEHLER Widgets: $e');
    }
  }

  /// Nimmt entgegen, wohin ein angetipptes Widget fuehren soll.
  ///
  /// Zwei Wege, und beide werden gebraucht: Beim Kaltstart steht das Ziel
  /// schon in der Intent, bevor Dart ueberhaupt laeuft – das holt [_take]
  /// ab, sobald der Navigator steht. Laeuft die App schon, kommt das Ziel
  /// als Aufruf von Android herein.
  void listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        _open(call.arguments as String?);
      }
      return null;
    });
    unawaited(_take());
  }

  Future<void> _take() async {
    try {
      _open(await _channel.invokeMethod<String>('launchTarget'));
    } on MissingPluginException {
      _unavailable = true;
    } catch (e) {
      JoeLog.log('FEHLER Widgets: $e');
    }
  }

  void _open(String? name) {
    final target = WidgetTarget.fromName(name);
    if (target == null) return;
    JoeLog.log('Widget angetippt: ${target.name}');
    onOpen?.call(target);
  }
}
