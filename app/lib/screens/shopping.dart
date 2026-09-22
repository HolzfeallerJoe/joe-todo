import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';

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
      body: SafeArea(child: ShoppingList()),
    );
  }
}

/// Eine Einkaufsliste: die Eintraege auf einer Karte, darunter die
/// Eingabeleiste. Im Reiter und in den Notizen ist es dieselbe Liste
/// ([AppState.shoppingItems]), sie haengt an keinem Tag.
///
/// Das Eingabefeld steht unten und nicht oben: dort ist der Daumen, die
/// Tastatur schiebt es mit hoch, und neue Eintraege landen genau darueber –
/// dort, wo der Blick beim Tippen gerade ist.
class ShoppingList extends StatefulWidget {
  /// Was ueber der Karte mitscrollt – in den Notizen der Umschalter. Er
  /// steht *in* der Liste und nicht darueber, damit der Begleiter auf der
  /// obersten Karte sitzt und mit ihr wegscrollt (siehe [petPadding]).
  final List<Widget> header;

  const ShoppingList({super.key, this.header = const []});

  @override
  State<ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<ShoppingList> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Der zuletzt angelegte Eintrag traegt diesen Schluessel, damit die Liste
  /// zu ihm scrollen kann, wenn sie laenger als der Bildschirm ist.
  final _newestKey = GlobalKey();
  String? _newestId;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
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
    const page = PetPage.shopping;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: petPadding(
              context,
              page,
              const EdgeInsets.fromLTRB(16, 4, 16, 12),
            ),
            children: [
              ...widget.header,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      for (final item in items)
                        _ShoppingRow(
                          key: item.id == _newestId
                              ? _newestKey
                              : ValueKey(item.id),
                          item: item,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _InputBar(controller: _input, focusNode: _focus, onAdd: _add),
      ],
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

  const _ShoppingRow({super.key, required this.item});

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
            ],
          ),
        ),
      ),
    );
  }
}
