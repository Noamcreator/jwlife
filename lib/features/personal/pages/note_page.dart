import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/widgets/note_item_widget.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:diacritic/diacritic.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_search.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/tag.dart';

// --------------------------------------------------------------------------
// 🌟 FONCTION UTILITAIRE POUR CRÉER LES TEXTSPANS SURLIGNÉS
// --------------------------------------------------------------------------
List<TextSpan> _buildHighlightedTextSpans(
    String text, String? query, TextStyle defaultStyle, Color highlightColor) {
  if (query == null || query.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: defaultStyle)];
  }

  // Rendre la recherche insensible à la casse et aux accents
  final normalizedText = removeDiacritics(text.toLowerCase());
  final normalizedQuery = removeDiacritics(query.toLowerCase());

  final List<TextSpan> spans = [];
  int currentPosition = 0;
  int startMatch = normalizedText.indexOf(normalizedQuery, currentPosition);

  while (startMatch != -1) {
    // 1. Ajouter le texte avant la correspondance (style normal)
    if (startMatch > currentPosition) {
      spans.add(
        TextSpan(
          text: text.substring(currentPosition, startMatch),
          style: defaultStyle,
        ),
      );
    }

    // 2. Ajouter la correspondance (style surligné)
    final endMatch = startMatch + normalizedQuery.length;
    spans.add(
      TextSpan(
        text: text.substring(startMatch, endMatch),
        style: defaultStyle.copyWith(backgroundColor: highlightColor), // Surlignage
      ),
    );

    currentPosition = endMatch;
    startMatch = normalizedText.indexOf(normalizedQuery, currentPosition);
  }

  // 3. Ajouter le reste du texte après la dernière correspondance (style normal)
  if (currentPosition < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(currentPosition),
        style: defaultStyle,
      ),
    );
  }

  return spans;
}


// --------------------------------------------------------------------------
// 🌟 CONTROLLER PERSONNALISÉ POUR LE SURLIGNAGE DANS LE TEXTFIELD
// --------------------------------------------------------------------------
class HighlightedTextController extends TextEditingController {
  String? searchQuery;
  final Color highlightColor;
  final TextStyle defaultStyle;

  HighlightedTextController({
    super.text,
    this.searchQuery,
    required this.highlightColor,
    required this.defaultStyle,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Récupère les TextSpan générés par la fonction utilitaire
    final children = _buildHighlightedTextSpans(
      text,
      searchQuery,
      defaultStyle,
      highlightColor,
    );

    return TextSpan(
      style: style, // Le style du TextField lui-même
      children: children,
    );
  }
}


class NotePage extends StatefulWidget {
  final Note note;
  final String? searchQuery;

  const NotePage({super.key, required this.note, this.searchQuery});

  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late Note _note;
  // Les deux contrôleurs utiliseront le type HighlightedTextController
  late HighlightedTextController _titleController;
  late HighlightedTextController _contentController;
  late TextEditingController _categoriesController;
  late Future<Map<String, dynamic>> _dataFuture;

  final GlobalKey _inputKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool _showCategoryInput = false;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _note = widget.note;

    _scrollController = ScrollController();

