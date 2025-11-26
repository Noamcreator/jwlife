import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';

import '../../../app/app_page.dart';
import '../../../core/utils/common_ui.dart';
import '../../../i18n/i18n.dart';
import '../../publication/pages/document/data/models/multimedia.dart';
import '../../publication/pages/document/local/full_screen_image_page.dart';
import '../models/bible_chapter_model.dart';


class BibleBookMediasView extends StatefulWidget {
  final Publication bible;
  final BibleBook bibleBook;

  const BibleBookMediasView({super.key, required this.bible, required this.bibleBook});

  @override
  _BibleBookMediasViewState createState() => _BibleBookMediasViewState();
}

class _BibleBookMediasViewState extends State<BibleBookMediasView> {
  // La clé est le ChapterNumber (int)
  Map<int, List<Multimedia>> groupedMedias = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    setState(() {
      isLoading = true;
    });

    int? bookNumber = widget.bibleBook.bookInfo['BibleBookId'] as int?;
    int? firstVerseId = widget.bibleBook.firstVerseId;
    int? lastVerseId = widget.bibleBook.lastVerseId;

    if (bookNumber != null && firstVerseId != null && lastVerseId != null) {
      // Logique de requête inchangée
      List<Map<String, dynamic>> results = await widget.bible.documentsManager!.database.rawQuery(''' 
        SELECT 
          M.*, 
          BC.ChapterNumber AS ChapterNumber
        FROM 
          Multimedia M
        JOIN 
          VerseMultimediaMap VMM ON M.MultimediaId = VMM.MultimediaId
        JOIN
          BibleChapter BC ON VMM.BibleVerseId BETWEEN BC.FirstVerseId AND BC.LastVerseId
        WHERE 
          BC.BookNumber = ? AND BC.FirstVerseId BETWEEN ? AND ? AND M.CategoryType = 10
        GROUP BY 
          M.MultimediaId, BC.ChapterNumber
        ORDER BY 
          BC.ChapterNumber ASC;
      ''', [bookNumber, firstVerseId, lastVerseId]);

      Map<int, List<Multimedia>> tempGroupedMedias = {};

      for (var map in results) {
        final chapterNumber = map['ChapterNumber'] as int;
        final media = Multimedia.fromMap(map);

        if (!tempGroupedMedias.containsKey(chapterNumber)) {
          tempGroupedMedias[chapterNumber] = [];
        }
        tempGroupedMedias[chapterNumber]!.add(media);
      }

      setState(() {
        groupedMedias = tempGroupedMedias;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- Fonctions d'aide pour le rendu (Correction du micro-dépassement) ---

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 6;
    if (screenWidth > 900) return 4;
    if (screenWidth > 600) return 3;
    if (screenWidth > 400) return 2;
    return 2;
  }

  double _getSpacing(double screenWidth) {
    if (screenWidth > 1200) return 12.0;
    if (screenWidth > 900) return 10.0;
    if (screenWidth > 600) return 8.0;
    return 6.0;
  }

  // Facteur de hauteur de ligne (pour la cohérence du style)
  double _getLabelLineHeightFactor() => 1.3;

  // Hauteur Totale FIXE pour le TEXTE SEUL (2 lignes)
  double _getLabelTextHeight(double screenWidth) {
    final double labelFontSize = screenWidth > 600 ? 13.0 : 11.0;

    // CLÉ : Marge de sécurité augmentée à 5.0 pour absorber l'erreur résiduelle de 1.1px
    const double minimalSafetyPadding = 5.0;

    // Hauteur basée sur la police * le facteur de ligne * 2 lignes + padding de sécurité
    return (labelFontSize * _getLabelLineHeightFactor() * 2) + minimalSafetyPadding;
  }

  // Hauteur Totale de la Zone de Label (incluant l'espace entre l'image et le texte)
  double _getLabelAreaTotalHeight(double screenWidth) {
    const double innerSpacing = 4.0; // Espace entre l'image et le label
    return _getLabelTextHeight(screenWidth) + innerSpacing;
  }

  // Ratio ajusté du GridView
  double _getAdjustedAspectRatio(double screenWidth) {
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final outerSpacing = _getSpacing(screenWidth);

    final double labelAreaTotalHeight = _getLabelAreaTotalHeight(screenWidth);

    // Largeur de l'élément (W)
    final double itemWidth = (screenWidth - outerSpacing * (crossAxisCount - 1)) / crossAxisCount;
    // Hauteur de l'élément (H) = Image (W) + Hauteur de la zone de Label Totale Corrigée
    final double itemHeight = itemWidth + labelAreaTotalHeight;

    // Ratio (W/H)
    return itemWidth / itemHeight;
  }

  String _getChapterTitle(int chapterId) {
    final bookName = widget.bibleBook.bookInfo['BookName'] as String;
    return '$bookName $chapterId';
  }

  // --- Tuile d'Image ---

  Widget imageTile(BuildContext context, Multimedia media, List<Multimedia> allMediasInGroup, double screenWidth) {
    final double labelFontSize = screenWidth > 600 ? 13.0 : 11.0;
    const double innerSpacing = 2.0;

    // Utilisation de la hauteur de texte fixe et corrigée
    final double labelTextHeight = _getLabelTextHeight(screenWidth);

    final List<Multimedia> allMedias = groupedMedias.values.expand((list) => list).toList();

    return GestureDetector(
      onTap: () {
        showPage(FullScreenImagePage(publication: widget.bible, multimedias: allMedias, multimedia: media));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Image (carrée grâce à AspectRatio 1.0)
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: ImageCachedWidget(
                imageUrl: media.getImage(widget.bible),
                icon: media.getImage(widget.bible) == null ? JwIcons.image : null,
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Espacement entre l'image et le label
          const SizedBox(height: innerSpacing),

          // 3. Zone du Label (Hauteur corrigée)
          SizedBox(
            height: labelTextHeight,
            child: media.label.isNotEmpty
                ? Text(
              media.label,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                // Appliquer le facteur de hauteur de ligne pour le Text.
                height: _getLabelLineHeightFactor(),
              ),
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
                : Container(),
          ),
        ],
      ),
    );
  }

  // --- Méthode Build ---

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final spacing = _getSpacing(screenWidth);
    final sortedChapterIds = groupedMedias.keys.toList()..sort();

    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().label_media_gallery,
        subTitle: widget.bibleBook.bookInfo['BookName'],
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (BuildContext context) {
              History.showHistoryDialog(context);
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedMedias.isEmpty
          ? Center(child: Text(i18n().message_no_media_title))
          : ListView.builder(
        padding: EdgeInsets.all(spacing),
        itemCount: sortedChapterIds.length,
        itemBuilder: (context, index) {
          final chapterId = sortedChapterIds[index];
          final mediasForChapter = groupedMedias[chapterId]!;

          final chapterTitle = _getChapterTitle(chapterId);

          return Padding(
            padding: EdgeInsets.only(bottom: spacing * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre du groupe : Livre + Chapitre ID
                Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: Text(
                    chapterTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                // Grille des médias
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    // Utilisation du ratio ajusté corrigé
                    childAspectRatio: _getAdjustedAspectRatio(screenWidth),
                  ),
                  itemCount: mediasForChapter.length,
                  itemBuilder: (context, mediaIndex) {
                    final media = mediasForChapter[mediaIndex];
                    return imageTile(context, media, mediasForChapter, screenWidth);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}