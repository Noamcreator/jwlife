import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/views/search_views/search_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/utils.dart';

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
              printTime('Item tapped: $item');
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
      height: 90, // Hauteur pour les éléments horizontaux
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
                                color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFa3b9e3) : Color(0xFF516da8)
                              ),
                              maxLines: 2, // Limite à 2 lignes pour le titre
                              overflow: TextOverflow.ellipsis, // Tronque si nécessaire
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

                showDocumentView(context, docId, JwLifeSettings().currentLanguage.id);
              }
              else {
                printTime(item['links']['jw.org']);
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
          MediaItem mediaItem = getVideoItemFromLank(item['lank'], JwLifeSettings().currentLanguage.symbol);
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
          MediaItem mediaItem = getVideoItemFromLank(item['lank'], JwLifeSettings().currentLanguage.symbol);
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
              String? jwLink = item['links']['jw.org'] ?? '';
              String? wolLink = item['links']['wol'] ?? '';

              if (wolLink != null && wolLink.isNotEmpty) {
                String lank = item['lank'];
                String keySymbol = '';
                String issueTagNumber = '0';

                RegExp regExp = RegExp(r'^(pub|pi)-([\w-]+?)(?:_(\d+))?$');
                Match? match = regExp.firstMatch(lank);

                if (match != null) {
                  keySymbol = match.group(2) ?? '';
                  if (match.group(3) != null) {
                    String rawNumber = match.group(3)!;
                    issueTagNumber = rawNumber.length == 6 ? '${rawNumber}00' : rawNumber;
                  }
                }

                Publication? publication = await PubCatalog.searchPub(
                  keySymbol,
                  int.parse(issueTagNumber),
                  JwLifeSettings().currentLanguage.id,
                );

                if (publication != null) {
                  publication.showMenu(context);
                }
                else {
                  printTime('Publication not found for lank: $lank');
                }
              }
              else {
                launchUrl(Uri.parse(jwLink!), mode: LaunchMode.externalApplication);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildArticlesList(dynamic result) {
    return Column(
      children: result['results'].map<Widget>((article) {
        return GestureDetector(
          onTap: () {
            if (article['links'] != null && article['links']['wol'] != null) {
              String lank = article['lank'];
              int docId = int.parse(lank.replaceAll("pa-", ""));

              printTime('docId: $docId');

              showDocumentView(context, docId, JwLifeSettings().currentLanguage.id);
            }
            else {
              printTime(article['links']['jw.org']);
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
                        article['context'] != null ? Text(article['context'], style: TextStyle(fontSize: 15, color: Color(0xFF858585))) : Container(),
                        Text(
                          article['title'] ?? '',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFa3b9e3) : Color(0xFF516da8)),
                          maxLines: 1, // Limiter à une ligne
                          overflow: TextOverflow.ellipsis, // Ajouter des points de suspension si le texte est trop long
                        ),
                        // Snippet en dessous du titre
                        Text(article['snippet'] ?? '', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
              printTime('result: $result');
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
                          _buildArticlesList(result)
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
