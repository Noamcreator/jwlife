import 'package:flutter/material.dart';

import '../../../../core/icons.dart';
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

    return Directionality(
        textDirection: textDirection,
        child: InkWell(
          onTap: () {
            publication.showMenu(context, showDownloadDialog: false);
          },
          child: SizedBox(
            width: 80,
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
                        height: 80,
                        width: 80,
                      ),
                    ),
                    // 1. Menu contextuel (Positionné en HAUT-FIN)
                    Positioned.directional(
                        textDirection: textDirection,
                        top: -15,
                        end: -10, // Utilise 'end' au lieu de 'right'
                        child: RepaintBoundary(
                            child: PopupMenuButton(
                              icon: const Icon(
                                Icons.more_horiz,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                              ),
                              shadowColor: Colors.black,
                              elevation: 8,
                              itemBuilder: (context) => [
                                getPubShareMenuItem(publication),
                                getPubLanguagesItem(context, i18n().label_languages_more, publication),
                                getPubFavoriteItem(publication),
                                getPubDownloadItem(context, publication),
                              ],
                            )
                        )
                    ),

                    // 2. Bouton dynamique (Positionné en BAS-FIN)
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
                                end: -8, // Utilise 'end' au lieu de 'right'
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
                                end: -8, // Utilise 'end' au lieu de 'right'
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
                    // 3. Barre de progression (Positionnée en BAS-Départ/Fin)
                    Positioned(
                      bottom: 0,
                      // Garder right et left à 0 ou mieux, utiliser Positioned.directional
                      // Ici, 'width: 80' garantit qu'elle couvre la zone, donc left:0, right:0 est aussi une option si width était à null.
                      // Avec width: 80, on garde right: 0 (ou left: 0)
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
                    // 4. Utilisation de Padding.symmetric pour le texte
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      publication.getShortTitle(),
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w100,
                        fontFamily: 'Roboto',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      // Aligner le texte au début de la direction
                      textAlign: TextAlign.start,
                      softWrap: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }
}