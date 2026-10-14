import 'package:flutter/material.dart';
import 'package:joe_sync/joe_sync.dart' show ShareLink;
import 'package:share_plus/share_plus.dart';

import '../log.dart';
import '../models.dart';
import '../shared_lists.dart';
import '../toast.dart';
import '../widgets.dart';
import 'shopping_shared.dart';

/// Die Einkaufsliste als eigener Reiter (Modus [ShoppingListMode.tab]).
/// Kein Plus-Knopf – der Weg zum Hinzufuegen ist das Eingabefeld am
/// unteren Rand.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JoeScaffold(
      page: PetPage.shopping,
      title: 'Einkaufsliste',
      body: SafeArea(child: ShoppingListView()),
    );
  }
}

/// Die Einkaufslisten: oben die Wahl der Liste, darunter die Eintraege der
/// gewaehlten auf einer Karte, unten die Eingabeleiste. Im Reiter und in den
/// Notizen sind es dieselben Listen ([AppState.shoppingLists]), sie haengen
/// an keinem Tag.
///
/// Das Eingabefeld steht unten und nicht oben: dort ist der Daumen, die
/// Tastatur schiebt es mit hoch, und neue Eintraege landen genau darueber –
/// dort, wo der Blick beim Tippen gerade ist.
class ShoppingListView extends StatefulWidget {
  /// Was ueber der Karte mitscrollt – in den Notizen der Umschalter. Er
  /// steht *in* der Liste und nicht darueber, damit der Begleiter auf der
  /// obersten Karte sitzt und mit ihr wegscrollt (siehe [petPadding]).
  final List<Widget> header;

  const ShoppingListView({super.key, this.header = const []});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Der zuletzt angelegte Eintrag traegt diesen Schluessel, damit die Liste
  /// zu ihm scrollen kann, wenn sie laenger als der Bildschirm ist.
  final _newestKey = GlobalKey();
  String? _newestId;

  /// Die Liste, deren Abgleich gerade laeuft (siehe [SharedLists.watch]).
  String? _watchedId;

  @override
  void dispose() {
    // Nur abmelden, was diese Ansicht angemeldet hat: im Reiter und in den
    // Notizen kann kurz eine zweite stehen.
    if (_watchedId != null) SharedLists.instance.watch(null);
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Eine geteilte Liste gleicht nur ab, solange sie zu sehen ist (G7).
  void _watch(ShoppingList list) {
    final id = list.isShared ? list.id : null;
    if (id == _watchedId) return;
    _watchedId = id;
    // Nicht mitten im Bauen: watch() kann gleich abgleichen und melden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SharedLists.instance.watch(id == null ? null : list);
    });
  }

  void _add() {
    final state = AppScope.of(context);
    final item = state.addShoppingItem(_input.text);
    // Leere Eingabe tut nichts – auch das Feld bleibt, wie es ist.
    if (item == null) return;
    _input.clear();
    // Der Fokus bleibt im Feld: wer einkauft, tippt meist mehrere Dinge
    // hintereinander, und die Tastatur soll dabei nicht zu- und aufgehen.
    _focus.requestFocus();
    setState(() => _newestId = item.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _newestKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final items = state.shoppingItems;
    final current = state.currentShoppingList;
    const page = PetPage.shopping;
    _watch(current);

    final list = ListView(
      // Herunterziehen gleicht ab – auch bei einer kurzen Liste.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: petPadding(
        context,
        page,
        const EdgeInsets.fromLTRB(16, 4, 16, 12),
      ),
      children: [
        ...widget.header,
        const _ListPicker(),
        SharedStatusLine(key: ValueKey(current.id), list: current),
        // Auch der leere Zustand steht auf Papier: frei auf dem
        // Hintergrund waere er auf einem Foto-Design nicht zu lesen.
        if (items.isEmpty)
          PaperCard(
            child: Text(
              'Noch nichts auf der Liste. Unten eintippen und mit '
              'Enter hinzufügen.',
              style: TextStyle(color: theme.inkSoft, fontSize: 15),
            ),
          )
        else
          PaperCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                for (final item in items)
                  _ShoppingRow(
                    key: item.id == _newestId
                        ? _newestKey
                        : ValueKey(item.id),
                    item: item,
                    list: current,
                  ),
              ],
            ),
          ),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: current.isShared
              ? RefreshIndicator(
                  color: theme.accent,
                  onRefresh: () => SharedLists.instance.syncList(current),
                  child: list,
                )
              : list,
        ),
        _InputBar(controller: _input, focusNode: _focus, onAdd: _add),
      ],
    );
  }
}

