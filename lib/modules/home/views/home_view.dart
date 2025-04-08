import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/BibleCluesInfo.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/Video.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/bible/views/bible_view.dart';
import 'package:jwlife/modules/home/views/alert_banner.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:realm/realm.dart';
import 'package:searchfield/searchfield.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/image_widget.dart';
import 'article_view.dart';
import '../../settings_view.dart';
import 'daily_text_view.dart';
import 'search_views/bible_search_page.dart';
import 'search_views/search_view.dart';

class HomeView extends StatefulWidget {
  static late Function() setStateHomePage;
  static late Function() refreshHomeView;
  static late bool isRefreshing;
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;
  //static Publication? dailyTextPub;

  HomeView({Key? key, required this.toggleTheme, required this.changeLocale}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  dynamic alerts = {};
  String verseOfTheDay = '';
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, dynamic>> suggestions = [];

  int _currentArticleIndex = 0;

  bool _isRefreshing = false;
  bool _isSearchVisible = false; // Variable d'état pour contrôler l'affichage du SearchBar

  @override
  void initState() {
    super.initState();
    HomeView.setStateHomePage = _setStateHomePage;
    HomeView.refreshHomeView = _refreshView;
    HomeView.isRefreshing = _isRefreshing;
    _init();
  }

  Future<void> _init({bool first = true}) async {
    await _initPage();
    await _refresh(first: first);

    _refreshViews();

    await _loadBibleCluesInfo();

    await PubCatalog.fetchAssemblyPublications();

    MeetingsView.refreshMeetingsView();
  }

  Future<void> _setStateHomePage({bool first = true}) async {
    await _reloadPage();
    await _refresh(first: first);

    _refreshViews();

    await _loadBibleCluesInfo();

    await PubCatalog.fetchAssemblyPublications();

    MeetingsView.refreshMeetingsView();
  }

  Future<void> _reloadPage() async {
    await PubCatalog.loadHomePage();
    await _initPage();
  }

  Future<void> _initPage() async {
    fetchVerseOfTheDay();
    fetchAlertInfo();
    fetchArticleInHomePage();
    RealmLibrary.loadTeachingToolboxVideos();
    RealmLibrary.loadLatestVideos();
  }

  void _refreshViews() {
    LibraryView.setStateLibraryPage();
    BibleView.refreshBibleView();
    MeetingsView.refreshMeetingsView();
  }

  Future<void> _loadBibleCluesInfo() async {
    File mepsFile = await getMepsFile();

    if (await mepsFile.exists()) {
      Database db = await openDatabase(mepsFile.path);
      List<Map<String, dynamic>> result = await db.rawQuery("SELECT * FROM BibleCluesInfo WHERE LanguageId = ${JwLifeApp.settings.currentLanguage.id}");
      List<Map<String, dynamic>> result2 = await db.rawQuery("SELECT * FROM BibleBookName WHERE BibleCluesInfoId = ${result[0]['BibleCluesInfoId']}");

      List<BibleBookName> bibleBookNames = result2.map((book) => BibleBookName.fromJson(book)).toList();

      JwLifeApp.bibleCluesInfo = BibleCluesInfo.fromJson(result.first, bibleBookNames);
      db.close();
    }
  }

  Future<void> _refresh({bool first=false}) async {
    if (await hasInternetConnection()) {
      // Vérifier si une mise à jour de la bibliothèque est disponible
      bool libraryUpdate = await Api.isLibraryUpdateAvailable();

      // Vérifier si une mise à jour du catalogue est disponible
      bool catalogUpdate = await Api.isCatalogUpdateAvailable();

      setState(() {
        _isRefreshing = true;
      });

      if (!catalogUpdate && !libraryUpdate) {
        // Si aucune mise à jour n'est disponible
        if(!first) {
          showBottomMessage(context, 'Aucune mise à jour disponible');
        }
      }
      else {
        showBottomMessage(context, 'Mise à jour disponible');

        // Si une mise à jour de la bibliothèque est disponible
        if (libraryUpdate) {
          await Api.updateLibrary(JwLifeApp.settings.currentLanguage.symbol);
          await RealmLibrary.loadLatestVideos();
          await RealmLibrary.loadTeachingToolboxVideos();

          setState(() {});
        }

        // Si une mise à jour du catalogue est disponible
        if (catalogUpdate) {
          await Api.updateCatalog();
          await PubCatalog.loadHomePage();

          setState(() {});
        }
      }

      if (catalogUpdate || libraryUpdate) {
        showBottomMessage(context, 'Mise à jour terminée');
      }

      setState(() {
        _isRefreshing = false;
      });
    }
    else {
      showBottomMessage(context, 'Aucune connexion Internet');
    }
  }

  _refreshView() {
    setState(() {});
  }

  Future<void> fetchAlertInfo() async {
    // Préparer les paramètres de requête pour l'URL
    final queryParams = {
      'type': 'news',
      'lang': JwLifeApp.settings.currentLanguage.symbol,
      'context': 'homePage',
    };

    // Construire l'URI avec les paramètres
    final url = Uri.https('b.jw-cdn.org', '/apis/alerts/list', queryParams);

    try {
      // Préparer les headers pour la requête avec l'autorisation
      Map<String, String> headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      // Faire la requête HTTP pour récupérer les alertes
      http.Response alertResponse = await http.get(url, headers: headers);

      if (alertResponse.statusCode == 200) {
        // La requête a réussi, traiter la réponse JSON
        Map<String, dynamic> data = jsonDecode(alertResponse.body);

        setState(() {
          alerts = data['alerts'];
        });
      }
      else {
        // Gérer une erreur de statut HTTP
        print('Erreur de requête HTTP: ${alertResponse.statusCode}');
      }
    }
    catch (e) {
      // Gérer les erreurs lors des requêtes
      print('Erreur lors de la récupération des données de l\'API: $e');
    }
  }

  Future<void> fetchVerseOfTheDay() async {
    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));
    if (verseOfTheDayPub!= null) {
      Publication pub = JwLifeApp.pubCollections.getPublication(verseOfTheDayPub);
      if (pub.isDownloaded) {
        Map<String, dynamic>? document = await PubCatalog.getDatedDocumentForToday(pub);

        final decodedHtml = decodeBlobContent(
          document!['Content'] as Uint8List,
          pub.hash,
        );

        final htmlDocument = html_parser.parse(decodedHtml);

        setState(() {
          verseOfTheDay = htmlDocument.querySelector('.themeScrp')?.text ?? '';
        });
      }
    }

