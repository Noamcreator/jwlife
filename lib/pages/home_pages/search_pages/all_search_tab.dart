import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../jwlife.dart';
import '../../../utils/api.dart';
import '../../../utils/utils.dart';
import '../../../video/FullScreenVideoPlayer.dart';
import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/htmlView/html_widget.dart';
import '../../library_pages/publication_pages/online/publication_menu.dart';

class AllSearchTab extends StatefulWidget {
  final String query;

  const AllSearchTab({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  _AllSearchTabState createState() => _AllSearchTabState();
}

class _AllSearchTabState extends State<AllSearchTab> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    fetchApiJw(widget.query);
  }

  Future<void> fetchApiJw(String query) async {
    final queryParams = {'q': query};
    final url = Uri.https('b.jw-cdn.org', '/apis/search/results/${JwLifeApp.currentLanguage.symbol}/all', queryParams);

    try {
      Map<String, String> headers = {
        'Authorization': 'Bearer ${Api.currentJwToken}',
      };

      http.Response alertResponse = await http.get(url, headers: headers);
      if (alertResponse.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(alertResponse.body);
        setState(() {
          results = (data['results'] as List).map((item) {
            return {
              'type': item['type'] ?? '',
              'label': item['label'] ?? '',
              'links': item['links'] ?? [],
              'layout': item['layout'] ?? [],
              'results': item['results'] ?? [],
            };
          }).toList();
        });
      }
      else {
        print('Erreur de requête HTTP: ${alertResponse.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des données de l\'API: $e');
    }
  }

  Widget _buildVerseList(dynamic result) {
    return SizedBox(
      height: 175, // Hauteur pour les éléments horizontaux
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, verseIndex) {
          final item = result['results'][verseIndex];
          return GestureDetector(
            onTap: () async {
              print('Item tapped: $item');
            },
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: HtmlWidget(
                      item['title'],
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 225
                      ),
                      child: Text(
                        item['snippet'],
                        style: TextStyle(
                          fontSize: 14,
                        ),
                        maxLines: 5, // Limite à 3 lignes pour le snippet
                        overflow: TextOverflow.ellipsis, // Tronque si nécessaire
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideosList(dynamic result) {
    return SizedBox(
      height: 200, // Hauteur pour les éléments horizontaux
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, videoIndex) {
          final item = result['results'][videoIndex];
          return GestureDetector(
            onTap: () async {
              JwLifePage.toggleNavBarBlack.call(JwLifePage.currentTabIndex, true);
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                    return FullScreenVideoPlayer(
                      lank: item['lank'],
                      lang: JwLifeApp.currentLanguage.symbol,
                    );
                  },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      item['image']['url'].isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                        child: Image.network(
                          item['image']['url'],
                          width: 250,
                          height: 125,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Container(
                        width: 250,
                        height: 125,
                        color: Colors.grey,
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            item['duration'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 0,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              child: const Text('Envoyer le lien'),
                              onTap: () {
                                Share.share(
                                  'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${JwLifeApp.currentLanguage.symbol}&lank=${item['lank']}',
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Ajouter à la liste de lecture'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Autres langues'),
                              onTap: () async {
                                String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item['lank']}?clientType=www';
                                final response = await http.get(Uri.parse(link));
                                if (response.statusCode == 200) {
                                  final jsonFile = response.body;
                                  final jsonData = json.decode(jsonFile);

                                  LanguageDialog languageDialog = LanguageDialog(languagesListJson: jsonData['languages']);
                                  showDialog(
                                    context: context,
                                    builder: (context) => languageDialog,
                                  );
                                }
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Ajouter aux favoris'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Télécharger la vidéo'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Copier les sous-titres'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 250), // Limite la largeur du texte
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 2, // Limite le texte à 2 lignes
                        overflow: TextOverflow.ellipsis, // Tronque le texte si nécessaire
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioList(dynamic result) {
    return SizedBox(
      height: 200, // Hauteur pour les éléments horizontaux
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, audioIndex) {
          final item = result['results'][audioIndex];
          return GestureDetector(
            onTap: () async {
              JwLifeApp.jwAudioPlayer.setRandomMode(false);
              JwLifeApp.jwAudioPlayer.fetchAudioData(item['lank'], JwLifeApp.currentLanguage.symbol);
              JwLifeApp.jwAudioPlayer.play();
            },
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      item['image']['url'].isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                        child: Image.network(
                          item['image']['url'],
                          width: 250,
                          height: 125,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Container(
                        width: 250,
                        height: 125,
                        color: Colors.grey,
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            item['duration'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 0,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              child: const Text('Envoyer le lien'),
                              onTap: () {
                                Share.share(
                                  'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${JwLifeApp.currentLanguage.symbol}&lank=${item['lank']}',
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Ajouter à la liste de lecture'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Autres langues'),
                              onTap: () async {
                                String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item['lank']}?clientType=www';
                                final response = await http.get(Uri.parse(link));
                                if (response.statusCode == 200) {
                                  final jsonFile = response.body;
                                  final jsonData = json.decode(jsonFile);

                                  LanguageDialog languageDialog = LanguageDialog(languagesListJson: jsonData['languages']);
                                  showDialog(
                                    context: context,
                                    builder: (context) => languageDialog,
                                  );
                                }
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Ajouter aux favoris'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Télécharger la vidéo'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Copier les sous-titres'),
                              onTap: () {
                                // Action à effectuer lors de l'appui sur le bouton de suppression
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 250), // Limite la largeur du texte
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 2, // Limite le texte à 2 lignes
                        overflow: TextOverflow.ellipsis, // Tronque le texte si nécessaire
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublicationsList(dynamic result) {
    return SizedBox(
      height: 140, // Hauteur pour les éléments horizontaux
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, publicationIndex) {
          final item = result['results'][publicationIndex];
          return GestureDetector(
            child: Card(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Container(
                width: 300, // Garde la hauteur de la Card
                child: Row(
                  children: [
                    // Image à gauche
                    item['image']['url'] != null && item['image']['url'] != ''
                        ? Container(
                      width: 100, // Définit la largeur fixe pour l'image en mode portrait
                      height: 140, // Garde la hauteur pour correspondre à la Card
                      child: Image.network(
                        item['image']['url'],
                        fit: BoxFit.cover, // Remplit tout l'espace en conservant les proportions
                      ),
                    )
                        : Container(
                      width: 110,
                      height: 150,
                      color: Colors.grey,
                    ),
                    // Texte à droite
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0), // Ajoute un peu de padding autour du texte
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['context'],
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              maxLines: 3, // Limite le texte à 3 lignes
                              overflow: TextOverflow.ellipsis, // Si le texte est trop long, il sera tronqué
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onTap: () async {
              if (item['wolLink'] != null && item['wolLink'] != '') {
                String lank = item['lank'];

                // Initialize variables
                String keySymbol = '';
                String issueTagNumber = '0';

                // Corrected regular expression
                RegExp regExp = RegExp(r'^(pub|pi)-([\w-]+?)(?:_(\d+))?$');
                Match? match = regExp.firstMatch(lank);

                if (match != null) {
                  keySymbol = match.group(2) ?? ''; // Captures the part after "pub-" or "pi-" up to the underscore

                  if (match.group(3) != null) {
                    String rawNumber = match.group(3)!;
                    // Append "00" only if the number has 6 digits, otherwise keep it as is
                    issueTagNumber = rawNumber.length == 6 ? '${rawNumber}00' : rawNumber;
                  }
                  else {
                    issueTagNumber = '0';
                  }
                }

                Map<String, dynamic>? publication = await searchPub(keySymbol, issueTagNumber);
                if (publication != null) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return PublicationMenu(publication: publication);
                      },
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                }
                else {
                  print('Publication not found for lank: $lank');
                  print('lank: $lank');
                  print('keySymbol: $keySymbol');
                  print('issueTagNumber: $issueTagNumber');
                }
              }
              else {
                print(item['jwLink']);
                launchUrl(Uri.parse(item['jwLink']), mode: LaunchMode.externalApplication);
              }
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        if (result['type'] == 'group' && result['results'].isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                result['label'] != null && result['label'] != '' ? Text(result['label'], style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)) : Container(),
                if (result['layout'].contains('bible')) // Pour les vidéos et audios
                  _buildVerseList(result)
                else if (result['layout'].contains('videos')) // Pour les vidéos et audios
                    _buildVideosList(result)
                else if (result['layout'].contains('audio')) // Pour les vidéos et audios
                    _buildAudioList(result)
                else if (result['layout'].contains('publications')) // Pour les vidéos et audios
                    _buildPublicationsList(result)
                else if (result['layout'].contains('linkGroup')) // Pour les articles
                      Column(
                        children: result['results'].map<Widget>((index) {
                          return GestureDetector(
                            onTap: () async {
                              if (index['links'] != null && index['links']['wol'] != null) {
                                String lank = index['lank'];
                                int docId = int.parse(lank.replaceAll("pa-", ""));
                                /*
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                      return DocumentView(title: index['title'], link: index['links']['wol'], docId: docId, scrollController: ScrollController());
                                    },
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );

                                 */
                              }
                              else {
                                print(index['links']['jw.org']);
                              }
                            },
                            child: Card(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                              margin: EdgeInsets.symmetric(vertical: 5.0),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    // Image à gauche
                                    Container(
                                      width: 80, // Définit la largeur fixe pour l'image en mode portrait
                                      height: 80, // Garde la hauteur pour correspondre à la Card
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 10), // Espacement entre l'image et le texte
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start, // Alignement à gauche
                                        children: [
                                          // Titre en haut à droite
                                          Text(
                                            index['title'],
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            maxLines: 1, // Limiter à une ligne
                                            overflow: TextOverflow.ellipsis, // Ajouter des points de suspension si le texte est trop long
                                          ),
                                          // Snippet en dessous du titre
                                          HtmlWidget(
                                            index['snippet'],
                                            textStyle: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[700],
                                                //maxLines: 2,
                                                //textOverflow: TextOverflow.ellipsis,
                                              ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ));
                        }).toList(),
                      )
                else if (result['layout'].contains('flat')) // Pour les articles
                    Column(
                      children: result['results'].map<Widget>((article) {
                        return GestureDetector(
                          onTap: () {
                            if (article['links'] != null && article['links']['wol'] != null) {
                              String lank = article['lank'];
                              int docId = int.parse(lank.replaceAll("pa-", ""));

                              /*
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                    return DocumentView(title: article['title'], link: article['links']['wol'], docId: docId, scrollController: ScrollController());
                                  },
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );

                               */
                            }
                            else {
                              print(article['links']['jw.org']);
                            }
                          },
                          child: Card(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                            margin: EdgeInsets.symmetric(vertical: 5.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Image à gauche
                                  article['image'] != null && article['image']['url'] != null ? Image.network(
                                    article['image']['url'],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ) : Container(width: 70, height: 70, color: Colors.grey),
                                  SizedBox(width: 10), // Espacement entre l'image et le texte
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, // Alignement à gauche
                                      children: [
                                        // Titre en haut à droite
                                        Text(
                                          article['title'] ?? '',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1, // Limiter à une ligne
                                          overflow: TextOverflow.ellipsis, // Ajouter des points de suspension si le texte est trop long
                                        ),
                                        // Snippet en dessous du titre
                                        Text(
                                          article['snippet'] ?? '',
                                          style: TextStyle(fontSize: 14),
                                          maxLines: 2, // Limiter à deux lignes
                                          overflow: TextOverflow.ellipsis, // Ajouter des points de suspension si le texte est trop long
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
              ],
            ),
          );
        }
        return Container(); // Pour les types non gérés
      },
    );
  }
}
