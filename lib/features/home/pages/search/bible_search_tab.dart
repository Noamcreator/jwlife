import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/html_styles.dart';
import '../../../../core/utils/widgets_utils.dart';
import '../../../../data/models/publication.dart';
import 'search_model.dart';

class BibleSearchTab extends StatefulWidget {
  final SearchModel model;

  const BibleSearchTab({super.key, required this.model});

  @override
  _BibleSearchTabState createState() => _BibleSearchTabState();
}

class _BibleSearchTabState extends State<BibleSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchBible(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return getLoadingWidget(Theme.of(context).primaryColor);
        } else if (snapshot.hasError) {
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
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                    'Aucun résultat trouvé',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  String itemString = item['lank'];
                  String itemString2 = itemString.split("-")[1].split("_")[0];

                  int bookNumber = int.parse(itemString2.substring(0, 2));
                  int chapterNumber = int.parse(itemString2.substring(2, 5));
                  int verseNumber = int.parse(itemString2.substring(5, 8));

                  final publications = PublicationRepository().getAllDownloadedPublications().where((pub) => pub.category.id == 1 && pub.mepsLanguage.symbol == JwLifeSettings.instance.libraryLanguage.value.symbol).toList();
                  Publication? latestBible = publications.isEmpty ? null : publications.reduce((a, b) => a.year > b.year ? a : b);

                  List<String> wordsSelected = widget.model.query.split(' ');
                  showChapterView(
                    context,
                    latestBible?.keySymbol ?? 'nwtsty',
                    JwLifeSettings.instance.libraryLanguage.value.id,
                    bookNumber,
                    chapterNumber,
                    firstVerseNumber: verseNumber,
                    lastVerseNumber: verseNumber,
                    wordsSelected: wordsSelected,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Référence biblique (titre)
                      TextHtmlWidget(
                        text: item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? const Color(0xFF9AB5E0) : const Color(0xFF4a6da7),
                          letterSpacing: -0.1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Snippet du verset
                      TextHtmlWidget(
                        text: item['snippet'],
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}