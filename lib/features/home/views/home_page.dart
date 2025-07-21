import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/features/library/pages/library_page.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/alert_banner.dart';
import 'package:jwlife/features/home/views/search_views/suggestion.dart';
import 'package:jwlife/features/home/widgets/HomeRectanglePublicationItem.dart';
import 'package:jwlife/features/meetings/views/meeting_page.dart';
import 'package:jwlife/features/home/widgets/HomeSquarePublicationItem.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:realm/realm.dart';
import 'package:searchfield/searchfield.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../../app/services/settings_service.dart';
import '../../../data/models/tile.dart';
import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/image_cached_widget.dart';
import 'article_page.dart';
import '../../settings_page.dart';
import 'daily_text_page.dart';
import 'search_views/bible_search_page.dart';
import 'search_views/search_view.dart';

class HomePage extends StatefulWidget {
  static late Future<void> Function() refreshChangeLanguage;
  static late Function() refreshHomeView;
  static late bool isRefreshing;
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;

  const HomePage({super.key, required this.toggleTheme, required this.changeLocale});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> alerts = [];
  String verseOfTheDay = '';
  List<Map<String, dynamic>> _articles = [];

  List<MediaItem> teachingToolboxVideos = [];
  List<MediaItem> latestAudiosVideos = [];

  List<SuggestionItem> suggestions = [];
  final TextEditingController _searchController = TextEditingController();

  int _currentArticleIndex = 0;

  bool _isRefreshing = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    HomePage.refreshChangeLanguage = _refreshChangeLanguage;
    HomePage.refreshHomeView = _refreshView;
    HomePage.isRefreshing = _isRefreshing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init({bool first = true}) async {
    printTime("Init start");
    _initPage();
    printTime("Init end");

    printTime("Refresh page start");
    _refresh(first: first);
    printTime("Refresh page end");

    await _loadBibleCluesInfo();
    await PubCatalog.fetchAssemblyPublications();

    printTime("Refresh MeetingsView start");
    MeetingsPage.refreshConventionsPubs();
  }

  Future<void> _refreshChangeLanguage() async {
    printTime("Refresh change language start");
    LibraryPage.refreshLibraryCategories();
    PubCatalog.updateCatalogCategories();

    // Enveloppe toute la première séquence dans un Future synchronisé
    PubCatalog.loadPublicationsInHomePage().then((_) async {
      printTime("Refresh Homepage start");
      setState(() {});

      MeetingsPage.refreshMeetingsPubs();

      await _loadBibleCluesInfo();
      await PubCatalog.fetchAssemblyPublications();

      printTime("Refresh MeetingsView start");
      MeetingsPage.refreshConventionsPubs();

      fetchVerseOfTheDay();
    });

    _initPage();
    _refresh(first: true);
  }

  Future<void> _initPage() async {
    fetchVerseOfTheDay();
    fetchAlertInfo();
    fetchArticleInHomePage();

    setState(() {
      teachingToolboxVideos = RealmLibrary.loadTeachingToolboxVideos();
      latestAudiosVideos = RealmLibrary.loadLatestVideos();
    });
  }

  Future<void> _loadBibleCluesInfo() async {
    File mepsFile = await getMepsFile();

    if (await mepsFile.exists()) {
      Database db = await openDatabase(mepsFile.path);
      List<Map<String, dynamic>> result = await db.rawQuery("SELECT * FROM BibleCluesInfo WHERE LanguageId = ${JwLifeSettings().currentLanguage.id}");
      List<Map<String, dynamic>> result2 = await db.rawQuery("SELECT * FROM BibleBookName WHERE BibleCluesInfoId = ${result[0]['BibleCluesInfoId']}");

      List<BibleBookName> bibleBookNames = result2.map((book) => BibleBookName.fromJson(book)).toList();

      JwLifeApp.bibleCluesInfo = BibleCluesInfo.fromJson(result.first, bibleBookNames);
      db.close();
    }
  }

