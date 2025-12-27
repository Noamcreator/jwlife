import 'dart:io';

import 'package:collection/collection.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:sqflite/sqflite.dart';

import '../api/api.dart';
import '../utils/directory_helper.dart';
import '../utils/files_helper.dart';
import '../utils/utils.dart';

Future<void> fetchArticles(MepsLanguage language) async {
  printTime("fetchArticleInHomePage");
  final articlesDbFile = await getArticlesDatabaseFile();

  final db = await openDatabase(
    articlesDbFile.path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE Article (
          ArticleId INTEGER PRIMARY KEY AUTOINCREMENT,
          ContextTitle TEXT,
          Title TEXT,
          Description TEXT,
          Timestamp TEXT,
          Link TEXT,
          Content TEXT,
          ButtonText TEXT,
          Theme TEXT,
          LanguageSymbol TEXT,
          HasVideo INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE Image (
          ImageId INTEGER PRIMARY KEY AUTOINCREMENT,
          ArticleId INTEGER,
          Path TEXT,
          Type TEXT,
          FOREIGN KEY (ArticleId) REFERENCES Article (ArticleId) ON DELETE CASCADE
        )
      ''');
    },
    onDowngrade: (db, oldVersion, newVersion) {
      if(oldVersion == 2 && newVersion == 1) {
        db.execute('''
          ALTER TABLE Article ADD COLUMN HasVideo INTEGER DEFAULT 0
        ''');
      }
    }
  );

  printTime('fetchArticleInHomePage request start');

  // Récupérer les 3 derniers articles avec images LSR et PNR
  final articles = await db.rawQuery('''
    SELECT a.*, 
      i_lsr.Path AS ImagePathLsr,
      i_pnr.Path AS ImagePathPnr
    FROM Article a
    LEFT JOIN Image i_lsr ON a.ArticleId = i_lsr.ArticleId AND i_lsr.Type = 'lsr'
    LEFT JOIN Image i_pnr ON a.ArticleId = i_pnr.ArticleId AND i_pnr.Type = 'pnr'
    WHERE a.LanguageSymbol = ?
    ORDER BY a.Timestamp DESC
    LIMIT 4
  ''', [language.symbol]);

  if (articles.isNotEmpty) {
    AppDataService.instance.articles.value = List<Map<String, dynamic>>.from(articles);
  }

  printTime('fetchArticleInHomePage request end');

  if(await hasInternetConnection()) {
    final response = await Api.httpGetWithHeaders('https://jw.org/${language.primaryIetfCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load content');
    }

    printTime("fetchArticleInHomePage document start");

    final document = html_parser.parse(response.data);

    final html.Element? firstBillboard = document.querySelector('.billboard');

    // Fonction pour récupérer l'URL à partir d'une classe interne
    String getImageUrlFromFirst(String className) {
      if (firstBillboard == null) return '';

      // Utilisation de .attributes['style'] pour récupérer la chaîne de style
      final String style = firstBillboard.querySelector('$className .billboard-media-image')?.attributes['style'] ?? '';

      // L'expression régulière est correcte pour extraire l'URL entre les parenthèses de url(...)
      final RegExp regExp = RegExp(r'url\(([^)]+)\)');
      final Match? match = regExp.firstMatch(style);

      // Utilise le group(1) (ce qui est entre les parenthèses)
      return match?.group(1) ?? '';
    }

    // Fonction pour déterminer le thème de couleur
    String getThemeFromBillboard(html.Element? element) {
      if (element == null) return '';
      final String classes = element.attributes['class'] ?? '';
      final classList = classes.split(' ');

      // Cherche une classe qui correspond au thème
      for (final c in classList) {
        if (c != 'billboard')  {
          return c;
        }
      }

      return '';
    }

    // Extraction des infos uniquement dans le premier billboard

    // 1. Titre du contexte
    final String contextTitle = firstBillboard
        ?.querySelector('.contextTitle')
        ?.text
        .trim() ?? '';

    // 2. Titre de l'article
    final String title = firstBillboard
        ?.querySelector('.billboardTitle a')
        ?.text
        .trim() ?? '';

    // 3. Description (CORRIGÉ : le sélecteur a été ajusté à '.billboardDescription p')
    final String description = firstBillboard
        ?.querySelector('.billboardDescription p') // Anciennement : .bodyTxt .p2
        ?.text
        .trim() ?? '';

    // 4. Lien
    final String link = firstBillboard
        ?.querySelector('.billboardTitle a')
        ?.attributes['href'] ?? '';

    // 5. Texte du bouton
    final String buttonText = firstBillboard
        ?.querySelector('.billboardButton .buttonText')
        ?.text
        .trim() ?? '';

    // Correction : On vérifie si l'élément existe (!= null)
    final int hasVideo = firstBillboard?.querySelector('.hasVideo') != null ? 1 : 0;

    // 6. Thème
    final String theme = getThemeFromBillboard(firstBillboard);

    // 7. URLs des images
    //final String imageUrlLss = getImageUrlFromFirst('.lss');
    final String imageUrlLsr = getImageUrlFromFirst('.lsr');
    final String imageUrlPnr = getImageUrlFromFirst('.pnr');

    final lastArticle = articles.firstWhereOrNull((article) =>
    article['Title'] == title &&
        article['ContextTitle'] == contextTitle &&
        article['Description'] == description &&
        article['ButtonText'] == buttonText &&
        article['Theme'] == theme &&
        article['HasVideo'] == hasVideo,
    );

    if (articles.isEmpty || lastArticle == null) {
      final appTileDirectory = await getAppTileDirectory();

      // Télécharger les images en parallèle
      final futures = [
        downloadAndSaveImage(imageUrlLsr, appTileDirectory),
        downloadAndSaveImage(imageUrlPnr, appTileDirectory),
      ];
      final results = await Future.wait(futures);
      final imagePathLsr = results[0];
      final imagePathPnr = results[1];

      final fullLink = 'https://www.jw.org$link';

      final newArticle = {
        'ContextTitle': contextTitle,
        'Title': title,
        'Description': description,
        'Timestamp': DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(DateTime.now().toUtc()),
        'Link': fullLink,
        'Content': '',
        'ButtonText': buttonText,
        'Theme': theme,
        'LanguageSymbol': language.symbol,
        'ImagePathLsr': imagePathLsr,
        'ImagePathPnr': imagePathPnr,
        'HasVideo': hasVideo,
      };

      AppDataService.instance.articles.value = [newArticle, ...AppDataService.instance.articles.value];

      // Enregistrement en base
      final articleId = await saveArticleToDatabase(db, newArticle);
      await saveImagesToDatabase(db, articleId, newArticle);
    }
    else {
      // Vérifie si l'article trouvé en BDD n'est pas identique à celui placé en premier
      final isFirstDifferent =
          articles.first['Title'] != lastArticle['Title'] ||
              articles.first['ContextTitle'] != lastArticle['ContextTitle'] ||
              articles.first['Description'] != lastArticle['Description'] ||
              articles.first['ButtonText'] != lastArticle['ButtonText'] ||
              articles.first['Theme'] != lastArticle['Theme'] ||
              articles.first['HasVideo'] != lastArticle['HasVideo'];

      if (isFirstDifferent) {
        // Nouveau timestamp car l'article revient en tête
        final newTimestamp = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")
            .format(DateTime.now().toUtc());

        // Mise à jour en DB
        await db.update(
          'Article',
          {'Timestamp': newTimestamp},
          where: 'ArticleId = ?',
          whereArgs: [lastArticle['ArticleId']],
        );

        // Article mis à jour localement
        final updatedArticle = Map<String, dynamic>.from(lastArticle);
        updatedArticle['Timestamp'] = newTimestamp;

        // Retirer les anciennes occurrences de cet article
        AppDataService.instance.articles.value.removeWhere(
              (article) => article['ArticleId'] == lastArticle['ArticleId'],
        );

        // Le mettre en premier
        AppDataService.instance.articles.value = [
          updatedArticle,
          ...AppDataService.instance.articles.value
        ];
      }
    }


    await db.close();
    printTime("fetchArticleInHomePage end");
  }
}

// Enregistre un article et retourne son id
Future<int> saveArticleToDatabase(Database db, Map<String, dynamic> article) {
  return db.insert('Article', {
    'Title': article['Title'],
    'ContextTitle': article['ContextTitle'],
    'Description': article['Description'],
    'Timestamp': article['Timestamp'],
    'Link': article['Link'],
    'Content': article['Content'],
    'ButtonText': article['ButtonText'],
    'Theme': article['Theme'],
    'LanguageSymbol': article['LanguageSymbol'],
    'HasVideo': article['HasVideo'],
  });
}

// Enregistre les images associées à un article
Future<void> saveImagesToDatabase(Database db, int articleId, Map<String, dynamic> article) async {
  final inserts = <Future>[];

  if ((article['ImagePathLsr'] as String?)?.isNotEmpty ?? false) {
    inserts.add(db.insert('Image', {
      'ArticleId': articleId,
      'Path': article['ImagePathLsr'],
      'Type': 'lsr',
    }));
  }
  if ((article['ImagePathPnr'] as String?)?.isNotEmpty ?? false) {
    inserts.add(db.insert('Image', {
      'ArticleId': articleId,
      'Path': article['ImagePathPnr'],
      'Type': 'pnr',
    }));
  }

  await Future.wait(inserts);
}

// Télécharge et sauvegarde une image localement
Future<String> downloadAndSaveImage(String imageUrl, Directory appTileDirectory) async {
  if (imageUrl.isEmpty) return '';
  try {
    final response = await Api.httpGetWithHeaders(imageUrl);
    if (response.statusCode == 200) {
      final filename = Uri.parse(imageUrl).pathSegments.last;
      final file = File('${appTileDirectory.path}/$filename');
      await file.writeAsBytes(response.data);
      return file.path;
    }
  } catch (e) {
    // Gestion d'erreur si besoin
  }
  return '';
}