import 'package:flutter/material.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';

import '../../../../core/ui/app_dimens.dart';
import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_pub.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';
import '../../../../widgets/image_cached_widget.dart';

class HomeRectanglePublicationItem extends StatelessWidget {
  final Publication pub;

  const HomeRectanglePublicationItem({super.key, required this.pub});

  // Décalage de l'image (80px) pour positionner la barre de progression
  static const double _imageSize = 80.0;
  // Largeur totale de l'item (utilisée pour le calcul de la barre de progression)
  static const double _itemWidth = 320.0;
  // Largeur de la barre de progression (Largeur totale - Taille de l'image)
  static const double _progressBarWidth = _itemWidth - _imageSize;


  // 🔵 Barre de progression compatible RTL
  Widget _buildProgressBar(BuildContext context, Publication publication) {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        // La barre doit commencer APRES l'image et aller jusqu'à la FIN.
        return isDownloading
            ? PositionedDirectional(
          bottom: 0,
          start: _imageSize, // Débute à 80px (après l'image)
          end: 0, // Va jusqu'à la fin de la Stack (320px)
          height: 2,
          // Nous n'utilisons plus 'width: 320 - 80 - 1' car 'start: 80, end: 0' le gère
          child: ValueListenableBuilder<double>(
            valueListenable: publication.progressNotifier,
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
        )
            : const SizedBox.shrink();
      },
    );
  }

  // 🔵 Bouton dynamique compatible RTL
  Widget _buildDynamicButton(Publication publication) {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        if (isDownloading) {
          // Annuler le téléchargement (Positionné en BAS-FIN)
          return PositionedDirectional(
            bottom: -4,
            end: -5, // Utilisé au lieu de 'right'
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                publication.cancelDownload(context);
              },
              icon: const Icon(
                JwIcons.x,
                color: Color(0xFF9d9d9d),
              ),
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: publication.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded || publication.hasUpdate()) {
              // Téléchargement/Mise à jour (Positionné en BAS-FIN)
              return Stack(
                children: [
                  // Icône de téléchargement
                  PositionedDirectional(
                    bottom: 3,
                    end: -5, // Utilisé au lieu de 'right'
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (publication.hasUpdate()) {
                          publication.update(context);
                        }
                        else {
                          publication.download(context);
                        }
                      },
                      icon: Icon(
                        publication.hasUpdate() ? JwIcons.arrows_circular : JwIcons.cloud_arrow_down,
                        size: publication.hasUpdate() ? 20 : 24,
                        color: const Color(0xFF9d9d9d),
                      ),
                    ),
                  ),
                  // Texte sous l'icône (Positionné en BAS-FIN)
                  PositionedDirectional(
                    bottom: 0,
                    end: 4, // Utilisé au lieu de 'right'
                    child: Text(
                      formatFileSize(publication.size),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9d9d9d),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: publication.isFavoriteNotifier,
              builder: (context, isFavorite, _) {
                if (isFavorite) {
                  // Favori (Positionné en BAS-FIN)
                  return const PositionedDirectional(
                    bottom: -4,
                    end: 2, // Utilisé au lieu de 'right'
                    height: 40,
                    child: Icon(
                      JwIcons.star,
                      color: Color(0xFF9d9d9d),
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
    );
  }

  // 🔵 Menu contextuel compatible RTL
  Widget _buildPopupMenu(Publication publication) {
    // Menu (Positionné en HAUT-FIN)
    return PositionedDirectional(
      top: -13,
      end: -7, // Utilisé au lieu de 'right'
      child: RepaintBoundary(
        child: PopupMenuButton(
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF9d9d9d)),
          itemBuilder: (context) => [
            getPubShareMenuItem(publication),
            getPubQrCodeMenuItem(context, publication),
            getPubLanguagesItem(context, i18n().label_languages_more, publication),
            getPubFavoriteItem(publication),
            getPubDownloadItem(context, publication),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final publication = PublicationRepository().getPublication(pub);

    return Material(
      color: Theme.of(context).extension<JwLifeThemeStyles>()!.containerColor,
      child: InkWell(
        onTap: () => publication.showMenu(context, showDownloadDialog: false),
        child: SizedBox(
          height: kSquareItemHeight,
          width: 320,
          child: Stack(
            children: [
              Row(
                // La Row gère la direction (Image à gauche en LTR, à droite en RTL) par défaut.
                children: [
                  ClipRRect(
                    child: ImageCachedWidget(
                      imageUrl: publication.imageSqr,
                      icon: publication.category.icon,
                      height: kSquareItemHeight,
                      width: kSquareItemHeight,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6.0, end: 25.0, top: 4.0, bottom: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publication.issueTagNumber == 0 ? publication.category.getName() : publication.issueTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // *** AMÉLIORATION RTL: Ajouter TextAlign.start ***
                            textAlign: TextAlign.start,
                            style: Theme.of(context).extension<JwLifeThemeStyles>()!.rectanglePublicationContext
                          ),
                          Text(
                            publication.issueTagNumber == 0 ? publication.title : publication.coverTitle,
                            style: Theme.of(context).extension<JwLifeThemeStyles>()!.rectanglePublicationTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                          ),
                          const Spacer(),
                          Text(
                            publication.getRelativeDateText(),
                            style: Theme.of(context).extension<JwLifeThemeStyles>()!.rectanglePublicationSubtitle,
                            textAlign: TextAlign.start,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Menu (Utilise _buildPopupMenu avec PositionedDirectional)
              _buildPopupMenu(publication),

              // Bouton dynamique (Utilise _buildDynamicButton avec PositionedDirectional)
              _buildDynamicButton(publication),

              // Barre de progression (Utilise _buildProgressBar avec PositionedDirectional)
              _buildProgressBar(context, publication),
            ],
          ),
        ),
      ),
    );
  }
}