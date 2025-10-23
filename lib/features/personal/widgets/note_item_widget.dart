import 'package:flutter/material.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart'; // Import de diacritic

import '../../../app/jwlife_app.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/note.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../widgets/image_cached_widget.dart';
import '../pages/note_page.dart';
import '../pages/tag_page.dart';

class NoteItemWidget extends StatefulWidget {
  final Note note;
  final Tag? tag;
  final VoidCallback? onUpdated;
  final bool fullNote;
  final String? highlightQuery; // Terme de recherche à mettre en évidence

  const NoteItemWidget({
    super.key,
    required this.note,
    required this.tag,
    this.onUpdated,
    this.fullNote = false,
    this.highlightQuery,
  });

  static Future<Map<String, dynamic>> resolveNoteDependencies(Note note) async {
    String? keySymbol = note.location.keySymbol;
    int? issueTagNumber = note.location.issueTagNumber;
    int? mepsLanguageId = note.location.mepsLanguageId;

    if (keySymbol == null || issueTagNumber == null || mepsLanguageId == null) {
      return {'pub': null, 'docTitle': ''};
    }

    Publication? pub = PublicationRepository().getAllPublications().firstWhereOrNull((element) => element.keySymbol == note.location.keySymbol && element.issueTagNumber == note.location.issueTagNumber && element.mepsLanguage.id == note.location.mepsLanguageId);

    String docTitle = '';
    pub ??= await PubCatalog.searchPubNoMepsLanguage(note.location.keySymbol!, note.location.issueTagNumber!, note.location.mepsLanguageId!);

    if (pub != null) {
      if (pub.isDownloadedNotifier.value) {
        if(pub.isBible() && note.location.bookNumber != null && note.location.chapterNumber != null) {
          docTitle = JwLifeApp.bibleCluesInfo.getVerse(note.location.bookNumber!, note.location.chapterNumber!, note.blockIdentifier ?? 0);
        }
        else {
          if (pub.documentsManager == null) {
            final db = await openDatabase(pub.databasePath!);
            final rows = await db.rawQuery(
              'SELECT Title FROM Document WHERE MepsDocumentId = ?',
              [note.location.mepsDocumentId],
            );
            if (rows.isNotEmpty) {
              docTitle = rows.first['Title'] as String;
            }
          }
          else {
            final doc = pub.documentsManager!.documents.firstWhereOrNull((d) => d.mepsDocumentId == note.location.mepsDocumentId);
            docTitle = doc?.title ?? '';
          }
        }
      }
    }

    return {'pub': pub, 'docTitle': docTitle};
  }

  @override
  State<NoteItemWidget> createState() => _NoteItemWidgetState();

