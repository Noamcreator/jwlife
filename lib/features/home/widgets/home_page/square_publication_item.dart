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
  final Publication publication;
  final bool toolbox;
  final bool favorite;

  const HomeSquarePublicationItem({super.key, required this.publication, this.toolbox = false, this.favorite = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
        onTap: () {
          publication.showMenu(context, showDownloadDialog: false);
        },
        child: SizedBox(
            width: kSquareItemHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // La colonne reste 'start' pour l'alignement
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.0),
                      child: ImageCachedWidget(
                        imageUrl: publication.imageSqr,
                        icon: publication.category.icon,
                        height: kSquareItemHeight,
                        width: kSquareItemHeight,
                      ),
                    ),

                    PositionedDirectional(
                        top: -13,
                        end: -8,
                        child: RepaintBoundary(
                            child: PopupMenuButton(
                              useRootNavigator: true,
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

                    ValueListenableBuilder<bool>(
                      valueListenable: publication.isDownloadingNotifier,
                      builder: (context, isDownloading, _) {
                        if (isDownloading) {
                          return PositionedDirectional(
                            bottom: -4,
                            end: -8,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
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
                              return PositionedDirectional(
                                bottom: -4,
                                end: -5,
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
                              return PositionedDirectional(
                                bottom: -4,
                                end: -5,
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
                                if (isFavorite && !favorite) {
                                  // Icône de favori (étoile)
                                  return PositionedDirectional(
                                    bottom: -4,
                                    end: 2,
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

                    // 4. Barre de progression (Positionnée en BAS-Départ/Fin)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
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
            )
        ),
      )
    );
  }
}