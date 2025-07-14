import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/databases/Publication.dart';
import '../../../data/databases/PublicationRepository.dart';
import '../../../widgets/image_widget.dart';

class RectanglePublicationItem extends StatelessWidget {
  final Publication pub;

  const RectanglePublicationItem({super.key, required this.pub});

  @override
  Widget build(BuildContext context) {
    final publication = PublicationRepository().getPublication(pub);

    return GestureDetector(
      onTap: () => publication.showMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF292929)
              : Colors.white,
        ),
        child: SizedBox(
          height: 80,
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    child: ImageCachedWidget(
                      imageUrl: publication.imageSqr,
                      pathNoImage: publication.category.image,
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
                          if (publication.issueTitle.isNotEmpty)
                            Text(
                              publication.issueTitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFc3c3c3)
                                    : const Color(0xFF626262),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (publication.coverTitle.isNotEmpty)
                            Text(
                              publication.coverTitle,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty)
                            Text(
                              publication.title,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const Spacer(),
                          Text(
                            '${publication.year} - ${publication.symbol}',
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
                child: PopupMenuButton(
                  popUpAnimationStyle: AnimationStyle.lerp(
                    const AnimationStyle(curve: Curves.ease),
                    const AnimationStyle(curve: Curves.ease),
                    0.5,
                  ),
                  icon: const Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
                  itemBuilder: (context) => [
                    getPubShareMenuItem(publication),
                    getPubLanguagesItem(context, "Autres langues", publication),
                    getPubFavoriteItem(publication),
                    getPubDownloadItem(context, publication),
                  ],
                ),
              ),

              Stack(
                children: [
                  // Éléments dynamiques en fonction de l'état
                  ValueListenableBuilder<bool>(
                    valueListenable: publication.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (isDownloading) {
                        return Positioned(
                          bottom: -2,
                          right: -8,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => publication.cancelDownload(context),
                            icon: const Icon(JwIcons.x, color: Color(0xFF9d9d9d)),
                          ),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: publication.isDownloadedNotifier,
                        builder: (context, isDownloaded, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: publication.isFavoriteNotifier,
                            builder: (context, isFavorite, _) {
                              final hasUpdate = publication.hasUpdate();

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
                                        onPressed: () => publication.download(context),
                                        icon: const Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: -5,
                                      width: 50,
                                      child: Text(
                                        textAlign: TextAlign.center,
                                        formatFileSize(publication.expandedSize),
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
                                        onPressed: () => publication.update(context),
                                        icon: const Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: -5,
                                      width: 50,
                                      child: Text(
                                        textAlign: TextAlign.center,
                                        formatFileSize(publication.expandedSize),
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
                    valueListenable: publication.isDownloadingNotifier,
                    builder: (context, isDownloading, _) {
                      if (!isDownloading) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        height: 2,
                        width: 302,
                        child: ValueListenableBuilder<double>(
                          valueListenable: publication.progressNotifier,
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

