import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/html_styles.dart';
import '../../../../widgets/image_cached_widget.dart';

class WolSearchTab extends StatefulWidget {
  final SearchModel model;

  const WolSearchTab({super.key, required this.model});

  @override
  _WolSearchTabState createState() => _WolSearchTabState();
}

class _WolSearchTabState extends State<WolSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  // ---------------------------------------------------------------------------
  //  BUILD ARTICLE — ASYNC (RENVOI WIDGET)
  // ---------------------------------------------------------------------------

  Future<Widget> _buildArticle(dynamic article) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ---- Extraction docId ----
    int docId = -1;
    try {
      String lastSegment = article['url'].toString().split('/').last;
      docId = int.parse(lastSegment.split('?').first);
    } catch (e) {
      debugPrint("Erreur parsing docId: $e");
    }

    // ---- Récupération Publication ----
    Publication? pub;
    if (docId != -1) {
      pub = await CatalogDb.instance.searchPubNoMepsFromMepsDocumentId(
        docId,
        JwLifeSettings.instance.currentLanguage.value.id,
      );
    }

    // ---- Image prioritaire : pub.imageSqr ----
    String? imageUrl;
    if (pub?.imageSqr != null && pub!.imageSqr!.isNotEmpty) {
      imageUrl = pub.imageSqr;
    } else if (article["documentImageUrl"] != null &&
        article["documentImageUrl"].toString().isNotEmpty) {
      imageUrl = "https://wol.jw.org/" + article["documentImageUrl"];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (docId != -1) {
              showDocumentView(
                context,
                docId,
                JwLifeSettings.instance.currentLanguage.value.id,
                wordsSelected: widget.model.query.split(' '),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------------------------------
                //     IMAGE (à gauche)
                // ---------------------------------------
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageUrl != null
                        ? ImageCachedWidget(
                      imageUrl: imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                        : Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 32,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ---------------------------------------
                //     CONTENU (à droite)
                // ---------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Titre de la publication (en haut) ----
                      if (pub?.title != null && pub!.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            pub.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // ---- Caption (titre de l'article) ----
                      if (article['caption'] != null &&
                          article['caption'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            article['caption'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // ---- Content HTML (extrait) ----
                      if (article['content'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: TextHtmlWidget(
                            text: article['content'],
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 3,
                          ),
                        ),

                      // ---- Reference (en bas) ----
                      if (article['reference'].toString().isNotEmpty)
                        Text(
                          article['reference'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                            letterSpacing: 0.1,
                          ),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  BUILD MAIN WIDGET
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchWolSearch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.blue[300]! : Colors.blue[700]!,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Une erreur est survenue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Essayez avec d\'autres termes de recherche',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final results = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[850] : Colors.grey[200],
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final article = results[index];

            return FutureBuilder<Widget>(
              future: _buildArticle(article),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    height: 96,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.grey[600]! : Colors.grey[400]!,
                        ),
                      ),
                    ),
                  );
                }
                return snapshot.data!;
              },
            );
          },
        );
      },
    );
  }
}