  // Fonction utilitaire pour la mise en évidence (AVEC DIACRITIC)
  Widget _buildHighlightedText(String text, String? query, TextStyle defaultStyle, TextStyle highlightStyle, {int? maxLines, TextOverflow? overflow}) {
    if (query == null || query.isEmpty) {
      return Text(text, style: defaultStyle, maxLines: maxLines, overflow: overflow ?? TextOverflow.ellipsis);
    }

    // Normalisation du texte et de la requête pour la recherche
    final normalizedText = removeDiacritics(text.toLowerCase());
    final normalizedQuery = removeDiacritics(query.toLowerCase());
    int firstMatchIndex = normalizedText.indexOf(normalizedQuery); // Recherche sur le texte normalisé

    String displayText = text;
    int searchStartOffset = 0; // Point de départ de la recherche dans le texte normalisé

    // Logic: Si maxLines est défini (mode aperçu) ET qu'il y a une correspondance
    if (maxLines != null && maxLines > 0 && firstMatchIndex != -1) {
      // Déterminer le point de départ: 40 caractères avant la correspondance (ou 0 si c'est au début)
      int charBeforeMatch = 40;
      searchStartOffset = (firstMatchIndex - charBeforeMatch).clamp(0, firstMatchIndex);

      // Le texte à afficher est tronqué. On utilise l'index trouvé (startOffset) pour tronquer le texte ORIGINAL.
      displayText = text.substring(searchStartOffset);

      // Ajouter des points de suspension au début si le texte a été tronqué
      if (searchStartOffset > 0) {
        displayText = '...$displayText';
      }
    }

    final List<TextSpan> spans = [];
    int start = 0;

    // Pour l'itération de RichText: nous devons normaliser le displayText pour trouver les occurrences dans cette sous-chaîne.
    final normalizedDisplayText = removeDiacritics(displayText.toLowerCase());

    while (start < normalizedDisplayText.length) {
      final index = normalizedDisplayText.indexOf(normalizedQuery, start);

      if (index == -1) {
        // Ajouter le reste du texte normal
        spans.add(TextSpan(text: displayText.substring(start), style: defaultStyle));
        break;
      }

      // Texte normal avant la correspondance
      if (index > start) {
        spans.add(TextSpan(text: displayText.substring(start, index), style: defaultStyle));
      }

      // Texte de la correspondance mis en évidence
      // On utilise la partie correspondante du texte ORIGINAL (displayText)
      spans.add(
        TextSpan(
          text: displayText.substring(index, index + query.length), // Utiliser query.length car c'est la longueur de la partie à mettre en évidence.
          style: highlightStyle,
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}

class _NoteItemWidgetState extends State<NoteItemWidget> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = NoteItemWidget.resolveNoteDependencies(widget.note);
  }

  // Mise à jour de _dataFuture lorsque la note change pour rafraîchir les dépendances
  @override
  void didUpdateWidget(covariant NoteItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != oldWidget.note) {
      _dataFuture = NoteItemWidget.resolveNoteDependencies(widget.note);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note.noteId == -1) return SizedBox.shrink();

    // Styles de mise en évidence
    final defaultTitleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    final highlightTitleStyle = defaultTitleStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.4),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.black, // Assurer la lisibilité
    );
    final defaultContentStyle = TextStyle(fontSize: 14);
    final highlightContentStyle = defaultContentStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.4),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.black,
    );

    final note = widget.note;
    final maxLinesContent = widget.fullNote ? null : (note.location.keySymbol != null ? 4 : 8);

    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            height: widget.fullNote ? null : 280,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        final pub = snapshot.data!['pub'] as Publication?;
        final docTitle = snapshot.data!['docTitle'] as String;
        final hasPub = pub != null;

        return GestureDetector(
          onTap: () async {
            // 🌟 MODIFICATION : Passe le highlightQuery à NotePage pour le défilement
            await showPage(NotePage(note: note, searchQuery: widget.highlightQuery));
            widget.onUpdated?.call();
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            height: widget.fullNote ? null : 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]!
                    : Colors.grey[300]!,
              ),
              color: note.getColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: widget.fullNote ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // Date
                Text(note.getRelativeTime(), style: TextStyle(fontSize: 10)),
                SizedBox(height: 4),

                // Titre : Utilisation de la fonction de mise en évidence
                widget._buildHighlightedText(
                  note.title ?? '',
                  widget.highlightQuery,
                  defaultTitleStyle,
                  highlightTitleStyle,
                  maxLines: widget.fullNote ? null : 1,
                  overflow: widget.fullNote ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                SizedBox(height: 10),

                // Contenu : Utilisation de la fonction de mise en évidence
                widget.fullNote
                    ? widget._buildHighlightedText(
                  note.content ?? '',
                  widget.highlightQuery,
                  defaultContentStyle,
                  highlightContentStyle,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                )
                    : Expanded(
                  child: widget._buildHighlightedText(
                    note.content ?? '',
                    widget.highlightQuery,
                    defaultContentStyle,
                    highlightContentStyle,
                    maxLines: hasPub ? 4 : 8, // Logique de lignes basée sur la présence de la pub
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 8),

                // Tags - MAINTENANT UNIFIÉ pour avoir une hauteur de 32 dans les deux modes
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: note.tagsId.map((t) {
                      final tag = JwLifeApp.userdata.tags.firstWhereOrNull((tg) => tg.id == t);
                      if (tag == null) return SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: _buildTagButton(context, tag),
                      );
                    }).toList(),
                  ),
                ),

                // Publication (si existe)
                if (hasPub) ...[
                  const SizedBox(height: 8),
                  Divider(thickness: 1, color: Colors.grey, height: 1),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      if (note.location.mepsDocumentId != null) {
                        showDocumentView(
                          context,
                          note.location.mepsDocumentId!,
                          note.location.mepsLanguageId!,
                          startParagraphId: note.blockIdentifier,
                          endParagraphId: note.blockIdentifier,
                        );
                      }
                      else if (note.location.bookNumber != null && note.location.chapterNumber != null) {
                        showChapterView(
                            context,
                            note.location.keySymbol!,
                            note.location.mepsLanguageId!,
                            note.location.bookNumber!,
                            note.location.chapterNumber!,
                            firstVerseNumber: note.blockIdentifier,
                            lastVerseNumber: note.blockIdentifier
                        );
                      }
                    },
                    child: Row(
                      children: [
                        ImageCachedWidget(
                          imageUrl: pub.imageSqr,
                          icon: pub.category.icon,
                          height: 30,
                          width: 30,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docTitle.isEmpty ? pub.getShortTitle() : docTitle,
                                style: TextStyle(fontSize: 14, height: 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                docTitle.isEmpty ? pub.getSymbolAndIssue() : pub.getShortTitle(),
                                style: TextStyle(fontSize: 11, height: 1, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagButton(BuildContext context, Tag tag) {
    return ElevatedButton(
      onPressed: () async {
        if(widget.tag != null && tag.id == widget.tag!.id) return;
        await showPage(TagPage(tag: tag));
        widget.onUpdated?.call();
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xEE1e1e1e)
            : Color(0xFFe8e8e8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
        elevation: 0,
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF8b9fc1)
              : Color(0xFF4a6da7),
        ),
      ),
    );
  }
}