    /*
    if(JwLifeApp.currentLanguage.rsConf.isEmpty || JwLifeApp.currentLanguage.lib.isEmpty) {
      try {
        // Préparer les paramètres de requête
        final queryParams = {
          'wtlocale': JwLifeApp.currentLanguage.symbol,
          // langue de la recherche
          'alias': 'daily-text',
          // type de la recherche
          'date': DateFormat('yyyy-MM-dd').format(
              DateTime.now().add(Duration(days: 1))),
          // date pour la recherche +1 jour pour avoir le bon jour
        };

        // Construire l'URI avec les paramètres
        final uri = Uri.https('wol.jw.org', '/wol/finder', queryParams);

        print('uri: $uri');

        // Faire la requête HTTP
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final document = html_parser.parse(response.body);

          if (HomeView.dailyTextPub.isEmpty) {
            // Trouver l'élément contenant le verset du jour
            final doc = document.querySelector('.tabContent');
            final articleClasses = document
                .querySelector('article')
                ?.className;
            final articleClasses2 = document
                .querySelector('#dailyText')
                ?.className;

            if (doc != null) {
              setState(() {
                verseOfTheDay['Verse'] = doc
                    .querySelector('.themeScrp')
                    ?.text ?? '';
                verseOfTheDay['Content'] = doc.outerHtml;
                verseOfTheDay['Class'] = '$articleClasses $articleClasses2';
              });
            }
          }

          // Récupérer la valeur de rsConf et lib
          final rsConfElement = document.querySelector('#contentRsconf');
          final libElement = document.querySelector('#contentLib');

          if (rsConfElement != null && libElement != null) {
            final newRsConf = rsConfElement.attributes['value'] ?? '';
            final newLib = libElement.attributes['value'] ?? '';

            // Mettre à jour l'objet currentLanguage
            JwLifeApp.currentLanguage.setRsConf(newRsConf);
            JwLifeApp.currentLanguage.setLib(newLib);
          }
          else {
            throw Exception('Elements #contentRsconf or #contentLib not found');
          }
        }
      }
      catch (e) {
        print('Error: $e');
      }
    }
     */
  }

  Future<void> fetchArticleInHomePage() async {
    _articles = [];

    // Ouvrir ou créer la base de données
    String languageSymbol = JwLifeApp.settings.currentLanguage.symbol;
    File articlesDbFile = await getArticlesFile();

    final db = await openDatabase(
      articlesDbFile.path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Créer la table Article
        await db.execute(''' 
        CREATE TABLE Article (
          ArticleId INTEGER PRIMARY KEY AUTOINCREMENT,
          ContextTitle TEXT,
          Title TEXT,
          Description TEXT,
          Link TEXT,
          Content TEXT,
          ButtonText TEXT,
          LanguageSymbol TEXT
        )
      ''');

        // Créer la table Image
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
    );

    // Récupérer le dernier article et ses images, incluant ImagePathLss, ImagePathLsr, et ImagePathPnr
    final List<Map<String, dynamic>> articles = await db.rawQuery('''
    SELECT a.*, 
       i_lsr.Path AS ImagePathLsr,
       i_pnr.Path AS ImagePathPnr
FROM Article a
LEFT JOIN Image i_lsr ON a.ArticleId = i_lsr.ArticleId AND i_lsr.Type = 'lsr'
LEFT JOIN Image i_pnr ON a.ArticleId = i_pnr.ArticleId AND i_pnr.Type = 'pnr'
WHERE a.LanguageSymbol = ?
ORDER BY a.ArticleId DESC
LIMIT 3
  ''', [languageSymbol]);

    print(articles);

    // Si un article existe déjà, l'afficher
    if (articles.isNotEmpty) {
      setState(() {
        _articles = [...articles]; // Copier les articles de la base de données
        _currentArticleIndex = _articles.length - 1;
      });
    }

    // Faire la requête réseau pour récupérer l'article le plus récent
    final response = await http.get(Uri.parse('https://jw.org/${JwLifeApp.settings.currentLanguage.primaryIetfCode}'));

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);

      // Utilisation de la fonction pour récupérer les URLs
      String imageUrlLsr = getImageUrl(document, '.billboard-media.lsr');
      String imageUrlPnr = getImageUrl(document, '.billboard-media.pnr');

      String contextTitle = document.querySelector('.contextTitle')?.text ?? '';
      String title = document.querySelector('.billboardTitle a')?.text ?? '';
      String description = document.querySelector('.billboardDescription .bodyTxt .p2')?.text ?? '';
      String link = document.querySelector('.billboardTitle a')?.attributes['href'] ?? '';
      String buttonText = document.querySelector('.billboardButton .buttonText')?.text ?? '';

      // Si les données sont nouvelles, ajouter l'article à la base de données
      if (articles.isEmpty || title != articles.first['Title']) {
        Directory appTileDirectory = await getAppTileDirectory();

        // Télécharger et enregistrer les images puis récupérer leurs chemins
        String imagePathLsr = await downloadAndSaveImage(imageUrlLsr, appTileDirectory);
        String imagePathPnr = await downloadAndSaveImage(imageUrlPnr, appTileDirectory);

        // Télécharger le contenu de l'article via le lien
        String fullLink = 'https://www.jw.org/$link';

        // Ajouter un nouvel article à la liste
        Map<String, dynamic> newArticle = {
          'ContextTitle': contextTitle,
          'Title': title,
          'Description': description,
          'Link': fullLink,
          'Content': '', // Vous pouvez ajouter du contenu si nécessaire
          'ButtonText': buttonText,
          'LanguageSymbol': languageSymbol,
          'ImagePathLsr': imagePathLsr,
          'ImagePathPnr': imagePathPnr,
        };

        // Mettre à jour l'état de l'application avec les nouveaux articles
        setState(() {
          _articles.add(newArticle);
          _currentArticleIndex = _articles.length - 1;
        });

        // Enregistrer l'article dans la base de données
        int articleId = await saveArticleToDatabase(db, newArticle);

        // Enregistrer les images dans la base de données
        await saveImagesToDatabase(db, articleId, newArticle);
      }
    }
    else {
      throw Exception('Failed to load content');
    }
  }

// Fonction utilitaire pour récupérer l'URL de l'image
  String getImageUrl(final document, String className) {
    return document.querySelector('$className .billboard-media-image')
        ?.attributes['style']
        ?.split('url(')[1]
        .split(')')[0] ?? '';
  }

// Enregistrer l'article dans la base de données
  Future<int> saveArticleToDatabase(Database db, Map<String, dynamic> article) async {
    return await db.insert('Article', {
      'Title': article['Title'],
      'ContextTitle': article['ContextTitle'],
      'Description': article['Description'],
      'Link': article['Link'],
      'Content': article['Content'],
      'ButtonText': article['ButtonText'],
      'LanguageSymbol': article['LanguageSymbol'],
    });
  }

