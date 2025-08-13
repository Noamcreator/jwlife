import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/bible_clues_info.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/features/home/widgets/home_page/favorite_section.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/pages/alert_banner.dart';
import 'package:jwlife/features/home/widgets/home_page/rectangle_publication_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/mediaitem_item_widget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../widgets/home_page/article_widget.dart';
import '../widgets/home_page/daily_text_widget.dart';
import '../widgets/home_page/home_appbar.dart';
import 'article_page.dart';
import '../../settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GlobalKey<AlertBannerState> _alertBannerKey = GlobalKey<AlertBannerState>();
  final GlobalKey<DailyTextWidgetState> _dailyTextKey = GlobalKey<DailyTextWidgetState>();
  final GlobalKey<ArticleWidgetState> _articlesKey = GlobalKey<ArticleWidgetState>();

  final GlobalKey<FavoriteSectionState> _favoritesKey = GlobalKey<FavoriteSectionState>();

  List<dynamic> _favorites = [];
  List<Publication> _recentPublications = [];
  List<Publication?> _teachingToolboxPublications = [];
  List<Publication> _latestPublications = [];

  List<MediaItem> _teachingToolboxVideos = [];
  List<MediaItem> _latestAudiosVideos = [];

  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
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
    GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();
  }

  Future<void> _initPage() async {
    fetchVerseOfTheDay();
    fetchAlertInfo();
    fetchArticleInHomePage();

    _favoritesKey.currentState?.refreshFavorites();

    setState(() {
      _recentPublications = PubCatalog.recentPublications;
      _teachingToolboxPublications = PubCatalog.teachingToolboxPublications;
      _latestPublications = PubCatalog.latestPublications;
      _teachingToolboxVideos = RealmLibrary.loadTeachingToolboxVideos();
      _latestAudiosVideos = RealmLibrary.loadLatestVideos();
    });
  }

  Future<void> changeLanguageAndRefresh() async {
    printTime("Refresh change language start");
    GlobalKeyService.libraryKey.currentState?.refreshLibraryCategories();
    PubCatalog.updateCatalogCategories();

    // Enveloppe toute la première séquence dans un Future synchronisé
    PubCatalog.loadPublicationsInHomePage().then((_) async {
      printTime("Refresh Homepage start");
      setState(() {
        _recentPublications = PubCatalog.recentPublications;
        _teachingToolboxPublications = PubCatalog.teachingToolboxPublications;
        _latestPublications = PubCatalog.latestPublications;
      });

      GlobalKeyService.meetingsKey.currentState?.refreshMeetingsPubs();

      await _loadBibleCluesInfo();
      await PubCatalog.fetchAssemblyPublications();

      printTime("Refresh MeetingsView start");
      GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();

      fetchVerseOfTheDay();
    });

    _initPage();
    _refresh(first: true);
  }

  Future<void> _loadBibleCluesInfo() async {
    File mepsFile = await getMepsUnitDatabaseFile();

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
      isRefreshing = true;
    });

    // Préparer les tâches de mise à jour
    final List<Future> updateTasks = [];

    if (libraryUpdate) {
      updateTasks.add(
        Api.updateLibrary(JwLifeSettings().currentLanguage.symbol).then((_) {
          setState(() {
            _teachingToolboxVideos = RealmLibrary.loadTeachingToolboxVideos();
            _latestAudiosVideos = RealmLibrary.loadLatestVideos();
          });
          GlobalKeyService.libraryKey.currentState?.refreshLibraryCategories();
        }),
      );
    }

    if (catalogUpdate) {
      updateTasks.add(
        Api.updateCatalog().then((_) async {
          await PubCatalog.loadPublicationsInHomePage().then((_) async {
            printTime("Refresh Homepage start");
            setState(() {
              _recentPublications = PubCatalog.recentPublications;
              _teachingToolboxPublications = PubCatalog.teachingToolboxPublications;
              _latestPublications = PubCatalog.latestPublications;
            });

            PubCatalog.updateCatalogCategories();
            GlobalKeyService.meetingsKey.currentState?.refreshMeetingsPubs();

            await PubCatalog.fetchAssemblyPublications();

            GlobalKeyService.meetingsKey.currentState?.refreshConventionsPubs();

            fetchVerseOfTheDay();
          });
        }),
      );
    }

    // Exécuter toutes les tâches en parallèle
    await Future.wait(updateTasks);

    showBottomMessage(context, 'Mise à jour terminée');

    setState(() {
      isRefreshing = false;
    });
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

    Publication? verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'),);

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

        final decodedHtml = decodeBlobContent(document!['Content'] as Uint8List, verseOfTheDayPub.hash!);
        final htmlDocument = html_parser.parse(decodedHtml);

        _dailyTextKey.currentState!.setVerseOfTheDay(htmlDocument.querySelector('.themeScrp')?.text ?? '');
      }
    }
    printTime("fetchVerseOfTheDay end");
  }

  Future<void> fetchArticleInHomePage() async {
    printTime("fetchArticleInHomePage");

    final languageSymbol = JwLifeSettings().currentLanguage.symbol;
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
    LIMIT 3
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

    // Récupère le premier .billboard
    final firstBillboard = document.querySelector('.billboard');

    // Fonction pour récupérer l'URL à partir d'une classe interne
    String getImageUrlFromFirst(String className) {
      if (firstBillboard == null) return '';
      final style = firstBillboard
          .querySelector('$className .billboard-media-image')
          ?.attributes['style'] ?? '';
      final match = RegExp(r'url\(([^)]+)\)').firstMatch(style);
      return match?.group(1) ?? '';
    }

    // Extraction des infos uniquement dans le premier billboard
    final contextTitle = firstBillboard
        ?.querySelector('.contextTitle')
        ?.text
        .trim() ?? '';

    final title = firstBillboard
        ?.querySelector('.billboardTitle a')
        ?.text
        .trim() ?? '';

    final description = firstBillboard
        ?.querySelector('.billboardDescription .bodyTxt .p2')
        ?.text
        .trim() ?? '';

    final link = firstBillboard
        ?.querySelector('.billboardTitle a')
        ?.attributes['href'] ?? '';

    final buttonText = firstBillboard
        ?.querySelector('.billboardButton .buttonText')
        ?.text
        .trim() ?? '';

    // Images du premier billboard
    final imageUrlLsr = getImageUrlFromFirst('.billboard-media.lsr');
    final imageUrlPnr = getImageUrlFromFirst('.billboard-media.pnr');

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
        'Timestamp': DateTime.now().toString(),
        'Link': fullLink,
        'Content': '', // Ajouter contenu si besoin
        'ButtonText': buttonText,
        'LanguageSymbol': languageSymbol,
        'ImagePathLsr': imagePathLsr,
        'ImagePathPnr': imagePathPnr,
      };

      _articlesKey.currentState!.addArticle(newArticle);

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

  Widget _buildLatestVideosWidget() {
    if (_latestAudiosVideos.isEmpty) {
      return const SizedBox(height: 15);
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _latestAudiosVideos.length,
            itemBuilder: (context, mediaIndex) {
              return MediaItemItemWidget(
                  mediaItem: _latestAudiosVideos[mediaIndex],
                  timeAgoText: true
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Build HomePage');

    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: HomeAppBar(
          onOpenSettings: () {
            showPage(context, SettingsPage());
          },
        ),
        body: RefreshIndicator(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          onRefresh: () async {
            if (await hasInternetConnection() && !isRefreshing) {
              await _refresh();
            }
            else if (!isRefreshing) {
              showNoConnectionDialog(context);
            }
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isRefreshing ? LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Colors.grey[300]) : SizedBox(height: 8),

                /* Afficher le banner */
                AlertBanner(key: _alertBannerKey),

                /* Afficher le texte du jour */
                DailyTextWidget(key: _dailyTextKey),

                /* Afficher l'article en page d'accueil */
                ArticleWidget(
                  key: _articlesKey,
                  onReadMore: (article) {
                    showPage(
                      context,
                      ArticlePage(
                        title: article['Title'] ?? '',
                        link: article['Link'] ?? '',
                      ),
                    );
                  },
                ),

                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                        children: [
                          const SizedBox(height: 20),

                          if (_favorites.isNotEmpty)
                            FavoritesSection(
                                key: _favoritesKey,
                                onReorder: (oldIndex, newIndex) {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  JwLifeApp.userdata.reorderFavorites(oldIndex, newIndex);
                                  _favoritesKey.currentState?.refreshFavorites();
                                }
                            ),

                          if (_recentPublications.isNotEmpty)
                            Text(
                              'Publications récentes',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          if (_recentPublications.isNotEmpty)
                            const SizedBox(height: 4),
                          if (_recentPublications.isNotEmpty)
                            SizedBox(
                              height: 120, // Hauteur à ajuster selon votre besoin
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentPublications.length,
                                itemBuilder: (context, index) {
                                  Publication publication = _recentPublications[index];
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
                              itemCount: _teachingToolboxVideos.length + _teachingToolboxPublications.length,
                              itemBuilder: (context, index) {
                                // Déterminer si l'élément est une vidéo ou une publication
                                if (index < _teachingToolboxVideos.length) {
                                  // Partie des vidéos
                                  MediaItem mediaItem = _teachingToolboxVideos[index];

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                    child: HomeSquareMediaItemItem(mediaItem: mediaItem),
                                  );
                                }
                                else {
                                  int pubIndex = index - _teachingToolboxVideos.length;
                                  Publication? pub = _teachingToolboxPublications[pubIndex];

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
                            child: _latestPublications.isEmpty ? getLoadingWidget(Theme.of(context).primaryColor) : ListView.builder(
                              scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
                              itemCount: _latestPublications.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                    padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                                    child: HomeRectanglePublicationItem(pub: _latestPublications[index])
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