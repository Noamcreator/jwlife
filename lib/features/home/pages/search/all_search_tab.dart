import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
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

  static const double _verseListHeight = 160.0;

  Widget _buildVerseList(dynamic result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _verseListHeight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, verseIndex) {
          final item = result['results'][verseIndex];
          return GestureDetector(
            onTap: () {
              String itemString = item['lank'];
              String itemString2 = itemString.split("-")[1].split("_")[0];

              printTime('Item tapped: $itemString2');

              int verseNumber = int.parse(itemString2.substring(itemString2.length - 3));
              String remainingString = itemString2.substring(0, itemString2.length - 3);
              int chapterNumber = int.parse(remainingString.substring(remainingString.length - 3));
              int bookNumber = int.parse(remainingString.substring(0, remainingString.length - 3));

              List<String> wordsSelected = widget.model.query.split(' ');
              showChapterView(context, 'nwtsty', JwLifeSettings.instance.currentLanguage.value.id, bookNumber, chapterNumber, firstVerseNumber: verseNumber, lastVerseNumber: verseNumber, wordsSelected: wordsSelected);
            },
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextHtmlWidget(
                      text: item['title'].replaceAll("&nbsp;", " "),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? const Color(0xFF9AB5E0) : const Color(0xFF4a6da7),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextHtmlWidget(
                        text: item['snippet'],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildIndexList(dynamic result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 90,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              width: 240,
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  item['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? const Color(0xFF9AB5E0) : const Color(0xFF516da8),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const double _mediaListHeight = 220.0;

  Widget _buildVideosList(dynamic result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _mediaListHeight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, videoIndex) {
          final item = result['results'][videoIndex];
          RealmMediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

          if (mediaItem == null) return const SizedBox.shrink();

          Video video = Video.fromJson(mediaItem: mediaItem);
          return GestureDetector(
            onTap: () async {
              video.showPlayer(context);
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          item['image']['url'],
                          width: double.infinity,
                          height: 124,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['duration'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: PopupMenuButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                            itemBuilder: (context) => [
                              getVideoShareItem(video),
                              getVideoQrCode(context, video),
                              getVideoAddPlaylistItem(context, video),
                              getVideoLanguagesItem(context, video),
                              getVideoFavoriteItem(video),
                              getVideoDownloadItem(context, video),
                              getShowSubtitlesItem(context, video),
                              getCopySubtitlesItem(context, video),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.3,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _mediaListHeight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: result['results'].length,
        itemBuilder: (context, audioIndex) {
          final item = result['results'][audioIndex];
          RealmMediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

          if (mediaItem == null) return const SizedBox.shrink();

          Audio audio = Audio.fromJson(mediaItem: mediaItem);

          return GestureDetector(
            onTap: () async {
              audio.showPlayer(context);
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          item['image']['url'],
                          width: double.infinity,
                          height: 124,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['duration'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: PopupMenuButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                            itemBuilder: (context) => [
                              getAudioShareItem(audio),
                              getAudioQrCode(context, audio),
                              getAudioAddPlaylistItem(context, audio),
                              getAudioLanguagesItem(context, audio),
                              getAudioFavoriteItem(audio),
                              getAudioDownloadItem(context, audio),
                              getAudioLyricsItem(context, audio),
                              getCopyLyricsItem(audio),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.3,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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

  static const double _publicationListHeight = 130.0;

  Widget _buildPublicationsList(dynamic result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _publicationListHeight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              width: 280,
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: item['image']['url'] != null && item['image']['url'] != ''
                        ? Image.network(
                      item['image']['url'],
                      width: 70,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 70,
                      height: double.infinity,
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextHtmlWidget(
                            text: item['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item['context'] != null && item['context'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            TextHtmlWidget(
                              text: item['context'],
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: result['results'].map<Widget>((article) {
          return Container(
            margin: const EdgeInsets.only(bottom: 1),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (article['links'] != null && article['links']['wol'] != null) {
                    String lank = article['lank'];
                    int docId = int.parse(lank.replaceAll("pa-", ""));
                    List<String> wordsSelected = widget.model.query.split(' ');
                    showDocumentView(context, docId, JwLifeSettings.instance.currentLanguage.value.id, wordsSelected: wordsSelected);
                  } else {
                    launchUrl(Uri.parse(article['links']['jw.org']!), mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: article['image'] != null && article['image']['url'] != null
                              ? ImageCachedWidget(
                            imageUrl: article['image']['url'],
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                              : Center(
                            child: Icon(
                              JwIcons.article,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (article['context'] != null && article['context'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: TextHtmlWidget(
                                  text: article['context'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            TextHtmlWidget(
                              text: article['title'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF9AB5E0) : const Color(0xFF516da8),
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (article['snippet'] != null && article['snippet'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              TextHtmlWidget(
                                text: article['snippet'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchAllSearch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.blue[300]! : Colors.blue[700]!,
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Une erreur est survenue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Essayez avec d\'autres termes de recherche',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          final results = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              if (result['type'] == 'group' && result['results'].isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (result['label'] != null && result['label'] != '')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            result['label'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
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