import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/media.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils_audio.dart';
import '../../../core/utils/utils_video.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/MediaRepository.dart';
import '../../../widgets/image_cached_widget.dart';

class RectangleMediaItemItem extends StatelessWidget {
  final Media media;

  const RectangleMediaItemItem({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final m = MediaRepository().getMedia(media);

    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
      child: InkWell(
        onTap: () {
          m.showPlayer(context);
        },
        child: SizedBox(
          height: 80,
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: ImageCachedWidget(
                      imageUrl: m.networkImageSqr,
                      pathNoImage: m is Audio ? "pub_type_audio" : "pub_type_video",
                      height: 80,
                      width: 80,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 25.0, top: 3.0, bottom: 3.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            '${formatDateTime(m.lastModified ?? m.firstPublished!).year} - ${m.keySymbol}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFc3c3c3)
                                  : const Color(0xFF626262),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Menu contextuel
              Positioned(
                top: -5,
                right: -10,
                child: RepaintBoundary(
                  child: PopupMenuButton(
                    popUpAnimationStyle: AnimationStyle.lerp(
                      const AnimationStyle(curve: Curves.ease),
                      const AnimationStyle(curve: Curves.ease),
                      0.5,
                    ),
                    icon: const Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
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
                )
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

              Stack(
                children: [
                  // Éléments dynamiques en fonction de l'état
                  ValueListenableBuilder<bool>(
                    valueListenable: media.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (isDownloading) {
                        return Positioned(
                          bottom: -2,
                          right: -8,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => media.cancelDownload(context),
                            icon: const Icon(JwIcons.x, color: Color(0xFF9d9d9d)),
                          ),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: media.isDownloadedNotifier,
                        builder: (context, isDownloaded, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: media.isFavoriteNotifier,
                            builder: (context, isFavorite, _) {
                              final hasUpdate = media.hasUpdate();

                              if (!isDownloaded) {
                                // Nuage de téléchargement + taille
                                return Stack(
                                  children: [
                                    Positioned(
                                      bottom: 5,
                                      right: -8,
                                      height: 40,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => media.download(context),
                                        icon: const Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              else if (hasUpdate) {
                                // Bouton mise à jour + taille
                                return Stack(
                                  children: [
                                    Positioned(
                                      bottom: 5,
                                      right: -8,
                                      height: 40,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => media.download(context),
                                        icon: const Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              else if (isFavorite) {
                                // Étoile favoris (optionnel, ajoute un bouton ou un indicateur ici)
                                return Positioned(
                                  bottom: 5,
                                  right: -8,
                                  height: 40,
                                  child: Icon(
                                    Icons.star,
                                    color: const Color(0xFF9d9d9d),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: media.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (!isDownloading) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        height: 2,
                        width: 302,
                        child: ValueListenableBuilder<double>(
                          valueListenable: media.progressNotifier,
                          builder: (context, progress, _) {
                            return LinearProgressIndicator(
                              value: progress == -1 ? null : progress,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                              backgroundColor: Colors.grey,
                              minHeight: 2,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

