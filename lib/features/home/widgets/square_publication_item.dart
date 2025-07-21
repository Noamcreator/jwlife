import 'package:flutter/material.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/models/publication.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../widgets/image_cached_widget.dart';

class HomeSquarePublicationItem extends StatelessWidget {
  final Publication pub;

  const HomeSquarePublicationItem({super.key, required this.pub});

  @override
  Widget build(BuildContext context) {
    final publication = PublicationRepository().getPublication(pub);

    return InkWell(
      onTap: () {
        publication.showMenu(context);
      },
      child: SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: ImageCachedWidget(
                    imageUrl: publication.imageSqr,
                    pathNoImage: publication.category.image,
                    height: 80,
                    width: 80,
                  ),
                ),
                // Menu contextuel
                Positioned(
                  top: -8,
                  right: -10,
                  child: PopupMenuButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                    shadowColor: Colors.black,
                    elevation: 8,
                    itemBuilder: (context) => [
                      getPubShareMenuItem(publication),
                      getPubLanguagesItem(context, "Autres langues", publication),
                      getPubFavoriteItem(publication),
                      getPubDownloadItem(context, publication),
                    ],
                  ),
                ),
                // Bouton dynamique
                ValueListenableBuilder<bool>(
                  valueListenable: publication.isDownloadingNotifier,
                  builder: (context, isDownloading, _) {
                    if (isDownloading) {
                      return Positioned(
                        bottom: -4,
                        right: -8,
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
                          return Positioned(
                            bottom: -4,
                            right: -8,
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
                          return Positioned(
                            bottom: -4,
                            right: -8,
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
                              return Positioned(
                                bottom: -4,
                                right: 2,
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
                // Barre de progression
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
                            backgroundColor: Colors.grey,
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
                padding: const EdgeInsets.only(left: 2.0, right: 4.0),
                child: Text(
                  publication.getTitle(),
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w100,
                    fontFamily: 'Roboto',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  softWrap: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}