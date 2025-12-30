import 'package:flutter/material.dart';
import 'dart:async';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/pages/tag_page.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:provider/provider.dart';
import '../../../app/app_page.dart';
import '../../../data/controller/notes_controller.dart';
import '../../../i18n/i18n.dart';
import '../widgets/note_item_widget.dart';
import 'note_page.dart';

class NotesTagsPage extends StatefulWidget {

  const NotesTagsPage({super.key});

  @override
  _NotesTagsPageState createState() => _NotesTagsPageState();
}

class _NotesTagsPageState extends State<NotesTagsPage> {
  List<Tag> filteredTags = [];
  List<Note> filteredNotes = [];
  String searchQuery = ''; // Terme de recherche à mettre en évidence
  bool showAllCategories = false; // Pour afficher toutes les catégories

  // 🌟 DÉBOUNCING : Timer pour contrôler la fréquence de la recherche
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 🌟 Annuler le timer à la destruction du widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesController = context.watch<NotesController>();
    final tagsController  = context.watch<TagsController>();

    filteredNotes = searchQuery.isEmpty ? notesController.getNotes() : filteredNotes;
    filteredTags = searchQuery.isEmpty ? tagsController.tags : filteredTags;

    return AppPage(
        appBar: JwLifeAppBar(
          title: i18n().navigation_notes_and_tag,
          subTitle: i18n().label_tags_and_notes(formatNumber(filteredTags.length), formatNumber(filteredNotes.length)),
          actions: [
            IconTextButton(
              icon: Icon(JwIcons.note_plus),
              onPressed: (BuildContext context) async {
                Note note = await notesController.addNote();
                await showPage(NotePage(note: note));
              },
            ),
            IconTextButton(
              icon: Icon(JwIcons.tag_plus),
              onPressed: (BuildContext context) async {
                await showAddTagDialog(context, false);
              },
            ),
            IconTextButton(
              icon: Icon(JwIcons.arrow_circular_left_clock),
              onPressed: (BuildContext context) {
                History.showHistoryDialog(context);
              },
            ),
          ],
        ),
        body: CustomScrollView(
          physics: ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: TextField(
                  keyboardType: TextInputType.text,
                  // 🌟 LOGIQUE DE DEBOUNCING APPLIQUÉE ICI
                  onChanged: (value) {
                    // 1. Mettre à jour la valeur de recherche immédiatement
                    searchQuery = value;

                    // 2. Annuler le timer précédent s'il existe
                    if (_debounce?.isActive ?? false) _debounce!.cancel();

                    // 3. Démarrer un nouveau timer
                    _debounce = Timer(const Duration(milliseconds: 200), () {
                      // Exécuter le filtrage seulement après l'arrêt de la saisie
                      final normalizedQuery = normalize(searchQuery);

                      setState(() {
                        // 4. Filtrer les Tags
                        filteredTags = tagsController.tags.where((tag) {
                          final normalizedTagName = normalize(tag.name);
                          return normalizedTagName.contains(normalizedQuery);
                        }).toList();

                        // 5. Filtrer les Notes
                        filteredNotes = notesController.getNotes().where((note) {
                          final normalizedTitle = note.title != null
                              ? normalize(note.title!)
                              : '';

                          final normalizedContent = note.content != null
                              ? normalize(note.content!)
                              : '';

                          return normalizedTitle.contains(normalizedQuery) ||
                              normalizedContent.contains(normalizedQuery);
                        }).toList();
                      });
                    });
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: i18n().search_bar_search,
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    contentPadding: EdgeInsets.all(10),
                    visualDensity: VisualDensity.compact,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey), // reste gris même en focus
                    ),
                  ),
                  cursorColor: Colors.grey, // couleur du curseur si tu veux
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: -5,
                  children: [
                    // Afficher les catégories selon l'état
                    ...(showAllCategories ? filteredTags : filteredTags.take(10)).map((category) {
                      return ElevatedButton(
                        onPressed: () async {
                          await showPage(TagPage(tag: category));
                        },
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(Size(0, 30)),
                          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                            EdgeInsets.symmetric(horizontal: 20),
                          ),
                          backgroundColor: WidgetStateProperty.all<Color>(
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF292929)
                                : Color(0xFFd8d8d8),
                          ),
                        ),
                        child: Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF8b9fc1)
                                : Color(0xFF4a6da7),
                          ),
                        ),
                      );
                    }),
                    // Bouton "Mes X catégories" ou "Réduire"
                    if (filteredTags.length > 10)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showAllCategories = !showAllCategories;
                          });
                        },
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(Size(0, 30)),
                          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                            EdgeInsets.symmetric(horizontal: 20),
                          ),
                          backgroundColor: WidgetStateProperty.all<Color>(
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF3d3d3d)
                                : Color(0xFFc8c8c8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              showAllCategories
                                  ? i18n().action_collapse
                                  : i18n().label_all_tags(formatNumber(filteredTags.length)),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF9fb1d1)
                                    : Color(0xFF3a5d97),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              showAllCategories ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF9fb1d1)
                                  : Color(0xFF3a5d97),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                  final note = filteredNotes[index];

                  return _KeepAliveNoteItem(
                    key: ValueKey('note_${note.guid}'),
                    note: note,
                    onUpdated: () => setState(() {}),
                    // 🌟 TRANSMISSION du terme de recherche au widget enfant
                    searchQuery: searchQuery,
                  );
                },
                childCount: filteredNotes.length,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                addSemanticIndexes: true,
              ),
            ),
          ],
        )
    );
  }
}

class _KeepAliveNoteItem extends StatefulWidget {
  final Note note;
  final VoidCallback onUpdated;
  final String searchQuery;

  const _KeepAliveNoteItem({
    super.key,
    required this.note,
    required this.onUpdated,
    this.searchQuery = '', // Initialisé à vide par défaut
  });

  @override
  State<_KeepAliveNoteItem> createState() => _KeepAliveNoteItemState();
}

class _KeepAliveNoteItemState extends State<_KeepAliveNoteItem>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return NoteItemWidget(
      note: widget.note,
      tag: null,
      onUpdated: widget.onUpdated,
      fullNote: false,
      highlightQuery: widget.searchQuery,
    );
  }
}