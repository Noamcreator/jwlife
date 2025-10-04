import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/models/publication.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../widgets/image_cached_widget.dart';

class RectanglePublicationItem extends StatelessWidget {
  final Publication publication;
  final Color? backgroundColor;

  const RectanglePublicationItem({super.key, required this.publication, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Material(
        color: backgroundColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white),
        child: InkWell(
            onTap: () => publication.showMenu(context),
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
                            padding: EdgeInsets.only(left: 6.0, right: 25.0, top: publication.issueTitle.isNotEmpty ? 2.0 : 4.0, bottom: 2.0),
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
                                    style: TextStyle(
                                      height: 1.2,
                                      fontSize: 14,
                                      color: Theme.of(context).secondaryHeaderColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty)
                                  Text(
                                    publication.title,
                                    style: TextStyle(
                                      height: 1.2,
                                      fontSize: 14.5,
                                      color: Theme.of(context).secondaryHeaderColor,
                                    ),
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
                      child: RepaintBoundary(
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
                        )
                      )
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
                                color: Color(0xFF9d9d9d),
                              ),
                            ),
                          );
                        }

                        return ValueListenableBuilder<bool>(
                          valueListenable: publication.isDownloadedNotifier,
                          builder: (context, isDownloaded, _) {
                            if (!isDownloaded || publication.hasUpdate()) {
                              return Stack(
                                children: [
                                  // Icône de téléchargement
                                  Positioned(
                                    bottom: 3,
                                    right: -10,
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
                                        color: Color(0xFF9d9d9d),
                                      ),
                                    ),
                                  ),
                                  // Texte sous l'icône
                                  Positioned(
                                    bottom: 0,
                                    right: 2,
                                    child: Text(
                                      formatFileSize(publication.size),
                                      style: TextStyle(
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
                                  return Positioned(
                                    bottom: -4,
                                    right: 2,
                                    height: 40,
                                    child: const Icon(
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
                    ),

                    // Barre de progression
                    ValueListenableBuilder<bool>(
                      valueListenable: publication.isDownloadingNotifier,
                      builder: (context, isDownloading, _) {
                        return isDownloading
                            ? Positioned(
                          bottom: 0,
                          right: 0,
                          height: 2,
                          width: MediaQuery.of(context).size.width - 20 - 80,
                          child: ValueListenableBuilder<double>(
                            valueListenable: publication.progressNotifier,
                            builder: (context, progress, _) {
                              return LinearProgressIndicator(
                                value: progress == -1 ? null : progress,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                                backgroundColor: Color(0xFFbdbdbd),
                                minHeight: 2,
                              );
                            },
                          ),
                        ) : const SizedBox.shrink();
                      },
                    ),
                  ],
                )
            )
        )
    );
  }
}

