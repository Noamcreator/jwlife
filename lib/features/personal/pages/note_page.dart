import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/controller/notes_controller.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_search.dart';
import '../../../data/databases/catalog.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../i18n/i18n.dart';

List<TextSpan> _buildHighlightedTextSpans(
    String text, String? query, TextStyle defaultStyle, Color highlightColor) {
  if (query == null || query.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: defaultStyle)];
  }

  // Rendre la recherche insensible à la casse et aux accents
  final normalizedText = normalize(text);
  final normalizedQuery = normalize(query);

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

  late NotesController _notesController;
  late TagsController _tagsController;

  @override
  void initState() {
    super.initState();

    _note = widget.note;

    _notesController = context.read<NotesController>();
    _tagsController = context.read<TagsController>();

    _scrollController = ScrollController();

    // 🌟 TITRE : Utilisation du HighlightedTextControlle
    const defaultTitleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 22);
    _titleController = HighlightedTextController(
      text: _note.title,
      searchQuery: widget.searchQuery,
      highlightColor: Colors.yellow.withOpacity(0.5),
      defaultStyle: defaultTitleStyle,
    );
    _titleController.addListener(() {
      _notesController.updateNote(_note.guid, _titleController.text, _contentController.text);
      if (widget.searchQuery != null && _titleController.searchQuery != null) {
        _titleController.searchQuery = null;
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
      _notesController.updateNote(_note.guid, _titleController.text, _contentController.text);
      if (widget.searchQuery != null && _contentController.searchQuery != null) {
        _contentController.searchQuery = null;
        setState(() {});
      }
    });

    _categoriesController = TextEditingController();
    _categoriesController.addListener(() {
      _removeOverlay();
      _showOverlay();
    });

    _dataFuture = resolveDependenciesCached(widget.note);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToQuery();

      // Affiche le widget avec la note sur la page principale
      JwLifeApp.noteController.show(widget.note);
    });
  }

  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> resolveDependenciesCached(Note note) async {
    if (_cache.containsKey(note.guid)) return _cache[note.guid]!;

    final loc = note.location;


    Publication? pub;
    Media? media;
    String docTitle = '';

    if(loc.type == 1 || loc.type == 0) {
      pub = PublicationRepository().getAllPublications().firstWhereOrNull((p) => p.keySymbol == loc.keySymbol && p.issueTagNumber == loc.issueTagNumber && p.mepsLanguage.id == loc.mepsLanguageId);

      pub ??= await CatalogDb.instance.searchPubNoMepsLanguage(loc.keySymbol!,loc.issueTagNumber!, loc.mepsLanguageId!);

      if (pub != null && pub.isDownloadedNotifier.value) {
        if (pub.isBible() &&
            loc.bookNumber != null &&
            loc.chapterNumber != null) {
          docTitle = JwLifeApp.bibleCluesInfo.getVerse(
            loc.bookNumber!,
            loc.chapterNumber!,
            note.blockIdentifier ?? 0,
          );
        } 
        else {
          if (pub.documentsManager == null) {
            final db = await openReadOnlyDatabase(pub.databasePath!);
            final rows = await db.rawQuery(
              'SELECT Title FROM Document WHERE MepsDocumentId = ?',
              [loc.mepsDocumentId],
            );
            if (rows.isNotEmpty) docTitle = rows.first['Title'] as String;
          } 
          else {
            final doc = pub.documentsManager!.documents.firstWhereOrNull((d) => d.mepsDocumentId == loc.mepsDocumentId);
            docTitle = doc?.title ?? '';
          }
        }
      }
    }
    else if (loc.type == 2 || loc.type == 3) {
      RealmMediaItem? realmMediaItem = getMediaItem(loc.keySymbol, loc.track, loc.mepsDocumentId, loc.issueTagNumber, loc.mepsLanguageId);
      if (realmMediaItem != null) {
        if(realmMediaItem.type == 'AUDIO') {
          media = Audio.fromJson(mediaItem: realmMediaItem);
        }
        else {
          media = Video.fromJson(mediaItem: realmMediaItem);
        }
      }
    }
 
    return _cache[note.guid] = {'pub': pub, 'media': media, 'docTitle': docTitle};
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
    final normalizedContent = normalize(content);
    final normalizedQuery = normalize(widget.searchQuery!);

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
    final allAvailableTags = _tagsController.tags.where((tag) => !_note.tagsId.contains(tag.id));

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
      builder: (context) => PositionedDirectional(
        start: position.dx,
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
                      '${i18n().action_add_a_tag} "${_categoriesController.text.trim()}"',
                      style: TextStyle(fontSize: 15),
                    ),
                    onTap: () async {
                      Tag tag = await _tagsController.addTag(_categoriesController.text);
                      _notesController.addTagIdToNote(_note.guid, tag.id);

                      setState(() {
                        _categoriesController.clear();
                        _showCategoryInput = false;
                      });
                      _removeOverlay();
                    },
                  );
                }

                // Sinon → élément de filteredTags
                final tag = filteredTags[showAdd ? index - 1 : index];
                return ListTile(
                  dense: true,
                  title: Text(tag.name, style: TextStyle(fontSize: 15)),
                  onTap: () async {
                    _notesController.addTagIdToNote(_note.guid, tag.id);
                    setState(() {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppPage(
      isNotePage: true,
      backgroundColor: _note.getColor(context),
      appBar: AppBar(
        backgroundColor: _note.getColor(context),
        titleSpacing: 0.0,
        leading: IconButton(
            icon: Icon(JwIcons.chevron_down, color: isDark ? Colors.white : Color(0xFF626262)),
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
              GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
            }
        ),
        actions: [
          PopupMenuButton(
            icon: Icon(JwIcons.three_dots_horizontal, color: isDark ? Colors.white : Color(0xFF626262)),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text(i18n().action_delete),
                  onTap: () {
                    Navigator.pop(context);
                    GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
                    _notesController.removeNote(_note.guid);
                  },
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  title: Text(i18n().action_change_color),
                  onTap: () {},
                  trailing: DropdownButton<int>(
                    dropdownColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF292929)
                        : Color(0xFFf1f1f1),
                    value: _note.colorIndex,
                    onChanged: (int? newValue) {
                      Navigator.pop(context);
                      if (newValue != null) {
                        setState(() {
                          widget.note.colorIndex = newValue;
                        });
                        _notesController.changeNoteColor(_note.guid, 0, newValue);
                      }
                    },
                    items: List.generate(9, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Container(
                          width: 20,
                          height: 20,
                          color: _note.getIndicatorColor(context, colorId: index),
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
                        hintText: i18n().label_note_title,
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
                        hintText: i18n().label_note,
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
                      children: (context.watch<NotesController>().notes.firstWhereOrNull((note) => note.guid == _note.guid)?.tagsId ?? []).map<Widget>((tagId) {
                        Tag? tag = context.watch<TagsController>().tags.firstWhereOrNull((tag) => tag.id == tagId);
                        if (tag == null) return SizedBox.shrink();
                        return Chip(
                          shape: StadiumBorder(),
                          side: BorderSide(color: color, width: 1),
                          label: Text(tag.name, style: TextStyle(fontSize: 15)),
                          backgroundColor: color,
                          deleteIcon: Icon(JwIcons.x, size: 18),
                          onDeleted: () async {
                            _notesController.removeTagIdFromNote(_note.guid, tagId);
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
                                  Tag tag = await _tagsController.addTag(value);
                                  _notesController.addTagIdToNote(_note.guid, tag.id);

                                  setState(() {
                                    _categoriesController.clear();
                                    _showCategoryInput = false;
                                  });
                                  _removeOverlay();
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                // On vérifie si les données sont présentes
                if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();

                final data = snapshot.data!;
                final pub = data['pub'];
                final media = data['media'];
                final docTitle = data['docTitle'] ?? '';

                // 🌟 BLOC DE PUBLICATION
                if (pub != null || media != null) {
                  // AJOUT DU RETURN ICI
                  return Column(
                    mainAxisSize: MainAxisSize.min, // Évite de prendre trop de place verticalement
                    children: [
                      const SizedBox(height: 12),
                      const Divider(thickness: 1, color: Colors.grey),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          final loc = widget.note.location;

                          if (loc.mepsDocumentId != null) {
                            showDocumentView(
                              context,
                              loc.mepsDocumentId!,
                              loc.mepsLanguageId!,
                              startParagraphId: widget.note.blockIdentifier,
                              endParagraphId: widget.note.blockIdentifier,
                            );
                          } else if (loc.bookNumber != null && loc.chapterNumber != null) {
                            showChapterView(
                              context,
                              loc.keySymbol!,
                              loc.mepsLanguageId!,
                              loc.bookNumber!,
                              loc.chapterNumber!,
                              firstVerseNumber: widget.note.blockIdentifier,
                              lastVerseNumber: widget.note.blockIdentifier,
                            );
                          } else if (loc.type == 2) {
                            final mediaItem = getAudioItem(
                              loc.keySymbol,
                              loc.track,
                              loc.mepsDocumentId,
                              loc.issueTagNumber,
                              loc.mepsLanguageId,
                            );
                            if (mediaItem != null) {
                              Audio.fromJson(mediaItem: mediaItem).showPlayer(context);
                            }
                          } else if (loc.type == 3) {
                            final mediaItem = getMediaItem(
                              loc.keySymbol,
                              loc.track,
                              loc.mepsDocumentId,
                              loc.issueTagNumber,
                              loc.mepsLanguageId,
                            );
                            if (mediaItem != null) {
                              Video.fromJson(mediaItem: mediaItem).showPlayer(context);
                            }
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 10, 
                            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Row(
                            children: [
                              ImageCachedWidget(
                                imageUrl: pub?.imageSqr ?? (media?.networkImageSqr ?? media?.imagePath),
                                icon: pub != null 
                                    ? pub.category.icon 
                                    : (media is Audio ? JwIcons.headphones__simple : JwIcons.video),
                                height: 35,
                                width: 35,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pub != null 
                                          ? (docTitle.isEmpty ? pub.getShortTitle() : docTitle) 
                                          : (media?.title ?? ''),
                                      style: const TextStyle(fontSize: 14, height: 1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      pub != null 
                                          ? (docTitle.isEmpty ? pub.getSymbolAndIssue() : pub.getShortTitle()) 
                                          : (media is Audio 
                                              ? i18n().pub_type_audio_programs 
                                              : (media is Video ? i18n().label_videos : media?.title ?? '')),
                                      style: const TextStyle(fontSize: 11, height: 1, color: Color(0xFFA0A0A0)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Si aucune donnée pub ou media, on retourne un widget vide
                return const SizedBox.shrink();
              },
            ),
          )
        ],
      ),
    );
  }
}