  Future<void> _refresh({bool first = false}) async {
    printTime("Refresh start");
    if (!await hasInternetConnection()) {
      showBottomMessage(context, 'Aucune connexion Internet');
      return;
    }

    // Lancer les vérifications en parallèle
    final results = await Future.wait([
      Api.isLibraryUpdateAvailable(),
      Api.isCatalogUpdateAvailable()
    ]);

    bool libraryUpdate = results[0];
    bool catalogUpdate = results[1];

    if (!catalogUpdate && !libraryUpdate) {
      if (!first) {
        showBottomMessage(context, 'Aucune mise à jour disponible');
      }
      return;
    }

    showBottomMessage(context, 'Mise à jour disponible');

    setState(() {
      _isRefreshing = true;
    });

    // Préparer les tâches de mise à jour
    final List<Future> updateTasks = [];

    if (libraryUpdate) {
      updateTasks.add(
        Api.updateLibrary(JwLifeSettings().currentLanguage.symbol).then((_) {
          setState(() {
            teachingToolboxVideos = RealmLibrary.loadTeachingToolboxVideos();
            latestAudiosVideos = RealmLibrary.loadLatestVideos();
          });
          LibraryPage.refreshLibraryCategories();
        }),
      );
    }

    if (catalogUpdate) {
      updateTasks.add(
        Api.updateCatalog().then((_) async {
          await PubCatalog.loadPublicationsInHomePage().then((_) async {
            printTime("Refresh Homepage start");
            setState(() {});

            PubCatalog.updateCatalogCategories();
            MeetingsPage.refreshMeetingsPubs();

            await PubCatalog.fetchAssemblyPublications();

            printTime("Refresh MeetingsView start");
            MeetingsPage.refreshConventionsPubs();

            fetchVerseOfTheDay();
          });
        }),
      );
    }

    // Exécuter toutes les tâches en parallèle
    await Future.wait(updateTasks);

    showBottomMessage(context, 'Mise à jour terminée');

    setState(() {
      _isRefreshing = false;
    });
  }

  void _refreshView() {
    printTime("Refresh view start");
    setState(() {});
  }

  Future<void> fetchAlertInfo() async {
    printTime("fetchAlertInfo");
    // Préparer les paramètres de requête pour l'URL
    final queryParams = {
      'type': 'news',
      'lang': JwLifeSettings().currentLanguage.symbol,
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
        final data = jsonDecode(alertResponse.body);

        setState(() {
          alerts = data['alerts'];
        });
      }
      else {
        // Gérer une erreur de statut HTTP
        printTime('Erreur de requête HTTP: ${alertResponse.statusCode}');
      }
    }
    catch (e) {
      // Gérer les erreurs lors des requêtes
      printTime('Erreur lors de la récupération des données de l\'API: $e');
    }

