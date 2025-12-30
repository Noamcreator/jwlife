import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart'; // Ajout de l'import manquant
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils_playlist.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/independent_media.dart';
import '../../../data/models/userdata/location.dart';
import '../../../data/models/userdata/playlist_item.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/MediaRepository.dart';
import '../../../i18n/i18n.dart';
import '../pages/playlist_player.dart';

class RectanglePlaylistItemItem extends StatefulWidget {
  final List<PlaylistItem> items;
  final PlaylistItem item;
  final Function(PlaylistItem) onDelete;

  const RectanglePlaylistItemItem({super.key, required this.items, required this.item, required this.onDelete});

  @override
  State<RectanglePlaylistItemItem> createState() => _RectanglePlaylistItemItemState();
}

class _RectanglePlaylistItemItemState extends State<RectanglePlaylistItemItem> {
  List<PopupMenuItem<int>> buildEndAction(BuildContext context) {
    return [
      PopupMenuItem(
        value: 0,
        child: Row(
          children: [
            const Icon(JwIcons.play),
            const SizedBox(width: 8),
            Text(i18n().action_playlist_end_continue),
          ],
        ),
      ),
      PopupMenuItem(
        value: 1,
        child: Row(
          children: [
            const Icon(Icons.square_outlined),
            const SizedBox(width: 8),
            Text(i18n().action_playlist_end_stop),
          ],
        ),
      ),
      PopupMenuItem(
        value: 2,
        child: Row(
          children: [
            const Icon(JwIcons.pause),
            const SizedBox(width: 8),
            Text(i18n().action_playlist_end_freeze),
          ],
        ),
      ),
      PopupMenuItem(
        value: 3,
        child: Row(
          children: [
            const Icon(JwIcons.arrows_loop),
            const SizedBox(width: 8),
            Text(i18n().label_repeat),
          ],
        ),
      ),
    ];
  }

  // Cette fonction détermine le bouton actuel affiché dans l'UI.
  Widget buildPopupMenuButton() {
    String label;
    IconData? icon;

    // Utiliser widget.item pour accéder à la propriété 'item'
    switch (widget.item.endAction) {
      case 0:
        label = i18n().action_playlist_end_continue;
        icon = JwIcons.play;
        break;
      case 1:
        label = i18n().action_playlist_end_stop;
        icon = Icons.square_outlined;
        break;
      case 2:
        label = i18n().action_playlist_end_freeze;
        icon = JwIcons.pause;
        break;
      case 3:
        label = i18n().label_repeat;
        icon = JwIcons.arrows_loop;
        break;
      default:
        label = i18n().action_playlist_end_continue;
        icon = JwIcons.play;
        break;
    }

    return PopupMenuButton<int>(
      useRootNavigator: true,
      itemBuilder: buildEndAction,
      onSelected: (int newValue) async {
        // Mettre à jour la valeur dans la base de données
        await JwLifeApp.userdata.updateEndActionPlaylistItem(widget.item, newValue);
        // 3. Appeler setState pour rafraîchir l'UI après la mise à jour
        setState(() {
        });
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
    // Utiliser widget.item
    PlaylistItem playlistItem = widget.item;

    Location? location = playlistItem.location;
    IndependentMedia? independentMedia = playlistItem.independentMedia;

    // Utilisation de la méthode d'extension `isNull()` non standard, je la laisse telle quelle
    if (location!.isNull() && independentMedia!.isNull()) {
      return Container();
    }

    // print(location); // Le print est conservé, mais l'utilisation de `location!` est risquée

    Media? media;
    bool isAudio = false;
    String title = playlistItem.label ?? '';

    // Il y a des problèmes potentiels d'opérateur de nullité `!`
    if (!location.isNull()) {
      final mediaItem = getMediaItem(
        playlistItem.location?.keySymbol,
        playlistItem.location?.track,
        playlistItem.location?.mepsDocumentId,
        playlistItem.location?.issueTagNumber,
        playlistItem.location?.mepsLanguageId,
        isVideo: playlistItem.location?.type != 2, // plus clair et inversé logiquement
      );

      if (mediaItem != null) {
        final mediaRepo = MediaRepository();
        final existingMedia = mediaRepo.getByCompositeKey(mediaItem);

        if (mediaItem.type == 'AUDIO') {
          media = existingMedia ?? Audio.fromJson(mediaItem: mediaItem);
        } else {
          media = existingMedia ?? Video.fromJson(mediaItem: mediaItem);
        }

        isAudio = media is Audio;
      }
    }
    else if(independentMedia == null) {
      return Container();
    }

    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
      child: InkWell(
        onTap: () async {
          showPlaylistPlayer(widget.items, startIndex: widget.items.indexOf(widget.item));
        },
        child: SizedBox(
          height: kItemHeight,
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: FutureBuilder<File?>(
                      future: widget.item.getThumbnailFile(),
                      builder: (context, snapshot) {
                        final placeholder = Container(
                          height: kItemHeight,
                          width: kItemHeight,
                          color: Colors.grey.shade300,
                        );

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return placeholder;
                        }

                        if (snapshot.hasError || snapshot.data == null) {
                          return Container(
                            height: kItemHeight,
                            width: kItemHeight,
                            color: Colors.grey,
                          );
                        }

                        return Image.file(
                          snapshot.data!,
                          height: kItemHeight,
                          width: kItemHeight,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6.0, end: 25.0, top: 3.0, bottom: 3.0),
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
                          // Le `buildPopupMenuButton` utilise maintenant `setState`
                          buildPopupMenuButton()
                        ],
                      ),
                    ),
                  )
                ],
              ),

