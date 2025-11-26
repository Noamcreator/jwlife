import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Pour formatDateTime
import '../../../core/utils/utils_audio.dart'; // Fonctions de menu Audio
import '../../../core/utils/utils_video.dart'; // Fonctions de menu Video
import '../../../data/models/media.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/MediaRepository.dart';
import '../../../widgets/image_cached_widget.dart';

class RectangleMediaItemItem extends StatelessWidget {
  final Media media;
  final Color? backgroundColor;
  final double height; // Rendre la hauteur modifiable, mais garder 80 par défaut

  const RectangleMediaItemItem({
    super.key,
    required this.media,
    this.backgroundColor,
    this.height = kItemHeight,
  });

  // Utilise le MediaRepository pour récupérer l'objet Media (comme dans l'original)
  Media get _m => MediaRepository().getMedia(media);

  // --- Fonctions d'extraction basées sur RectanglePublicationItem ---

  // Extrait la logique de la barre de progression
  Widget _buildProgressBar(double leftOffset) {
    return ValueListenableBuilder<bool>(
      valueListenable: media.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading
            ? Positioned(
          bottom: 0,
          right: 0,
          left: leftOffset, // Décalage basé sur la taille de l'image
          height: 2,
          child: ValueListenableBuilder<double>(
            valueListenable: media.progressNotifier,
            builder: (context, progress, _) {
              return LinearProgressIndicator(
                value: progress == -1 ? null : progress,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                backgroundColor: const Color(0xFFbdbdbd),
                minHeight: 2,
              );
            },
          ),
        ) : const SizedBox.shrink();
      },
    );
  }

  // Extrait la logique du bouton dynamique (Téléchargement, Annuler, Mise à jour, Favori)
  Widget _buildDynamicButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: media.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        // --- 1. Mode Téléchargement en cours (Annuler) ---
        if (isDownloading) {
          return Positioned(
            bottom: -4,
            right: -8,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => media.cancelDownload(context),
              icon: const Icon(
                JwIcons.x,
                color: Color(0xFF9d9d9d),
              ),
            ),
          );
        }

        // --- 2. Mode Non Téléchargé / Mise à jour requise ---
        return ValueListenableBuilder<bool>(
          valueListenable: media.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded || media.hasUpdate()) {
              return Positioned(
                bottom: 0,
                right: -5,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (media.hasUpdate()) {
                      //media.update(context);
                    }
                    else {
                      final RenderBox renderBox = context.findRenderObject() as RenderBox;
                      final Offset tapPosition = renderBox.localToGlobal(Offset.zero) + renderBox.size.center(Offset.zero);

                      media.download(context, tapPosition: tapPosition);
                    }
                  },
                  icon: Icon(
                    media.hasUpdate() ? JwIcons.arrows_circular : JwIcons.cloud_arrow_down,
                    size: media.hasUpdate() ? 20 : 24,
                    color: const Color(0xFF9d9d9d),
                  ),
                ),
              );
            }

            // --- 3. Mode Téléchargé (Afficher Favori si besoin) ---
            return ValueListenableBuilder<bool>(
              valueListenable: media.isFavoriteNotifier,
              builder: (context, isFavorite, _) {
                if (isFavorite) {
                  return const Positioned(
                    bottom: -4,
                    right: 2,
                    height: 40,
                    child: Icon(
                      JwIcons.star, // Assurez-vous que JwIcons.star existe ou utilisez Icons.star
                      color: Color(0xFF9d9d9d),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            );
          },
        );
      },
    );
  }

  // Extrait le menu contextuel (const)
  Widget _buildPopupMenu(BuildContext context) {
    return Positioned(
      top: -13,
      right: -7,
      child: RepaintBoundary(
        child: PopupMenuButton(
          popUpAnimationStyle: AnimationStyle.lerp(
            const AnimationStyle(curve: Curves.ease),
            const AnimationStyle(curve: Curves.ease),
            0.5,
          ),
          icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
          itemBuilder: (context) => _m is Audio
              ? [
            getAudioShareItem(_m as Audio),
            getAudioAddPlaylistItem(context, _m as Audio),
            getAudioLanguagesItem(context, _m as Audio),
            getAudioFavoriteItem(_m as Audio),
            getAudioDownloadItem(context, _m as Audio),
            getAudioLyricsItem(context, _m as Audio),
            getCopyLyricsItem(_m as Audio)
          ]
              : _m is Video
              ? [
            getVideoShareItem(_m as Video),
            getVideoAddPlaylistItem(context, _m as Video),
            getVideoLanguagesItem(context, _m as Video),
            getVideoFavoriteItem(_m as Video),
            getVideoDownloadItem(context, _m as Video),
            getShowSubtitlesItem(context, _m as Video),
            getCopySubtitlesItem(context, _m as Video),
          ]
              : [],
        ),
      ),
    );
  }

  // --- Fin des fonctions d'extraction ---

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Media m = _m; // Alias pour l'objet media résolu

    // Simplifie le calcul de la couleur de fond
    final Color itemBackgroundColor = backgroundColor ?? (isDarkMode ? const Color(0xFF292929) : Colors.white);
    final Color subtitleColor = isDarkMode ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () => m.showPlayer(context),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              // --- Contenu principal (Image + Texte) ---
              Row(
                children: [
                  SizedBox(
                    height: height,
                    width: height,
                    child: ClipRRect(
                      // Suppression du borderRadius pour imiter le design RectanglePublicationItem
                      child: ImageCachedWidget(
                        imageUrl: m.networkImageSqr,
                        icon: m is Audio ? JwIcons.headphones__simple : JwIcons.video,
                        height: height,
                        width: height,
                      ),
                    ),
                  ),
                  // Texte
                  Expanded(
                    child: Padding(
                      // Ajustement des paddings
                      padding: const EdgeInsets.only(left: 6.0, right: 25.0, top: 4.0, bottom: 2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre (toujours affiché)
                          Text(
                            m.title,
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 14,
                              color: Theme.of(context).secondaryHeaderColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          // Date + keySymbol
                          Text(
                            '${formatDateTime(m.lastModified ?? m.firstPublished!).year} - ${m.keySymbol}',
                            style: TextStyle(fontSize: 11, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // --- Éléments Positionnés ---

              // Affichage de la durée (comme le bandeau de l'original)
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

              // Menu contextuel
              _buildPopupMenu(context),

              // Bouton dynamique
              _buildDynamicButton(),

              // Barre de progression
              _buildProgressBar(height), // Utilise le paramètre height pour le décalage
            ],
          ),
        ),
      ),
    );
  }
}