    printTime("fetchAlertInfo end");
  }

  Future<void> fetchVerseOfTheDay() async {
    printTime("fetchVerseOfTheDay");

    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull(
          (element) => element.keySymbol.contains('es'),
    );

    if (verseOfTheDayPub != null) {
      VoidCallback? listener;

      listener = () async {
        if (verseOfTheDayPub.isDownloadedNotifier.value) {
          // Supprimer le listener après exécution pour éviter boucle
          verseOfTheDayPub.isDownloadedNotifier.removeListener(listener!);
          await fetchVerseOfTheDay();
        }
      };

      // Ajouter le listener une seule fois
      verseOfTheDayPub.isDownloadedNotifier.addListener(listener);

      if (verseOfTheDayPub.isDownloadedNotifier.value) {
        // Si déjà téléchargé, retirer le listener car on n'en aura pas besoin
        verseOfTheDayPub.isDownloadedNotifier.removeListener(listener);

        printTime("fetchVerseOfTheDay document start");
        Map<String, dynamic>? document = await PubCatalog.getDatedDocumentForToday(verseOfTheDayPub);
        printTime("fetchVerseOfTheDay document end");

        final decodedHtml = decodeBlobContent(
          document!['Content'] as Uint8List,
          verseOfTheDayPub.hash!,
        );

        final htmlDocument = html_parser.parse(decodedHtml);

        setState(() {
          verseOfTheDay = htmlDocument.querySelector('.themeScrp')?.text ?? '';
        });
      }
    }
    printTime("fetchVerseOfTheDay end");
  }

  Future<void> fetchArticleInHomePage() async {
    printTime("fetchArticleInHomePage");
    _articles = [];

    final languageSymbol = JwLifeSettings().currentLanguage.symbol;
    final articlesDbFile = await getArticlesFile();

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
          Link TEXT,
          Content TEXT,
          ButtonText TEXT,
          LanguageSymbol TEXT
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
    );

    // Récupérer les 3 derniers articles avec images LSR et PNR
    final articles = await db.rawQuery('''
    SELECT a.*, 
      i_lsr.Path AS ImagePathLsr,
      i_pnr.Path AS ImagePathPnr
    FROM Article a
    LEFT JOIN Image i_lsr ON a.ArticleId = i_lsr.ArticleId AND i_lsr.Type = 'lsr'
    LEFT JOIN Image i_pnr ON a.ArticleId = i_pnr.ArticleId AND i_pnr.Type = 'pnr'
    WHERE a.LanguageSymbol = ?
    ORDER BY a.ArticleId
    LIMIT 3
  ''', [languageSymbol]);

    if (articles.isNotEmpty) {
      setState(() {
        _articles = List<Map<String, dynamic>>.from(articles);
        _currentArticleIndex = _articles.length - 1;
      }); // Mise à jour unique
    }

    final response = await Api.httpGetWithHeaders('https://jw.org/${JwLifeSettings().currentLanguage.primaryIetfCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load content');
    }
    else {
      printTime("fetchArticleInHomePage document start");
    }
    final document = html_parser.parse(response.body);

    String getImageUrl(String className) {
      final style = document.querySelector('$className .billboard-media-image')?.attributes['style'] ?? '';
      final match = RegExp(r'url\(([^)]+)\)').firstMatch(style);
      return match?.group(1) ?? '';
    }

    final contextTitle = document.querySelector('.contextTitle')?.text.trim() ?? '';
    final title = document.querySelector('.billboardTitle a')?.text.trim() ?? '';
    final description = document.querySelector('.billboardDescription .bodyTxt .p2')?.text.trim() ?? '';
    final link = document.querySelector('.billboardTitle a')?.attributes['href'] ?? '';
    final buttonText = document.querySelector('.billboardButton .buttonText')?.text.trim() ?? '';

    final imageUrlLsr = getImageUrl('.billboard-media.lsr');
    final imageUrlPnr = getImageUrl('.billboard-media.pnr');

    // Si aucun article ou titre différent, on ajoute le nouvel article
    if (articles.isEmpty || !articles.any((article) => article['Title'] == title) ) {
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
        'Link': fullLink,
        'Content': '', // Ajouter contenu si besoin
        'ButtonText': buttonText,
        'LanguageSymbol': languageSymbol,
        'ImagePathLsr': imagePathLsr,
        'ImagePathPnr': imagePathPnr,
      };

      setState(() {
        _articles.add(newArticle);
        _currentArticleIndex = _articles.length - 1;
      }); // Mise à jour unique

      // Enregistrement en base
      final articleId = await saveArticleToDatabase(db, newArticle);
      await saveImagesToDatabase(db, articleId, newArticle);
    }

    await db.close();
    printTime("fetchArticleInHomePage end");
  }

