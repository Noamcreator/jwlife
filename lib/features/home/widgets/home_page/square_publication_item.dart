import 'package:flutter/material.dart';

import '../../../../core/ui/app_dimens.dart';
import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_pub.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/repositories/PublicationRepository.dart';
import '../../../../i18n/i18n.dart';
import '../../../../widgets/image_cached_widget.dart';

class HomeSquarePublicationItem extends StatelessWidget {
  final Publication pub;
  final bool toolbox;

  const HomeSquarePublicationItem({super.key, required this.pub, this.toolbox = false});

  @override
  Widget build(BuildContext context) {
    // Récupérer la direction du texte actuelle
    final textDirection = pub.mepsLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final publication = PublicationRepository().getPublication(pub);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
        onTap: () {
          publication.showMenu(context, showDownloadDialog: false);
        },
        child: SizedBox(
            width: kSquareItemHeight,
            child: Directionality(
              textDirection: textDirection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // La colonne reste 'start' pour l'alignement
                children: [
                  Stack(
                    children: [
                      // 1. Image de fond (doit être le premier élément)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.0),
                        child: ImageCachedWidget(
                          imageUrl: publication.imageSqr,
                          icon: publication.category.icon,
                          height: kSquareItemHeight,
                          width: kSquareItemHeight,
                        ),
                      ),

                      // 2. Menu contextuel (Positionné en HAUT-FIN)
                      Positioned.directional(
                          textDirection: textDirection,
                          top: -13,
                          end: -8, // Utilise 'end' au lieu de 'right'
                          child: RepaintBoundary(
                              child: PopupMenuButton(
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                                ),
                                shadowColor: Colors.black,
                                elevation: 8,
                                // L'onTap du bouton EST prioritaire sur l'InkWell parent
                                onSelected: (value) {
                                  // Gérer la sélection du menu si nécessaire
                                },
                                itemBuilder: (context) => [
                                  getPubShareMenuItem(publication),
                                  getPubQrCodeMenuItem(context, publication),
                                  getPubLanguagesItem(context, i18n().label_languages_more, publication),
                                  getPubFavoriteItem(publication),
                                  getPubDownloadItem(context, publication),
                                ],
                              )
                          )
                      ),

                      // 3. Bouton dynamique (Positionné en BAS-FIN)
                      ValueListenableBuilder<bool>(
                        valueListenable: publication.isDownloadingNotifier,
                        builder: (context, isDownloading, _) {
                          if (isDownloading) {
                            return Positioned.directional(
                              textDirection: textDirection,
                              bottom: -4,
                              end: -8, // Utilise 'end' au lieu de 'right'
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                // IMPORTANT : Le onTap de l'IconButton EST prioritaire
                                onPressed: () {
                                  publication.cancelDownload(context);
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
                            valueListenable: publication.isDownloadedNotifier,
                            builder: (context, isDownloaded, _) {
                              if (!isDownloaded) {
                                // Icône de téléchargement
                                return Positioned.directional(
                                  textDirection: textDirection,
                                  bottom: -4,
                                  end: -5, // Utilise 'end' au lieu de 'right'
                                  height: 40,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      publication.download(context);
                                    },
                                    icon: const Icon(
                                      JwIcons.cloud_arrow_down,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                                    ),
                                  ),
                                );
                              }
                              else if (publication.hasUpdate()) {
                                // Icône de mise à jour
                                return Positioned.directional(
                                  textDirection: textDirection,
                                  bottom: -4,
                                  end: -5, // Utilise 'end' au lieu de 'right'
                                  height: 40,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      publication.download(context);
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
                                valueListenable: publication.isFavoriteNotifier,
                                builder: (context, isFavorite, _) {
                                  if (isFavorite) {
                                    // Icône de favori (étoile)
                                    return Positioned.directional(
                                      textDirection: textDirection,
                                      bottom: -4,
                                      end: 2, // Utilise 'end' au lieu de 'right'
                                      height: 40,
                                      // Utilisation d'un widget non-interactif (Icon)
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

                      // 4. Barre de progression (Positionnée en BAS-Départ/Fin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        height: 2,
                        width: 80,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: publication.isDownloadingNotifier,
                          builder: (context, isDownloading, _) {
                            if (!isDownloading) return const SizedBox.shrink();

                            return ValueListenableBuilder<double>(
                              valueListenable: publication.progressNotifier,
                              builder: (context, progress, _) {
                                return LinearProgressIndicator(
                                  value: progress == -1 ? null : progress,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                  backgroundColor: const Color(0xFFbdbdbd),
                                  minHeight: 2,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    child: Padding(
                      // 5. Utilisation de Padding.symmetric pour le texte
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Text(
                        publication.getShortTitle(),
                        style: Theme.of(context).extension<JwLifeThemeStyles>()!.squareTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                ],
              ),
            )
        ),
      )
    );
  }
}