    // 🌟 TITRE : Utilisation du HighlightedTextController
    const defaultTitleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 22);
    _titleController = HighlightedTextController(
      text: _note.title,
      searchQuery: widget.searchQuery,
      highlightColor: Colors.yellow.withOpacity(0.5),
      defaultStyle: defaultTitleStyle,
    );
    _titleController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
      if (widget.searchQuery != null && _titleController.searchQuery != null) {
        _titleController.searchQuery = null; // Retire le surlignage lors de l'édition
        // 🌟 CORRECTION : Force le rebuild pour retirer le surlignage
        setState(() {});
      }
    });

    // 🌟 CONTENU : Utilisation du HighlightedTextController
    const defaultContentStyle = TextStyle(fontSize: 20);
    _contentController = HighlightedTextController(
      text: _note.content,
      searchQuery: widget.searchQuery,
      highlightColor: Colors.yellow.withOpacity(0.5),
      defaultStyle: defaultContentStyle,
    );
    _contentController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
      if (widget.searchQuery != null && _contentController.searchQuery != null) {
        _contentController.searchQuery = null; // Retire le surlignage lors de l'édition
        // 🌟 CORRECTION : Force le rebuild pour retirer le surlignage
        setState(() {});
      }
    });

    _categoriesController = TextEditingController();
    _categoriesController.addListener(() {
      _removeOverlay();
      _showOverlay();
    });

    _dataFuture = NoteItemWidget.resolveNoteDependencies(widget.note);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToQuery();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _titleController.dispose();
    _contentController.dispose();
    _categoriesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // 🌟 CORRECTION : Utilise TextPainter pour un défilement précis
  void _scrollToQuery() {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) return;

    final content = _note.content ?? '';
    if (content.isEmpty) return;

    // Utiliser removeDiacritics pour une recherche insensible aux accents
    final normalizedContent = removeDiacritics(content.toLowerCase());
    final normalizedQuery = removeDiacritics(widget.searchQuery!.toLowerCase());

    final firstMatchIndex = normalizedContent.indexOf(normalizedQuery);

    if (firstMatchIndex == -1) return;

    // 1. Déterminer la taille de la zone de rendu du TextField
    final RenderBox? renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double contentWidth = renderBox.size.width;

    // 2. Utiliser TextPainter pour calculer la position de la ligne exacte
    final textPainter = TextPainter(
      text: TextSpan(
        text: content.substring(0, firstMatchIndex), // Texte jusqu'au début de la correspondance
        style: const TextStyle(fontSize: 20), // Utiliser le style exact du TextField (défini dans defaultContentStyle)
      ),
      textDirection: TextDirection.ltr,
    );

    // Déterminer la contrainte de largeur pour simuler le wrapping
    textPainter.layout(maxWidth: contentWidth);

    // La hauteur calculée est l'offset jusqu'au début de la ligne de la correspondance
    final scrollOffset = textPainter.height;

    // 3. Calculer l'offset final pour centrer approximativement
    // On soustrait une partie de la hauteur de l'écran pour remonter l'élément.
    final offsetToScrollTo = (scrollOffset - (MediaQuery.of(context).size.height / 3)).clamp(0.0, _scrollController.position.maxScrollExtent);

    // Défilement animé
    _scrollController.animateTo(
      offsetToScrollTo,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _showOverlay() {
    if (!_showCategoryInput) return;

    final renderBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final String searchText = _categoriesController.text.trim();
    // Tags disponibles qui ne sont pas déjà dans la note
    final allAvailableTags = JwLifeApp.userdata.tags.where((tag) => !_note.tagsId.contains(tag.id));

    // Utilisation de getFilteredTags qui doit utiliser removeDiacritics pour être cohérent avec NotesTagsPage
    final filteredTags = searchText.isEmpty
        ? allAvailableTags.toList() // Affiche toutes les tags disponibles si le champ est vide
        : getFilteredTags(searchText, _note.tagsId).toList(); // Filtre les tags si l'utilisateur a tapé

    // Vérifie si on doit afficher le bouton "Ajouter"
    final showAdd = searchText.isNotEmpty && !filteredTags.any((tag) => tag.name.toLowerCase() == searchText.toLowerCase());

    _removeOverlay(); // Supprime l’ancien overlay

    final totalItemCount = (showAdd ? 1 : 0) + filteredTags.length;
    final visibleCount = totalItemCount.clamp(0, 5);
    final itemHeight = 48.0;
    final spacing = 12.0;

    final totalHeight = visibleCount * itemHeight + spacing;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy - totalHeight, // Décale VERS LE HAUT
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey[900],
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: itemHeight * 5),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: (showAdd ? 1 : 0) + filteredTags.length,
              itemBuilder: (context, index) {
                // Si showAdd est activé et que l'index est 0 → bouton "Ajouter"
                if (showAdd && index == 0) {
                  return ListTile(
                    dense: true,
                    leading: Icon(JwIcons.plus),
                    title: Text(
                      "Ajouter la catégorie '${_categoriesController.text.trim()}'",
                      style: TextStyle(fontSize: 15),
                    ),
                    onTap: () async {
                      Tag? tag = await JwLifeApp.userdata
                          .addTag(_categoriesController.text, 1);
                      if (tag != null) {
                        await JwLifeApp.userdata
                            .addTagToNoteWithGuid(_note.guid, tag.id);
                        setState(() {
                          _note.tagsId.add(tag.id);
                          _categoriesController.clear();
                          _showCategoryInput = false;
                        });
                        _removeOverlay();
                      }
                    },
                  );
                }

                // Sinon → élément de filteredTags
                final tag = filteredTags[showAdd ? index - 1 : index];
                return ListTile(
                  dense: true,
                  title: Text(tag.name, style: TextStyle(fontSize: 15)),
                  onTap: () async {
                    await JwLifeApp.userdata.addTagToNoteWithGuid(_note.guid, tag.id);
                    setState(() {
                      _note.tagsId.add(tag.id);
                      _categoriesController.clear();
                      _showCategoryInput = false;
                    });
                    _removeOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, debugRequiredFor: widget).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    Color color = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF292929)
        : Color(0xFFe9e9e9);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _note.getColor(context),
      appBar: AppBar(
        backgroundColor: _note.getColor(context),
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // 2. Vérifie si un champ de texte a le focus (clavier ouvert) et le ferme
              if (FocusScope.of(context).hasFocus) {
                FocusScope.of(context).unfocus();
              }

              if (_showCategoryInput) {
                setState(() {
                  _showCategoryInput = false;
                });
                _removeOverlay();
              }

              // 3. Effectue la navigation après avoir fermé tout ce qui est ouvert
              GlobalKeyService.jwLifePageKey.currentState?.handleBack(context, result: _note);
            }
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text('Supprimer'),
                  onTap: () async {
                    await JwLifeApp.userdata.deleteNote(_note);
                    _note.noteId = -1;
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  title: Text('Changer la couleur'),
                  onTap: () {},
                  trailing: DropdownButton<int>(
                    dropdownColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF292929)
                        : Color(0xFFf1f1f1),
                    value: _note.colorIndex,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        _note.colorIndex = newValue;
                        JwLifeApp.userdata.updateNote(_note, _titleController.text,
                            _contentController.text,
                            colorIndex: newValue)
                            .then((updatedNote) {
                          setState(() {
                            _note = updatedNote;
                          });
                        });
                      }
                    },
                    items: List.generate(7, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Container(
                          width: 20,
                          height: 20,
                          color: _note.getColor(context, colorId: index),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // 🌟 CORRECTION : Le body est maintenant une Column pour fixer le bas
      body: Column(
        children: [
          // 1. ZONE DE TEXTE DÉFILANTE (TITRE, CONTENU, TAGS)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showCategoryInput) {
                  setState(() {
                    _showCategoryInput = false;
                  });
                  _removeOverlay();
                  FocusScope.of(context).unfocus();
                }
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🌟 TITRE
                    TextField(
                      controller: _titleController,
                      maxLines: null,
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Titre',
                        hintStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Color(0xFF757575)),
                      ),
                    ),
                    SizedBox(height: 10),
                    // 🌟 CONTENU
                    TextField(
                      key: _contentKey, // Clé utilisée par _scrollToQuery
                      controller: _contentController,
                      maxLines: null,
                      style: TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Note',
                        hintStyle:
                        TextStyle(fontSize: 22, color: Color(0xFF757575)),
                      ),
                    ),
                    SizedBox(height: 10),
                    // 🌟 TAGS EXISTANTS
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: _note.tagsId.map<Widget>((tagId) {
                        Tag tag = JwLifeApp.userdata.tags.firstWhere((tag) => tag.id == tagId);
                        return Chip(
                          shape: StadiumBorder(),
                          side: BorderSide(color: color, width: 1),
                          label: Text(tag.name, style: TextStyle(fontSize: 15)),
                          backgroundColor: color,
                          deleteIcon: Icon(JwIcons.x, size: 18),
                          onDeleted: () async {
                            await JwLifeApp.userdata
                                .removeTagFromNoteWithGuid(_note.guid, tag.id);
                            setState(() {
                              _note.tagsId.remove(tagId);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // 🌟 INPUT DE CATÉGORIE
                    if (_showCategoryInput)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: _inputKey,
                              controller: _categoriesController,
                              autofocus: true,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (value) async {
                                if (value.trim().isNotEmpty) {
                                  Tag? tag = await JwLifeApp.userdata
                                      .addTag(value, 1);
                                  if (tag != null) {
                                    await JwLifeApp.userdata
                                        .addTagToNoteWithGuid(
                                        _note.guid, tag.id);
                                    setState(() {
                                      _note.tagsId.add(tag.id);
                                      _categoriesController.clear();
                                      _showCategoryInput = false;
                                    });
                                    _removeOverlay();
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showCategoryInput = true;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _showOverlay();
                          });
                        },
                        label: Icon(JwIcons.plus,
                            size: 22,
                            color: Theme.of(context).brightness ==
                                Brightness.light
                                ? Colors.black
                                : Colors.white),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Theme.of(context).brightness ==
                                  Brightness.light
                                  ? Colors.black
                                  : Colors.white),
                          shape: CircleBorder(),
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // 2. ZONE FIXE EN BAS (SÉPARATEUR ET PUBLICATION)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Divider(thickness: 1, color: Colors.grey), // SÉPARATEUR
                FutureBuilder<Map<String, dynamic>>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return SizedBox.shrink();

                    final pub = snapshot.data!['pub'] as Publication?;
                    final docTitle = snapshot.data!['docTitle'] as String;

                    if (pub == null) return SizedBox.shrink();

                    // 🌟 BLOC DE PUBLICATION
                    return InkWell(
                      onTap: () {
                        if (_note.location.mepsDocumentId != null) {
                          showDocumentView(
                            context,
                            _note.location.mepsDocumentId!,
                            _note.location.mepsLanguageId!,
                            startParagraphId: _note.blockIdentifier,
                            endParagraphId: _note.blockIdentifier,
                          );
                        } else if (_note.location.bookNumber != null &&
                            _note.location.chapterNumber != null) {
                          showChapterView(
                            context,
                            _note.location.keySymbol!,
                            _note.location.mepsLanguageId!,
                            _note.location.bookNumber!,
                            _note.location.chapterNumber!,
                            firstVerseNumber: _note.blockIdentifier,
                            lastVerseNumber: _note.blockIdentifier,
                          );
                        }
                      },
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            children: [
                              ImageCachedWidget(
                                imageUrl: pub.imageSqr,
                                icon: pub.category.icon,
                                height: 35,
                                width: 35,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docTitle.isEmpty
                                          ? pub.getShortTitle()
                                          : docTitle,
                                      style: TextStyle(fontSize: 16, height: 1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      docTitle.isEmpty
                                          ? pub.getSymbolAndIssue()
                                          : pub.getShortTitle(),
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1,
                                          color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    );
                  },
                ),
                // Padding en bas pour le cas où le clavier est fermé
                const SizedBox(height: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}