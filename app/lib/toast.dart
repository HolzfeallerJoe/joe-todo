import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Kurze Meldungen am oberen Bildschirmrand – der eine Weg, auf dem etwas
/// beim Nutzer ankommt.
///
/// Warum nicht `ScaffoldMessenger`: die Meldungen, um die es hier geht,
/// entstehen groesstenteils *ohne* Bildschirm. Eine fehlgeschlagene
/// Erinnerungsplanung passiert im Hintergrund, ein Kalender-Abruf faellt
/// waehrend eines Frames um – beide haben keinen `BuildContext`, an dem eine
/// Snackbar haengen koennte. Darum ein Singleton, das jeder aufrufen kann,
/// und genau ein [ToastHost] weit oben im Baum, der es anzeigt.
///
/// Grundsatz: **kein Fehler bleibt im Log stecken.** [JoeLog] ist fuer die
/// Fehlersuche hinterher, der Toast fuer den Nutzer jetzt.
enum ToastKind { info, success, error }

/// Ein antippbarer Knopf in der Meldung – fuer den Weg in die
/// System-Einstellungen, wenn eine Berechtigung dauerhaft fehlt.
class ToastAction {
  final String label;
  final VoidCallback onTap;
  const ToastAction(this.label, this.onTap);
}

class ToastMessage {
  final String text;
  final ToastKind kind;
  final ToastAction? action;
  final Duration duration;

  /// Laufende Nummer, damit zwei gleich aussehende Meldungen hintereinander
  /// als zwei erkannt werden (der [AnimatedSwitcher] haengt daran).
  final int seq;

  const ToastMessage({
    required this.text,
    required this.kind,
    required this.duration,
    required this.seq,
    this.action,
  });
}

class JoeToast extends ChangeNotifier {
  JoeToast._();
  static final JoeToast instance = JoeToast._();

  /// Wie lange eine Meldung steht. Mit Aktion laenger – drei Sekunden reichen
  /// nicht, um zu lesen *und* zu tippen.
  static const showDuration = Duration(seconds: 3);
  static const actionDuration = Duration(seconds: 6);

  /// Mehr als das staut sich nicht auf: was danach kommt, ist ohnehin
  /// Folgerauschen desselben Problems.
  static const _queueCap = 3;

  final Queue<ToastMessage> _waiting = Queue();
  ToastMessage? _current;
  Timer? _timer;
  int _seq = 0;

  ToastMessage? get current => _current;

  static void info(String text, {ToastAction? action}) =>
      instance.show(text, ToastKind.info, action);

  static void success(String text, {ToastAction? action}) =>
      instance.show(text, ToastKind.success, action);

  static void error(String text, {ToastAction? action}) =>
      instance.show(text, ToastKind.error, action);

  void show(String text, ToastKind kind, [ToastAction? action]) {
    // Dieselbe Meldung nicht doppelt: ein Fehler, der pro Monatszelle einmal
    // auftritt, soll den Bildschirm nicht 42-mal belegen.
    if (_current?.text == text) return;
    if (_waiting.any((m) => m.text == text)) return;

    final message = ToastMessage(
      text: text,
      kind: kind,
      action: action,
      duration: action == null ? showDuration : actionDuration,
      seq: _seq++,
    );
    if (_current == null) {
      _present(message);
      return;
    }
    // Ein Fehler draengelt sich vor: er ist das, was der Nutzer wissen muss.
    if (kind == ToastKind.error && _current!.kind != ToastKind.error) {
      _waiting.addFirst(message);
    } else {
      _waiting.addLast(message);
    }
    while (_waiting.length > _queueCap) {
      _waiting.removeLast();
    }
  }

  void _present(ToastMessage message) {
    _timer?.cancel();
    _current = message;
    _timer = Timer(message.duration, dismiss);
    notifyListeners();
  }

  /// Wegwischen bzw. Zeit abgelaufen – danach kommt der naechste dran.
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_waiting.isNotEmpty) {
      _present(_waiting.removeFirst());
      return;
    }
    _current = null;
    notifyListeners();
  }

  /// Damit ein Test nicht mit einem laufenden Timer aus dem vorigen faellt.
  @visibleForTesting
  void reset() {
    _timer?.cancel();
    _timer = null;
    _waiting.clear();
    _current = null;
    _seq = 0;
  }
}

/// Haengt die Meldungen ueber die App. Genau einmal einbauen, moeglichst weit
/// oben – in Joe ueber `MaterialApp.builder`, damit ein Toast auch ueber einem
/// offenen Blatt oder Dialog steht.
class ToastHost extends StatefulWidget {
  final Widget child;
  const ToastHost({super.key, required this.child});

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: JoeToast.instance,
              builder: (context, _) {
                final message = JoeToast.instance.current;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.7),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: message == null
                      ? const SizedBox(key: ValueKey('leer'), width: double.infinity)
                      : _ToastCard(
                          key: ValueKey(message.seq),
                          message: message,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastMessage message;
  const _ToastCard({super.key, required this.message});

  /// Ein warmes Rot bzw. Gruen – das Design gibt keine Signalfarben her, und
  /// der Akzent des Designs ist als "etwas ist schiefgegangen" zu freundlich.
  static const _errorColor = Color(0xFFA33B2A);
  static const _successColor = Color(0xFF43704E);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemes[state.themeIndex % joeThemes.length];
    final (Color tone, IconData icon) = switch (message.kind) {
      ToastKind.error => (_errorColor, Icons.error_outline),
      ToastKind.success => (_successColor, Icons.check_circle_outline),
      ToastKind.info => (theme.accent, Icons.info_outline),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: JoeToast.instance.dismiss,
          // Nach oben wegwischen, wie man es von Benachrichtigungen kennt.
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < 0) JoeToast.instance.dismiss();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: theme.paper,
              borderRadius: BorderRadius.circular(14),
              // Der farbige Streifen links traegt die Bedeutung mit, nicht
              // nur das Symbol – Farbe allein waere zu wenig.
              border: Border(left: BorderSide(color: tone, width: 4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (message.action != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: tone,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      JoeToast.instance.dismiss();
                      message.action!.onTap();
                    },
                    child: Text(
                      message.action!.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
