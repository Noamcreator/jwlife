import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/models/video.dart';
import '../../../../widgets/image_cached_widget.dart';

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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchVideos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune vidéo trouvée.'));
        } else {
          final results = snapshot.data!;

          return OrientationBuilder(
            builder: (context, orientation) {
              final int crossAxisCount = orientation == Orientation.portrait ? 1 : 2;

              if (orientation == Orientation.portrait) {
                return ListView.builder(
                  itemCount: results.length,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    if (item['subtype'] == 'videoCategory') {
                      return _buildVideoCategoryCard(context, item);
                    } else if (item['subtype'] == 'video') {
                      return _buildVideoCard(context, item);
                    } else {
                      return const SizedBox.shrink();
                    }
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
                    if (item['subtype'] == 'videoCategory') {
                      return _buildVideoCategoryCard(context, item);
                    } else if (item['subtype'] == 'video') {
                      return _buildVideoCard(context, item);
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildVideoCategoryCard(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        launchUrl(Uri.parse(item['links']['jw.org']));
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                  ? Image.network(
                item['imageUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              )
                  : Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item['context'] != null && item['context'].isNotEmpty)
                    Text(
                      item['context'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> item) {
    RealmMediaItem? mediaItem = getMediaItemFromLank(item['lank'], JwLifeSettings.instance.currentLanguage.value.symbol);

    if (mediaItem == null) {
      return const SizedBox.shrink();
    }

    Video video = Video.fromJson(mediaItem: mediaItem);

    return GestureDetector(
      onTap: () {
        video.showPlayer(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
          borderRadius: BorderRadius.circular(0),
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
                ImageCachedWidget(
                  imageUrl: mediaItem.images?.wideFullSizeImageUrl ??
                      mediaItem.images?.wideImageUrl ??
                      mediaItem.images?.squareImageUrl,
                  icon: JwIcons.video,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '►︎',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(mediaItem.duration!),
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
                      getVideoShareItem(video),
                      getVideoQrCode(context, video),
                      getVideoAddPlaylistItem(context, video),
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
                  fontSize: 17,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}