// Enregistre un article et retourne son id
  Future<int> saveArticleToDatabase(Database db, Map<String, dynamic> article) {
    return db.insert('Article', {
      'Title': article['Title'],
      'ContextTitle': article['ContextTitle'],
      'Description': article['Description'],
      'Link': article['Link'],
      'Content': article['Content'],
      'ButtonText': article['ButtonText'],
      'LanguageSymbol': article['LanguageSymbol'],
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
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      // Gestion d'erreur si besoin
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
    String locale = JwLifeSettings().currentLanguage.primaryIetfCode;
    if (!DateFormat.allLocalesWithSymbols().contains(locale)) {
      locale = 'en'; // Fallback vers l'anglais ou une autre langue par défaut
    }

    initializeDateFormatting(locale);
    DateTime now = DateTime.now();
    String formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', locale).format(now));

    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));

    if (verseOfTheDayPub == null) {
      return Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF121212)
                : Colors.white,
            height: 128,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Bienvenue sur JW Life',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center, // ← Optionnel pour s’assurer
                ),
                SizedBox(height: 8),
                Text(
                  "Une application pour la vie d'un Témoin de Jéhovah",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center, // ← Optionnel aussi
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
      );
    }

    Publication publication = PublicationRepository().getPublication(verseOfTheDayPub);

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (publication.isDownloadedNotifier.value) {
              showPage(context, DailyTextPage(publication: publication));
            } else {
              publication.download(context);
            }
                    },
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF121212)
                    : Colors.white,
                height: 128,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: publication.isDownloadedNotifier,
                      builder: (context, isDownloaded, _) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: isDownloaded && verseOfTheDay.isNotEmpty ? [
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
                              ]
                                  : [
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
                            ValueListenableBuilder<bool>(
                              valueListenable: publication.isDownloadedNotifier,
                              builder: (context, isDownloaded, _) {
                                if (isDownloaded) {
                                  return verseOfTheDay.isNotEmpty ? Text(
                                    verseOfTheDay,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, height: 1.2),
                                    maxLines: 4,
                                  ) : getLoadingWidget(Theme.of(context).primaryColor);
                                }
                                else {
                                  return Text(
                                    "Télécharger le Texte du Jour de l'année ${DateFormat('yyyy').format(now)}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, height: 1.2),
                                    maxLines: 4,
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: publication.isDownloadingNotifier,
                builder: (context, isDownloading, _) {
                  if (!isDownloading) return SizedBox.shrink();
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: publication.progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress == -1.0 ? null : progress,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                          backgroundColor: Colors.grey[300],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }

  Widget _buildArticleWidget() {
    if (_articles.isEmpty || _articles[_currentArticleIndex]['Title'] == null) {
      return const SizedBox.shrink();
    }

    final currentArticle = _articles[_currentArticleIndex];
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final imagePath = isLandscape
        ? currentArticle['ImagePathPnr'] ?? ''
        : currentArticle['ImagePathLsr'] ?? '';

    return Stack(
      children: [
        // Image en arrière-plan
        _buildImageContainer(imagePath, screenSize.width),

        // Flèches de navigation
        ..._buildNavigationArrows(),

        // Conteneur avec texte
        _buildContentContainer(currentArticle, screenSize),
      ],
    );
  }

  Widget _buildImageContainer(String imagePath, double screenWidth) {
    return Container(
      width: double.infinity,
      height: 200, // Hauteur fixe pour éviter le calcul d'aspect ratio
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(imagePath)),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  List<Widget> _buildNavigationArrows() {
    final arrows = <Widget>[];

    if (_currentArticleIndex < _articles.length - 1) {
      arrows.add(
        Positioned(
          right: 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(1),
            child: _buildArrowButton(JwIcons.chevron_right),
          ),
        ),
      );
    }

    if (_currentArticleIndex > 0) {
      arrows.add(
        Positioned(
          left: 10,
          top: 60,
          child: GestureDetector(
            onTap: () => _navigateArticle(-1),
            child: _buildArrowButton(JwIcons.chevron_left),
          ),
        ),
      );
    }

    return arrows;
  }

  void _navigateArticle(int direction) {
    setState(() {
      _currentArticleIndex = (_currentArticleIndex + direction).clamp(0, _articles.length - 1);
    });
  }

  Widget _buildContentContainer(Map<String, dynamic> article, Size screenSize) {
    return Center(
      child: Container(
        width: screenSize.width * 0.9, // 90% de la largeur de l'écran
        constraints: BoxConstraints(
          maxWidth: 600, // Largeur maximale pour les grands écrans
          maxHeight: screenSize.height * 0.7, // Maximum 70% de la hauteur
        ),
        margin: EdgeInsets.only(top: 140), // Décale le conteneur vers le haut
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.70),
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
      onPressed: () => _navigateToArticle(article),
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

  void _navigateToArticle(Map<String, dynamic> article) {
    showPage(
      context,
      ArticlePage(
        title: article['Title'] ?? '',
        link: article['Link'] ?? '',
      ),
    );
  }

  Widget _buildLatestVideosWidget() {
    if (latestAudiosVideos.isEmpty) {
      return const SizedBox(height: 15);
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: latestAudiosVideos.length,
            itemBuilder: (context, mediaIndex) {
              return _buildMediaItemWidget(context, mediaIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItemWidget(BuildContext context, int mediaIndex) {
    MediaItem mediaItem = latestAudiosVideos[mediaIndex];
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

    return InkWell(
      onTap: () {
        if (isAudio) {
          showAudioPlayer(context, mediaItem);
        } else {
          showFullScreenVideo(context, mediaItem);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 2.0),
        child: SizedBox(
          width: 165,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildMediaImage(mediaItem, isAudio),
                  _buildPopupMenu(mediaItem, isAudio),
                  _buildMediaInfoOverlay(mediaItem, isAudio),
                  _buildDownloadButton(mediaItem),
                ],
              ),
              const SizedBox(height: 4),
              // Texte en dessous de l'image
              _buildMediaTitle(mediaItem, textToShow),
            ],
          ),
        ),
      ),
    );
  }

  Future<Color> getDominantColorFromFile2(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 40,
        targetHeight: 40,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return const Color(0xFFE0E0E0);

      final pixels = byteData.buffer.asUint8List();

      Map<String, int> colorFrequency = {};

      // Échantillonner tous les 4 pixels pour optimiser
      for (int i = 0; i < pixels.length; i += 16) {
        if (i + 3 < pixels.length) {
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];

          // Grouper les couleurs similaires (réduire la précision)
          final groupedR = (r ~/ 32) * 32;
          final groupedG = (g ~/ 32) * 32;
          final groupedB = (b ~/ 32) * 32;

          final colorKey = '$groupedR,$groupedG,$groupedB';
          colorFrequency[colorKey] = (colorFrequency[colorKey] ?? 0) + 1;
        }
      }

      final dominantColorKey = colorFrequency.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      final parts = dominantColorKey.split(',');
      return Color.fromARGB(
        255,
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return const Color(0xFFE0E0E0);
    }
  }

  // Votre widget modifié avec l'une des solutions
  Widget _buildMediaImage(MediaItem mediaItem, bool isAudio) {
    final images = mediaItem.realmImages!;
    final wideImageUrl = images.wideFullSizeImageUrl ?? images.wideImageUrl;
    final squareImageUrl = images.squareFullSizeImageUrl ?? images.squareImageUrl;

    final isWide = wideImageUrl != null;
    final imageUrl = wideImageUrl ?? squareImageUrl;

    if (isWide || imageUrl == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2.0),
        child: SizedBox(
          width: 165,
          height: 85,
          child: ImageCachedWidget(
            imageUrl: imageUrl,
            pathNoImage: isAudio ? "pub_type_audio" : "pub_type_video",
            height: 85,
            width: 165,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return FutureBuilder<Tile?>(
      future: JwLifeApp.tilesCache.getOrDownloadImage(imageUrl),
      builder: (context, snapshot) {
        final tile = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting || tile == null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: Container(
              width: 165,
              height: 85,
              alignment: Alignment.center,
              child: ImageCachedWidget(
                imageUrl: imageUrl,
                pathNoImage: isAudio ? "pub_type_audio" : "pub_type_video",
                height: 85,
                width: 85,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        return FutureBuilder<Color>(
          // Choisissez l'une des solutions ci-dessus
          future: getDominantColorFromFile2(tile.file), // Par exemple, la solution 2
          builder: (context, colorSnapshot) {
            final bgColor = colorSnapshot.data ?? const Color(0xFFE0E0E0);
            return ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: Container(
                width: 165,
                height: 85,
                color: bgColor,
                alignment: Alignment.center,
                child: Image.file(
                  tile.file,
                  width: 85,
                  height: 85,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupMenu(MediaItem mediaItem, bool isAudio) {
    return Positioned(
      top: -8,
      right: -13,
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
      top: 4,
      left: 4,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(isAudio ? JwIcons.headphones__simple : JwIcons.play, size: 12, color: Colors.white),
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

  Widget _buildMediaTitle(MediaItem mediaItem, String textToShow) {
    return Padding(
      padding: const EdgeInsets.only(left: 2.0, right: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mediaItem.title!,
            style: const TextStyle(
              fontSize: 10,
              height: 1.1,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
          Text(
            textToShow,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFc3c3c3)
                  : const Color(0xFF585858),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(MediaItem mediaItem) {
    Video? video = JwLifeApp.mediaCollections.getVideo(mediaItem);

    return video != null && video.isDownloaded == true ? Container() : Positioned(
      bottom: -7,
      right: -7,
      child: IconButton(
        iconSize: 22,
        padding: const EdgeInsets.all(0),
        onPressed: () async {
          if(await hasInternetConnection()) {
            String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${mediaItem.languageSymbol}/${mediaItem.languageAgnosticNaturalKey}';
            final response = await Api.httpGetWithHeaders(link);
            if (response.statusCode == 200) {
              final jsonFile = response.body;
              final jsonData = json.decode(jsonFile);

              printTime(link);

              showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
                if (value != null) {
                  downloadMedia(context, mediaItem, jsonData['media'][0], file: value);
                }
              });
            }
          }
        },
        icon: const Icon(JwIcons.cloud_arrow_down, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
      ),
    );
  }

  int _latestRequestId = 0;

  Future<void> fetchSuggestions(String query) async {
    final int requestId = ++_latestRequestId;

    const String baseImageUrl = "https://app.jw-cdn.org/catalogs/publications/";

    List<SuggestionItem> suggestions = [];

    if (query.isEmpty || requestId != _latestRequestId) {
      if(query.isEmpty) {
        setState(() {
          this.suggestions = suggestions;
        });
      }
      return;
    }

    // Rechercher dans les bases de données avec des sujets (topics)
    final List<Publication> pubsWithTopics = PublicationRepository()
        .getAllDownloadedPublications()
        .where((pub) => pub.hasTopics)
        .toList();

    for (final pub in pubsWithTopics) {
      final db = await openReadOnlyDatabase(pub.databasePath!);
      final topics = await db.rawQuery(
        '''
      SELECT 
        Topic.DisplayTopic,
        Document.MepsDocumentId
      FROM Topic
      LEFT JOIN TopicDocument ON Topic.TopicId = TopicDocument.TopicId
      LEFT JOIN Document ON TopicDocument.DocumentId = Document.DocumentId
      WHERE Topic.Topic LIKE ?
      LIMIT 1
      ''',
        ['%$query%'],
      );

      if (topics.isNotEmpty && requestId == _latestRequestId) {
        final topic = topics.first;
        SuggestionItem suggestionItem = SuggestionItem(
          type: 0,
          query: topic['MepsDocumentId'],
          caption: topic['DisplayTopic'] as String,
          icon: pub.imageSqr,
          subtitle: pub.title,
          label: 'Ouvrage de référence',
        );

        suggestions.add(suggestionItem);
      }
      else if(requestId != _latestRequestId) {
        return;
      }

      if(!pub.isBible()) {
        await db.close();
      }
    }

    // Rechercher dans la base de données principale (catalogue)
    final catalogFile = await getCatalogFile();
    final db = await openDatabase(catalogFile.path, readOnly: true);

    final result = await db.rawQuery(
      '''
    SELECT
      p.*,
      MAX(CASE WHEN ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600)
        THEN ia.NameFragment END) AS ImageSqr
    FROM Publication p
    LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
    LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
    LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
    WHERE LOWER(p.Symbol) = ? AND p.MepsLanguageId = ?
    GROUP BY p.Id
    LIMIT 1
    ''',
      [query.toLowerCase(), JwLifeSettings().currentLanguage.id],
    );

    if (result.isEmpty || result.first['KeySymbol'] == null) {
      final fallbackResult = await db.rawQuery(
        '''
      SELECT
        p.*,
        MAX(CASE WHEN ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600)
          THEN ia.NameFragment END) AS ImageSqr
      FROM Publication p
      LEFT JOIN PublicationAsset pa ON p.Id = pa.PublicationId
      LEFT JOIN PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
      LEFT JOIN ImageAsset ia ON paim.ImageAssetId = ia.Id
      WHERE p.Title COLLATE NOCASE LIKE ? AND p.MepsLanguageId = ?
      GROUP BY p.Id
      LIMIT 10
      ''',
        ['%${query.toLowerCase()}%', JwLifeSettings().currentLanguage.id],
      );

      if (fallbackResult.isNotEmpty && requestId == _latestRequestId) {
        final e = fallbackResult.first;
        suggestions.add(SuggestionItem(
          type: 2,
          query: e['Symbol'] ?? '',
          caption: e['Title'] as String,
          icon: e['ImageSqr'] != null ? "$baseImageUrl${e['ImageSqr']}" : null,
          subtitle: e['KeySymbol'] as String,
          label: 'Publication',
        ),);
      }
    }
    else if (requestId == _latestRequestId) {
      final e = result.first;
      suggestions.add(
        SuggestionItem(
          type: 2,
          query: e['Symbol'] ?? '',
          caption: e['Title'] as String,
          icon: e['ImageSqr'] != null ? "$baseImageUrl${e['ImageSqr']}" : null,
          subtitle: e['KeySymbol'] as String,
          label: 'Publication',
        ),
      );
    }
    else {
      return;
    }

    await db.close();

    // Rechercher dans les médias Realm
    final medias = RealmLibrary.realm.all<MediaItem>().query(
      r"title CONTAINS[c] $0 AND languageSymbol == $1",
      [query, JwLifeSettings().currentLanguage.symbol],
    );

    if (medias.isNotEmpty && requestId == _latestRequestId) {
      for (final media in medias.take(10)) {
        final category = RealmLibrary.realm
            .all<Category>()
            .query(r"key == $0", [media.primaryCategory ?? ''])
            .firstOrNull;

        suggestions.add(
          SuggestionItem(
            type: 3,
            query: media,
            caption: media.title.toString(),
            icon: media.realmImages?.squareImageUrl ?? '',
            subtitle: category?.localizedName ?? '',
            label: media.type == 'AUDIO' ? 'Audio' : 'Vidéo',
          ),
        );
      }
    }
    else if(requestId != _latestRequestId) {
      return;
    }

    setState(() {
      this.suggestions = suggestions;
    });
  }

  /// Méthode réutilisable pour construire chaque élément de suggestion
  SearchFieldListItem<SuggestionItem> _buildSuggestionItem(SuggestionItem item) {
    return SearchFieldListItem<SuggestionItem>(
      item.caption,
      item: item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (item.icon?.isNotEmpty ?? false)
              Row(
                children: [
                  ImageCachedWidget(
                    imageUrl: item.icon!,
                    pathNoImage: 'pub_type_placeholder',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.caption,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle?.isNotEmpty ?? false)
                    Text(
                      item.subtitle!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.type == 3) const SizedBox(width: 5),
            if (item.type == 3)
              Icon(item.label == 'Audio' ? JwIcons.music : JwIcons.video),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),

    );

    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: _isSearching
            ? AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                });
              },
            ),
          title: SearchField<SuggestionItem>(
            controller: _searchController,
            animationDuration: Duration(milliseconds: 300),
            itemHeight: 53,
            autofocus: true,
            offset: const Offset(-65, 55),
            maxSuggestionsInViewPort: 9,
            maxSuggestionBoxHeight: 200,
            suggestionState: Suggestion.expand,
            searchInputDecoration: SearchInputDecoration(
              hintText: localization(context).search_hint,
              searchStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1f1f1f)
                  : const Color(0xFFf1f1f1),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide.none,
              ),
              suffixIcon: GestureDetector(
                child: Container(
                  color: Color(0xFF345996),
                    margin: const EdgeInsets.only(left: 2),
                    child: Icon(JwIcons.magnifying_glass, color: Colors.white)
                ),
                 onTap: () {
                   setState(() => _isSearching = false);
                   showPage(context, SearchView(query: _searchController.text));
                },
              )
            ),
            suggestionsDecoration: SuggestionDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1f1f1f)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              width: MediaQuery.of(context).size.width-15,
            ),
            suggestions: suggestions.map(_buildSuggestionItem).toList(),
            onSearchTextChanged: (text) async {
              fetchSuggestions(text);
              return [];
            },
            onSuggestionTap: (item) async {
              final selected = item.item!;
              switch (selected.type) {
                case 0:
                  showDocumentView(context, selected.query, JwLifeSettings().currentLanguage.id);
                  break;
                case 1:
                  showPage(context, SearchBiblePage(query: selected.query));
                  break;
                case 2:
                  final publication = await PubCatalog.searchPub(selected.query, 0, JwLifeSettings().currentLanguage.id);
                  if (publication != null) {
                    publication.showMenu(context);
                  } else {
                    showErrorDialog(context, "Aucune publication ${selected.query} n'a pu être trouvée.");
                  }
                  break;
                case 3:
                  selected.label == 'Audio'
                      ? showAudioPlayer(context, selected.query)
                      : showFullScreenVideo(context, selected.query);
                  break;
                default:
                  showPage(context, SearchView(query: selected.query));
              }

              setState(() => _isSearching = false);
            },
            onSubmit: (text) {
              setState(() => _isSearching = false);
              showPage(context, SearchView(query: text));
            },
            onTapOutside: (_) => setState(() => _isSearching = false),
          )) : AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localization(context).navigation_home, style: textStyleTitle),
              Text(JwLifeSettings().currentLanguage.vernacular, style:  textStyleSubtitle),
            ],
          ),
          actions: [
            IconButton(
              disabledColor: Colors.grey,
              icon: Icon(JwIcons.magnifying_glass),
              onPressed: () async {
                setState(() {
                  _isSearching = true;
                });
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
                      if (value['Symbol'] != JwLifeSettings().currentLanguage.symbol) {
                        setLibraryLanguage(value);
                        _refreshChangeLanguage();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isRefreshing ? LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Colors.grey[300]) : SizedBox(height: 8),

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
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: JwLifeApp.userdata.favorites.length,
                                itemBuilder: (context, index) {
                                  Publication publication = JwLifeApp.userdata.favorites[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                    child: HomeSquarePublicationItem(pub: publication),
                                  );
                                },
                              ),
                            ),

                          if (PubCatalog.recentPublications.isNotEmpty)
                            Text(
                              'Publications récentes',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          if (PubCatalog.recentPublications.isNotEmpty)
                            const SizedBox(height: 4),
                          if (PubCatalog.recentPublications.isNotEmpty)
                            SizedBox(
                              height: 120, // Hauteur à ajuster selon votre besoin
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: PubCatalog.recentPublications.length,
                                itemBuilder: (context, index) {
                                  Publication publication = PubCatalog.recentPublications[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                    child: HomeSquarePublicationItem(pub: publication),
                                  );
                                },
                              ),
                            ),

                          /// Teaching Toolbox
                          Text(
                            localization(context).navigation_ministry,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),

                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: teachingToolboxVideos.length + PubCatalog.teachingToolBoxPublications.length,
                              itemBuilder: (context, index) {
                                // Déterminer si l'élément est une vidéo ou une publication
                                if (index < teachingToolboxVideos.length) {
                                  // Partie des vidéos
                                  MediaItem mediaItem = teachingToolboxVideos[index];
                                  bool isAudio = mediaItem.type == "AUDIO";

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                    child: InkWell(
                                        onTap: () {
                                          if (isAudio) {
                                            showAudioPlayer(context, mediaItem);
                                          }
                                          else {
                                            showFullScreenVideo(context, mediaItem);
                                          }
                                        },
                                        child: SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Stack(
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
                                                            isAudio ? JwIcons.headphones__simple : JwIcons.play,
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
                                              SizedBox(height: 4),
                                              SizedBox(
                                                width: 80,
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
                                        )
                                    )
                                  );
                                }
                                else {
                                  int pubIndex = index - teachingToolboxVideos.length;
                                  Publication? pub = PubCatalog.teachingToolBoxPublications[pubIndex];

                                  // Vérifier si la valeur est présente dans availableTeachingToolBoxInt
                                  if (pub != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                      child: HomeSquarePublicationItem(pub: pub),
                                    );
                                  }
                                  else {
                                    return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 2.0),
                                        child: SizedBox(
                                            width: 20
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
                            height: 80, // Adjust height as needed
                            child: PubCatalog.lastPublications.isEmpty ? getLoadingWidget(Theme.of(context).primaryColor) : ListView.builder(
                              scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
                              itemCount: PubCatalog.lastPublications.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                  child: HomeRectanglePublicationItem(pub: PubCatalog.lastPublications[index])
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
                            height: 110, // Augmenté pour tenir compte du texte sur 2 lignes
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _iconLinks(context).length,
                              itemBuilder: (context, index) {
                                final iconLinkInfo = _iconLinks(context)[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2.0), // Espacement entre chaque icône
                                  child: IconLink(
                                    imagePath: iconLinkInfo.imagePath,
                                    url: iconLinkInfo.url,
                                    description: iconLinkInfo.description,
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),
                        ]
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
    return InkWell(
      onTap: () {
        _launchURL(url);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
            ),
          ),
          SizedBox(height: 2), // Espacement entre l'image et le texte
          SizedBox(
            width: 80, // Assure que le texte s'aligne avec l'image
            height: 28, // Hauteur fixe pour le texte (environ 2 lignes de texte)
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
    IconLinkInfo('assets/icons/nav_jworg.png', localization(context).navigation_official_website, 'https://www.jw.org/${JwLifeSettings().currentLanguage.primaryIetfCode}'),
    IconLinkInfo('assets/icons/nav_jwb.png', localization(context).navigation_online_broadcasting, 'https://www.jw.org/open?docid=1011214&wtlocale=${JwLifeSettings().currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_onlinelibrary.png', localization(context).navigation_online_library, 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeSettings().currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_donation.png', localization(context).navigation_online_donation, 'https://donate.jw.org/ui/${JwLifeSettings().currentLanguage.symbol}/donate-home.html'),
    IconLinkInfo(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/icons/nav_github_light.png'
          : 'assets/icons/nav_github_dark.png',
      localization(context).navigation_online_gitub,
      'https://github.com/Noamcreator/jwlife',
    ),
  ];
}