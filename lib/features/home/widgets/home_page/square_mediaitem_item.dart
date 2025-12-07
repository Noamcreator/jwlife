import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/repositories/MediaRepository.dart';

import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
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
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
          onTap: () {
            media.showPlayer(context);
          },
          child: SizedBox(
            width: kSquareItemHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.0),
                      child: ImageCachedWidget(
                        imageUrl: media.networkImageSqr,
                        icon: media is Audio ? JwIcons.headphones__simple : JwIcons.video,
                        height: kSquareItemHeight,
                        width: kSquareItemHeight,
                      ),
                    ),
                    Positioned(
                      top: -13,
                      right: -7,
                      child: PopupMenuButton(
                        icon: const Icon(Icons.more_horiz, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 20)]),
                        itemBuilder: (context) => media is Audio ? [
                          getAudioShareItem(media as Audio),
                          getAudioQrCode(context, media as Audio),
                          getAudioAddPlaylistItem(context, media as Audio),
                          getAudioLanguagesItem(context, media as Audio),
                          getAudioFavoriteItem(media as Audio),
                          getAudioDownloadItem(context, media as Audio),
                          getAudioLyricsItem(context, media as Audio),
                          getCopyLyricsItem(media as Audio)
                        ]
                            : media is Video ? [
                          getVideoShareItem(media as Video),
                          getVideoQrCode(context, media as Video),
                          getVideoAddPlaylistItem(context, media as Video),
                          getVideoLanguagesItem(context, media as Video),
                          getVideoFavoriteItem(media as Video),
                          getVideoDownloadItem(context, media as Video),
                          getShowSubtitlesItem(context, media as Video),
                          getCopySubtitlesItem(context, media as Video),
                        ] : [],
                      ),
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.85),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Row(
                          children: [
                            media is Audio ? Icon(JwIcons.headphones__simple, size: 10, color: Colors.white) : Text('►', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white)),
                            const SizedBox(width: 4),
                            Text(
                              formatDuration(media.duration),
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
                                right: -5,
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
                    media.title,
                    style: Theme.of(context).extension<JwLifeThemeStyles>()!.squareTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          )
      ),
    );
  }
}