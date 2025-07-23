import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';

import '../../../../core/api.dart';
import '../../../../core/icons.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_audio.dart';
import '../../../../core/utils/utils_media.dart';
import '../../../../core/utils/utils_video.dart';
import '../../../../data/models/video.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../widgets/dialog/publication_dialogs.dart';
import '../../../../widgets/image_cached_widget.dart';

class HomeSquareMediaItemItem extends StatelessWidget {
  final MediaItem mediaItem;

  const HomeSquareMediaItemItem({super.key, required this.mediaItem});

  @override
  Widget build(BuildContext context) {
    Video? video = JwLifeApp.mediaCollections.getVideo(mediaItem);
    bool isAudio = mediaItem.type == "AUDIO";

    return InkWell(
        onTap: () {
          if (isAudio) {
            showAudioPlayer(context, mediaItem);
          }
          else {
            showFullScreenVideo(context, mediaItem);
          }
        },
        child: SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: ImageCachedWidget(
                      imageUrl: mediaItem.realmImages?.squareImageUrl ?? '',
                      pathNoImage: "pub_type_video",
                      height: 80,
                      width: 80,
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -10,
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
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                      child: Row(
                        children: [
                          Icon(
                            isAudio ? JwIcons.headphones__simple : JwIcons.play,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatDuration(mediaItem.duration ?? 0),
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                  video != null && video.isDownloaded == true ? Container() : Positioned(
                    bottom: -7,
                    right: -7,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        if(await hasInternetConnection()) {
                          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${mediaItem.languageSymbol}/${mediaItem.languageAgnosticNaturalKey}';
                          final response = await Api.httpGetWithHeaders(link);
                          if (response.statusCode == 200) {
                            final jsonFile = response.body;
                            final jsonData = json.decode(jsonFile);

                            printTime(link);

                            showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
                              if (value != null) {
                                downloadMedia(context, mediaItem, jsonData['media'][0], file: value);
                              }
                            });
                          }
                        }
                      },
                      icon: const Icon(
                        JwIcons.cloud_arrow_down,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                  ),
                  video != null && video.isDownloaded == true && JwLifeApp.userdata.favorites.contains(mediaItem) ? Positioned(
                    bottom: -4,
                    right: 2,
                    height: 40,
                    child: Icon(
                      JwIcons.star,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ) : Container(),
                ],
              ),
              SizedBox(height: 4),
              SizedBox(
                width: 80,
                child: Text(
                  mediaItem.title ?? '',
                  style: TextStyle(fontSize: 9.0, height: 1.2),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        )
    );
  }
}