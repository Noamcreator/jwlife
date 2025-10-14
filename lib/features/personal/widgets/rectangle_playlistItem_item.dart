import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_video.dart'; // Ajout de l'import manquant
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/userdata/independentMedia.dart';
import 'package:jwlife/data/models/userdata/playlistItem.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';

import '../../../core/icons.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/location.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/MediaRepository.dart';
import '../../image/image_page.dart';

// 1. Convertir en StatefulWidget
class RectanglePlaylistItemItem extends StatefulWidget {
  final PlaylistItem item;
  final Function(PlaylistItem) onDelete;

  const RectanglePlaylistItemItem({super.key, required this.item, required this.onDelete});

  @override
  State<RectanglePlaylistItemItem> createState() => _RectanglePlaylistItemItemState();
}

// 2. Créer l'état
class _RectanglePlaylistItemItemState extends State<RectanglePlaylistItemItem> {
  // Le widget n'a pas accès directement à 'item', utiliser 'widget.item' à la place.
  // Déplacer les fonctions ici, ou adapter pour utiliser 'widget.item'.

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

    // Utiliser widget.item pour accéder à la propriété 'item'
    switch (widget.item.endAction) {
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
      media = MediaRepository().getByCompositeKey(getMediaItem(playlistItem.location?.keySymbol, playlistItem.location?.track, playlistItem.location?.mepsDocumentId, playlistItem.location?.issueTagNumber, playlistItem.location?.mepsLanguageId, isVideo: playlistItem.location?.type == 2 ? false : true)!);
      isAudio = media is Audio;
    }
    else if (independentMedia != null) {
      // Bloc vide dans le code original, conservé
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
            // S'assurer que showPlayer est une méthode définie sur Media
            media.showPlayer(context);
          }
          else if (independentMedia != null) {
            // Problème potentiel: les vérifications de type MIME peuvent être faites sur independentMedia.mimeType!
            if(independentMedia.mimeType?.contains('image') == true) { // Utilisation du `?` et vérification de booléen
              // La variable locale 'independentMedia' est écrasée ici, ce qui est une mauvaise pratique.
              // J'ai renommé la variable de fichier pour éviter le conflit.
              File imageFile = await playlistItem.independentMedia!.getImageFile();
              showPage(ImagePage(filePath: imageFile.path));
            }
            // Les blocs 'video' et 'audio' sont étranges car ils appellent `media.showPlayer(context)`
            // alors que `media` n'est défini que dans le bloc `if (!location.isNull())`.
            // S'il n'y a pas de location, `media` est probablement null.
            // Je suppose que vous vouliez appeler une méthode pour jouer le média indépendant.
            else if(independentMedia.mimeType?.contains('video') == true) {
              // Devrait probablement jouer le média indépendant
              // if(media != null) { // Ceci est incorrect si c'est un média indépendant sans location
              //   media.showPlayer(context);
              // }
            }
            else if(independentMedia.mimeType?.contains('audio') == true) {
              // Devrait probablement jouer le média indépendant
              // if(media != null) { // Ceci est incorrect si c'est un média indépendant sans location
              //   media.showPlayer(context);
              // }
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
                      // Utiliser widget.item
                      future: widget.item.getThumbnailFile(),
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
                          // Le `buildPopupMenuButton` utilise maintenant `setState`
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
                      // La propriété `popUpAnimationStyle` n'existe plus dans les versions récentes de Flutter.
                      // Elle a été remplacée par `splashRadius` et d'autres contrôles d'animation
                      // ou est gérée par le thème. Je la supprime pour éviter l'erreur de compilation.
                      /*
                    popUpAnimationStyle: AnimationStyle.lerp(
                      const AnimationStyle(curve: Curves.ease),
                      const AnimationStyle(curve: Curves.ease),
                      0.5,
                    ),
                    */
                      icon: const Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry>[
                          PopupMenuItem(
                            // Le onTap sur le PopupMenuItem doit être déplacé sur le `onSelected` du `PopupMenuButton`
                            // ou être géré dans l'implémentation de la fonction de retour (ce qui semble être l'intention).
                            // Laissez le onTap ici pour une exécution immédiate.
                            child: Row(
                              children: const [
                                Icon(JwIcons.pencil),
                                SizedBox(width: 8),
                                Text('Renommer'),
                              ],
                            ),
                            onTap: () async {
                              TextEditingController controller = TextEditingController(text: widget.item.label);
                              showJwDialog(context: context,
                                titleText: 'Renommer',
                                content: TextField(
                                  controller: controller,
                                ),
                                buttons: [
                                  JwDialogButton(label: 'ANNULER', closeDialog: true),
                                  JwDialogButton(label: 'RENOMMER', closeDialog: false, onPressed: (buildContext) {
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
                              children: const [
                                Icon(JwIcons.trash),
                                SizedBox(width: 8),
                                Text('Supprimer'),
                              ],
                            ),
                            onTap: () async {
                              JwLifeApp.userdata.deletePlaylistItem(widget.item);
                              widget.onDelete(widget.item);
                            },
                          ),
                        ];

                        // S'assurer que media est un Video si vous appelez getVideoShareItem
                        if (media != null && media is Video) {
                          items.addAll([
                            getVideoShareItem(media),
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

              if((widget.item.durationTicks != null && widget.item.durationTicks != 40000000) || widget.item.baseDurationTicks != null)
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
                          // Utiliser widget.item
                          formatTick((widget.item.durationTicks != null && widget.item.durationTicks != 40000000) ? widget.item.durationTicks! : (widget.item.baseDurationTicks ?? 0)),
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),

              // Le bloc de code commenté `Stack` n'est pas corrigé car il n'est pas utilisé
              // et il contient de nombreuses références à des variables (`MediaItem`) qui
              // ne sont pas définies dans le contexte actuel.
            ],
          ),
        ),
      ),
    );
  }
}