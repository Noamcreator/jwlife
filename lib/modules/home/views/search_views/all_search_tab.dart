import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/modules/home/views/search_views/search_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AllSearchTab extends StatefulWidget {
  final SearchModel model;

  const AllSearchTab({super.key, required this.model});

  @override
  _AllSearchTabState createState() => _AllSearchTabState();
}

class _AllSearchTabState extends State<AllSearchTab> {
  @override
  void initState() {
    super.initState();
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

  Widget _buildIndexList(dynamic result) {
    return SizedBox(
      height: 120, // Hauteur pour les éléments horizontaux
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
              child: SizedBox(
                width: 250, // Garde la hauteur de la Card
                child: Row(
                  children: [
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
              if (item['links'] != null && item['links']['wol'] != null) {
                String lank = item['lank'];
                int docId = int.parse(lank.replaceAll("pa-", ""));

                showDocumentView(context, docId, JwLifeApp.settings.currentLanguage.id);
              }
              else {
                print(item['links']['jw.org']);
              }
            },
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
          MediaItem mediaItem = getVideoItemFromLank(item['lank'], JwLifeApp.settings.currentLanguage.symbol);
          return GestureDetector(
            onTap: () async {
              showFullScreenVideo(context, mediaItem);
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
          MediaItem mediaItem = getVideoItemFromLank(item['lank'], JwLifeApp.settings.currentLanguage.symbol);
          return GestureDetector(
            onTap: () async {
              showAudioPlayer(context, mediaItem);
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

                Publication? publication = await PubCatalog.searchPub(keySymbol, int.parse(issueTagNumber), JwLifeApp.settings.currentLanguage.id);
                if (publication != null) {
                  publication.showMenu(context, update: null);
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchAllSearch(), // Appel de la méthode fetchAllSearch
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Affiche un indicateur de chargement pendant l'attente de la réponse
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Affiche un message d'erreur si la récupération des données échoue
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Affiche un message si aucune donnée n'a été trouvée
          return Center(child: Text('Aucun résultat trouvé.'));
        } else {
          // Si les données sont récupérées avec succès, on affiche la liste
          final results = snapshot.data!;
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
                      result['label'] != null && result['label'] != ''
                          ? Text(result['label'], style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold))
                          : Container(),
                      if (result['layout'].contains('bible')) // Pour les vidéos et audios
                        _buildVerseList(result)
                      else if (result['layout'].contains('videos')) // Pour les vidéos et audios
                        _buildVideosList(result)
                      else if (result['layout'].contains('audio')) // Pour les vidéos et audios
                          _buildAudioList(result)
                        else if (result['layout'].contains('publications')) // Pour les vidéos et audios
                            _buildPublicationsList(result)
                          else if (result['layout'].contains('linkGroup')) // Pour les articles
                              _buildIndexList(result)
                            else if (result['layout'].contains('flat')) // Pour les articles
                                Column(
                                  children: result['results'].map<Widget>((article) {
                                    return GestureDetector(
                                      onTap: () {
                                        if (article['links'] != null && article['links']['wol'] != null) {
                                          String lank = article['lank'];
                                          int docId = int.parse(lank.replaceAll("pa-", ""));

                                          print('docId: $docId');

                                          showDocumentView(context, docId, JwLifeApp.settings.currentLanguage.id);
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
                                              article['image'] != null && article['image']['url'] != null
                                                  ? Image.network(
                                                article['image']['url'],
                                                width: 70,
                                                height: 70,
                                                fit: BoxFit.cover,
                                              )
                                                  : Container(width: 70, height: 70, color: Colors.grey),
                                              SizedBox(width: 10), // Espacement entre l'image et le texte
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start, // Alignement à gauche
                                                  children: [
                                                    // Titre en haut à droite
                                                    Text(
                                                      article['title'] ?? '',
                                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                      maxLines: 1, // Limiter à une ligne
                                                      overflow: TextOverflow.ellipsis, // Ajouter des points de suspension si le texte est trop long
                                                    ),
                                                    // Snippet en dessous du titre
                                                    HtmlWidget(article['snippet'] ?? '', textStyle: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
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
      },
    );
  }
}
