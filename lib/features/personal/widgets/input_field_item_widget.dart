import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';

import '../../../core/utils/utils_document.dart';
import '../../../data/models/publication.dart';
import '../../../data/databases/catalog.dart';
import '../../../data/models/userdata/input_field.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../widgets/image_cached_widget.dart';


/// Widget pour afficher un élément InputField.
/// Reprend la logique de résolution de dépendance de publication de NoteItemWidget.
class InputFieldItemWidget extends StatefulWidget {
  final InputField inputField;
  final VoidCallback? onUpdated;
  final bool fullField;
  final String? highlightQuery; // Terme de recherche à mettre en évidence

  const InputFieldItemWidget({
    super.key,
    required this.inputField,
    this.onUpdated,
    this.fullField = false,
    this.highlightQuery,
  });

  /// Résout les dépendances de publication/document pour l'emplacement de l'InputField.
  /// (Réutilisation de la logique de NoteItemWidget)
  static Future<Map<String, dynamic>> resolveFieldDependencies(InputField inputField) async {
    String? keySymbol = inputField.location.keySymbol;
    int? issueTagNumber = inputField.location.issueTagNumber;
    int? mepsLanguageId = inputField.location.mepsLanguageId;

    if (keySymbol == null || issueTagNumber == null || mepsLanguageId == null) {
      return {'pub': null, 'docTitle': ''};
    }

    Publication? pub = PublicationRepository().getAllPublications().firstWhereOrNull((element) =>
    element.keySymbol == inputField.location.keySymbol &&
        element.issueTagNumber == inputField.location.issueTagNumber &&
        element.mepsLanguage.id == inputField.location.mepsLanguageId
    );

    String docTitle = '';
    pub ??= await CatalogDb.instance.searchPubNoMepsLanguage(inputField.location.keySymbol!, inputField.location.issueTagNumber!, inputField.location.mepsLanguageId!);

    if (pub != null) {
      if (pub.isDownloadedNotifier.value) {
        if (pub.documentsManager == null) {
          final db = await openReadOnlyDatabase(pub.databasePath!);
          final rows = await db.rawQuery(
            'SELECT Title FROM Document WHERE MepsDocumentId = ?',
            [inputField.location.mepsDocumentId],
          );
          if (rows.isNotEmpty) {
            docTitle = rows.first['Title'] as String;
          }
        }
        else {
          final doc = pub.documentsManager!.documents.firstWhereOrNull((d) => d.mepsDocumentId == inputField.location.mepsDocumentId);
          docTitle = doc?.title ?? '';
        }
      }
    }

    return {'pub': pub, 'docTitle': docTitle};
  }

  @override
  State<InputFieldItemWidget> createState() => _InputFieldItemWidgetState();

  // Fonction utilitaire pour la mise en évidence (copiée de NoteItemWidget)
  Widget _buildHighlightedText(String text, String? query, TextStyle defaultStyle, TextStyle highlightStyle, {int? maxLines, TextOverflow? overflow}) {
    if (query == null || query.isEmpty) {
      return Text(text, style: defaultStyle, maxLines: maxLines, overflow: overflow ?? TextOverflow.ellipsis);
    }

    // Normalisation du texte et de la requête pour la recherche
    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);
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
    final normalizedDisplayText = normalize(displayText);

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

class _InputFieldItemWidgetState extends State<InputFieldItemWidget> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = InputFieldItemWidget.resolveFieldDependencies(widget.inputField);
  }

  // Mise à jour de _dataFuture lorsque l'inputField change
  @override
  void didUpdateWidget(covariant InputFieldItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inputField != oldWidget.inputField) {
      _dataFuture = InputFieldItemWidget.resolveFieldDependencies(widget.inputField);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultContentStyle = TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black);
    final highlightContentStyle = defaultContentStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.4),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.black,
    );

    final inputField = widget.inputField;
    final maxLinesContent = widget.fullField ? null : 11; // On simplifie les maxLines car pas de tags

    // Seulement afficher si il y a du contenu
    if (inputField.content == null || inputField.content!.trim().isEmpty) {
      return SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            height: widget.fullField ? null : 200, // Hauteur réduite car moins d'info que Note
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
            widget.onUpdated?.call();
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            // Pas de hauteur fixe pour éviter les problèmes de débordement
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]!
                    : Colors.grey[300]!,
              ),
              color: Theme.of(context).cardColor, // Utilisation de la couleur de carte par défaut
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // S'adapte au contenu
              children: [
                // Contenu : Utilisation de la fonction de mise en évidence
                widget.fullField
                    ? widget._buildHighlightedText(
                  inputField.content!,
                  widget.highlightQuery,
                  defaultContentStyle,
                  highlightContentStyle,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                )
                    : widget._buildHighlightedText(
                  inputField.content!,
                  widget.highlightQuery,
                  defaultContentStyle,
                  highlightContentStyle,
                  maxLines: maxLinesContent,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),

                // Publication (si existe)
                if (hasPub) ...[
                  const SizedBox(height: 8),
                  Divider(thickness: 1, color: Colors.grey, height: 1),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      // Logique pour ouvrir la publication à l'emplacement
                      if (inputField.location.mepsDocumentId != null) {
                        showDocumentView(
                          context,
                          inputField.location.mepsDocumentId!,
                          inputField.location.mepsLanguageId!,
                          textTag: inputField.textTag,
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
}