import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/directory_helper.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_publication.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/l10n/localization.dart';
import 'package:jwlife/modules/home/views/alert_banner.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/modules/library/views/publication/publications_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
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
  static late Function() setStateFavorites;
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;
  static Map<String, dynamic> dailyTextPub = {};

  HomeView({Key? key, required this.toggleTheme, required this.changeLocale}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  dynamic alerts = {};
  dynamic verseOfTheDay = {'Verse': '', 'Content': '', 'Class': ''};
  dynamic article = {};
  List<Map<String, dynamic>> suggestions = [];

  bool _isRefreshing = false;
  bool _isSearchVisible = false; // Variable d'état pour contrôler l'affichage du SearchBar

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    HomeView.setStateHomePage = _reloadPage;
    HomeView.setStateFavorites = _setStateFavorites;
    _reloadPage();
    _refresh(first: true);
  }

  Future<void> _reloadPage() async {
    await fetchPublicationsOfTheDay();
    fetchAlertInfo();
    fetchVerseOfTheDay();
    fetchArticleInHomePage();
    RealmLibrary.loadTeachingToolboxVideos();
    RealmLibrary.loadLatestVideos();
    await PublicationsCatalog.loadLastPublications(12).then((loadedPublications) {
      setState(() {});
    });
  }

  Future<void> _refresh({bool first=false}) async {
    if (await hasInternetConnection()) {
      // Vérifier si une mise à jour du catalogue est disponible
      bool catalogUpdate = await Api.isCatalogUpdateAvailable();

      // Vérifier si une mise à jour de la bibliothèque est disponible
      bool libraryUpdate = await Api.isLibraryUpdateAvailable(JwLifeApp.currentLanguage.symbol);

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
          await Api.updateLibrary(JwLifeApp.currentLanguage.symbol);
          await RealmLibrary.loadLatestVideos();
          await RealmLibrary.loadTeachingToolboxVideos();

          setState(() {});

          LibraryView.setStateLibraryPage();
        }

        // Si une mise à jour du catalogue est disponible
        if (catalogUpdate) {
          await Api.updateCatalog();
          await PublicationsCatalog.loadLastPublications(12);

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

  _setStateFavorites() {
    setState(() {});
  }

  Future<void> fetchAlertInfo() async {
    // Préparer les paramètres de requête pour l'URL
    final queryParams = {
      'type': 'news',
      'lang': JwLifeApp.currentLanguage.symbol,
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

  Future<void> fetchPublicationsOfTheDay() async {
    List<Map<String, dynamic>> pubOfTheDayList = await PublicationsCatalog.getPublicationsForTheDay();

    if (pubOfTheDayList.isNotEmpty) {
      HomeView.dailyTextPub = Map<String, dynamic>.from(pubOfTheDayList.firstWhere((element) => element['PublicationCategorySymbol'] == 'es'));
      MeetingsView.watchtowerPub = Map<String, dynamic>.from(pubOfTheDayList.firstWhere((element) => element['PublicationCategorySymbol'] == 'w'));
      MeetingsView.meetingWorkbookPub = Map<String, dynamic>.from(pubOfTheDayList.firstWhere((element) => element['PublicationCategorySymbol'] == 'mwb'));
    }
  }

  Future<void> fetchVerseOfTheDay() async {
    if (HomeView.dailyTextPub.isNotEmpty) {
      String? dailyTextHtml = await PublicationsCatalog.getDatedDocumentForToday(HomeView.dailyTextPub);
      if (dailyTextHtml != null) {
        final document = html_parser.parse(dailyTextHtml);
        setState(() {
          verseOfTheDay['Verse'] = document.querySelector('.themeScrp')?.text ?? '';
          verseOfTheDay['Content'] = dailyTextHtml;
          verseOfTheDay['Class'] = 'jwac ms-ROMAN ml-F dir-ltr layout-reading layout-sidebar';
        });
      }
    }

    try {
      // Préparer les paramètres de requête
      final queryParams = {
        'wtlocale': JwLifeApp.currentLanguage.symbol, // langue de la recherche
        'alias': 'daily-text', // type de la recherche
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1))), // date pour la recherche +1 jour pour avoir le bon jour
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
          final articleClasses = document.querySelector('article')?.className;
          final articleClasses2 = document.querySelector('#dailyText')?.className;

          if (doc != null) {
            setState(() {
              verseOfTheDay['Verse'] = doc.querySelector('.themeScrp')?.text ?? '';
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
        } else {
          throw Exception('Elements #contentRsconf or #contentLib not found');
        }
      }
      else {
        throw Exception('Failed to load publication');
      }
    }
    catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchArticleInHomePage() async {
    // Ouvrir ou créer la base de données
    String languageSymbol = JwLifeApp.currentLanguage.symbol;
    File articlesDbFile = await getArticlesFile();
    final db = await openDatabase(articlesDbFile.path, version: 1, onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE Article (ArticleId INTEGER PRIMARY KEY AUTOINCREMENT, ContextTitle TEXT, Title TEXT, Description TEXT, Link TEXT, Content TEXT, ImagePath TEXT, ButtonText TEXT, LanguageSymbol TEXT)',
      );
      await db.execute(
        'CREATE TABLE Image (ImageId INTEGER PRIMARY KEY AUTOINCREMENT, Link TEXT, Name TEXT, Path TEXT, Alt TEXT)',
      );
    });

    // Récupérer le dernier article
    final List<Map<String, dynamic>> articles = await db.query(
      'Article',
      orderBy: 'ArticleId DESC',
      where: 'LanguageSymbol = ?',
      whereArgs: [languageSymbol],
      limit: 1,
    );

    // Si un article existe déjà, l'afficher
    if (articles.isNotEmpty) {
      setState(() {
        article = articles.first;
      });
    }

    // Faire la requête réseau pour récupérer l'article le plus récent
    final response = await http.get(Uri.parse('https://jw.org/${JwLifeApp.currentLanguage.primaryIetfCode}'));

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);

      String imageUrlLsr = document
          .querySelector('.billboard-media.lss .billboard-media-image')
          ?.attributes['style']
          ?.split('url(')[1]
          .split(')')[0] ?? '';

      String contextTitle = document.querySelector('.contextTitle')?.text ?? '';
      String title = document.querySelector('.billboardTitle a')?.text ?? '';
      String description = document.querySelector('.billboardDescription .bodyTxt .p2')?.text ?? '';
      String link = document.querySelector('.billboardTitle a')?.attributes['href'] ?? '';
      String buttonText = document.querySelector('.billboardButton .buttonText')?.text ?? '';

      // Si les données sont nouvelles, ajouter l'article à la base de données
      if (articles.isEmpty || title != articles.first['Title']) {
        Directory appTileDirectory = await getAppTileDirectory();

        // Télécharger et enregistrer l'image puis récupérer son chemin
        String imagePath = await downloadAndSaveImage(imageUrlLsr, appTileDirectory);
        String languageSymbol = JwLifeApp.currentLanguage.symbol;

        // Télécharger le contenu de l'article via le lien
        String fullLink = 'https://www.jw.org/' + link;
        String fullArticleHtml = await fetchArticleContent(db, fullLink);

        setState(() {
          article = {
            'ContextTitle': contextTitle,
            'Title': title,
            'Description': description,
            'Link': fullLink,
            'Content': fullArticleHtml,
            'ImagePath': imagePath,
            'ButtonText': buttonText,
            'LanguageSymbol': languageSymbol
          };
        });

        await saveArticleToDatabase(db, title, contextTitle, description, fullLink, fullArticleHtml, imagePath, buttonText, languageSymbol);
      }
    }
    else {
      throw Exception('Failed to load content');
    }
  }

  // Enregistrer l'article dans la base de données
  Future<void> saveArticleToDatabase(Database db, String title, String contextTitle, String description, String link, String fullArticleHtml, String imagePath, String buttonText, String languageSymbol) async {
    await db.insert('article', {
      'Title': title,
      'ContextTitle': contextTitle,
      'Description': description,
      'Link': link,
      'Content': fullArticleHtml,
      'ImagePath': imagePath,
      'ButtonText': buttonText,
      'LanguageSymbol': languageSymbol,
    });
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

      print('articleTopRelatedImage: $articleTopRelatedImage');
      print('textSizeIncrement: $textSizeIncrement');
      print('docSubContent: $docSubContent');
      print('className: $className');

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

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        suggestions = []; // Clear suggestions if the query is empty
      });
      return;
    }

    // Prepare the query for the API call
    String newQuery = Uri.encodeComponent(query);
    final String url = "https://wol.jw.org/wol/sg/${JwLifeApp.currentLanguage.rsConf}/${JwLifeApp.currentLanguage.lib}?q=$newQuery";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      // Verify that 'items' is a list
      if (jsonResponse['items'] is List) {
        setState(() {
          suggestions = (jsonResponse['items'] as List).map((item) {
            return {
              'type': item['type'] ?? 0,
              'query': item['query'] ?? '',
              'caption': item['caption'] ?? '',
              'label': item['label'] ?? '',
            };
          }).toList();
        });
      }
      else {
        setState(() {
          suggestions = []; // Initialize suggestions to an empty list
        });
      }
    }
    else {
      throw Exception('Error fetching suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    initializeDateFormatting(JwLifeApp.currentLanguage.primaryIetfCode);
    DateTime now = DateTime.now();
    String formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', JwLifeApp.currentLanguage.primaryIetfCode).format(now));

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
              icon: const Icon(JwIcons.language),
              onPressed: () async {
                LanguageDialog languageDialog = LanguageDialog();
                showDialog(
                  context: context,
                  builder: (context) => languageDialog,
                ).then((value) {
                  if(value != null) {
                    setState(() async {
                      if (value['Symbol'] != JwLifeApp.currentLanguage.symbol) {
                        await setLibraryLanguage(value);
                        _reloadPage();
                        _refresh();
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
                ));
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          onRefresh: () async {
            if (await hasInternetConnection()) {
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
                  _isRefreshing
                      ? LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), // Couleur de remplissage de l'indicateur
                  ) : SizedBox(height: 8),

                  if (alerts.isNotEmpty)
                    AlertBanner(alerts: alerts),

                  if (alerts.isNotEmpty)
                    const SizedBox(height: 8), // Espace entre l'info et le texte du jour

                  /* Afficher le texte du jour avec la date en haut et le verset en bas */
                  GestureDetector(
                    onTap: () {
                      showPage(context, DailyTextPage(
                          data: verseOfTheDay
                      ));
                    },
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF121212) : Colors.white,
                      height: 128, // Hauteur à ajuster selon votre besoin
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Centrer verticalement les enfants
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center, // Centrer horizontalement les enfants
                            children: [
                              Icon(JwIcons.calendar, size: 24),
                              SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(JwIcons.chevron_right, size: 24),
                            ],
                          ),
                          Text(
                            verseOfTheDay['Verse'],
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, height: 1.2),
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10), // Espace entre le texte du jour et l'article

                  /* Afficher l'article le plus récent du site jw.org */
                  if (article['Title'] != null)
                    SizedBox(
                      height: 450, // Hauteur du conteneur
                      child: Stack(
                        children: [
                          // Image en arrière-plan
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: Image.file(File(article['ImagePath'] ?? '')).image,
                                fit: BoxFit.cover, // Remplir le conteneur tout en conservant l'aspect
                              ),
                            ),
                          ),
                          // Conteneur noir au-dessus de l'image
                          Positioned(
                              bottom: 0, // Positionner le conteneur noir en bas
                              left: 0,
                              right: 0,
                              top: 140,
                              child: Padding(padding: EdgeInsets.only(left: 20, right: 20),
                                child: Container(
                                  color: Colors.grey[900]!.withOpacity(0.7), // Couleur du conteneur noir
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        article['ContextTitle'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Couleur du texte en blanc
                                        ),
                                        maxLines: 1, // Limite à 2 lignes si nécessaire
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        article['Title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Couleur du texte en blanc
                                        ),
                                        maxLines: 3, // Limite à 2 lignes si nécessaire
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        article['Description'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white, // Couleur du texte en blanc
                                        ),
                                        maxLines: 3, // Limite à 3 lignes si nécessaire
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 14),
                                      ElevatedButton(onPressed: () {
                                        showPage(context, ArticlePage(
                                          title: article['Title'] ?? '',
                                          link: article['Link'] ?? '',
                                        ));
                                      },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(0),
                                          ),
                                          textStyle: const TextStyle(fontSize: 20),
                                        ),
                                        child: Text(article['ButtonText'] ?? '', style: TextStyle(color: Colors.white)),
                                      )
                                    ],
                                  ),
                                ),
                              )
                          ),
                        ],
                      ),
                    ),
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
                                    var favorite = JwLifeApp.userdata.favorites[index];

                                    return Padding(
                                      padding: EdgeInsets.only(left: 2.0, right: 2.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              showPublicationMenu(context, favorite);
                                            },
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(2.0),
                                                  child: ImageCachedWidget(
                                                      imageUrl: 'https://app.jw-cdn.org/catalogs/publications/${favorite['ImageSqr']}',
                                                      pathNoImage: initializeCategories(context).firstWhere((category) => category['id'] == favorite['PublicationTypeId'])['image'],
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
                                                      getPubShareMenuItem(favorite),
                                                      getPubLanguagesItem(context, "Autres langues", favorite),
                                                      getPubFavoriteItem(favorite),
                                                      getPubDownloadItem(context, favorite),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              favorite['Title'] ?? '',
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
                              height: 130, // Hauteur à ajuster selon votre besoin
                              child: RealmLibrary.teachingToolboxVideos.isEmpty ? getLoadingWidget() : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: RealmLibrary.teachingToolboxVideos.length,
                                itemBuilder: (context, index) {
                                  MediaItem mediaItem = RealmLibrary.teachingToolboxVideos[index];
                                  bool isAudio = mediaItem.type == "AUDIO";

                                  return Padding(
                                    padding: EdgeInsets.only(left: 2.0, right: 2.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (isAudio) {
                                              showAudioPlayer(context, mediaItem.languageAgnosticNaturalKey!, mediaItem.languageSymbol!);
                                            }
                                            else {
                                              showFullScreenVideo(context, mediaItem.languageAgnosticNaturalKey!, mediaItem.languageSymbol!);
                                            }
                                          },
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(2.0),
                                                child: ImageCachedWidget(
                                                    imageUrl: mediaItem.realmImages!.squareImageUrl,
                                                    pathNoImage: "pub_type_video",
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
                                                    getVideoShareItem(mediaItem),
                                                    getVideoLanguagesItem(context, mediaItem),
                                                    getVideoFavoriteItem(mediaItem),
                                                    getVideoDownloadItem(context, mediaItem),
                                                    getShowSubtitlesItem(context, mediaItem),
                                                    getCopySubtitlesItem(context, mediaItem)
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
                                                      Icon(isAudio ? JwIcons.headphones_simple : JwIcons.play, size: 10, color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        formatDuration(mediaItem.duration!),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        SizedBox(
                                          width: 75,
                                          child: Text(
                                            mediaItem.title!,
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
                              localization(context).navigation_whats_new,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 85, // Adjust height as needed
                              child: PublicationsCatalog.lastPublications.isEmpty ? getLoadingWidget() : ListView.builder(
                                scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
                                itemCount: PublicationsCatalog.lastPublications.length,
                                itemBuilder: (context, index) {
                                  dynamic publication = PublicationsCatalog.lastPublications[index];

                                  // Convertir la chaîne de date en objet DateTime
                                  DateTime firstPublished = DateTime.parse(publication['CatalogedOn']);

                                  // Calculer la différence entre la date actuelle et la date de publication
                                  DateTime now = DateTime.now();
                                  Duration difference = now.difference(firstPublished);

                                  // Obtenir le nombre de jours écoulés
                                  int days = difference.inDays;

                                  // Afficher le texte en fonction du nombre de jours écoulés
                                  String textToShow = (days == 0) ? "Aujourd'hui" : (days == 1) ? "Hier" : "Il y a $days jours";
                                  String textLanguageAndDate = "${publication['LanguageVernacularName']} · $textToShow";

                                  return GestureDetector(
                                    onTap: () {
                                      showPublicationMenu(context, publication);
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
                                                    imageUrl: 'https://app.jw-cdn.org/catalogs/publications/${publication['ImageSqr']}',
                                                    pathNoImage: initializeCategories(context).firstWhere((category) => category['id'] == publication['PublicationTypeId'])['image'],
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
                                                          publication['IssueTagNumber'] == 0
                                                              ? initializeCategories(context).firstWhere((category) => category['id'] == publication['PublicationTypeId'])['name']
                                                              : publication['IssueTitle'],
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
                                                          publication['IssueTagNumber'] == 0 ? publication['Title'] : publication['CoverTitle'],
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Theme.of(context).secondaryHeaderColor,
                                                          ),
                                                          maxLines: 2, // Limite à deux lignes
                                                          overflow: TextOverflow.ellipsis, // Tronque le texte avec des points de suspension
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          textLanguageAndDate,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? const Color(0xFFc3c3c3)
                                                                : const Color(0xFF626262),
                                                          ),
                                                        ),
                                                        publication['inProgress'] != null ? const Spacer() : Container(),
                                                        publication['inProgress'] != null
                                                            ? publication['inProgress'] == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)):
                                                            LinearProgressIndicator(
                                                              value: publication['inProgress'],
                                                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                              color: Theme.of(context).primaryColor) : Container()
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
                                                  getPubDownloadItem(context, publication, update: () {
                                                    setState(() {});
                                                  }),
                                                ],
                                              ),
                                            ),
                                            publication['isDownload'] == 0 && publication['inProgress'] == null ? Positioned(
                                              bottom: 5,
                                              right: -8,
                                              height: 40,
                                              child: IconButton(
                                                padding: const EdgeInsets.all(0),
                                                onPressed: () {
                                                  downloadPublication(context, publication, update: () {
                                                    setState(() {});
                                                  });
                                                },
                                                icon: Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                                              ),
                                            ): Container(),
                                            publication['isDownload'] == 0 && publication['inProgress'] == null ? Positioned(
                                              bottom: 0,
                                              right: -5,
                                              width: 50,
                                              child: Text(
                                                textAlign: TextAlign.center,
                                                formatFileSize(publication['ExpandedSize']),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFFc3c3c3)
                                                      : const Color(0xFF626262),
                                                ),
                                              )
                                            ) : Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 150,
                              child: RealmLibrary.latestAudiosVideos.isEmpty ? getLoadingWidget() : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: RealmLibrary.latestAudiosVideos.length,
                                itemBuilder: (context, mediaIndex) {
                                  MediaItem mediaItem = RealmLibrary.latestAudiosVideos[mediaIndex];
                                  DateTime firstPublished = DateTime.parse(mediaItem.firstPublished!);
                                  DateTime now = DateTime.now();
                                  Duration difference = now.difference(firstPublished);
                                  int days = difference.inDays;
                                  String textToShow = (days == 0) ? "Aujourd'hui" : (days == 1) ? "Hier" : "Il y a $days jours";
                                  bool isAudio = mediaItem.type == "AUDIO";

                                  return GestureDetector(
                                    onTap: () {
                                      if (isAudio) {
                                        showAudioPlayer(context, mediaItem.languageAgnosticNaturalKey!, mediaItem.languageSymbol!);
                                      }
                                      else {
                                        showFullScreenVideo(context, mediaItem.languageAgnosticNaturalKey!, mediaItem.languageSymbol!);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                      child: SizedBox(
                                        width: 180,
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8.0),
                                              child: ImageCachedWidget(
                                                imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl,
                                                pathNoImage: "pub_type_video",
                                                height: 90,
                                                width: 180,
                                              )
                                            ),
                                            Positioned(
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
                                            ),
                                            Positioned(
                                              top: -6,
                                              right: -10,
                                              child: PopupMenuButton(
                                                popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.ease), 0.5),
                                                icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                                                shadowColor: Colors.black,
                                                elevation: 8,
                                                itemBuilder: (context) => [
                                                  getVideoShareItem(mediaItem),
                                                  getVideoLanguagesItem(context, mediaItem),
                                                  getVideoFavoriteItem(mediaItem),
                                                  getVideoDownloadItem(context, mediaItem),
                                                  getShowSubtitlesItem(context, mediaItem),
                                                  getCopySubtitlesItem(context, mediaItem)
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 90, // Ajuster la position du texte en fonction du contenu
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
                                            ),
                                            // Texte de "Il y a ... jours"
                                            Positioned(
                                              top: mediaItem.title!.length > 30 ? 115 : 103, // Ajustement dynamique de la position
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
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

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
                    opacity: 0.6,
                    child: Container(
                      color: Colors.black,
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                Visibility(
                    visible: _isSearchVisible,
                    child: Positioned(
                        top: 30,
                        left: 0,
                        right: 0,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SearchField<Map<String, dynamic>>(
                              animationDuration: const Duration(milliseconds: 0),
                              itemHeight: 55,
                              autofocus: true,
                              offset: Offset(0, 58),
                              maxSuggestionsInViewPort: 6,
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
                                if (item.item!['type'] == 2) {
                                  Map<String, dynamic>? publication = await PublicationsCatalog.searchPub(item.item!['query'], "0");
                                  if(publication != null) {
                                    showPublicationMenu(context, publication);
                                  }
                                  else {
                                    showErrorDialog(context, "Aucune publication ${item.item?['query']} n'a pu étre trouvée.");
                                  }
                                }
                                else if(item.item!['type'] == 1) {
                                  await showPage(context, SearchBiblePage(query: item.item?['query']));
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                              suggestions: suggestions
                                  .map((item) => SearchFieldListItem<Map<String, dynamic>>(item['caption'],
                                item: item,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item['caption'], style: TextStyle(fontSize: 17)),
                                      item['label'] == '' ? Container() : Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF595959) : Color(0xFFc0c0c0),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(item['label'], style: TextStyle(fontSize: 15, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ).toList(),
                            )
                        )
                    ),
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
    IconLinkInfo('assets/icons/nav_jworg.png', localization(context).navigation_official_website, 'https://www.jw.org/${JwLifeApp.currentLanguage.primaryIetfCode}'),
    IconLinkInfo('assets/icons/nav_jwb.png', localization(context).navigation_online_broadcasting, 'https://www.jw.org/open?docid=1011214&wtlocale=${JwLifeApp.currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_onlinelibrary.png', localization(context).navigation_online_library, 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeApp.currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_donation.png', localization(context).navigation_online_donation, 'https://donate.jw.org/ui/${JwLifeApp.currentLanguage.symbol}/donate-home.html'),
    IconLinkInfo(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/icons/nav_github_light.png'
          : 'assets/icons/nav_github_dark.png',
      localization(context).navigation_online_gitub,
      'https://github.com/Noamcreator/jwlife',
    ),
  ];
}