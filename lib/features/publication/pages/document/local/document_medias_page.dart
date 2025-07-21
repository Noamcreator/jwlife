import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../data/models/document.dart';
import '../data/models/multimedia.dart';
import 'full_screen_image_page.dart';

class DocumentMediasView extends StatefulWidget {
  final Document document;

  const DocumentMediasView({super.key, required this.document});

  @override
  _DocumentMediasViewState createState() => _DocumentMediasViewState();
}

class _DocumentMediasViewState extends State<DocumentMediasView> {
  List<Multimedia> videos = [];
  List<Multimedia> images = [];

  @override
  void initState() {
    super.initState();
    setState(() {
      videos = widget.document.multimedias.where((media) => media.mimeType == 'video/mp4').toList();
      images = widget.document.multimedias.where((media) => media.mimeType != 'video/mp4' && !widget.document.multimedias.any((media2) => media.id == media2.linkMultimediaId)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voir les médias"),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: () {
              History.showHistoryDialog(context);
            },
          ),
        ],
      ),
      body: (videos.isEmpty && images.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (videos.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20.0,
                  mainAxisSpacing: 5.0,
                  childAspectRatio: 16 / 11,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final media = videos[index];
                  MediaItem? mediaItem = getVideoItem(media.keySymbol, media.track, media.mepsDocumentId, media.issueTagNumber, media.mepsLanguageId);
                  if (mediaItem == null) {
                    return Container();
                  }
                  return videoTile(context, mediaItem);
                },
              ),
            ],
            SizedBox(height: 20),
            if (images.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  "Images",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20.0,
                  mainAxisSpacing: 20.0,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final media = images[index];
                  return imageTile(context, media);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget videoTile(BuildContext context, MediaItem mediaItem) {
    bool isAudio = mediaItem.type == 'AUDIO';

    return Column(
        children: [
          GestureDetector(
            onTap: () {
              if (isAudio) {
                showAudioPlayer(context, mediaItem);
              } else {
                showFullScreenVideo(context, mediaItem);
              }
            },
            child: Stack(
              children: [
                ClipRRect(
                  child: ImageCachedWidget(
                    imageUrl:
                        mediaItem.realmImages?.wideFullSizeImageUrl ??
                        mediaItem.realmImages?.wideImageUrl ??
                        mediaItem.realmImages?.squareImageUrl,
                    pathNoImage: isAudio ? "pub_type_audio" : "pub_type_video",
                    height: 90,
                    width: 180,
                    fit: BoxFit.fitHeight,
                  ),
                ),
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          isAudio ? JwIcons.headphones__simple : JwIcons.play,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDuration(mediaItem.duration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -10,
                  child: PopupMenuButton(
                    popUpAnimationStyle: AnimationStyle.lerp(
                      AnimationStyle(curve: Curves.ease),
                      AnimationStyle(curve: Curves.ease),
                      0.5,
                    ),
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                    shadowColor: Colors.black,
                    elevation: 8,
                    itemBuilder: (context) => isAudio
                        ? [
                      getAudioShareItem(mediaItem),
                      getAudioLanguagesItem(context, mediaItem),
                      getAudioFavoriteItem(mediaItem),
                      getAudioDownloadItem(context, mediaItem),
                      getAudioLyricsItem(context, mediaItem),
                      getCopyLyricsItem(mediaItem),
                    ]
                        : [
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
          ),
          const SizedBox(height: 4),
          Text(
            mediaItem.title ?? '',
            style: const TextStyle(
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ]
    );
  }

  Widget imageTile(BuildContext context, Multimedia media) {
    return GestureDetector(
      onTap: () {
        JwLifePage.toggleNavBarBlack.call(true);

        int index = widget.document.multimedias.indexWhere((img) => img.filePath.toLowerCase() == media.filePath.toLowerCase());
        showPage(context, FullScreenImagePage(publication: widget.document.publication, multimedias: widget.document.multimedias, index: index));
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            child: ImageCachedWidget(
              imageUrl: '${widget.document.publication.path}/${media.filePath}',
              pathNoImage: 'pub_type_video',
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          if (media.caption.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  media.caption,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