// Enregistrer les images dans la base de données
  Future<void> saveImagesToDatabase(Database db, int articleId, Map<String, dynamic> article) async {
    // Ajouter les images à la table Image
    if (article['ImagePathLsr'] != null) {
      await db.insert('Image', {
        'ArticleId': articleId,
        'Path': article['ImagePathLsr'],
        'Type': 'lsr', // Type pour l'image LSR
      });
    }
    if (article['ImagePathPnr'] != null) {
      await db.insert('Image', {
        'ArticleId': articleId,
        'Path': article['ImagePathPnr'],
        'Type': 'pnr', // Type pour l'image PNR
      });
    }
  }

  Future<String> fetchArticleContent(Database db, String articleUrl) async {
    final response = await http.get(Uri.parse(articleUrl));

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);

      final mainWrapper = document.querySelector('.main-wrapper') ?? document;

      final articleTopRelatedImage = mainWrapper.querySelector('#articleTopRelatedImage')?.outerHtml ?? '';
      final textSizeIncrement = mainWrapper.querySelector('.textSizeIncrement:not(#articleTopRelatedImage)')?.outerHtml ?? '';
      final docSubContent = mainWrapper.querySelector('.docSubContent')?.outerHtml ?? '';
      final className = mainWrapper.querySelector('#article')?.attributes['class'] ?? '';

      // Combiner les éléments
      final String mainContent = articleTopRelatedImage + textSizeIncrement + docSubContent;
      final documentMainContent = html_parser.parse(mainContent);

      // Extraire les images
      final images1 = documentMainContent.querySelectorAll('img');
      final images2 = documentMainContent.querySelectorAll('figure');
      final images = images1.toList() + images2.toList();
      for (var image in images) {
        print(image.outerHtml);
        /*
        String imageUrl = image.attributes['src'] ?? '';
        String imageAlt = image.attributes['alt'] ?? '';
        String imagePath = await downloadAndSaveImage(imageUrl, await getAppTileDirectory());
        String imageName = imagePath.split('/').last;

        await db.insert('Image', {'Url': imageUrl, 'Name': imageName, 'Path': imagePath, 'Alt': imageAlt});

         */
      }

      return mainContent;
    }
    return '';
  }

  // Télécharger et enregistrer l'image dans le répertoire app_tile
  Future<String> downloadAndSaveImage(String imageUrl, Directory appTileDirectory) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      File file = File('${appTileDirectory.path}/${imageUrl.split('/').last}'); // Utiliser + pour concaténer le chemin
      await file.writeAsBytes(response.bodyBytes);

      return file.path;
    }
    return '';
  }

  /*
      final bibleCluesInfo = JwLifeApp.bibleCluesInfo; // Obtient les informations de BibleCluesInfo

      // Accéder aux séparateurs depuis l'objet BibleCluesInfo
      final chapterVerseSeparator = RegExp.escape(bibleCluesInfo.chapterVerseSeparator); // 12:15
      final separator = RegExp.escape(bibleCluesInfo.separator); // Gn 12:15, 13:16 ou Gn 12:15,17
      final rangeSeparator = RegExp.escape(bibleCluesInfo.rangeSeparator); // Gn 12:15-16
      final nonConsecutiveRangeSeparator = RegExp.escape(bibleCluesInfo.nonConsecutiveRangeSeparator); // Gn 12:15 ; Exode 2:16

      // Expression régulière pour détecter un verset sous différents formats
      final verseRegExp = RegExp(
          // Format de verset simple (Ps 12:15)
          '([A-Za-z]+)\\s?(\\d+)$chapterVerseSeparator(\\d+)'

          // Format de plage (Gn 12:15,17)
          '|([A-Za-z]+)\\s?(\\d+)$chapterVerseSeparator(\\d+)$separator(\\d+)'

          // Format de plage (Gn 12:15-16)
          '|([A-Za-z]+)\\s?(\\d+)$chapterVerseSeparator(\d+)$rangeSeparator(\\d+)'

          // Format non consécutif (Gn 12:15 ; Exode 2:16)
          '|([A-Za-z]+)\\s?(\\d+)\\s?($nonConsecutiveRangeSeparator)\\s?([A-Za-z]+)\\s?(\\d+)$chapterVerseSeparator(\\d+)'
      );

      final match = verseRegExp.firstMatch(query);

      if (match != null) {
        String? bookName;
        String? bookName2;
        int chapter = 0;
        int verse = 0;
        int chapter2 = 0;
        int verse2 = 0;


        // Cas : format simple "Ps 12:15"
        if (match.group(1) != null && match.group(2) != null && match.group(3) != null) {
          bookName = match.group(1)?.trim() ?? '';
          chapter = int.parse(match.group(2) ?? '0');
          verse = int.parse(match.group(3) ?? '0');
        }
        // Cas : format plage "Gn 12:15,17"
        else if (match.group(4) != null && match.group(5) != null && match.group(6) != null && match.group(7) != null) {
          bookName = match.group(4)?.trim() ?? '';
          chapter = int.parse(match.group(5) ?? '0');
          verse = int.parse(match.group(6) ?? '0');
          chapter2 = int.parse(match.group(7) ?? '0');
          verse2 = int.parse(match.group(8) ?? '0');
        }
        // Cas : format plage "Gn 12:15-16"
        else if (match.group(9) != null && match.group(10) != null && match.group(11) != null && match.group(12) != null) {
          bookName = match.group(9)?.trim() ?? '';
          chapter = int.parse(match.group(10) ?? '0');
          verse = int.parse(match.group(11) ?? '0');
          chapter2 = int.parse(match.group(12) ?? '0');
          verse2 = int.parse(match.group(13) ?? '0');
        }
        // Cas : format non consécutif "Gn 12:15 ; Exode 2:16"
        else if (match.group(14) != null && match.group(15) != null && match.group(16) != null && match.group(17) != null) {
          bookName = match.group(14)?.trim() ?? '';
          chapter = int.parse(match.group(15) ?? '0');
          verse = int.parse(match.group(16) ?? '0');
          // Le second verset, si présent
          bookName2 = match.group(17)?.trim() ?? '';
          chapter2 = int.parse(match.group(18) ?? '0');
          verse2 = int.parse(match.group(19) ?? '0');
        }

        if (bookName != null) {
          // Chercher le livre correspondant dans BibleCluesInfo
          final book = bibleCluesInfo.getBook(bookName);
          final book2 = bookName2 != null ? bibleCluesInfo.getBook(bookName2) : null;

          if (book != null) {
            // Ajouter la suggestion de verset à la liste
            setState(() {
              suggestions.add({
                'type': 3, // Type verset
                'query': query,
                'caption': '${book.standardBookName} $chapter:$verse', // Affiche le verset détecté
                'icon': '',
                'label': 'Verset',
              });

              // Si c'est un format de plage
              if (chapter2 != 0 && verse2 != 0) {
                suggestions.add({
                  'type': 3, // Type verset
                  'query': query,
                  'caption': '${book.standardBookName} $chapter:$verse-$chapter2:$verse2',
                  'icon': '',
                  'label': 'Plage de versets',
                });
              }

              // Si c'est un format non consécutif
              if (chapter2 != 0 && verse2 != 0) {
                suggestions.add({
                  'type': 3, // Type verset
                  'query': query,
                  'caption': '${book.standardBookName} $chapter:$verse ; ${book2!.standardBookName} $chapter2:$verse2',
                  'icon': '',
                  'label': 'Versets non consécutifs',
                });
              }
            });
          }
        }
        return;
      }

       */

  int _latestRequestId = 0;

  Future<void> fetchSuggestions(String query) async {
    final int requestId = ++_latestRequestId; // Incrémente et stocke l’ID de la requête

    setState(() {
      suggestions.clear();
    });

    if (query.isEmpty) return;

    List<Publication> pubsTopics = JwLifeApp.pubCollections.getPublications().where((pub) => pub.hasTopics).toList();

    for (var pub in pubsTopics) {
      Database db = await openReadOnlyDatabase(pub.databasePath);
      List<Map<String, dynamic>> topics = await db.rawQuery("""
        SELECT 
          Topic.DisplayTopic,
          Document.MepsDocumentId
        FROM Topic
        LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
        LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
        WHERE Topic.Topic LIKE '%$query%'
        LIMIT 1
      """);

      if (topics.isNotEmpty && requestId == _latestRequestId) {
        suggestions.add({
          'type': 0,
          'query': topics.first['MepsDocumentId'],
          'caption': topics.first['DisplayTopic'],
          'icon': pub.imageSqr,
          'subtitle': pub.title,
          'label': 'Ouvrage de référence',
        });
      }
    }

    setState(() {});

    File catalogFile = await getCatalogFile();
    Database db = await openDatabase(catalogFile.path, readOnly: true);

    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        p.*,
        MAX(CASE WHEN ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600) THEN ia.NameFragment END) AS ImageSqr
      FROM Publication p
      LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
      LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
      LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
      WHERE LOWER(p.Symbol) = ? AND p.MepsLanguageId = ?
      GROUP BY p.Id
      LIMIT 1;
    ''',
        [query.toLowerCase(), JwLifeApp.settings.currentLanguage.id]
    );

    if (result.isEmpty || result.first['KeySymbol'] == null) {
      List<Map<String, dynamic>> result1 = await db.rawQuery('''
        SELECT
          p.*,
          MAX(CASE WHEN ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600) THEN ia.NameFragment END) AS ImageSqr
        FROM Publication p
        LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
        LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
        WHERE p.Title COLLATE NOCASE LIKE ? AND p.MepsLanguageId = ?
        GROUP BY p.Id
        LIMIT 10
      ''',
          [
            '%${query.toLowerCase()}%',
            JwLifeApp.settings.currentLanguage.id,
          ]
      );

      if (result1.isNotEmpty && requestId == _latestRequestId) {
        setState(() {
          suggestions.addAll(result1.map((e) => {
            'type': 2,
            'query': e['Symbol'] ?? '',
            'caption': e['Title'] ?? '',
            'icon': "https://app.jw-cdn.org/catalogs/publications/${e['ImageSqr']}",
            'subtitle': e['KeySymbol'] ?? '',
            'label': 'Publication',
          }).toList());
        });
      }
    }
    else if (requestId == _latestRequestId) {
      setState(() {
        suggestions = [{
          'type': 2,
          'query': result.first['Symbol'] ?? '',
          'caption': result.first['Title'] ?? '',
          'icon': "https://app.jw-cdn.org/catalogs/publications/${result.first['ImageSqr']}",
          'subtitle': result.first['KeySymbol'] ?? '',
          'label': 'Publication',
        }];
      });
    }
    await db.close();

    RealmResults<MediaItem> medias = RealmLibrary.realm
        .all<MediaItem>()
        .query(r"title CONTAINS[c] $0 AND languageSymbol == $1", [query, JwLifeApp.settings.currentLanguage.symbol]);

    if (medias.isNotEmpty && requestId == _latestRequestId) {
      for (int i = 0; i < 10; i++) {
        MediaItem media = medias[i];
        Category? category = RealmLibrary.realm
            .all<Category>()
            .query(r"key == $0", [media.primaryCategory!])
            .firstOrNull;

        String? localizedName = category?.localizedName;
        setState(() {
          suggestions.add({
            'type': 3,
            'query': media,
            'caption': media.title,
            'icon': media.realmImages == null ? '' : media.realmImages!.squareImageUrl,
            'subtitle': localizedName ?? '',
            'label': media.type == 'AUDIO' ? 'Audio' : 'Vidéo',
          });
        });
      }
    }
  }

  Widget _buildAlertBannerWidget() {
    if (alerts.isEmpty) return SizedBox.shrink(); // Retourne un widget vide si aucune alerte

    return Column(
      children: [
        AlertBanner(alerts: alerts),
        SizedBox(height: 8), // Espace entre l'alerte et le texte du jour
      ],
    );
  }

  Widget _buildDailyTextWidget() {
    // Vérifier si la locale est supportée
    String locale = JwLifeApp.settings.currentLanguage.primaryIetfCode;
    if (!DateFormat.allLocalesWithSymbols().contains(locale)) {
      locale = 'en'; // Fallback vers l'anglais ou une autre langue par défaut
    }

    initializeDateFormatting(locale);
    DateTime now = DateTime.now();
    String formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', locale).format(now));

    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));
    if (verseOfTheDayPub == null) {
      return SizedBox.shrink(); // Retourne un widget vide si aucun texte du jour n'est disponible
    }

    Publication dailyTextPub = JwLifeApp.pubCollections.getPublication(verseOfTheDayPub);

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (dailyTextPub.isDownloaded) {
              showPage(context, DailyTextPage(publication: dailyTextPub));
            }
            else {
              dailyTextPub.download(context, update: (progress) => setState(() {}));
            }
          },
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF121212) : Colors.white,
                height: 128,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    dailyTextPub.isDownloaded
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(JwIcons.calendar, size: 24),
                        SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(JwIcons.chevron_right, size: 24),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bienvenue sur JW Life',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      dailyTextPub.isDownloaded
                          ? verseOfTheDay
                          : "Télécharger le Texte du Jour de l'année ${DateFormat('yyyy').format(now)}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.2),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              if (verseOfTheDayPub.downloadProgress != 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: verseOfTheDayPub.downloadProgress == -1
                      ? LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  )
                      : LinearProgressIndicator(
                    value: verseOfTheDayPub.downloadProgress,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Colors.grey[300],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 10), // Espace après le texte du jour
      ],
    );
  }

  Widget _buildArticleWidget() {
    if (_articles.isEmpty || _articles[_currentArticleIndex]['Title'] == null) {
      return SizedBox.shrink(); // Retourner un widget vide si aucune donnée n'est disponible
    }

    // Récupérer les données de l'article
    var currentArticle = _articles[_currentArticleIndex];

    return Stack(
      children: [
        // Image en arrière-plan
        _getImageContainer(currentArticle),

        // Flèche gauche
        if (_currentArticleIndex < _articles.length - 1)
          Positioned(
            right: 10,
            top: 60, // Ajuste la position verticale
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentArticleIndex = (_currentArticleIndex + 1) % _articles.length;
                });
              },
              child: _buildArrowButton(JwIcons.chevron_right),
            ),
          ),

        // Flèche droite
        if (_currentArticleIndex > 0)
          Positioned(
            left: 10,
            top: 60, // Ajuste la position verticale
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentArticleIndex = (_currentArticleIndex - 1) % _articles.length;
                });
              },
              child: _buildArrowButton(JwIcons.chevron_left),
            ),
          ),

        // Conteneur avec texte qui dépasse légèrement sur l'image
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            margin: EdgeInsets.only(top: 145), // Décale le conteneur vers le haut
            padding: EdgeInsets.all(18),
            color: Colors.grey[900]!.withOpacity(0.7), // Couleur du conteneur noir
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextTitle(currentArticle['ContextTitle'], 15, FontWeight.bold),
                  _buildTextTitle(currentArticle['Title'], 26, FontWeight.bold),
                  _buildTextDescription(currentArticle['Description']),
                  SizedBox(height: 10),
                  _buildReadMoreButton(context, currentArticle),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  final Map<String, Size> _imageSizeCache = {};
  Widget _getImageContainer(Map<String, dynamic> currentArticle) {
    double screenWidth = MediaQuery.of(context).size.width;
    String imagePath = screenWidth > MediaQuery.of(context).size.height
        ? currentArticle['ImagePathPnr'] ?? ''
        : currentArticle['ImagePathLsr'] ?? '';

    Image image = Image.file(File(imagePath));

    // Vérifie si la taille est déjà connue
    if (_imageSizeCache.containsKey(imagePath)) {
      final size = _imageSizeCache[imagePath]!;
      double imageAspectRatio = size.width / size.height;
      double containerHeight = screenWidth / imageAspectRatio;

      return Container(
        width: double.infinity,
        height: containerHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: image.image,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Sinon, on calcule la taille comme avant
    return FutureBuilder<Size>(
      future: _getImageSize(image).then((size) {
        _imageSizeCache[imagePath] = size;
        return size;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement de l\'image'));
        } else if (snapshot.hasData) {
          double imageAspectRatio = snapshot.data!.width / snapshot.data!.height;
          double containerHeight = screenWidth / imageAspectRatio;

          return Container(
            width: double.infinity,
            height: containerHeight,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: image.image,
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          return Center(child: Text('Aucune image disponible'));
        }
      },
    );
  }

  // Fonction pour obtenir la taille de l'image de manière asynchrone
  Future<Size> _getImageSize(Image image) async {
    final completer = Completer<Size>();
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool synchronousCall) {
        final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
        completer.complete(size);
      }),
    );
    return completer.future;
  }

  Widget _buildArrowButton(IconData icon) {
    return Container(
      height: 50,
      width: 50, // Ajout pour garder une surface cliquable correcte
      alignment: Alignment.center, // Centre l'icône
      color: Colors.grey[900]!.withOpacity(0.7), // Couleur du conteneur noir
      child: Icon(
        icon,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildTextTitle(String? text, double fontSize, FontWeight fontWeight) {
    return text != '' ? Text(
      text ?? '',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: Colors.white, // Couleur du texte en blanc
      ),
      maxLines: 1, // Limite à 1 ligne si nécessaire
      overflow: TextOverflow.ellipsis,
    ) : Container();
  }

  Widget _buildTextDescription(String? text) {
    return text != '' ? Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text ?? '',
        style: TextStyle(
          fontSize: 15,
          color: Colors.white, // Couleur du texte en blanc
        ),
        maxLines: 3, // Limite à 3 lignes si nécessaire
        overflow: TextOverflow.ellipsis,
      ),
    ) : Container();
  }

  Widget _buildReadMoreButton(BuildContext context, var currentArticle) {
    return ElevatedButton(
      onPressed: () {
        showPage(
          context,
          ArticlePage(
            title: currentArticle['Title'] ?? '',
            link: currentArticle['Link'] ?? '',
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        textStyle: const TextStyle(fontSize: 22),
      ),
      child: Text(currentArticle['ButtonText'] ?? '', style: TextStyle(color: Colors.white)),
    );
  }


  Widget _buildLatestVideosWidget() {
    if (RealmLibrary.latestAudiosVideos.isEmpty) {
      return const SizedBox(height: 15);
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: RealmLibrary.latestAudiosVideos.length,
            itemBuilder: (context, mediaIndex) {
              return _buildMediaItemWidget(context, mediaIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItemWidget(BuildContext context, int mediaIndex) {
    MediaItem mediaItem = RealmLibrary.latestAudiosVideos[mediaIndex];
    DateTime firstPublished = DateTime.parse(mediaItem.firstPublished!);
    DateTime publishedDate = DateTime(firstPublished.year, firstPublished.month, firstPublished.day);
    DateTime today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    int days = currentDate.difference(publishedDate).inDays;

    String textToShow = (days == 0)
        ? "Aujourd'hui"
        : (days == 1)
        ? "Hier"
        : "Il y a $days jours";

    bool isAudio = mediaItem.type == "AUDIO";

    return GestureDetector(
      onTap: () {
        if (isAudio) {
          showAudioPlayer(context, mediaItem);
        } else {
          showFullScreenVideo(context, mediaItem);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: SizedBox(
          width: 180,
          child: Stack(
            children: [
              _buildMediaImage(mediaItem, isAudio),
              _buildPopupMenu(mediaItem, isAudio),
              _buildMediaInfoOverlay(mediaItem, isAudio),
              _buildMediaTitle(mediaItem),
              _buildMediaTimeAgoText(textToShow, mediaItem),
              _buildDownloadButton(mediaItem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaImage(MediaItem mediaItem, bool isAudio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.0),
      child: ImageCachedWidget(
        imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl ?? mediaItem.realmImages!.wideImageUrl,
        pathNoImage: isAudio ? "pub_type_audio" : "pub_type_video",
        height: 90,
        width: 180,
      ),
    );
  }

  Widget _buildPopupMenu(MediaItem mediaItem, bool isAudio) {
    return Positioned(
      top: -5,
      right: -10,
      child: PopupMenuButton(
        popUpAnimationStyle: AnimationStyle.lerp(
          AnimationStyle(curve: Curves.ease),
          AnimationStyle(curve: Curves.ease),
          0.5,
        ),
        icon: const Icon(
          Icons.more_vert,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
        ),
        shadowColor: Colors.black,
        elevation: 8,
        itemBuilder: (context) {
          return isAudio
              ? [
            getAudioShareItem(mediaItem),
            getAudioLanguagesItem(context, mediaItem),
            getAudioFavoriteItem(mediaItem),
            getAudioDownloadItem(context, mediaItem),
            getAudioLyricsItem(context, mediaItem),
            getCopyLyricsItem(mediaItem),
          ]
              : [
            getVideoShareItem(mediaItem),
            getVideoLanguagesItem(context, mediaItem),
            getVideoFavoriteItem(mediaItem),
            getVideoDownloadItem(context, mediaItem),
            getShowSubtitlesItem(context, mediaItem),
            getCopySubtitlesItem(context, mediaItem),
          ];
        },
      ),
    );
  }

  Widget _buildMediaInfoOverlay(MediaItem mediaItem, bool isAudio) {
    return Positioned(
      top: 5,
      left: 5,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(isAudio ? JwIcons.headphones_simple : JwIcons.play, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              formatDuration(mediaItem.duration!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTitle(MediaItem mediaItem) {
    return Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          mediaItem.title!,
          style: const TextStyle(
            fontSize: 11,
            height: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  Widget _buildMediaTimeAgoText(String textToShow, MediaItem mediaItem) {
    return Positioned(
      top: mediaItem.title!.length > 32 ? 115 : 103,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          textToShow,
          style: const TextStyle(
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  Widget _buildDownloadButton(MediaItem mediaItem) {
    Video? video = JwLifeApp.mediaCollections.getVideo(mediaItem);

    return video != null && video.isDownloaded == true ? Container() : Positioned(
      bottom: 55,
      right: -5,
      child: IconButton(
        padding: const EdgeInsets.all(0),
        onPressed: () async {
          if(await hasInternetConnection()) {
            String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${mediaItem.languageSymbol}/${mediaItem.languageAgnosticNaturalKey}';
            final response = await http.get(Uri.parse(link));
            if (response.statusCode == 200) {
              final jsonFile = response.body;
              final jsonData = json.decode(jsonFile);

              print(link);

              showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
                if (value != null) {
                  downloadMedia(context, mediaItem, jsonData['media'][0], file: value);
                }
              });
            }
          }
        },
        icon: const Icon(JwIcons.cloud_arrow_down, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(localization(context).navigation_home, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          actions: [
            IconButton(
              disabledColor: Colors.grey,
              icon: Icon(JwIcons.magnifying_glass),
              onPressed: _isSearchVisible
                  ? null // Désactiver le bouton si _isSearchVisible est vrai
                  : () {
                if (!_isSearchVisible) {
                  setState(() {
                    _isSearchVisible = true;
                  });
                }
              },
            ),
            IconButton(
              disabledColor: Colors.grey,
              icon: Icon(JwIcons.arrow_circular_left_clock),
              onPressed: () {
                History.showHistoryDialog(context);
              },
            ),
            IconButton(
              icon: const Icon(JwIcons.language),
              onPressed: () async {
                LanguageDialog languageDialog = LanguageDialog();
                showDialog(
                  context: context,
                  builder: (context) => languageDialog,
                ).then((value) {
                  if(value != null) {
                    setState(() async {
                      if (value['Symbol'] != JwLifeApp.settings.currentLanguage.symbol) {
                        await setLibraryLanguage(value);
                        await _setStateHomePage();
                        await LibraryView.setStateLibraryPage();
                      }
                    });
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(JwIcons.gear),
              onPressed: () {
                showPage(context, SettingsView(
                    toggleTheme: widget.toggleTheme,
                    changeLanguage: widget.changeLocale
                )).then((value) {
                  setState(() {});
                });
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          onRefresh: () async {
            if (await hasInternetConnection() && !_isRefreshing) {
              await _refresh();
            }
            else {
              showNoConnectionDialog(context);
            }
          },
          child: SingleChildScrollView(
            child: Stack(
              children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isRefreshing ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)) : SizedBox(height: 8),

                  /* Afficher le banner */
                  _buildAlertBannerWidget(),

                  /* Afficher le texte du jour */
                  _buildDailyTextWidget(),

                  /* Afficher l'article en page d'accueil */
                  _buildArticleWidget(),

                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                          children: [
                            const SizedBox(height: 20),
                            if (JwLifeApp.userdata.favorites.isNotEmpty)
                              Text(
                                localization(context).navigation_favorites,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            if (JwLifeApp.userdata.favorites.isNotEmpty)
                              const SizedBox(height: 4),
                            if (JwLifeApp.userdata.favorites.isNotEmpty)
                              SizedBox(
                                height: 130, // Hauteur à ajuster selon votre besoin
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: JwLifeApp.userdata.favorites.length,
                                  itemBuilder: (context, index) {
                                    Publication publication = JwLifeApp.pubCollections.getPublication(JwLifeApp.userdata.favorites[index]);

                                    return Padding(
                                      padding: EdgeInsets.only(left: 2.0, right: 2.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              publication.showMenu(context, update: (progress) {setState(() {});});
                                            },
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(2.0),
                                                  child: ImageCachedWidget(
                                                      imageUrl: publication.imageSqr,
                                                      pathNoImage: publication.category.image,
                                                      height: 80,
                                                      width: 80
                                                  ),
                                                ),
                                                Positioned(
                                                  top: -8,
                                                  right: -10,
                                                  child: PopupMenuButton(
                                                    popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.ease), 0.5),
                                                    icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    shadowColor: Colors.black,
                                                    elevation: 8,
                                                    itemBuilder: (context) => [
                                                      getPubShareMenuItem(publication),
                                                      getPubLanguagesItem(context, "Autres langues", publication),
                                                      getPubFavoriteItem(publication),
                                                      getPubDownloadItem(context, publication),
                                                    ],
                                                  ),
                                                ),
                                                publication.isDownloading ? Positioned(
                                                    bottom: -4,
                                                    right: -8,
                                                    height: 40,
                                                    child: IconButton(
                                                      padding: const EdgeInsets.all(0),
                                                      onPressed: () {
                                                        publication.cancelDownload(context, update: (progress) {setState(() {});});
                                                      },
                                                      icon: const Icon(JwIcons.x, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    )) :
                                                JwLifeApp.userdata.favorites[index].hasUpdate(publication) ? Positioned(
                                                    bottom: -4,
                                                    right: -8,
                                                    height: 40,
                                                    child: IconButton(
                                                      padding: const EdgeInsets.all(0),
                                                      onPressed: () {
                                                        publication.download(context, update: (progress) {setState(() {});});
                                                      },
                                                      icon: const Icon(JwIcons.arrows_circular, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    )) :
                                                !publication.isDownloaded ? Positioned(
                                                  bottom: -4,
                                                  right: -8,
                                                  height: 40,
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(0),
                                                    onPressed: () {
                                                      publication.download(context, update: (progress) {setState(() {});});
                                                    },
                                                    icon: const Icon(JwIcons.cloud_arrow_down, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                  ),
                                                ): Container(),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  height: 2,
                                                  width: 80,
                                                  child: publication.isDownloading
                                                      ? LinearProgressIndicator(
                                                    value: publication.downloadProgress == -1 ? null : publication.downloadProgress,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                    backgroundColor: Colors.grey, // Fond gris
                                                    minHeight: 2, // Assure que la hauteur est bien prise en compte
                                                  )
                                                      : Container(),
                                                )
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              publication.title,
                                              style: TextStyle(
                                                  fontSize: 9.0, height: 1.2
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.start,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (PubCatalog.recentPublications.isNotEmpty)
                              Text(
                                'Publications récentes',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            if (PubCatalog.recentPublications.isNotEmpty)
                              const SizedBox(height: 4),
                            if (PubCatalog.recentPublications.isNotEmpty)
                              SizedBox(
                                height: 130, // Hauteur à ajuster selon votre besoin
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: PubCatalog.recentPublications.length,
                                  itemBuilder: (context, index) {
                                    Publication publication = JwLifeApp.pubCollections.getPublication(PubCatalog.recentPublications[index]);

                                    return Padding(
                                      padding: EdgeInsets.only(left: 2.0, right: 2.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              publication.showMenu(context, update: (progress) {setState(() {});});
                                            },
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(2.0),
                                                  child: ImageCachedWidget(
                                                      imageUrl: publication.imageSqr,
                                                      pathNoImage: publication.category.image,
                                                      height: 80,
                                                      width: 80
                                                  ),
                                                ),
                                                Positioned(
                                                  top: -8,
                                                  right: -10,
                                                  child: PopupMenuButton(
                                                    popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.ease), 0.5),
                                                    icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    shadowColor: Colors.black,
                                                    elevation: 8,
                                                    itemBuilder: (context) => [
                                                      getPubShareMenuItem(publication),
                                                      getPubLanguagesItem(context, "Autres langues", publication),
                                                      getPubFavoriteItem(publication),
                                                      getPubDownloadItem(context, publication),
                                                    ],
                                                  ),
                                                ),
                                                publication.isDownloading ? Positioned(
                                                    bottom: -4,
                                                    right: -8,
                                                    height: 40,
                                                    child: IconButton(
                                                      padding: const EdgeInsets.all(0),
                                                      onPressed: () {
                                                        publication.cancelDownload(context, update: (progress) {setState(() {});});
                                                      },
                                                      icon: const Icon(JwIcons.x, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    )) :
                                                PubCatalog.recentPublications[index].hasUpdate(publication) ? Positioned(
                                                    bottom: -4,
                                                    right: -8,
                                                    height: 40,
                                                    child: IconButton(
                                                      padding: const EdgeInsets.all(0),
                                                      onPressed: () {
                                                        publication.download(context, update: (progress) {setState(() {});});
                                                      },
                                                      icon: const Icon(JwIcons.arrows_circular, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    )) :
                                                !publication.isDownloaded ? Positioned(
                                                  bottom: -4,
                                                  right: -8,
                                                  height: 40,
                                                  child: IconButton(
                                                    padding: const EdgeInsets.all(0),
                                                    onPressed: () {
                                                      publication.download(context, update: (progress) {setState(() {});});
                                                    },
                                                    icon: const Icon(JwIcons.cloud_arrow_down, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                  ),
                                                ): Container(),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  height: 2,
                                                  width: 80,
                                                  child: publication.isDownloading
                                                      ? LinearProgressIndicator(
                                                    value: publication.downloadProgress == -1 ? null : publication.downloadProgress,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                    backgroundColor: Colors.grey, // Fond gris
                                                    minHeight: 2, // Assure que la hauteur est bien prise en compte
                                                  )
                                                      : Container(),
                                                )
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              publication.title,
                                              style: TextStyle(
                                                  fontSize: 9.0, height: 1.2
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.start,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Text(
                              localization(context).navigation_ministry,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),

                            SizedBox(
                              height: 130,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: RealmLibrary.teachingToolboxVideos.length + PubCatalog.teachingToolBoxPublications.length,
                                itemBuilder: (context, index) {
                                  // Déterminer si l'élément est une vidéo ou une publication
                                  if (index < RealmLibrary.teachingToolboxVideos.length) {
                                    // Partie des vidéos
                                    MediaItem mediaItem = RealmLibrary.teachingToolboxVideos[index];
                                    bool isAudio = mediaItem.type == "AUDIO";

                                    return Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (isAudio) {
                                                showAudioPlayer(context, mediaItem);
                                              }
                                              else {
                                                showFullScreenVideo(context, mediaItem);
                                              }
                                            },
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(2.0),
                                                  child: ImageCachedWidget(
                                                    imageUrl: mediaItem.realmImages?.squareImageUrl ?? '',
                                                    pathNoImage: "pub_type_video",
                                                    height: 80,
                                                    width: 80,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: -8,
                                                  right: -10,
                                                  child: PopupMenuButton(
                                                    icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                    shadowColor: Colors.black,
                                                    elevation: 8,
                                                    itemBuilder: (context) => [
                                                      getVideoShareItem(mediaItem),
                                                      getVideoLanguagesItem(context, mediaItem),
                                                      getVideoFavoriteItem(mediaItem),
                                                      getVideoDownloadItem(context, mediaItem),
                                                      getShowSubtitlesItem(context, mediaItem),
                                                      getCopySubtitlesItem(context, mediaItem),
                                                    ],
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 0,
                                                  left: 0,
                                                  child: Container(
                                                    color: Colors.black.withOpacity(0.8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          isAudio ? JwIcons.headphones_simple : JwIcons.play,
                                                          size: 10,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          formatDuration(mediaItem.duration ?? 0),
                                                          style: const TextStyle(color: Colors.white, fontSize: 9),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              mediaItem.title ?? '',
                                              style: TextStyle(fontSize: 9.0, height: 1.2),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.start,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  else {
                                    int pubIndex = index - RealmLibrary.teachingToolboxVideos.length;
                                    Publication? pub = PubCatalog.teachingToolBoxPublications[pubIndex];

                                    // Vérifier si la valeur est présente dans availableTeachingToolBoxInt
                                    if (pub != null) {
                                      Publication? publication = JwLifeApp.pubCollections.getPublication(pub);
                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 2.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                publication.showMenu(context, update: (progress) {setState(() {});});
                                              },
                                              child: Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(2.0),
                                                    child: ImageCachedWidget(
                                                      imageUrl: publication.imageSqr,
                                                      pathNoImage: publication.category.image,
                                                      height: 80,
                                                      width: 80,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: -8,
                                                    right: -10,
                                                    child: PopupMenuButton(
                                                      icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                      shadowColor: Colors.black,
                                                      elevation: 8,
                                                      itemBuilder: (context) => [
                                                        getPubShareMenuItem(publication),
                                                        getPubLanguagesItem(context, "Autres langues", publication),
                                                        getPubFavoriteItem(publication),
                                                        getPubDownloadItem(context, publication),
                                                      ],
                                                    ),
                                                  ),
                                                  if (!publication.isDownloaded && publication.downloadProgress == 0)
                                                    Positioned(
                                                      bottom: -4,
                                                      right: -8,
                                                      height: 40,
                                                      child: IconButton(
                                                        padding: const EdgeInsets.all(0),
                                                        onPressed: () {
                                                          publication.download(context, update: (progress) {setState(() {});});
                                                        },
                                                        icon: const Icon(JwIcons.cloud_arrow_down, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                      ),
                                                    ),
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    height: 2,
                                                    width: 80,
                                                    child: publication.downloadProgress != 0
                                                        ? LinearProgressIndicator(
                                                      value: publication.downloadProgress == -1 ? null : publication.downloadProgress,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                      backgroundColor: Colors.grey,
                                                      minHeight: 2,
                                                    )
                                                        : Container(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            SizedBox(
                                              width: 75,
                                              child: Text(
                                                publication.title,
                                                style: TextStyle(fontSize: 9.0, height: 1.2),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.start,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    else {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 2.0),
                                        child: SizedBox(
                                          width: 30
                                        )
                                      );
                                    }
                                  }
                                },
                              ),
                            ),

                            Text(
                              localization(context).navigation_whats_new,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 85, // Adjust height as needed
                              child: PubCatalog.lastPublications.isEmpty ? getLoadingWidget() : ListView.builder(
                                scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
                                itemCount: PubCatalog.lastPublications.length,
                                itemBuilder: (context, index) {
                                  Publication pub = PubCatalog.lastPublications[index];

                                  Publication publication = JwLifeApp.pubCollections.getPublication(pub);

                                  return GestureDetector(
                                    onTap: () {
                                      publication.showMenu(context, update: (progress) {setState(() {});});
                                    },
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: 2.0), // Espacement supplémentaire entre chaque ListTile
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white
                                      ),
                                      child: SizedBox(
                                        height: 85,
                                        width: 340,
                                        child: Stack(
                                          children: [
                                            Row(
                                              children: [
                                                ClipRRect(
                                                  child: ImageCachedWidget(
                                                    imageUrl: publication.imageSqr,
                                                    pathNoImage: publication.category.image,
                                                    height: 85,
                                                    width: 85,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 7.0, right: 25.0, top: 4.0, bottom: 4.0),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          publication.issueTagNumber == 0 ? publication.category.getName(context) : publication.issueTitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? const Color(0xFFc3c3c3)
                                                                : const Color(0xFF626262),
                                                          ),
                                                        ),
                                                        Text(
                                                          publication.issueTagNumber == 0 ? publication.title : publication.coverTitle,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Theme.of(context).secondaryHeaderColor,
                                                          ),
                                                          maxLines: 2, // Limite à deux lignes
                                                          overflow: TextOverflow.ellipsis, // Tronque le texte avec des points de suspension
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          pub.getRelativeDateText(),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? const Color(0xFFc3c3c3)
                                                                : const Color(0xFF626262),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Positioned(
                                              top: -5,
                                              right: -15,
                                              child: PopupMenuButton(
                                                popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.ease), 0.5),
                                                icon: Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
                                                itemBuilder: (context) => [
                                                  getPubShareMenuItem(publication),
                                                  getPubLanguagesItem(context, "Autres langues", publication),
                                                  getPubFavoriteItem(publication),
                                                  getPubDownloadItem(context, publication, update: (progress) {
                                                    setState(() {});
                                                  }),
                                                ],
                                              ),
                                            ),
                                            publication.isDownloading ? Positioned(
                                                bottom: -2,
                                                right: -8,
                                                height: 40,
                                                child: IconButton(
                                                  padding: const EdgeInsets.all(0),
                                                  onPressed: () {
                                                    publication.cancelDownload(context, update: (progress) {setState(() {});});
                                                  },
                                                  icon: Icon(JwIcons.x, color: Color(0xFF9d9d9d)),
                                                )) : pub.hasUpdate(publication) ? Positioned(
                                                bottom: 5,
                                                right: -8,
                                                height: 40,
                                                child: IconButton(
                                                  padding: const EdgeInsets.all(0),
                                                  onPressed: () {
                                                    publication.update(context, update: (progress) {setState(() {});});
                                                  },
                                                  icon: Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
                                                )) :
                                            !publication.isDownloaded ? Positioned(
                                              bottom: 5,
                                              right: -8,
                                              height: 40,
                                              child: IconButton(
                                                padding: const EdgeInsets.all(0),
                                                onPressed: () {
                                                  publication.download(context, update: (progress) {setState(() {});});
                                                },
                                                icon: Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                                              ),
                                            ): Container(),
                                            (!publication.isDownloaded || pub.hasUpdate(publication)) && !publication.isDownloading ? Positioned(
                                              bottom: 0,
                                              right: -5,
                                              width: 50,
                                              child: Text(
                                                textAlign: TextAlign.center,
                                                formatFileSize(publication.expandedSize),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFFc3c3c3)
                                                      : const Color(0xFF626262),
                                                ),
                                              )
                                            ) : Container(),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              height: 2,
                                              width: 340-85,
                                                child: publication.isDownloading
                                                    ? LinearProgressIndicator(
                                                  value: publication.downloadProgress == -1 ? null : publication.downloadProgress,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                  backgroundColor: Colors.grey, // Fond gris
                                                  minHeight: 2, // Assure que la hauteur est bien prise en compte
                                                )
                                                    : Container(),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            _buildLatestVideosWidget(),

                            Text(
                              localization(context).navigation_online,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            SizedBox(
                              height: 120, // Augmenté pour tenir compte du texte sur 2 lignes
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _iconLinks(context).length,
                                itemBuilder: (context, index) {
                                  final iconLinkInfo = _iconLinks(context)[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0), // Espacement entre chaque icône
                                    child: IconLink(
                                      imagePath: iconLinkInfo.imagePath,
                                      url: iconLinkInfo.url,
                                      description: iconLinkInfo.description,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ]
                      )
                  ),
                ],
              ),
                /* Afficher la barre de recherche */
                if (_isSearchVisible)
                  Opacity(
                    opacity: 0.8,
                    child: Container(
                      color: Colors.black,
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                if(_isSearchVisible)
                  Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SearchField<Map<String, dynamic>>(
                            animationDuration: const Duration(milliseconds: 0),
                            itemHeight: 57,
                            autofocus: true,
                            offset: Offset(0, 62),
                            maxSuggestionsInViewPort: 7,
                            searchInputDecoration: SearchInputDecoration(
                              searchStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                              fillColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                              filled: true,
                              hintText: localization(context).search_hint,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onSearchTextChanged: (text) {
                              setState(() {
                                fetchSuggestions(text);
                              });
                              return null;
                            },
                            onSuggestionTap: (SearchFieldListItem<Map<String, dynamic>> item) async {
                              if(item.item!['type'] == 0) {
                                showDocumentView(context, item.item?['query'], JwLifeApp.settings.currentLanguage.id);
                              }
                              else if(item.item!['type'] == 1) {
                                await showPage(context, SearchBiblePage(query: item.item?['query']));
                              }
                              else if (item.item!['type'] == 2) {
                                Publication? publication = await PubCatalog.searchPub(item.item!['query'], 0, JwLifeApp.settings.currentLanguage.id);
                                if(publication != null) {
                                  publication.showMenu(context, update: null);
                                }
                                else {
                                  showErrorDialog(context, "Aucune publication ${item.item?['query']} n'a pu étre trouvée.");
                                }
                              }
                              else if(item.item!['type'] == 3) {
                                if(item.item!['label'] == 'Audio') {
                                  showAudioPlayer(context, item.item?['query']);
                                }
                                else if(item.item!['label'] == 'Vidéo') {
                                  showFullScreenVideo(context, item.item?['query']);
                                }
                              }
                              else {
                                await showPage(context, SearchView(query: item.item?['query']));
                              }

                              setState(() {
                                _isSearchVisible = false;
                              });
                            },
                            onSubmit: (text) async {
                              await showPage(context, SearchView(query: text));
                              setState(() {
                                _isSearchVisible = false;
                              });
                            },
                            onTapOutside: (event) {
                              setState(() {
                                _isSearchVisible = false;
                              });
                            },
                            suggestionsDecoration: SuggestionDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suggestions: suggestions.map((item) => SearchFieldListItem<Map<String, dynamic>>(
                              item['caption'],
                              item: item,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      item['icon'] != '' ? ImageCachedWidget(
                                          imageUrl: item['icon'],
                                          pathNoImage: 'pub_type_placeholder',
                                          width: 40,
                                          height: 40
                                      ) : Container(),
                                      item['icon'] != '' ? const SizedBox(width: 10) : Container(),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['caption'],
                                                style: TextStyle(fontSize: 16),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                item['subtitle'],
                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ]
                                        ),
                                      ),
                                      item['type'] == 3 ? const SizedBox(width: 5) : Container(),
                                      item['type'] == 3 ? item['label'] == 'Audio' ? const Icon(JwIcons.music) : const Icon(JwIcons.video) : Container(),
                                    ],
                                  )
                              ),
                            ),
                            ).toList(),
                          )
                      )
                  ),
              ],
            ),
          ),
        )
    );
  }
}

class IconLink extends StatelessWidget {
  final String imagePath;
  final String url;
  final String description;

  const IconLink({
    super.key,
    required this.imagePath,
    required this.url,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _launchURL(url);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 80,
            height: 80,
          ),
          SizedBox(height: 2), // Espacement entre l'image et le texte
          SizedBox(
            width: 80, // Assure que le texte s'aligne avec l'image
            height: 30, // Hauteur fixe pour le texte (environ 2 lignes de texte)
            child: Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis, // Si le texte est trop long, on coupe
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}

class IconLinkInfo {
  final String imagePath;
  final String description;
  final String url;

  IconLinkInfo(this.imagePath, this.description, this.url);
}

List<IconLinkInfo> _iconLinks(BuildContext context) {
  return [
    IconLinkInfo('assets/icons/nav_jworg.png', localization(context).navigation_official_website, 'https://www.jw.org/${JwLifeApp.settings.currentLanguage.primaryIetfCode}'),
    IconLinkInfo('assets/icons/nav_jwb.png', localization(context).navigation_online_broadcasting, 'https://www.jw.org/open?docid=1011214&wtlocale=${JwLifeApp.settings.currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_onlinelibrary.png', localization(context).navigation_online_library, 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeApp.settings.currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_donation.png', localization(context).navigation_online_donation, 'https://donate.jw.org/ui/${JwLifeApp.settings.currentLanguage.symbol}/donate-home.html'),
    IconLinkInfo(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/icons/nav_github_light.png'
          : 'assets/icons/nav_github_dark.png',
      localization(context).navigation_online_gitub,
      'https://github.com/Noamcreator/jwlife',
    ),
  ];
}