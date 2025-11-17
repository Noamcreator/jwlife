import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // 👈 NOUVEL IMPORT
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/pages/tag_page.dart';
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
  List<Note> allNotes = [];
  List<Note> filteredNotes = [];
  String searchQuery = ''; // Terme de recherche à mettre en évidence
  bool showAllCategories = false; // Pour afficher toutes les catégories

  // 🌟 DÉBOUNCING : Timer pour contrôler la fréquence de la recherche
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 🌟 Annuler le timer à la destruction du widget
    super.dispose();
  }

  void init() async {
    // Constante pour la taille du lot
    const batchSize = 2000;
    int offset = 0;
    bool moreNotes = true;
    List<Note> allFetchedNotes = [];

    // Début de la boucle de chargement
    while (moreNotes) {
      // 1. Récupération du lot de notes
      final notesBatch = await JwLifeApp.userdata.getNotes(
          limit: batchSize,
          offset: offset
      );

      if (notesBatch.isEmpty) {
        // 2. Fin de la récupération si le lot est vide
        moreNotes = false;
      } else {
        // 3. Ajout des notes récupérées à la liste complète
        allFetchedNotes.addAll(notesBatch);

        // 4. MISE À JOUR DE L'ÉTAT DE L'UI APRÈS CHAQUE LOT
        // Cela rafraîchit la liste avec les notes nouvellement chargées.
        setState(() {
          // Il est souvent préférable de créer une nouvelle liste
          // pour s'assurer que Flutter détecte le changement.
          allNotes = List.from(allFetchedNotes);
          // Si les filtres/tags n'ont pas encore été chargés, faites-le ici
          if (filteredTags.isEmpty) {
            filteredTags = JwLifeApp.userdata.tags;
          }
          filteredNotes = allNotes;
        });

        // 5. Préparation pour le prochain lot
        offset += batchSize;
      }
    }

    // NOTE : Un setState final n'est plus strictement nécessaire ici,
    // car le dernier lot (même s'il est incomplet) aura déclenché un setState.
    // Cependant, le laisser ne fait pas de mal.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n().navigation_notes_and_tag),
              Text(
                i18n().label_tags_and_notes(filteredTags.length, filteredNotes.length),
                style: TextStyle(fontSize: 12),
                maxLines: 2,
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(JwIcons.note_plus),
              onPressed: () async {
                Note? note = await JwLifeApp.userdata.addNote("", "", 0, [], null, null, null, null, null, null);
                if (note != null) {
                  await showPage(NotePage(note: note));
                  setState(() {
                    filteredNotes.insert(0, note);
                  });
                }
              },
            ),
            IconButton(
              icon: Icon(JwIcons.tag_plus),
              onPressed: () async {
                await showAddTagDialog(context, false);
                setState(() {
                  filteredTags = JwLifeApp.userdata.tags;
                });
              },
            ),
            IconButton(
              icon: Icon(JwIcons.arrow_circular_left_clock),
              onPressed: () {
                History.showHistoryDialog(context);
              },
            ),
          ],
        ),
        body: Scrollbar(
          interactive: true,
          child: CustomScrollView(
            physics: ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    // 🌟 LOGIQUE DE DEBOUNCING APPLIQUÉE ICI
                    onChanged: (value) {
                      // 1. Mettre à jour la valeur de recherche immédiatement
                      searchQuery = value;

                      // 2. Annuler le timer précédent s'il existe
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      // 3. Démarrer un nouveau timer
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        // Exécuter le filtrage seulement après l'arrêt de la saisie
                        final normalizedQuery = removeDiacritics(searchQuery.toLowerCase());

                        setState(() {
                          // 4. Filtrer les Tags
                          filteredTags = JwLifeApp.userdata.tags.where((tag) {
                            final normalizedTagName = removeDiacritics(tag.name.toLowerCase());
                            return normalizedTagName.contains(normalizedQuery);
                          }).toList();

                          // 5. Filtrer les Notes
                          filteredNotes = allNotes.where((note) {
                            final normalizedTitle = note.title != null
                                ? removeDiacritics(note.title!.toLowerCase())
                                : '';

                            final normalizedContent = note.content != null
                                ? removeDiacritics(note.content!.toLowerCase())
                                : '';

                            return normalizedTitle.contains(normalizedQuery) ||
                                normalizedContent.contains(normalizedQuery);
                          }).toList();
                        });
                      });
                    },
                    decoration: InputDecoration(
                      hintText: i18n().search_bar_search,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: -5,
                    children: [
                      // Afficher les catégories selon l'état
                      ...(showAllCategories ? filteredTags : filteredTags.take(10)).map((category) {
                        return ElevatedButton(
                          onPressed: () async {
                            await showPage(TagPage(tag: category));
                            setState(() {
                              filteredTags = JwLifeApp.userdata.tags;
                            });
                          },
                          style: ButtonStyle(
                            minimumSize: MaterialStateProperty.all<Size>(Size(0, 30)),
                            padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                              EdgeInsets.symmetric(horizontal: 20),
                            ),
                            backgroundColor: MaterialStateProperty.all<Color>(
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
                      }).toList(),
                      // Bouton "Mes X catégories" ou "Réduire"
                      if (filteredTags.length > 10)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showAllCategories = !showAllCategories;
                            });
                          },
                          style: ButtonStyle(
                            minimumSize: MaterialStateProperty.all<Size>(Size(0, 30)),
                            padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                              EdgeInsets.symmetric(horizontal: 20),
                            ),
                            backgroundColor: MaterialStateProperty.all<Color>(
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
                                    : i18n().label_all_tags(filteredTags.length),
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
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final note = filteredNotes[index];

                    return _KeepAliveNoteItem(
                      key: ValueKey('note_${note.noteId}'),
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
          ),
        )
    );
  }
}

class _KeepAliveNoteItem extends StatefulWidget {
  final Note note;
  final VoidCallback onUpdated;
  // 🌟 NOUVELLE PROPRIÉTÉ pour le terme de recherche
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
      // 🌟 TRANSMISSION au NoteItemWidget (nommé ici highlightQuery pour clarifier son rôle)
      highlightQuery: widget.searchQuery,
    );
  }
}