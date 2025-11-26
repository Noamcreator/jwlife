import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/html_styles.dart';
import '../../../../core/utils/utils.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/models/video.dart';
import '../../../../widgets/image_cached_widget.dart';

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

  // Hauteur fixe raisonnable pour les versets/snippets.
  static const double _verseListHeight = 180.0;

  Widget _buildVerseList(dynamic result) {
    // Rétablissement de la hauteur fixe pour une performance optimale et des contraintes claires.
    return SizedBox(
      height: _verseListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, verseIndex) {
          final item = result['results'][verseIndex];
          return GestureDetector(
            onTap: () {
              String itemString = item['lank'];
              String itemString2 = itemString.split("-")[1].split("_")[0];

              printTime('Item tapped: $itemString2');

              // Le verset est toujours les 3 derniers chiffres
              int verseNumber = int.parse(itemString2.substring(itemString2.length - 3));

              // La partie qui reste contient le livre et le chapitre
              String remainingString = itemString2.substring(0, itemString2.length - 3);

              // Le chapitre est les 3 derniers chiffres de la partie restante
              int chapterNumber = int.parse(remainingString.substring(remainingString.length - 3));

              // Le livre est le reste de la chaîne
              int bookNumber = int.parse(remainingString.substring(0, remainingString.length - 3));

              List<String> wordsSelected = widget.model.query.split(' ');
              showChapterView(context, 'nwtsty', JwLifeSettings.instance.currentLanguage.value.id, bookNumber, chapterNumber, firstVerseNumber: verseNumber, lastVerseNumber: verseNumber, wordsSelected: wordsSelected);
            },
            child: Container(
                width: 250,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextHtmlWidget(
                        text: item['title'].replaceAll("&nbsp;", " "),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFa0b9e2)
                              : const Color(0xFF4a6da7),
                        ),
                        maxLines: 1, // Limite pour le titre
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Le snippet prend le reste de l'espace. La hauteur totale est maintenant fixée par _verseListHeight.
                      // MaxLines est fixé pour s'assurer que le snippet ne dépasse pas et ne cause pas de débordement interne.
                      TextHtmlWidget(
                        text: item['snippet'],
                        style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        maxLines: 4, // Définir un nombre max de lignes
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
            ),
          );
        },
      ),
    );
  }

  Widget _buildIndexList(dynamic result) {
    // Hauteur fixée à 110 (comme dans le code original)
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, publicationIndex) {
          final item = result['results'][publicationIndex];
          return GestureDetector(
            onTap: () async {
              if (item['links'] != null && item['links']['wol'] != null) {
                String lank = item['lank'];
                int docId = int.parse(lank.replaceAll("pa-", ""));
                showDocumentView(context, docId, JwLifeSettings.instance.currentLanguage.value.id);
              } else {
                launchUrl(Uri.parse(item['links']['jw.org']!), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFa3b9e3) : const Color(0xFF516da8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Hauteur fixée à 250 (comme dans le code original)
  static const double _mediaListHeight = 250.0;

  Widget _buildVideosList(dynamic result) {
    return SizedBox(
      height: _mediaListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, videoIndex) {
          final item = result['results'][videoIndex];
          MediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

          if (mediaItem == null) return const SizedBox.shrink();

          Video video = Video.fromJson(mediaItem: mediaItem);
          return GestureDetector(
            onTap: () async {
              video.showPlayer(context);
            },
            child: Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          item['image']['url'],
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item['duration'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (context) => [
                            getVideoShareItem(video),
                            getVideoAddPlaylistItem(context, video),
                            getVideoLanguagesItem(context, video),
                            getVideoFavoriteItem(video),
                            getVideoDownloadItem(context, video),
                            getShowSubtitlesItem(context, video),
                            getCopySubtitlesItem(context, video),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
      height: _mediaListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, audioIndex) {
          final item = result['results'][audioIndex];
          MediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

          if (mediaItem == null) return const SizedBox.shrink();

          Audio audio = Audio.fromJson(mediaItem: mediaItem);

          return GestureDetector(
            onTap: () async {
              audio.showPlayer(context);
            },
            child: Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          item['image']['url'],
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item['duration'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                          itemBuilder: (context) => [
                            getAudioShareItem(audio),
                            getAudioAddPlaylistItem(context, audio),
                            getAudioLanguagesItem(context, audio),
                            getAudioFavoriteItem(audio),
                            getAudioDownloadItem(context, audio),
                            getAudioLyricsItem(context, audio),
                            getCopyLyricsItem(audio),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  // Hauteur fixée à 200 (comme dans le code original)
  static const double _publicationListHeight = 200.0;

  Widget _buildPublicationsList(dynamic result) {
    return SizedBox(
      height: _publicationListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, publicationIndex) {
          final item = result['results'][publicationIndex];
          return GestureDetector(
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

                Publication? publication = await CatalogDb.instance.searchPub(
                  keySymbol,
                  int.parse(issueTagNumber),
                  JwLifeSettings.instance.currentLanguage.value.id,
                );

                if (publication != null) {
                  publication.showMenu(context);
                } else {
                  printTime('Publication not found for lank: $lank');
                }
              } else {
                launchUrl(Uri.parse(jwLink!), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 300,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    child: item['image']['url'] != null && item['image']['url'] != ''
                        ? Image.network(
                      item['image']['url'],
                      width: 100,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 100,
                      height: double.infinity,
                      color: Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextHtmlWidget(
                            text: item['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          TextHtmlWidget(
                            text: item['context'],
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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

  Widget _buildArticlesList(dynamic result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        children: result['results'].map<Widget>((article) {
          return GestureDetector(
            onTap: () {
              if (article['links'] != null && article['links']['wol'] != null) {
                String lank = article['lank'];
                int docId = int.parse(lank.replaceAll("pa-", ""));
                List<String> wordsSelected = widget.model.query.split(' ');
                showDocumentView(context, docId, JwLifeSettings.instance.currentLanguage.value.id, wordsSelected: wordsSelected);
              }
              else {
                launchUrl(Uri.parse(article['links']['jw.org']!), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Alignement en haut pour le Row
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: article['image'] != null && article['image']['url'] != null ? ImageCachedWidget(
                        imageUrl: article['image']['url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ) : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article['context'] != null && article['context'].isNotEmpty)
                            TextHtmlWidget(
                              text: article['context'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).hintColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          TextHtmlWidget(
                            text: article['title'] ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Retrait du TextHtmlWidget pour le snippet pour laisser le container s'adapter.
                          // Si vous voulez le snippet, assurez-vous qu'il ne déborde pas.
                          // Pour la proportion, on le réintègre en limitant les lignes:
                          TextHtmlWidget(
                            text: article['snippet'] ?? '',
                            style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchAllSearch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun résultat trouvé.'));
        }
        else {
          final results = snapshot.data!;
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              if (result['type'] == 'group' && result['results'].isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: result['label'] != null && result['label'] != ''
                            ? Text(
                          result['label'],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      if (result['layout'].contains('bible'))
                        _buildVerseList(result)
                      else if (result['layout'].contains('videos'))
                        _buildVideosList(result)
                      else if (result['layout'].contains('audio'))
                          _buildAudioList(result)
                        else if (result['layout'].contains('publications'))
                            _buildPublicationsList(result)
                          else if (result['layout'].contains('linkGroup'))
                              _buildIndexList(result)
                            else if (result['layout'].contains('flat'))
                                _buildArticlesList(result)
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          );
        }
      },
    );
  }
}