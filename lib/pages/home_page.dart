import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/pages/home_pages/alert_banner.dart';
import 'package:jwlife/pages/library_pages/publication_pages/local/publication_menu_local.dart';
import 'package:jwlife/utils/utils_publication.dart';
import 'package:jwlife/utils/utils_video.dart';
import 'package:realm/realm.dart';
import 'package:searchfield/searchfield.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../jwlife.dart';
import '../load_pages.dart';
import '../realm/catalog.dart';
import '../utils/api.dart';
import '../utils/directory_helper.dart';
import '../utils/files_helper.dart';

import '../utils/icons.dart';
import '../utils/shared_preferences_helper.dart';
import '../utils/utils.dart';
import '../video/FullScreenVideoPlayer.dart';
import '../widgets/dialog/language_dialog.dart';
import '../widgets/image_widget.dart';
import 'home_pages/article_page.dart';
import 'home_pages/search_pages/bible_search_page.dart';
import 'home_pages/search_pages/search_page.dart';
import 'library_pages/publication_pages/online/publication_menu.dart';
import 'library_pages/publication_pages/publications_page.dart';
import 'settings_page.dart';
import 'home_pages/daily_text_page.dart';

class HomePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  HomePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  dynamic alerts = {};
  String verseOfTheDay = ''; // Variable pour stocker le verset du jour
  Map<String, dynamic> article = {};
  List<Map<String, dynamic>> publications = [];
  bool isRefreshing = false;
  bool isSearchVisible = false; // Variable d'état pour contrôler l'affichage du SearchBar

  List<Map<String, dynamic>> suggestions = [];

  @override
  void initState() {
    super.initState();
    JwLifeApp.setStateHomePage = _reloadPage;
    _reloadPage();
  }

  Future<void> _reloadPage() async{
    fetchAlertInfo();
    fetchVerseOfTheDay();
    fetchArticleInHomePage();
    LoadPages.loadLatestVideos();
    LoadPages.loadTeachingToolbox();

    setState(() {
      isRefreshing = true;
    });

    await Api.updateLibrary(JwLifeApp.currentLanguage.symbol);
    LoadPages.loadLatestVideos();
    LoadPages.loadTeachingToolbox();

    await Api.updateCatalog();
    await loadLastPublications();

    setState(() {
      isRefreshing = false;
    });
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

    // URL pour récupérer le token JWT
    final jwtTokenUrl = Uri.https('b.jw-cdn.org', '/tokens/jworg.jwt');

    try {
      // Obtenir le JWT token
      http.Response tokenResponse = await http.get(jwtTokenUrl);

      if (tokenResponse.statusCode == 200) {
        // Extraire le token JWT
        String jwtToken = tokenResponse.body;

        // Préparer les headers pour la requête avec l'autorisation
        Map<String, String> headers = {
          'Authorization': 'Bearer $jwtToken',
        };

        // Faire la requête HTTP pour récupérer les alertes
        http.Response alertResponse = await http.get(url, headers: headers);

        if (alertResponse.statusCode == 200) {
          // La requête a réussi, traiter la réponse JSON
          Map<String, dynamic> data = jsonDecode(alertResponse.body);

          setState(() {
            alerts = data['alerts'];
          });
        } else {
          // Gérer une erreur de statut HTTP
          print('Erreur de requête HTTP: ${alertResponse.statusCode}');
        }
      } else {
        // Gérer une erreur de statut HTTP lors de la récupération du token JWT
        print('Erreur de requête HTTP pour le token: ${tokenResponse.statusCode}');
      }
    } catch (e) {
      // Gérer les erreurs lors des requêtes
      print('Erreur lors de la récupération des données de l\'API: $e');
    }
  }

  Future<void> fetchVerseOfTheDay() async {
    try {
      // Préparer les paramètres de requête
      final queryParams = {
        'wtlocale': JwLifeApp.currentLanguage.symbol, // langue de la recherche
        'alias': 'daily-text', // type de la recherche
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1))), // date pour la recherche +1 jour pour avoir le bon jour
      };

      // Construire l'URI avec les paramètres
      final uri = Uri.https('wol.jw.org', '/wol/finder', queryParams);

      // Faire la requête HTTP
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Trouver l'élément contenant le verset du jour
        final element = document.querySelector('.themeScrp');
        if (element != null) {
          setState(() {
            verseOfTheDay = element.text.trim();
          });
        } else {
          throw Exception('Element with class .themeScrp not found');
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
      } else {
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
    final db = await openDatabase(articlesDbFile.path, version: 1, onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE article (id INTEGER PRIMARY KEY AUTOINCREMENT, contextTitle TEXT, title TEXT, description TEXT, link TEXT, articleContent TEXT, imagePath TEXT, buttonText TEXT, symbol TEXT)',
      );
    });

    // Récupérer le dernier article
    final List<Map<String, dynamic>> articles = await db.query(
      'article',
      orderBy: 'id DESC',
      where: 'symbol = ?',
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
      if (articles.isEmpty || title != articles.first['title']) {
        Directory appTileDirectory = await getAppTileDirectory();

        // Télécharger et enregistrer l'image puis récupérer son chemin
        String imagePath = await downloadAndSaveImage(imageUrlLsr, appTileDirectory);
        String languageSymbol = JwLifeApp.currentLanguage.symbol;

        // Télécharger le contenu de l'article via le lien
        String fullArticleHtml = await fetchArticleContent('https://www.jw.org/' + link);

        await saveArticleToDatabase(db, title, contextTitle, description, 'https://www.jw.org/' + link, fullArticleHtml, imagePath, buttonText, languageSymbol);

        setState(() {
          article = {
            'contextTitle': contextTitle,
            'title': title,
            'description': description,
            'link': 'https://www.jw.org/' + link,
            'articleContent': fullArticleHtml,
            'imagePath': imagePath,
            'buttonText': buttonText,
            'symbol': languageSymbol
          };
        });
      }
    }
    else {
      throw Exception('Failed to load content');
    }
  }

  // Enregistrer l'article dans la base de données
  Future<void> saveArticleToDatabase(Database db, String title, String contextTitle, String description, String link, String fullArticleHtml, String imagePath, String buttonText, String languageSymbol) async {
    await db.insert('article', {
      'title': title,
      'contextTitle': contextTitle,
      'description': description,
      'link': link,
      'articleContent': fullArticleHtml,
      'imagePath': imagePath,
      'buttonText': buttonText,
      'symbol': languageSymbol,
    });
  }

  // Télécharger le contenu complet de l'article
  Future<String> fetchArticleContent(String articleUrl) async {
    final response = await http.get(Uri.parse(articleUrl));
    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      return document.querySelector('.main-wrapper')?.outerHtml.replaceAll(RegExp(r'>\s+<'), '><') ?? '';
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

  Future<void> loadLastPublications() async {
    File catalogFile = await getCatalogFile();
    File mepsFile = await getMepsFile();
    File pubCollectionsFile = await getPubCollectionsFile();
    File userdataFile = await getUserdataFile();

    if (await catalogFile.exists() && await mepsFile.exists() && await pubCollectionsFile.exists() && await userdataFile.exists()) {
      Database catalog = await openReadOnlyDatabase(catalogFile.path);
      await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
      await catalog.execute("ATTACH DATABASE '${pubCollectionsFile.path}' AS pub_collections");
      await catalog.execute("ATTACH DATABASE '${userdataFile.path}' AS userdata");

      // Récupérer les publications avec les informations supplémentaires en une seule requête
      List<Map<String, dynamic>> result = await catalog.rawQuery('''
      SELECT DISTINCT
    p.Id AS PublicationId,
    p.MepsLanguageId,
    meps.Language.Symbol AS LanguageSymbol,
    p.PublicationTypeId,
    p.IssueTagNumber,
    p.Title,
    p.IssueTitle,
    p.ShortTitle,
    p.CoverTitle,
    p.KeySymbol,
    p.Symbol,
    p.Year,
    pa.CatalogedOn,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND (ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600))
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageSqr,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND ia.NameFragment LIKE '%_lsr-%'
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageLsr,
    (SELECT CASE WHEN COUNT(pc.Symbol) > 0 THEN 1 ELSE 0 END
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId) AS isDownload,
    (SELECT pc.Path
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Path,
    (SELECT pc.DatabasePath
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS DatabasePath,
    (SELECT pc.Hash
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Hash,    
    (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
        FROM userdata.TagMap tg
        JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
        WHERE userdata.Location.IssueTagNumber = p.IssueTagNumber 
        AND userdata.Location.KeySymbol = p.KeySymbol 
        AND userdata.Location.MepsLanguage = p.MepsLanguageId 
        AND tg.TagId = 1) AS isFavorite
FROM
    Publication p
LEFT JOIN
    PublicationAsset pa ON p.Id = pa.PublicationId
LEFT JOIN
    PublicationRootKey prk ON p.PublicationRootKeyId = prk.Id
LEFT JOIN
    PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
LEFT JOIN
    ImageAsset ia ON paim.ImageAssetId = ia.Id
LEFT JOIN
    meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
WHERE 
    pa.MepsLanguageId = ?
ORDER BY
    pa.CatalogedOn DESC
LIMIT 12
''', [JwLifeApp.currentLanguage.id]);

      await catalog.execute("DETACH DATABASE userdata");
      await catalog.execute("DETACH DATABASE pub_collections");
      await catalog.execute("DETACH DATABASE meps");
      await catalog.close();

      setState(() {
        publications = result;
      });
    }
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
      } else {
        setState(() {
          suggestions = []; // Initialize suggestions to an empty list
        });
      }
    } else {
      throw Exception('Error fetching suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    initializeDateFormatting(JwLifeApp.currentLanguage.primaryIetfCode, null);
    DateTime now = DateTime.now();
    String formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', JwLifeApp.currentLanguage.primaryIetfCode).format(now));

    return Scaffold(
      appBar: AppBar(
        title: Text('Accueil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                isSearchVisible = !isSearchVisible; // Basculer la visibilité du SearchBar
              });
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
                setState(() async {
                  if (value != null && value['Symbol'] != JwLifeApp.currentLanguage.symbol) {
                    await setLibraryLanguage(value);
                    await _reloadPage();
                  }
                });
              });
            },
          ),
          IconButton(
            icon: Icon(JwIcons.gear),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                    return SettingsPage(toggleTheme: widget.toggleTheme, reloadPage: _reloadPage);
                  },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
            onRefresh: () async {
              await _reloadPage();
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* Afficher l'indicateur de rafraîchissement */
                  isRefreshing
                      ? LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), // Couleur de remplissage de l'indicateur
                  ) : Container(),
                  const SizedBox(height: 4),
                  /* Afficher la barre de recherche */
                  if (isSearchVisible)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SearchField<Map<String, dynamic>>(
                        itemHeight: 60,
                        autofocus: true,
                        maxSuggestionsInViewPort: 6,
                        suggestionAction: SuggestionAction.unfocus,
                        searchInputDecoration: SearchInputDecoration(
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                          filled: true,
                          hintText: 'Rechercher...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onSearchTextChanged: (text) {
                          setState(() {
                            fetchSuggestions(text);
                          });
                        },
                        onSuggestionTap: (SearchFieldListItem<Map<String, dynamic>> item) async {
                          if (item.item!['type'] == 2) {
                            Map<String, dynamic>? publication = await searchPub(item.item!['query']);
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                  return PublicationMenu(publication: publication!);
                                },
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          }
                          else if(item.item!['type'] == 1) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                  return SearchBiblePage(query: item.item?['query']);
                                },
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          }
                          else {
                            Navigator.push(
                                context,
                                PageRouteBuilder(
                                pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                              return SearchPage(query: item.item?['query']);
                            },
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          ));
                         }
                          isSearchVisible = false;
                        },
                        onSubmit: (text) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                return SearchPage(query: text);
                              },
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                          isSearchVisible = false;
                        },
                        onTapOutside: (event) {
                          setState(() {
                            isSearchVisible = false;
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: Text(item['label'], style: TextStyle(fontSize: 15, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ).toList(),
                      ),
                    ),
                  if (alerts.isNotEmpty)
                    AlertBanner(alerts: alerts),

                  const SizedBox(height: 8), // Espace entre l'info et le texte du jour

                  /* Afficher le texte du jour avec la date en haut et le verset en bas */
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                            return DailyTextPage(
                                data: verseOfTheDay
                            );
                          },
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
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
                              Icon(JwIcons.calendar,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                JwIcons.chevron_right,
                                size: 24,
                              ),
                            ],
                          ),
                          Text(
                            verseOfTheDay,
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
                  if (article['title'] != null)
                    Container(
                      height: 400, // Hauteur du conteneur
                      child: Stack(
                        children: [
                          // Image en arrière-plan
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: Image.file(File(article['imagePath'] ?? '')).image,
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
                                        article['contextTitle'] ?? '',
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
                                        article['title'] ?? '',
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
                                        article['description'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white, // Couleur du texte en blanc
                                        ),
                                        maxLines: 1, // Limite à 3 lignes si nécessaire
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 14),
                                      ElevatedButton(onPressed: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                              return ArticlePage(
                                                  title: article['title'] ?? '',
                                                  html: article['articleContent'] ?? '',
                                              );
                                            },
                                            transitionDuration: Duration.zero,
                                            reverseTransitionDuration: Duration.zero,
                                          ),
                                        );
                                      },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(0),
                                          ),
                                          textStyle: const TextStyle(fontSize: 20),
                                        ),
                                        child: Text(article['buttonText'] ?? '', style: TextStyle(color: Colors.white)),
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
                            const Text(
                              'Mes Favoris',
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
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                                return favorite['isDownload'] == 1 ? PublicationMenuLocal(publication: favorite) : PublicationMenu(publication: favorite);
                                              },
                                              transitionDuration: Duration.zero,
                                              reverseTransitionDuration: Duration.zero,
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(2.0),
                                              child: ImageCachedWidget(
                                                  imageUrl: 'https://app.jw-cdn.org/catalogs/publications/${favorite['ImageSqr']}',
                                                  pathNoImage: categories.firstWhere((category) => category['id'] == favorite['PublicationTypeId'])['image'],
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
                                                  getPubDownloadItem(context, favorite)
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
                          const Text('Panoplie d\'enseignement',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 130, // Hauteur à ajuster selon votre besoin
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: LoadPages.teachingToolboxVideos.length,
                              itemBuilder: (context, index) {
                                final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
                                Realm realm = Realm(config);

                                var mediaItem = realm.all<MediaItem>().query("naturalKey == '${LoadPages.teachingToolboxVideos[index]}'").first;

                                return Padding(
                                  padding: EdgeInsets.only(left: 2.0, right: 2.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                                return FullScreenVideoPlayer(
                                                    lank: mediaItem.languageAgnosticNaturalKey!,
                                                    lang: mediaItem.languageSymbol!
                                                );
                                              },
                                              transitionDuration: Duration.zero,
                                              reverseTransitionDuration: Duration.zero,
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(2.0),
                                              child: ImageCachedWidget(
                                                  imageUrl: mediaItem.realmImages!.squareImageUrl!,
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
                                                  getCopySubtitlesItem(mediaItem)
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              child: Container(
                                                color: Colors.black.withOpacity(0.8),
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                                                child: Text(
                                                  formatDuration(mediaItem.duration!),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Container(
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
                          const Text(
                            'Nouveautés',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 85, // Adjust height as needed
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
                              itemCount: publications.length,
                              itemBuilder: (context, index) {
                                dynamic publication = publications[index];

                                // Convertir la chaîne de date en objet DateTime
                                DateTime firstPublished = DateTime.parse(publication['CatalogedOn']);

                                // Calculer la différence entre la date actuelle et la date de publication
                                DateTime now = DateTime.now();
                                Duration difference = now.difference(firstPublished);

                                // Obtenir le nombre de jours écoulés
                                int days = difference.inDays;

                                // Afficher le texte en fonction du nombre de jours écoulés
                                String textToShow = (days == 0) ? "Aujourd'hui" : (days == 1) ? "Hier" : "Il y a $days jours";

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                          return publication['isDownload'] == 1 ? PublicationMenuLocal(publication: publication) : PublicationMenu(publication: publication);
                                        },
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration: Duration.zero,
                                      ),
                                    );
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
                                                      pathNoImage: categories.firstWhere((category) => category['id'] == publication['PublicationTypeId'])['image'],
                                                      height: 85,
                                                      width: 85,
                                                  ),
                                              ),
                                              Expanded(
                                                  flex: 1,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 7.0, right: 10.0, top: 4.0, bottom: 4.0),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          publication['IssueTagNumber'] == 0
                                                              ? categories.firstWhere((category) => category['id'] == publication['PublicationTypeId'])['name']
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
                                                          textToShow,
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
                                                getPubDownloadItem(context, publication),
                                              ],
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
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: LoadPages.latestAudiosVideos.length,
                              itemBuilder: (context, mediaIndex) {
                                final config = Configuration.local([MediaItem.schema, Language.schema, Images.schema, Category.schema]);
                                Realm realm = Realm(config);

                                var mediaItem = realm.all<MediaItem>().query("naturalKey == '${LoadPages.latestAudiosVideos[mediaIndex]}'").first;

                                DateTime firstPublished = DateTime.parse(mediaItem.firstPublished!);
                                DateTime now = DateTime.now();
                                Duration difference = now.difference(firstPublished);
                                int days = difference.inDays;
                                String textToShow = (days == 0) ? "Aujourd'hui" : (days == 1) ? "Hier" : "Il y a $days jours";

                                return GestureDetector(
                                  onTap: () {
                                    JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);

                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                          return FullScreenVideoPlayer(
                                            lank: mediaItem.languageAgnosticNaturalKey!,
                                            lang: mediaItem.languageSymbol!,
                                          );
                                        },
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration: Duration.zero,
                                      ),
                                    );
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
                                              imageUrl: mediaItem.realmImages!.wideFullSizeImageUrl!,
                                              pathNoImage: "pub_type_video",
                                              height: 90,
                                              width: 180,
                                            ),
                                          ),
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: Container(
                                              color: Colors.black.withOpacity(0.8),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              child: Text(
                                                formatDuration(mediaItem.duration!),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -6,
                                            right: -8,
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
                                                getCopySubtitlesItem(mediaItem)
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
                                            top: mediaItem.title!.length > 35 ? 115 : 103, // Ajustement dynamique de la position
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

                          const Text(
                            'En ligne',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Container(
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
            ),
        ),
    );
  }
}

class IconLink extends StatelessWidget {
  final String imagePath;
  final String url;
  final String description;

  const IconLink({
    Key? key,
    required this.imagePath,
    required this.url,
    required this.description,
  }) : super(key: key);

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
          Container(
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
    IconLinkInfo('assets/icons/nav_jworg.png', 'Site web officiel', 'https://www.jw.org/' + JwLifeApp.currentLanguage.primaryIetfCode),
    IconLinkInfo('assets/icons/nav_jwb.png', 'JW Télédiffusion', 'https://www.jw.org/open?docid=1011214&wtlocale=' + JwLifeApp.currentLanguage.symbol),
    IconLinkInfo('assets/icons/nav_onlinelibrary.png', 'Bibliothèque en ligne', 'https://wol.jw.org/wol/finder?wtlocale=' + JwLifeApp.currentLanguage.symbol),
    IconLinkInfo('assets/icons/nav_donation.png', 'Faire un don', 'https://donate.jw.org/ui/${JwLifeApp.currentLanguage.symbol}/donate-home.html'),
    IconLinkInfo(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/icons/nav_github_light.png'
          : 'assets/icons/nav_github_dark.png',
      'GitHub de JW Life',
      'https://github.com/Noamcreator/jwlife',
    ),
  ];
}
