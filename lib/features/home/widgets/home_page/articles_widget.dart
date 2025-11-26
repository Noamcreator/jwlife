import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/utils/common_ui.dart';
import '../../pages/article_page.dart';

class ArticlesWidget extends StatefulWidget {
  const ArticlesWidget({super.key});

  @override
  State<ArticlesWidget> createState() => ArticlesWidgetState();
}

class ArticlesWidgetState extends State<ArticlesWidget> {
  int _currentArticleIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: AppDataService.instance.articles,
      builder: (context, articles, _) {
        if (articles.isEmpty) return const SizedBox.shrink();

        // clamp si la liste a changé
        _currentArticleIndex = _currentArticleIndex.clamp(0, articles.length - 1);

        final article = articles[_currentArticleIndex];

        // Si titre vide → on n’affiche rien
        if ((article['Title'] ?? "").isEmpty) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;
        final imagePath = isLandscape
            ? (article['ImagePathPnr'] ?? '')
            : (article['ImagePathLsr'] ?? '');

        return Stack(
          children: [
            _buildImageContainer(imagePath),
            ..._buildNavigationArrows(context, articles.length),
            _buildContentContainer(article, screenSize),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // IMAGE
  // ----------------------------------------------------------

  Widget _buildImageContainer(String imagePath) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        image: imagePath.isNotEmpty
            ? DecorationImage(
          image: FileImage(File(imagePath)),
          fit: BoxFit.cover,
        )
            : null,
        color: Colors.grey[800],
      ),
    );
  }

  // ----------------------------------------------------------
  // NAVIGATION
  // ----------------------------------------------------------

  List<Widget> _buildNavigationArrows(BuildContext context, int length) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final arrows = <Widget>[];

    // Suivant
    if (_currentArticleIndex < length - 1) {
      arrows.add(
        Positioned(
          right: isRTL ? 10 : null,
          left: isRTL ? null : 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(1, length),
            child: _buildArrowButton(
                isRTL ? JwIcons.chevron_right : JwIcons.chevron_left),
          ),
        ),
      );
    }

    // Précédent
    if (_currentArticleIndex > 0) {
      arrows.add(
        Positioned(
          left: isRTL ? 10 : null,
          right: isRTL ? null : 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(-1, length),
            child: _buildArrowButton(
                isRTL ? JwIcons.chevron_left : JwIcons.chevron_right),
          ),
        ),
      );
    }

    return arrows;
  }

  void _navigateArticle(int direction, int length) {
    setState(() {
      _currentArticleIndex =
          (_currentArticleIndex + direction).clamp(0, length - 1);
    });
  }

  // ----------------------------------------------------------
  // CONTENU
  // ----------------------------------------------------------

  Widget _buildContentContainer(Map<String, dynamic> article, Size screenSize) {
    final isDark = (article['Theme'] as String).contains('dark');

    return Center(
      child: Container(
        width: screenSize.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenSize.height * 0.7,
        ),
        margin: const EdgeInsets.only(top: 140),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[900]!.withOpacity(0.7)
              : const Color(0xFFF1F1F1).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((article['ContextTitle'] ?? "").isNotEmpty)
              _buildText(article['ContextTitle'], 15, FontWeight.normal, isDark),

            _buildText(article['Title'], 26, FontWeight.bold, isDark),

            if ((article['Description'] ?? "").isNotEmpty)
              _buildDescription(article['Description'], isDark),

            const SizedBox(height: 10),
            _buildReadMoreButton(article, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildArrowButton(IconData icon) {
    return Container(
      height: 50,
      width: 50,
      alignment: Alignment.center,
      color: Colors.grey[900]!.withOpacity(0.7),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  Widget _buildText(
      String? text, double fontSize, FontWeight fontWeight, bool isDark) {
    if (text?.isEmpty != false) return const SizedBox.shrink();

    return Text(
      text!,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: isDark ? Colors.white : Colors.black,
      ),
      maxLines: fontSize > 20 ? 4 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildReadMoreButton(Map<String, dynamic> article, bool isDark) {
    final buttonText = article['ButtonText'];
    if (buttonText?.isEmpty != false) return const SizedBox.shrink();

    return ElevatedButton(
      onPressed: () {
        showPage(
          ArticlePage(
            title: article['Title'] ?? '',
            link: article['Link'] ?? '',
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        textStyle: const TextStyle(fontSize: 22),
      ),
      child: Text(buttonText!, style: const TextStyle(color: Colors.white)),
    );
  }
}
