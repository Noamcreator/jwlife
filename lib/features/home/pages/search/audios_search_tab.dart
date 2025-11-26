import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../data/models/audio.dart';
import 'search_model.dart';

class AudioSearchTab extends StatefulWidget {
  final SearchModel model;

  const AudioSearchTab({super.key, required this.model});

  @override
  _AudioSearchTabState createState() => _AudioSearchTabState();
}

class _AudioSearchTabState extends State<AudioSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchAudios(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun résultat trouvé.'));
        } else {
          final results = snapshot.data!;
          return OrientationBuilder(
            builder: (context, orientation) {
              final int crossAxisCount = orientation == Orientation.portrait ? 1 : 2;

              if (orientation == Orientation.portrait) {
                return ListView.builder(
                  itemCount: results.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _buildAudioCard(context, item);
                  },
                );
              } else {
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: results.length,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _buildAudioCard(context, item, isGrid: true);
                  },
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildAudioCard(BuildContext context, Map<String, dynamic> item, {bool isGrid = false}) {
    MediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

    if (mediaItem == null) return const SizedBox.shrink();

    Audio audio = Audio.fromJson(mediaItem: mediaItem);

    return GestureDetector(
      onTap: () async {
        audio.showPlayer(context);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isGrid ? 0 : 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
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
                item['imageUrl'].isNotEmpty
                    ? Image.network(
                  item['imageUrl'],
                  width: double.infinity,
                  height: isGrid ? null : 200,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: double.infinity,
                  height: isGrid ? null : 150,
                  color: Colors.grey,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          JwIcons.headphones,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(audio.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: PopupMenuButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
                    itemBuilder: (context) => [
                      getAudioShareItem(audio),
                      getAudioAddPlaylistItem(context, audio),
                      getAudioLanguagesItem(context, audio),
                      getAudioFavoriteItem(audio),
                      getAudioDownloadItem(context, audio),
                      getAudioLyricsItem(context, audio),
                      getCopyLyricsItem(audio)
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
                  fontSize: 17,
                ),
                maxLines: isGrid ? 2 : null,
                overflow: isGrid ? TextOverflow.ellipsis : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}