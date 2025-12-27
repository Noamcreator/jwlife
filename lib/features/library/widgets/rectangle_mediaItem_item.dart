import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Pour formatDateTime
import '../../../core/utils/utils_audio.dart'; // Fonctions de menu Audio
import '../../../core/utils/utils_video.dart'; // Fonctions de menu Video
import '../../../data/models/media.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/video.dart';
import '../../../widgets/image_cached_widget.dart';

class RectangleMediaItemItem extends StatelessWidget {
  final Media media;
  final Color? backgroundColor;
  final double height;
  final bool searchWidget;

  const RectangleMediaItemItem({
    super.key,
    required this.media,
    this.backgroundColor,
    this.height = kSquareItemHeight,
    this.searchWidget = false
  });

  // Extrait la logique de la barre de progression
  Widget _buildProgressBar(double leftOffset) {
    return ValueListenableBuilder<bool>(
      valueListenable: media.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading
            ? PositionedDirectional(
          bottom: 0,
          end: 0,
          start: leftOffset, // Décalage basé sur la taille de l'image
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
          return PositionedDirectional(
            bottom: -4,
            end: -8,
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
              return PositionedDirectional(
                bottom: 0,
                end: -5,
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
                  return const PositionedDirectional(
                    bottom: -4,
                    end: 2,
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
    return PositionedDirectional(
      top: -13,
      end: -7,
      child: RepaintBoundary(
        child: PopupMenuButton(
          useRootNavigator: true,
          popUpAnimationStyle: AnimationStyle.lerp(
            const AnimationStyle(curve: Curves.ease),
            const AnimationStyle(curve: Curves.ease),
            0.5,
          ),
          icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
          itemBuilder: (context) => media is Audio
              ? [
            getAudioShareItem(media as Audio),
            getAudioAddPlaylistItem(context, media as Audio),
            getAudioLanguagesItem(context, media as Audio),
            getAudioFavoriteItem(media as Audio),
            getAudioDownloadItem(context, media as Audio),
            getAudioLyricsItem(context, media as Audio),
            getCopyLyricsItem(media as Audio)
          ]
              : media is Video
              ? [
            getVideoShareItem(media as Video),
            getVideoQrCode(context, media as Video),
            getVideoAddPlaylistItem(context, media as Video),
            getVideoLanguagesItem(context, media as Video),
            getVideoFavoriteItem(media as Video),
            getVideoDownloadItem(context, media as Video),
            getShowSubtitlesItem(context, media as Video),
            getCopySubtitlesItem(context, media as Video),
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

    // Simplifie le calcul de la couleur de fond
    final Color itemBackgroundColor = backgroundColor ?? (isDarkMode ? const Color(0xFF292929) : Colors.white);
    final Color subtitleColor = isDarkMode ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () => media.showPlayer(context),
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
                        imageUrl: media.networkImageSqr,
                        icon: media is Audio ? JwIcons.headphones__simple : JwIcons.video,
                        height: height,
                        width: height,
                      ),
                    ),
                  ),
                  // Texte
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                          start: 6.0,
                          end: 25.0,
                          top: searchWidget ? 2.0 : 4.0,
                          bottom: 2.0
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if(searchWidget)
                            Text(
                              media.getCategoryName(),
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          Text(
                            media.title,
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 14,
                              color: Theme.of(context).secondaryHeaderColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            '${formatYear(formatDateTime(media.lastModified ?? media.firstPublished.toString()).year)} · ${media.keySymbol}',
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
              PositionedDirectional(
                top: 0,
                start: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                  child: Row(
                    children: [
                      Icon(
                        media is Audio ? JwIcons.headphones__simple : JwIcons.play,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDuration(media.duration),
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