/// Die Karte mit der Wahl der Liste: jede Liste ein Chip, dahinter
/// "Neue Liste". Ein Tipp zeigt die Liste, langer Druck fuehrt wie bei den
/// Eintraegen auf Bearbeiten und Loeschen. Rechts daneben das Teilen der
/// gezeigten Liste.
///
/// Chips und keine Ausklappliste: beim Einkaufen soll man sehen, welche
/// Listen es gibt, und mit einem Tipp wechseln.
class _ListPicker extends StatelessWidget {
  const _ListPicker();

  /// Neue Liste – oder, wenn statt eines Namens ein geteilter Link
  /// eingefuegt wird, beitreten (Konzept 6.2).
  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    final name = await showTextEntrySheet(
      context,
      title: 'Neue Liste',
      hint: 'Name – oder geteilten Link einfügen',
    );
    if (name == null || !context.mounted) return;
    final link = ShareLink.tryParse(name);
    if (link != null) {
      await joinSharedList(context, link);
      return;
    }
    state.addShoppingList(name);
  }

  void _options(BuildContext context, ShoppingList list) {
    final state = AppScope.of(context);
    final count = list.items.length;
    final share = list.share;
    showEntryOptions(
      context,
      deleteTitle: 'Liste löschen?',
      subject: [
        count == 0
            ? list.name
            : '${list.name} – '
                '$count ${count == 1 ? 'Eintrag geht' : 'Einträge gehen'} mit.',
        if (share != null) 'Die anderen behalten sie.',
      ].join(' '),
      onEdit: () async {
        final name = await showTextEntrySheet(
          context,
          title: 'Liste umbenennen',
          hint: 'Wie heißt die Liste?',
          initialText: list.name,
        );
        if (name != null) state.renameShoppingList(list, name);
      },
      extra: [
        if (share != null)
          EntryAction(
            icon: Icons.cloud_off_outlined,
            label: 'Teilen verlassen',
            onTap: () => confirmLeave(context, list),
          ),
        if (share != null && share.isOwner)
          EntryAction(
            icon: Icons.delete_sweep_outlined,
            label: 'Für alle löschen',
            destructive: true,
            onTap: () => confirmDeleteForAll(context, list),
          ),
      ],
      // Die letzte Liste bleibt: irgendwohin muss das Eingabefeld schreiben.
      onDelete: state.shoppingLists.length > 1
          ? () {
              SharedLists.instance.forget(list);
              state.deleteShoppingList(list);
            }
          : null,
    );
  }

  /// Schickt die offenen Eintraege als Text an den Share-Intent des Systems
  /// (siehe [ShoppingList.shareText]) – Messenger, Mail, was das Geraet hat.
  /// Die Empfaenger brauchen dafuer kein Joe.
  Future<void> _share(BuildContext context, ShoppingList list) async {
    final text = list.shareText;
    if (text == null) {
      JoeToast.info('Auf der Liste fehlt gerade nichts.');
      return;
    }
    // Auf iPad und Mac ist das Teilen-Blatt ein Popover und will wissen,
    // woran es haengen soll (wie bei "Logs teilen").
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: list.name,
          sharePositionOrigin: origin,
        ),
      );
      JoeLog.log('Einkaufsliste geteilt (${list.id})');
    } catch (e) {
      JoeLog.log('Einkaufsliste teilen fehlgeschlagen: $e');
      JoeToast.error('Die Liste ließ sich nicht teilen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final current = state.currentShoppingList;
    final chips = Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final list in state.shoppingLists)
          // Der Chip selbst kennt keinen langen Druck; der Detektor darueber
          // bekommt ihn, der Tipp bleibt beim Chip.
          Semantics(
            onLongPress: () => _options(context, list),
            child: GestureDetector(
              onLongPress: () => _options(context, list),
              child: ChoiceChip(
                // Eine geteilte Liste traegt eine Wolke.
                avatar: list.isShared
                    ? Icon(Icons.cloud_outlined, size: 18, color: theme.ink)
                    : null,
                label: Text(list.name),
                selected: list.id == current.id,
                selectedColor: theme.accent.withValues(alpha: 0.25),
                labelStyle: TextStyle(color: theme.ink),
                onSelected: (_) => state.selectShoppingList(list),
              ),
            ),
          ),
        ActionChip(
          avatar: Icon(Icons.add, size: 18, color: theme.accent),
          label: const Text('Neue Liste'),
          labelStyle: TextStyle(color: theme.ink),
          onPressed: () => _add(context),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: chips),
            // Eigener Kontext fuer den Knopf: an ihm haengt das Popover.
            Builder(
              builder: (buttonContext) => IconButton(
                icon: Icon(Icons.share_outlined, color: theme.ink),
                tooltip: 'Liste teilen',
                onPressed: () => showShareChooser(
                  buttonContext,
                  current,
                  shareAsText: () => _share(buttonContext, current),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Eingabeleiste am unteren Rand. Die Tastatur schiebt sie mit hoch
/// (Scaffold-Standard `resizeToAvoidBottomInset`).
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = joeThemeOf(context);
    return SafeArea(
      top: false,
      child: PaperCard(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: theme.ink, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Was fehlt?',
                  hintStyle: TextStyle(color: theme.inkSoft),
                  border: InputBorder.none,
                ),
                // Ohne eigenes onEditingComplete nimmt "Fertig" dem Feld den
                // Fokus, und die Tastatur klappt nach jedem Eintrag zu.
                onEditingComplete: () {},
                onSubmitted: (_) => onAdd(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: theme.accent, size: 30),
              tooltip: 'Hinzufügen',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Eintrag: Kaestchen und Titel wie eine Aufgabenzeile ([TaskTile]).
/// Tipp hakt ab bzw. nimmt den Haken zurueck, langer Druck fuehrt auf das
/// bekannte Blatt mit Bearbeiten und Loeschen.
class _ShoppingRow extends StatelessWidget {
  final ShoppingItem item;
  final ShoppingList list;

  const _ShoppingRow({super.key, required this.item, required this.list});

  void _options(BuildContext context) {
    final state = AppScope.of(context);
    showEntryOptions(
      context,
      deleteTitle: 'Eintrag löschen?',
      subject: item.title,
      onEdit: () async {
        final title = await showTextEntrySheet(
          context,
          title: 'Eintrag bearbeiten',
          hint: 'Was fehlt?',
          initialText: item.title,
          emptyMessage: 'Bitte gib etwas ein.',
        );
        if (title != null) state.renameShoppingItem(item, title);
      },
      onDelete: () => state.deleteShoppingItem(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = joeThemeOf(context);
    final done = item.done;
    final conflicts = list.share?.view.conflictsOf(item.id) ?? const [];
    final mine = [
      for (final c in conflicts)
        if (c.device == state.syncDevice) c,
    ];
    return Semantics(
      container: true,
      button: true,
      checked: done,
      label: item.title,
      onTap: () => state.toggleShoppingItem(item),
      onLongPress: () => _options(context),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => state.toggleShoppingItem(item),
        onLongPress: () => _options(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done ? theme.accent : Colors.transparent,
                  border: Border.all(color: theme.accent, width: 2.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: done
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: theme.bestOn(theme.accent),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: done ? theme.inkSoft : theme.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: theme.inkSoft,
                  ),
                ),
              ),
              // Konflikt (Konzept 5.4): wer ihn ausgeloest hat, klaert ihn
              // hier; alle anderen sehen nur, dass etwas geklaert wird.
              if (conflicts.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.sync_problem,
                    color: mine.isEmpty ? theme.inkSoft : theme.accent,
                  ),
                  tooltip: mine.isEmpty ? 'Wird gerade geklärt' : 'Klären',
                  onPressed: mine.isEmpty
                      ? () => JoeToast.info(
                            'Jemand anderes klärt gerade, was hier gilt.',
                          )
                      : () => showConflictSheet(context, list, mine.first),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
