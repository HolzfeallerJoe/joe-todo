import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joe_sync/joe_sync.dart';
import 'package:share_plus/share_plus.dart';

import '../env.dart';
import '../log.dart';
import '../models.dart';
import '../reminders.dart';
import '../shared_lists.dart';
import '../theme.dart';
import '../toast.dart';
import '../widgets.dart';

/// Die Oberflaeche geteilter Einkaufslisten (Konzept 6.2): Teilen-Blatt,
/// Code, Beitreten, Konflikte, Statuszeile. Der Abgleich selbst steckt in
/// [SharedLists].

/// Das Blatt hinter dem Teilen-Knopf (G12): als Text senden wie bisher, oder
/// gemeinsam bearbeiten.
Future<void> showShareChooser(
  BuildContext context,
  ShoppingList list, {
  required Future<void> Function() shareAsText,
}) {
  final theme = joeThemeOf(context);
  final share = list.share;
  return showJoeSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.notes_outlined, color: theme.ink),
            title: Text('Als Text senden', style: TextStyle(color: theme.ink)),
            subtitle: Text(
              'Die offenen Einträge als Nachricht',
              style: TextStyle(color: theme.inkSoft),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              shareAsText();
            },
          ),
          if (share == null)
            ListTile(
              leading: Icon(Icons.group_outlined, color: theme.ink),
              title: Text(
                'Gemeinsam bearbeiten',
                style: TextStyle(color: theme.ink),
              ),
              subtitle: Text(
                'Alle sehen und ändern dieselbe Liste',
                style: TextStyle(color: theme.inkSoft),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                startSharing(context, list);
              },
            )
          else ...[
            ListTile(
              leading: Icon(Icons.link, color: theme.ink),
              title: Text(
                'Link noch einmal senden',
                style: TextStyle(color: theme.ink),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                sendShareLink(context, list);
              },
            ),
            if (share.hasCode)
              ListTile(
                leading: Icon(Icons.pin_outlined, color: theme.ink),
                title: Text(
                  'Code anzeigen',
                  style: TextStyle(color: theme.ink),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showShareCode(context, share.code!);
                },
              ),
          ],
        ],
      ),
    ),
  );
}

/// „Gemeinsam bearbeiten“ fuer eine noch nicht geteilte Liste: erklaeren,
/// Code waehlen, teilen, Link senden.
Future<void> startSharing(
    BuildContext buttonContext, ShoppingList list) async {
  // Ist die Liste geteilt, baut sich die Ansicht um (Herunterziehen kommt
  // dazu), und der Kontext des Knopfs verschwindet. Die Blaetter danach
  // haengen deshalb am Navigator, der bleibt.
  final context = Navigator.of(buttonContext).context;
  final server = JoeEnv.syncUrl;
  final host = Uri.tryParse(server)?.host ?? '';
  final withCode = await showJoeSheet<bool>(
    context,
    expand: true,
    builder: (sheetContext) => _StartSharingSheet(host: host),
  );
  if (withCode == null || !context.mounted) return;
  JoeToast.info('Liste wird geteilt …');
  try {
    final share = await SharedLists.instance.share(list, withCode: withCode);
    if (!context.mounted) return;
    // Wer teilt, bekommt die Hinweise vor dem Entteilen (Konzept 6.6); die
    // brauchen die Erlaubnis fuer Benachrichtigungen.
    if (JoeReminders.instance.ready) {
      await JoeReminders.instance.ensurePermission();
      if (!context.mounted) return;
    }
    await sendShareLink(context, list);
    if (share.hasCode && context.mounted) {
      await showShareCode(context, share.code!);
    }
  } on SyncFailure catch (e) {
    JoeLog.log('Teilen fehlgeschlagen: ${e.status.name}');
    JoeToast.error(_failureText(e, sharing: true));
  }
}

class _StartSharingSheet extends StatefulWidget {
  final String host;

  const _StartSharingSheet({required this.host});

  @override
  State<_StartSharingSheet> createState() => _StartSharingSheetState();
}

