import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as html;
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/databases/mepsunit.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/widgets/home_page/favorite_section.dart';
import 'package:jwlife/features/home/widgets/home_page/latest_medias_section.dart';
import 'package:jwlife/features/home/widgets/home_page/alert_banner.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../../app/services/file_handler_service.dart';
import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../widgets/home_page/article_widget.dart';
import '../widgets/home_page/daily_text_widget.dart';
import '../widgets/home_page/frequently_used_section.dart';
import '../widgets/home_page/home_appbar.dart';
import '../widgets/home_page/latest_publications_section.dart';
import '../widgets/home_page/linear_progress.dart';
import '../widgets/home_page/online_section.dart';
import '../widgets/home_page/toolbox_section.dart';
import 'article_page.dart';
import '../../settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GlobalKey<LinearProgressState> _linearProgressKey = GlobalKey<LinearProgressState>();

  final GlobalKey<AlertBannerState> _alertBannerKey = GlobalKey<AlertBannerState>();
  final GlobalKey<DailyTextWidgetState> _dailyTextKey = GlobalKey<DailyTextWidgetState>();
  final GlobalKey<ArticleWidgetState> _articlesKey = GlobalKey<ArticleWidgetState>();

  final GlobalKey<FavoritesSectionState> _favoritesKey = GlobalKey<FavoritesSectionState>();
  final GlobalKey<FrequentlyUsedSectionState> _frequentlyUsedKey = GlobalKey<FrequentlyUsedSectionState>();
  final GlobalKey<ToolboxSectionState> _toolboxKey = GlobalKey<ToolboxSectionState>();

  final GlobalKey<LatestPublicationsSectionState> _latestPublicationsKey = GlobalKey<LatestPublicationsSectionState>();
  final GlobalKey<LatestMediasSectionState> _latestMediasKey = GlobalKey<LatestMediasSectionState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _init(first: true);

      if(JwOrgUri.startUri != null) {
        GlobalKeyService.jwLifeAppKey.currentState!.handleUri(JwOrgUri.startUri!);
        JwOrgUri.startUri = null;
      }

      FileHandlerService().processPendingContent();
    });
  }

  Future<void> _init({bool first = true}) async {
    printTime("Init start");
    _initPage();
    printTime("Init end");

    printTime("Refresh page start");
    _refresh(first: first);
    printTime("Refresh page end");

    _loadWolInfo();
    await Mepsunit.loadBibleCluesInfo();
    await PubCatalog.fetchOtherMeetingsPubs();
    await PubCatalog.fetchAssemblyPublications();

    printTime("Refresh MeetingsView start");

    GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();
  }

  Future<void> _initPage() async {
    fetchVerseOfTheDay();
    fetchAlertInfo();
    fetchArticles();

    _favoritesKey.currentState?.refreshFavorites();
    _frequentlyUsedKey.currentState?.refreshFrequentlyUsed();
    _toolboxKey.currentState?.refreshToolbox();
    _latestPublicationsKey.currentState?.refreshLatestPublications();
    _latestMediasKey.currentState?.refreshLatestMedias();
  }

  Future<void> changeLanguageAndRefresh() async {
    printTime("Refresh change language start");
    GlobalKeyService.libraryKey.currentState?.refreshLibraryCategories();
    PubCatalog.updateCatalogCategories();

    // Enveloppe toute la première séquence dans un Future synchronisé
    PubCatalog.loadPublicationsInHomePage().then((_) async {
      printTime("Refresh Homepage start");
      _frequentlyUsedKey.currentState?.refreshFrequentlyUsed();
      _toolboxKey.currentState?.refreshToolbox();
      _latestPublicationsKey.currentState?.refreshLatestPublications();

      fetchVerseOfTheDay();

      GlobalKeyService.meetingsKey.currentState?.refreshMeetingsPubs();

      await Mepsunit.loadBibleCluesInfo();
      await PubCatalog.fetchOtherMeetingsPubs();
      await PubCatalog.fetchAssemblyPublications();

      printTime("Refresh MeetingsView start");
      GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();
    });

    _articlesKey.currentState!.setArticles([]);

    _loadWolInfo();
    _initPage();
    _refresh(first: true);
  }

  Future<void> _loadWolInfo() async {
    if(JwLifeSettings().currentLanguage.rsConf.isEmpty || JwLifeSettings().currentLanguage.lib.isEmpty) {
      final wolLink = 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeSettings().currentLanguage.symbol}';
      printTime('WOL link: $wolLink');

      try {
        final headers = Api.getHeaders();

        final response = await Api.dio.get(
          wolLink,
          options: Options(
            headers: headers,
            followRedirects: false, // Bloque la redirection automatique
            maxRedirects: 0,
            validateStatus: (status) => true,
          ),
        );

        // Afficher tous les headers de la réponse
        printTime('All headers: ${response.headers}');

        // Gestion des codes de redirection (301, 302, 307, 308)
        if ([301, 302, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value('location');
          if (location != null && location.isNotEmpty) {
            // Analyse de l'URL de redirection
            final parts = location.split('/');
            if (parts.length >= 6) {
              final rCode = parts[4];
              final lpCode = parts[5];
              printTime('rCode: $rCode');
              printTime('lpCode: $lpCode');

              JwLifeSettings().currentLanguage.setRsConf(rCode);
              JwLifeSettings().currentLanguage.setLib(lpCode);

              setLibraryLanguage(JwLifeSettings().currentLanguage);
            }
          } else {
            printTime('No location header found in redirect response');
          }
        } else if (response.statusCode == 200) {
          printTime('Direct response (no redirect)');
          // Traitement si pas de redirection
        } else {
          printTime('Unexpected status code: ${response.statusCode}');
        }

      } catch (e, stack) {
        printTime('Error loading WOL info: $e');
        print(stack);
      }
    }
  }

  Future<void> _refresh({bool first = false}) async {
    printTime("Refresh start");
    if (!await hasInternetConnection()) {
      showBottomMessage('Aucune connexion Internet');
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
        showBottomMessage('Aucune mise à jour disponible');
      }
      return;
    }

    showBottomMessage('Mise à jour disponible');

    _linearProgressKey.currentState?.startRefreshing();

    // Préparer les tâches de mise à jour
    final List<Future> updateTasks = [];

    if (libraryUpdate) {
      updateTasks.add(
        Api.updateLibrary(JwLifeSettings().currentLanguage.symbol).then((_) {
          _toolboxKey.currentState?.refreshToolbox();
          _latestMediasKey.currentState?.refreshLatestMedias();
          GlobalKeyService.libraryKey.currentState?.refreshLibraryCategories();
        }),
      );
    }

    if (catalogUpdate) {
      updateTasks.add(
        Api.updateCatalog().then((_) async {
          await PubCatalog.loadPublicationsInHomePage().then((_) async {
            printTime("Refresh Homepage start");
            _frequentlyUsedKey.currentState?.refreshFrequentlyUsed();
            _toolboxKey.currentState?.refreshToolbox();
            _latestPublicationsKey.currentState?.refreshLatestPublications();

            fetchVerseOfTheDay();

            PubCatalog.updateCatalogCategories();
            GlobalKeyService.meetingsKey.currentState?.refreshMeetingsPubs();

            await PubCatalog.fetchOtherMeetingsPubs();
            await PubCatalog.fetchAssemblyPublications();

            GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();
          });
        }),
      );
    }

    // Exécuter toutes les tâches en parallèle
    await Future.wait(updateTasks);

    showBottomMessage('Mise à jour terminée');

    _linearProgressKey.currentState?.stopRefreshing();
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

        _alertBannerKey.currentState!.setAlerts(data['alerts']);
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

    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));

    if (verseOfTheDayPub != null) {
      _dailyTextKey.currentState!.setVersePub(verseOfTheDayPub);
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

        final decodedHtml = decodeBlobContent(document!['Content'] as Uint8List, verseOfTheDayPub.hash!);
        final htmlDocument = html_parser.parse(decodedHtml);

        _dailyTextKey.currentState!.setVerseOfTheDay(htmlDocument.querySelector('.themeScrp')?.text ?? '');
      }
    }
    printTime("fetchVerseOfTheDay end");
  }

  Future<void> fetchArticles() async {
    printTime("fetchArticleInHomePage");

    final languageSymbol = JwLifeSettings().currentLanguage.symbol;
    final articlesDbFile = await getArticlesDatabaseFile();

    final db = await openDatabase(
      articlesDbFile.path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1 && newVersion == 2) {
          await db.execute('''
          ALTER TABLE Article ADD COLUMN Theme TEXT DEFAULT 'dark';
          ''');
        }
      },
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
  ''', [languageSymbol]);

    if (articles.isNotEmpty) {
      _articlesKey.currentState!.setArticles(List<Map<String, dynamic>>.from(articles));
    }

    printTime('fetchArticleInHomePage request end');

    final response = await Api.httpGetWithHeaders('https://jw.org/${JwLifeSettings().currentLanguage.primaryIetfCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load content');
    }

    printTime("fetchArticleInHomePage document start");

    final document = html_parser.parse(response.body);

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

    // 6. Thème
    final String theme = getThemeFromBillboard(firstBillboard);

    // 7. URLs des images
    //final String imageUrlLss = getImageUrlFromFirst('.lss');
    final String imageUrlLsr = getImageUrlFromFirst('.lsr');
    final String imageUrlPnr = getImageUrlFromFirst('.pnr');

    final lastArticle = articles.firstWhereOrNull(
          (article) =>
      article['Title'] == title &&
          article['ContextTitle'] == contextTitle &&
          article['Description'] == description &&
          article['ButtonText'] == buttonText &&
          article['Theme'] == theme,
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
        'LanguageSymbol': languageSymbol,
        'ImagePathLsr': imagePathLsr,
        'ImagePathPnr': imagePathPnr,
      };

      _articlesKey.currentState!.addArticle(newArticle);

      // Enregistrement en base
      final articleId = await saveArticleToDatabase(db, newArticle);
      await saveImagesToDatabase(db, articleId, newArticle);
    }
    else if (articles.first['Title'] != lastArticle['Title'] && articles.first['ContextTitle'] != lastArticle['ContextTitle'] && articles.first['Description'] != lastArticle['Description'] && articles.first['ButtonText'] != lastArticle['ButtonText'] && articles.first['Theme'] != lastArticle['Theme']) {
      _articlesKey.currentState!.moveArticleToTop(lastArticle);
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
      'Timestamp': article['Timestamp'],
      'Link': article['Link'],
      'Content': article['Content'],
      'ButtonText': article['ButtonText'],
      'Theme': article['Theme'],
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

  void refreshFavorites() {
    _favoritesKey.currentState?.refreshFavorites();
  }

  @override
  Widget build(BuildContext context) {
    print('Build HomePage');

    double screenWidth = MediaQuery.of(context).size.width;

    // Calcul du padding proportionnel
    double horizontalPadding = (screenWidth * 0.03).clamp(8.0, 40.0);

    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: HomeAppBar(
          onOpenSettings: () {
            showPage(SettingsPage());
          },
        ),
        body: RefreshIndicator(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          onRefresh: () async {
            if (await hasInternetConnection() && !_linearProgressKey.currentState!.isRefreshing) {
              await _refresh();
            }
            else if (!_linearProgressKey.currentState!.isRefreshing) {
              showNoConnectionDialog(context);
            }
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /* Afficher la progress bar de chargement */
                LinearProgress(key: _linearProgressKey),

                /* Afficher le banner */
                AlertBanner(key: _alertBannerKey),

                /* Afficher le texte du jour */
                DailyTextWidget(key: _dailyTextKey),

                /* Afficher l'article en page d'accueil */
                ArticleWidget(
                  key: _articlesKey,
                  onReadMore: (article) {
                    showPage(
                      ArticlePage(
                        title: article['Title'] ?? '',
                        link: article['Link'] ?? '',
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                        children: [
                          FavoritesSection(
                              key: _favoritesKey,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                JwLifeApp.userdata.reorderFavorites(oldIndex, newIndex);
                                _favoritesKey.currentState?.refreshFavorites();
                              }
                          ),

                          /* Afficher la section des publications fréquemment utilisées */
                          FrequentlyUsedSection(key: _frequentlyUsedKey),

                          /* Afficher la section de la panoplie d'enseignants */
                          ToolboxSection(key: _toolboxKey),

                          /* Afficher la section des nouveaux */
                          LatestPublicationSection(key: _latestPublicationsKey),

                          const SizedBox(height: 4),

                          LatestMediasSection(key: _latestMediasKey),

                          /* Afficher la section Online */
                          const OnlineSection(),

                          const SizedBox(height: 25),
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