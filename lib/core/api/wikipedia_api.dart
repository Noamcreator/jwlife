import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/services/settings_service.dart';

class WikipediaApi {
  /// Cherche plusieurs mots sur Wikipédia et retourne une liste de WikipediaArticle
  static Future<List<WikipediaArticle>> getWikipediaSummary(
      String query) async {
    final List<WikipediaArticle> articles = [];

    try {
      final lang = JwLifeSettings.instance.libraryLanguage.value.primaryIetfCode;

      String queryEncoded = 'https://$lang.wikipedia.org/w/rest.php/v1/search/title?q=${Uri.encodeComponent(query.toLowerCase())}&limit=4';

      // 1️⃣ Recherche des mots
      final searchResponse = await http.get(
        Uri.parse(queryEncoded),
      );

      if (searchResponse.statusCode != 200) return articles;

      final searchData = json.decode(searchResponse.body) as Map<String, dynamic>;
      final pages = searchData['pages'] as List<dynamic>? ?? [];
      if (pages.isEmpty) return articles;

      // 2️⃣ Lancer toutes les requêtes de résumé en parallèle
      final futures = pages.map((page) async {
        final pageMap = page as Map<String, dynamic>;
        final pageKey = pageMap['key'] as String?;
        if (pageKey == null) return null;

        final summaryResponse = await http.get(
          Uri.parse(
            'https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(pageKey)}',
          ),
        );

        if (summaryResponse.statusCode != 200) return null;

        final summaryData = json.decode(summaryResponse.body) as Map<String, dynamic>;
        return WikipediaArticle.fromJson(summaryData);
      }).toList();

      // 3️⃣ Attendre que toutes les requêtes soient terminées
      final results = await Future.wait(futures);

      // 4️⃣ Ajouter les articles valides
      articles.addAll(results.whereType<WikipediaArticle>());
    } catch (e) {
      print('Error fetching Wikipedia summary: $e');
    }

    return articles;
  }
}

class WikipediaArticle {
  final String title;
  final String description;
  final String extract;
  final String extractHtml;
  final String? thumbnailUrl;
  final String? originalImageUrl;
  final String? url;

  WikipediaArticle({
    required this.title,
    required this.description,
    required this.extract,
    required this.extractHtml,
    this.thumbnailUrl,
    this.originalImageUrl,
    this.url,
  });

  factory WikipediaArticle.fromJson(Map<String, dynamic> json) {
    // Option 1 : Utiliser le chaînage conditionnel de manière complète
    final contentUrls = json['content_urls'] as Map<String, dynamic>?;
    final mobileUrls = contentUrls?['mobile'] as Map<String, dynamic>?;
    final pageUrl = mobileUrls?['page'] as String?;

    return WikipediaArticle(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      extract: json['extract'] as String? ?? '',
      extractHtml: json['extract_html'] as String? ?? '',
      thumbnailUrl: (json['thumbnail'] as Map<String, dynamic>?)?['source'] as String?,
      originalImageUrl: (json['originalimage'] as Map<String, dynamic>?)?['source'] as String?,
      // URL corrigée : s'assure que 'mobile' n'est pas null avant d'accéder à 'page'
      url: pageUrl,
    );
  }
}
