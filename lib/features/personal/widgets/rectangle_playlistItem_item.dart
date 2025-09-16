import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/userdata/independentMedia.dart';
import 'package:jwlife/data/models/userdata/playlistItem.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils_audio.dart';
import '../../../core/utils/utils_video.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/location.dart';
import '../../../data/models/video.dart';
import '../../../data/realm/catalog.dart';
import '../../../data/repositories/MediaRepository.dart';
import '../../image/image_page.dart';

class RectanglePlaylistItemItem extends StatelessWidget {
  final PlaylistItem item;

  const RectanglePlaylistItemItem({super.key, required this.item});

  // La fonction buildEndAction est maintenant utilisée pour générer les items du menu.
  List<PopupMenuItem<int>> buildEndAction(BuildContext context) {
    return [
      PopupMenuItem(
        value: 0,
        child: Row(
          children: const [
            Icon(JwIcons.play),
            SizedBox(width: 8),
            Text('Continuer'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 1,
        child: Row(
          children: const [
            Icon(Icons.square_outlined),
            SizedBox(width: 8),
            Text('Arrêter'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 2,
        child: Row(
          children: const [
            Icon(JwIcons.pause),
            SizedBox(width: 8),
            Text('Mettre en pause'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 3,
        child: Row(
          children: const [
            Icon(JwIcons.arrows_loop),
            SizedBox(width: 8),
            Text('Répéter'),
          ],
        ),
      ),
    ];
  }

  // Cette fonction détermine le bouton actuel affiché dans l'UI.
  Widget buildPopupMenuButton() {
    String label;
    IconData? icon;

    switch (item.endAction) {
      case 0:
        label = 'Continuer';
        icon = JwIcons.play;
        break;
      case 1:
        label = 'Arrêter';
        icon = Icons.square_outlined;
        break;
      case 2:
        label = 'Mettre en pause';
        icon = JwIcons.pause;
        break;
      case 3:
        label = 'Répéter';
        icon = JwIcons.arrows_loop;
        break;
      default:
        label = 'Continuer';
        icon = JwIcons.play;
        break;
    }

    return PopupMenuButton<int>(
      itemBuilder: buildEndAction,
      onSelected: (int newValue) {
        item.endAction = newValue;
      },
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PlaylistItem playlistItem = item;

    Location? location = playlistItem.location;
    IndependentMedia? independentMedia = playlistItem.independentMedia;
    if (location!.isNull() && independentMedia!.isNull()) {
      return Container();
    }

    print(location);

    Media? media;
    bool isAudio = false;
    String title = playlistItem.label ?? '';
    if (!location.isNull()) {
      print(playlistItem.location);
      media = MediaRepository().getByCompositeKey(getMediaItem(playlistItem.location?.keySymbol, playlistItem.location?.track, playlistItem.location?.mepsDocumentId, playlistItem.location?.issueTagNumber, playlistItem.location?.mepsLanguageId)!);

      isAudio = media is Audio;
    }
    else if (independentMedia != null) {

    }
    else {
      return Container();
    }

    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
      child: InkWell(
        onTap: () async {
          if (media != null) {
            media.showPlayer(context);
          }
          else if (independentMedia != null) {
            if(independentMedia.mimeType!.contains('image')) {
              File independentMedia = await playlistItem.independentMedia!.getImageFile();
              showPage(context, ImagePage(filePath: independentMedia.path));
            }
            else if(independentMedia.mimeType!.contains('video')) {
              if(media != null) {
                media.showPlayer(context);
              }
            }
            else if(independentMedia.mimeType!.contains('audio')) {
              if(media != null) {
                media.showPlayer(context);
              }
            }
          }
        },
        child: SizedBox(
          height: 80,
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: FutureBuilder<File?>(
                      future: item.getThumbnailFile(),
                      builder: (context, snapshot) {
                        final placeholder = Container(
                          height: 80,
                          width: 80,
                          color: Colors.grey.shade300,
                        );

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return placeholder;
                        }

                        if (snapshot.hasError || snapshot.data == null) {
                          return Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey,
                          );
                        }

                        return Image.file(
                          snapshot.data!,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 25.0, top: 3.0, bottom: 3.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espace entre le haut et le bas
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          buildPopupMenuButton()
                        ],
                      ),
                    ),
                  )
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
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry>[
                        PopupMenuItem(
                          child: Row(
                            children: const [
                              Icon(JwIcons.pencil),
                              SizedBox(width: 8),
                              Text('Renommer'),
                            ],
                          ),
                          onTap: () async {

                          },
                        ),
                        PopupMenuItem(
                          child: Row(
                            children: const [
                              Icon(JwIcons.trash),
                              SizedBox(width: 8),
                              Text('Supprimer'),
                            ],
                          ),
                          onTap: () async {

                          },
                        ),
                        PopupMenuItem(
                          child: Row(
                            children: const [
                              Icon(JwIcons.share),
                              SizedBox(width: 8),
                              Text('Partager'),
                            ],
                          ),
                          onTap: () {
                            // sharePlaylist(context, playlist);
                          },
                        ),
                      ];

                      if (media != null) {
                        items.addAll([
                          getVideoShareItem(media as Video),
                          getVideoLanguagesItem(context, media),
                          getVideoFavoriteItem(media),
                          getVideoDownloadItem(context, media),
                          getShowSubtitlesItem(context, media),
                          getCopySubtitlesItem(context, media),
                        ]);
                      }

                      return items;
                    },
                  ),
                )
              ),

              if((item.durationTicks != null && item.durationTicks != 40000000) || item.baseDurationTicks != null)
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
                        formatTick((item.durationTicks != null && item.durationTicks != 40000000) ? item.durationTicks! : (item.baseDurationTicks ?? 0)),
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),

              /*
              Stack(
                children: [
                  // Éléments dynamiques en fonction de l'état
                  ValueListenableBuilder<bool>(
                    valueListenable: MediaItem.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (isDownloading) {
                        return Positioned(
                          bottom: -2,
                          right: -8,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => MediaItem.cancelDownload(context),
                            icon: const Icon(JwIcons.x, color: Color(0xFF9d9d9d)),
                          ),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: MediaItem.isDownloadedNotifier,
                        builder: (context, isDownloaded, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: MediaItem.isFavoriteNotifier,
                            builder: (context, isFavorite, _) {
                              final hasUpdate = MediaItem.hasUpdate();

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
                                        onPressed: () => MediaItem.download(context),
                                        icon: const Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: -5,
                                      width: 50,
                                      child: Text(
                                        textAlign: TextAlign.center,
                                        formatFileSize(MediaItem.expandedSize),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFc3c3c3)
                                              : const Color(0xFF626262),
                                        ),
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
                                        onPressed: () => MediaItem.update(context),
                                        icon: const Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: -5,
                                      width: 50,
                                      child: Text(
                                        textAlign: TextAlign.center,
                                        formatFileSize(MediaItem.expandedSize),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFc3c3c3)
                                              : const Color(0xFF626262),
                                        ),
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
                    valueListenable: MediaItem.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (!isDownloading) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        height: 2,
                        width: 302,
                        child: ValueListenableBuilder<double>(
                          valueListenable: MediaItem.progressNotifier,
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

               */
            ],
          ),
        ),
      ),
    );
  }
}