class _StartSharingSheetState extends State<_StartSharingSheet> {
  bool _withCode = false;

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    final noServer = widget.host.isEmpty;
    final text = TextStyle(color: theme.ink, fontSize: 15, height: 1.35);
    return SheetFrame(
      title: 'Gemeinsam bearbeiten',
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.share_outlined),
          onPressed: noServer ? null : () => Navigator.pop(context, _withCode),
          label: const Text(
            'Link teilen',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      children: [
        if (noServer)
          Text(
            'In diesem Build ist kein Sync-Server eingerichtet '
            '(JOE_SYNC_URL). Beitreten geht trotzdem: einen geteilten Link '
            'unter „Neue Liste“ einfügen.',
            style: text,
          )
        else ...[
          Text(
            'Die Liste wird verschlüsselt auf ${widget.host} abgelegt. Wer '
            'den Link hat, kann sie sehen und ändern – mit Joe oder im '
            'Browser.',
            style: text,
          ),
          const SizedBox(height: 8),
          Text(
            'Joe gleicht nur ab, solange die Liste offen ist. Wird sie ein '
            'Jahr lang nicht benutzt, endet das Teilen; vorher sagt Joe '
            'Bescheid.',
            style: TextStyle(color: theme.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: theme.accent,
            title: Text(
              'Zusätzlich Code verlangen',
              style: TextStyle(color: theme.ink),
            ),
            subtitle: Text(
              'Den Code gibst du getrennt vom Link weiter.',
              style: TextStyle(color: theme.inkSoft),
            ),
            value: _withCode,
            onChanged: (value) => setState(() => _withCode = value),
          ),
        ],
      ],
    );
  }
}

/// Schickt den Link der geteilten [list] ueber das Teilen-Blatt des
/// Systems. Den Code nie mit: der geht getrennt (G4).
Future<void> sendShareLink(BuildContext context, ShoppingList list) async {
  final share = list.share;
  if (share == null) return;
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final text = [
    'Gemeinsame Einkaufsliste „${list.name}“ – zum Mitmachen öffnen:',
    share.link.toString(),
    if (share.hasCode) 'Den Code bekommst du extra.',
  ].join('\n');
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: list.name, sharePositionOrigin: origin),
    );
    JoeLog.log('Link einer geteilten Liste gesendet (${list.id})');
  } catch (e) {
    JoeLog.log('Link senden fehlgeschlagen: ${e.runtimeType}');
    JoeToast.error('Der Link ließ sich nicht senden.');
  }
}

