import 'package:flutter/material.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/databases/Publication.dart';
import '../../../data/databases/PublicationRepository.dart';
import '../../../widgets/image_widget.dart';

class HomeSquarePublicationItem extends StatelessWidget {
  final Publication pub;

  const HomeSquarePublicationItem({super.key, required this.pub});

  @override
  Widget build(BuildContext context) {
    final publication = PublicationRepository().getPublication(pub);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  publication.showMenu(context);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: ImageCachedWidget(
                    imageUrl: publication.imageSqr,
                    pathNoImage: publication.category.image,
                    height: 80,
                    width: 80,
                  ),
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

              // Bouton dynamique (cancel / update / download)
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
                      final isInFavorites = JwLifeApp.userdata.favorites.any((fav) => fav == publication);
                      final hasUpdate = isInFavorites &&
                          JwLifeApp.userdata.favorites.firstWhere((fav) => fav == publication).hasUpdate();

                      if (hasUpdate) {
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
                      } else if (!isDownloaded) {
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
                      } else {
                        return const SizedBox.shrink();
                      }
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
          const SizedBox(height: 2),
          SizedBox(
            width: 75,
            child: Text(
              publication.title,
              style: const TextStyle(fontSize: 9.0, height: 1.2),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}