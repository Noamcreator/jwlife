import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';

import '../../../../core/icons.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_audio.dart';
import '../../../../core/utils/utils_video.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/models/video.dart';
import '../../../../widgets/image_cached_widget.dart';

class HomeSquareMediaItemItem extends StatelessWidget {
  final Media media;

  const HomeSquareMediaItemItem({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final m = MediaRepository().getMedia(media);

    return InkWell(
        onTap: () {
          m.showPlayer(context);
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
                      imageUrl: m.networkImageSqr,
                      icon: m is Audio ? JwIcons.headphones__simple : JwIcons.video,
                      height: 80,
                      width: 80,
                    ),
                  ),
                  Positioned(
                    top: -15,
                    right: -10,
                    child: PopupMenuButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                      shadowColor: Colors.black,
                      elevation: 8,
                      itemBuilder: (context) => m is Audio ? [
                        getAudioShareItem(m),
                        getAudioAddPlaylistItem(context, m),
                        getAudioLanguagesItem(context, m),
                        getAudioFavoriteItem(m),
                        getAudioDownloadItem(context, m),
                        getAudioLyricsItem(context, m),
                        getCopyLyricsItem(m)
                      ]
                          : m is Video ? [
                        getVideoShareItem(m),
                        getVideoAddPlaylistItem(context, m),
                        getVideoLanguagesItem(context, m),
                        getVideoFavoriteItem(m),
                        getVideoDownloadItem(context, m),
                        getShowSubtitlesItem(context, m),
                        getCopySubtitlesItem(context, m),
                      ] : [],
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
                            m is Audio ? JwIcons.headphones__simple : JwIcons.play,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatDuration(m.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bouton dynamique
                  ValueListenableBuilder<bool>(
                    valueListenable: media.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (isDownloading) {
                        return Positioned(
                          bottom: -4,
                          right: -8,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              media.cancelDownload(context);
                            },
                            icon: const Icon(
                              JwIcons.x,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                            ),
                          ),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: media.isDownloadedNotifier,
                        builder: (context, isDownloaded, _) {
                          if (!isDownloaded) {
                            return Positioned(
                              bottom: -4,
                              right: -8,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                  final Offset tapPosition = renderBox.localToGlobal(Offset.zero) + renderBox.size.center(Offset.zero);

                                  media.download(context, tapPosition: tapPosition);
                                },
                                icon: const Icon(
                                  JwIcons.cloud_arrow_down,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                                ),
                              ),
                            );
                          }
                          else if (media.hasUpdate()) {
                            return Positioned(
                              bottom: -4,
                              right: -8,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                  final Offset tapPosition = renderBox.localToGlobal(Offset.zero) + renderBox.size.center(Offset.zero);
                                  media.download(context, tapPosition: tapPosition);
                                },
                                icon: const Icon(
                                  JwIcons.arrows_circular,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                                ),
                              ),
                            );
                          }
                          return ValueListenableBuilder<bool>(
                            valueListenable: media.isFavoriteNotifier,
                            builder: (context, isFavorite, _) {
                              if (isFavorite) {
                                return Positioned(
                                  bottom: -4,
                                  right: 2,
                                  height: 40,
                                  child: const Icon(
                                    JwIcons.star,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 5)
                                    ],
                                  ),
                                );
                              }
                              else {
                                return const SizedBox.shrink();
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                  // Barre de progression
                  Positioned(
                    bottom: 0,
                    right: 0,
                    height: 2,
                    width: 80,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: media.isDownloadingNotifier,
                      builder: (context, isDownloading, _) {
                        if (!isDownloading) return const SizedBox.shrink();

                        return ValueListenableBuilder<double>(
                          valueListenable: media.progressNotifier,
                          builder: (context, progress, _) {
                            return LinearProgressIndicator(
                              value: progress == -1 ? null : progress,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              backgroundColor: Color(0xFFbdbdbd),
                              minHeight: 2,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4),
              SizedBox(
                width: 80,
                child: Text(
                  m.title,
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