/// Zeigt den Code gross, zum Vorlesen oder Kopieren.
Future<void> showShareCode(BuildContext context, String code) {
  final theme = joeThemeOf(context);
  final spaced = code.length == 6
      ? '${code.substring(0, 3)} ${code.substring(3)}'
      : code;
  return showJoeSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Code der Liste',
              style: TextStyle(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              spaced,
              style: TextStyle(
                color: theme.accent,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Getrennt vom Link weitergeben, etwa per SMS oder mündlich.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.ink,
                      side: BorderSide(color: theme.inkSoft),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Kopieren'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      JoeToast.success('Code kopiert');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Fertig'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Beitreten ueber einen eingefuegten Link (Konzept 6.2): bei Bedarf nach
/// dem Code fragen, dann die Liste holen und zeigen.
Future<void> joinSharedList(BuildContext context, ShareLink link) async {
  final service = SharedLists.instance;
  JoeToast.info('Liste wird geholt …');
  try {
    final meta = await service.inspect(link);
    String? code;
    if (meta.code) {
      if (!context.mounted) return;
      code = await showTextEntrySheet(
        context,
        title: 'Code eingeben',
        hint: '6 Ziffern',
        emptyMessage: 'Bitte gib den Code ein.',
      );
      if (code == null) return;
    }
    final list = await service.join(link, code: code);
    JoeToast.success('„${list.name}“ ist jetzt hier.');
  } on SyncFailure catch (e) {
    JoeLog.log('Beitreten fehlgeschlagen: ${e.status.name}');
    JoeToast.error(_failureText(e));
  }
}

String _failureText(SyncFailure e, {bool sharing = false}) {
  switch (e.status) {
    case SyncStatus.offline:
      return 'Der Server ist gerade nicht erreichbar.';
    case SyncStatus.unauthorized:
      return sharing
          ? 'Der Server hat das Teilen abgelehnt.'
          : 'Der Code stimmt nicht.';
    case SyncStatus.gone:
      return e.reason == 'expired'
          ? 'Diese Liste wird nicht mehr geteilt.'
          : 'Diese Liste wurde gelöscht.';
    case SyncStatus.rateLimited:
      return 'Zu viele Versuche – bitte später noch einmal.';
    case SyncStatus.failed:
    case SyncStatus.ok:
      if (e.reason == 'unknown') return 'Diese Liste gibt es nicht (mehr).';
      if (e.reason == 'no-server') {
        return 'In diesem Build ist kein Sync-Server eingerichtet.';
      }
      return sharing
          ? 'Die Liste ließ sich nicht teilen.'
          : 'Die Liste ließ sich nicht holen.';
  }
}

/// Teilen verlassen, nach Rueckfrage (G6).
Future<void> confirmLeave(BuildContext context, ShoppingList list) async {
  final theme = joeThemeOf(context);
  final leave = await showJoeSheet<bool>(
    context,
    builder: (sheetContext) => _QuestionCard(
      theme: theme,
      title: 'Teilen verlassen?',
      text: '„${list.name}“ bleibt auf diesem Gerät, gleicht aber nicht '
          'mehr ab. Die anderen behalten die Liste.',
      first: 'Verlassen',
      second: 'Abbrechen',
    ),
  );
  if (leave == true) SharedLists.instance.leave(list);
}

/// Fuer alle loeschen (G5, nur Ersteller), nach Rueckfrage.
Future<void> confirmDeleteForAll(
    BuildContext context, ShoppingList list) async {
  final confirmed = await confirmDelete(
    context,
    title: 'Für alle löschen?',
    subject: '„${list.name}“ verschwindet vom Server. Die anderen behalten '
        'ihren letzten Stand, ohne Abgleich; hier bleibt die Liste ebenso.',
  );
  if (!confirmed) return;
  try {
    await SharedLists.instance.deleteForAll(list);
    JoeToast.success('Für alle gelöscht.');
  } on SyncFailure catch (e) {
    JoeLog.log('Fuer alle loeschen fehlgeschlagen: ${e.status.name}');
    JoeToast.error(e.status == SyncStatus.offline
        ? 'Der Server ist gerade nicht erreichbar.'
        : 'Die Liste ließ sich nicht löschen.');
  }
}

/// Die Fragen aus Konzept 5.4, je nach Art des Konflikts.
Future<void> showConflictSheet(
  BuildContext context,
  ShoppingList list,
  SyncConflict conflict,
) async {
  final state = AppScope.of(context);
  final theme = joeThemeOf(context);
  final view = list.share?.view;
  if (view == null) return;
  final item = conflict.item == null ? null : view.items[conflict.item];
  String text;
  String mine;
  String theirs;
  switch (conflict.kind) {
    case ConflictKind.deleted:
      text = 'Jemand hat „${item?.titleValue}“ gelöscht, du hattest den '
          'Eintrag in „${conflict.value}“ geändert.';
      mine = 'Behalten';
      theirs = 'Löschen lassen';
    case ConflictKind.edited:
      text = '„${item?.titleValue}“ wurde inzwischen geändert. '
          'Trotzdem löschen?';
      mine = 'Löschen';
      theirs = 'Behalten';
    case ConflictKind.field:
      if (conflict.field == 'done') {
        final now = item?.isDone == true ? 'abgehakt' : 'offen';
        final wanted = conflict.value == true ? 'abgehakt' : 'offen';
        text = '„${item?.titleValue}“ ist inzwischen $now, du wolltest '
            'den Eintrag $wanted.';
        mine = 'Meins: $wanted';
        theirs = 'Das andere: $now';
      } else {
        final current =
            conflict.item == null ? view.nameValue : item?.titleValue;
        text = '„${conflict.value}“ (von dir) oder „$current“ (geändert, '
            'während du offline warst)?';
        mine = 'Meins';
        theirs = 'Das andere';
      }
  }
  final keepMine = await showJoeSheet<bool>(
    context,
    builder: (sheetContext) => _QuestionCard(
      theme: theme,
      title: 'Gleichzeitig geändert',
      text: text,
      first: mine,
      second: theirs,
      // „Das andere“ ist hier keine Absage, sondern eine Antwort.
      secondAnswers: true,
    ),
  );
  if (keepMine == null) return;
  state.resolveShoppingConflict(list, conflict, keepMine);
}

/// Eine Frage mit zwei Antworten, als Karte von unten wie die Loeschkarte.
/// Liefert true fuer [first], false fuer [second] (nur mit
/// [secondAnswers]; sonst ist [second] ein Abbrechen und liefert null).
class _QuestionCard extends StatelessWidget {
  final JoeTheme theme;
  final String title;
  final String text;
  final String first;
  final String second;
  final bool secondAnswers;

  const _QuestionCard({
    required this.theme,
    required this.title,
    required this.text,
    required this.first,
    required this.second,
    this.secondAnswers = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(color: theme.ink, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 20),
            Row(
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
                    onPressed: () => Navigator.pop(
                      context,
                      secondAnswers ? false : null,
                    ),
                    child: Text(second, textAlign: TextAlign.center),
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
                    child: Text(
                      first,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Statuszeile unter der Listenwahl, nur bei geteilten Listen oder
/// direkt nach dem Ende des Teilens (Konzept 6.2).
class SharedStatusLine extends StatelessWidget {
  final ShoppingList list;

  const SharedStatusLine({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    final service = SharedLists.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final theme = joeThemeOf(context);
        final state = AppScope.of(context);
        final ended = service.endedOf(list);
        final share = list.share;
        if (share == null && ended == null) return const SizedBox.shrink();

        String text;
        var warn = false;
        VoidCallback? onTap;
        if (share == null) {
          warn = ended != ShareEnd.left;
          text = switch (ended!) {
            ShareEnd.left => 'Nicht mehr geteilt – die Liste bleibt hier.',
            ShareEnd.deleted =>
              'Vom Ersteller gelöscht – die Liste bleibt hier, ohne Abgleich.',
            ShareEnd.expired =>
              'Lange nicht benutzt, deshalb nicht mehr geteilt – die Liste '
                  'bleibt hier.',
          };
          onTap = () => service.dismissEnded(list);
        } else {
          final unsent = share.unsent;
          text = switch (service.statusOf(list)) {
            SharedListStatus.idle ||
            SharedListStatus.syncing =>
              'Geteilt · wird abgeglichen …',
            SharedListStatus.ok => 'Geteilt · ${_ago(share.lastSync)}',
            SharedListStatus.offline => unsent > 0
                ? 'Offline – Änderungen gehen später raus'
                : 'Offline',
            SharedListStatus.unauthorized =>
              'Kein Zugriff – Code falsch oder Link erneuert',
            SharedListStatus.rateLimited =>
              'Gebremst – später geht es weiter',
            SharedListStatus.failed => 'Abgleich gerade nicht möglich',
          };
          warn = switch (service.statusOf(list)) {
            SharedListStatus.idle ||
            SharedListStatus.syncing ||
            SharedListStatus.ok =>
              false,
            _ => true,
          };
          final mine = list.conflictsFor(state.syncDevice);
          if (mine.isNotEmpty) {
            warn = true;
            text += mine.length == 1
                ? ' · 1 Konflikt zu klären'
                : ' · ${mine.length} Konflikte zu klären';
            // Der Name hat keine eigene Zeile: sein Konflikt wird hier
            // geklaert, die der Eintraege an ihrem Zeichen.
            final nameConflict = mine.where((c) => c.item == null);
            if (nameConflict.isNotEmpty) {
              onTap = () =>
                  showConflictSheet(context, list, nameConflict.first);
            }
          }
        }
        final color = warn ? theme.accent : theme.inkSoft;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  share == null ? Icons.cloud_off_outlined : Icons.cloud_done,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: warn ? theme.ink : theme.inkSoft,
                      fontSize: 13,
                      fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (share == null)
                  Icon(Icons.close, size: 16, color: theme.inkSoft),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _ago(DateTime? time) {
  if (time == null) return 'noch nicht abgeglichen';
  final minutes = DateTime.now().difference(time).inMinutes;
  if (minutes < 1) return 'gerade abgeglichen';
  if (minutes < 60) return 'abgeglichen vor $minutes Min.';
  final hours = minutes ~/ 60;
  if (hours < 24) return 'abgeglichen vor $hours Std.';
  return 'zuletzt abgeglichen vor ${hours ~/ 24} Tag(en)';
}
