import 'dart:io';
import 'package:flutter/material.dart';

class ArticleWidget extends StatefulWidget {
  final bool lastArticleFirst;
  final void Function(Map<String, dynamic> article) onReadMore;

  const ArticleWidget({
    super.key,
    this.lastArticleFirst = true,
    required this.onReadMore,
  });

  @override
  State<ArticleWidget> createState() => ArticleWidgetState();
}

class ArticleWidgetState extends State<ArticleWidget> {
  List<Map<String, dynamic>> _articles = [];
  int _currentArticleIndex = 0;

  List<Map<String, dynamic>> get _orderedArticles {
    return widget.lastArticleFirst ? _articles : _articles.reversed.toList();
  }

  Map<String, dynamic> get _currentArticle => _orderedArticles[_currentArticleIndex];

  void setArticles(List<Map<String, dynamic>> articles) {
    setState(() {
      _articles = articles;
    });
  }

  void addArticle(Map<String, dynamic> article) {
    setState(() {
      _articles.add(article);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedArticles.isEmpty || _currentArticle['Title'] == null || _currentArticle['Title'].isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final imagePath = isLandscape
        ? _currentArticle['ImagePathPnr'] ?? ''
        : _currentArticle['ImagePathLsr'] ?? '';

    return Stack(
      children: [
        _buildImageContainer(imagePath),
        ..._buildNavigationArrows(),
        _buildContentContainer(_currentArticle, screenSize),
      ],
    );
  }

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

  List<Widget> _buildNavigationArrows() {
    final arrows = <Widget>[];

    if (_currentArticleIndex > 0) {
      arrows.add(
        Positioned(
          right: 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(-1),
            child: _buildArrowButton(Icons.chevron_right),
          ),
        ),
      );
    }

    if (_currentArticleIndex < _orderedArticles.length - 1) {
      arrows.add(
        Positioned(
          left: 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(1),
            child: _buildArrowButton(Icons.chevron_left),
          ),
        ),
      );
    }

    return arrows;
  }

  void _navigateArticle(int direction) {
    setState(() {
      _currentArticleIndex = (_currentArticleIndex + direction)
          .clamp(0, _orderedArticles.length - 1);
    });
  }

  Widget _buildContentContainer(Map<String, dynamic> article, Size screenSize) {
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
          color: Colors.grey[900]!.withOpacity(0.7),
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
            if (article['ContextTitle']?.isNotEmpty == true)
              _buildText(article['ContextTitle'], 15, FontWeight.bold),
            _buildText(article['Title'], 26, FontWeight.bold),
            if (article['Description']?.isNotEmpty == true)
              _buildDescription(article['Description']),
            const SizedBox(height: 10),
            _buildReadMoreButton(article),
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
      child: Icon(
        icon,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildText(String? text, double fontSize, FontWeight fontWeight) {
    if (text?.isEmpty != false) return const SizedBox.shrink();

    return Text(
      text!,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: Colors.white,
      ),
      maxLines: fontSize > 20 ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildReadMoreButton(Map<String, dynamic> article) {
    final buttonText = article['ButtonText'];
    if (buttonText?.isEmpty != false) return const SizedBox.shrink();

    return ElevatedButton(
      onPressed: () => widget.onReadMore(article),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        textStyle: const TextStyle(fontSize: 22),
      ),
      child: Text(
        buttonText!,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
