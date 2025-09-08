import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/models/video.dart';

class VideosSearchTab extends StatefulWidget {
  final SearchModel model;

  const VideosSearchTab({super.key, required this.model});

  @override
  _VideosSearchTabState createState() => _VideosSearchTabState();
}

class _VideosSearchTabState extends State<VideosSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.model.fetchVideos(), // Vérifie et retourne les vidéos en cache si déjà chargées
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucune vidéo trouvée.'));
          } else {
            final results = snapshot.data!;
            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                MediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings().currentLanguage.symbol);
                Video video = Video.fromJson(mediaItem: mediaItem);

                return GestureDetector(
                  onTap: () {
                    video.showPlayer(context);
                  },
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF292929)
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                                ? ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                              child: Image.network(
                                item['imageUrl'],
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  color: Colors.black.withOpacity(0.7),
                                  child: Row(
                                      children: [
                                        const Icon(
                                          JwIcons.play,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatDuration(mediaItem.duration!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ]
                                  )
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: PopupMenuButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                                itemBuilder: (context) => [
                                  getVideoShareItem(video),
                                  getVideoLanguagesItem(context, video),
                                  getVideoFavoriteItem(video),
                                  getVideoDownloadItem(context, video),
                                  getShowSubtitlesItem(context, video, query: widget.model.query),
                                  getCopySubtitlesItem(context, video),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
