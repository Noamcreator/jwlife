import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/modules/home/views/search_views/search_model.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:realm/realm.dart';

import '../../../../core/icons.dart';

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
                MediaItem? mediaItem = getVideoItemFromLank(item['lank'], JwLifeApp.settings.currentLanguage.symbol);

                return GestureDetector(
                  onTap: () {
                    showFullScreenVideo(context, mediaItem);
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
                            if (mediaItem != null)
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
                            if (mediaItem != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: PopupMenuButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                                  itemBuilder: (context) => [
                                    getVideoShareItem(mediaItem),
                                    getVideoLanguagesItem(context, mediaItem),
                                    getVideoFavoriteItem(mediaItem),
                                    getVideoDownloadItem(context, mediaItem),
                                    getShowSubtitlesItem(context, mediaItem, query: widget.model.query),
                                    getCopySubtitlesItem(context, mediaItem),
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