              // Menu contextuel
              PositionedDirectional(
                  top: -10,
                  end: -5,
                  child: RepaintBoundary(
                    child: PopupMenuButton(
                      useRootNavigator: true,
                      icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry>[
                          PopupMenuItem(
                            child: Row(
                              children: [
                                const Icon(JwIcons.pencil),
                                const SizedBox(width: 8),
                                Text(i18n().action_rename),
                              ],
                            ),
                            onTap: () async {
                              TextEditingController controller = TextEditingController(text: widget.item.label);
                              showJwDialog(context: context,
                                titleText: i18n().action_rename,
                                content: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 25),
                                    child: TextField(
                                      controller: controller,
                                    ),
                                ),
                                buttons: [
                                  JwDialogButton(label: i18n().action_cancel_uppercase, closeDialog: true),
                                  JwDialogButton(label: i18n().action_rename_uppercase, closeDialog: false, onPressed: (buildContext) {
                                    Navigator.of(buildContext).pop();
                                    setState(() {
                                      widget.item.label = controller.text;
                                    });
                                    JwLifeApp.userdata.renamePlaylistItem(widget.item, controller.text);
                                  })
                                ]
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                const Icon(JwIcons.trash),
                                const SizedBox(width: 8),
                                Text(i18n().action_delete),
                              ],
                            ),
                            onTap: () async {
                              JwLifeApp.userdata.deletePlaylistItem(widget.item);
                              widget.onDelete(widget.item);
                            },
                          ),
                        ];

                        if (media == null && widget.item.independentMedia != null && widget.item.independentMedia!.filePath != null) {
                          items.add(
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(JwIcons.list_plus),
                                    SizedBox(width: 8),
                                    Text(i18n().action_add_to_playlist),
                                  ],
                                ),
                                onTap: () {
                                  showAddItemToPlaylistDialog(context, widget.item);
                                },
                              )
                          );
                        }

                        // S'assurer que media est un Video si vous appelez getVideoShareItem
                        if (media != null && media is Video) {
                          items.addAll([
                            if (media.isDownloadedNotifier.value && media.filePath != null) getVideoShareFileItem(media),
                            getVideoShareItem(media),
                            getVideoQrCode(context, media),
                            getVideoAddPlaylistItem(context, media),
                            getVideoLanguagesItem(context, media),
                            getVideoFavoriteItem(media),
                            getVideoDownloadItem(context, media),
                            getShowSubtitlesItem(context, media),
                            getCopySubtitlesItem(context, media),
                          ]);
                        }

                        // S'assurer que media est un Video si vous appelez getVideoShareItem
                        if (media != null && media is Audio) {
                          items.addAll([
                            if (media.isDownloadedNotifier.value && media.filePath != null) getAudioShareFileItem(media),
                            getAudioShareItem(media),
                            getAudioQrCode(context, media),
                            getAudioAddPlaylistItem(context, media),
                            getAudioLanguagesItem(context, media),
                            getAudioFavoriteItem(media),
                            getAudioDownloadItem(context, media),
                            getAudioLyricsItem(context, media),
                            getCopyLyricsItem(media),
                          ]);
                        }

                        return items;
                      },
                    ),
                  )
              ),

              if((widget.item.durationTicks != null && widget.item.durationTicks != 40000000) || widget.item.baseDurationTicks != null)
                PositionedDirectional(
                  top: 0,
                  start: 0,
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
                          // Utiliser widget.item
                          formatTick((widget.item.durationTicks != null && widget.item.durationTicks != 40000000) ? widget.item.durationTicks! : (widget.item.baseDurationTicks ?? 0)),
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}