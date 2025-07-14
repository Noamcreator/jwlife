import 'package:flutter/material.dart';
import 'package:jwlife/data/databases/PublicationRepository.dart';

import '../../../core/icons.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/databases/Publication.dart';
import '../../../widgets/image_widget.dart';

class HomeRectanglePublicationItem extends StatelessWidget {
  final Publication pub;

  const HomeRectanglePublicationItem({super.key, required this.pub});

  @override
  Widget build(BuildContext context) {
    final publication = PublicationRepository().getPublication(pub);

    return GestureDetector(
      onTap: () {
        publication.showMenu(context);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF292929)
              : Colors.white,
        ),
        child: SizedBox(
          height: 85,
          width: 340,
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    child: ImageCachedWidget(
                      imageUrl: publication.imageSqr,
                      pathNoImage: publication.category.image,
                      height: 85,
                      width: 85,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7.0, right: 25.0, top: 4.0, bottom: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publication.issueTagNumber == 0
                                ? publication.category.getName(context)
                                : publication.issueTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFFc3c3c3)
                                  : Color(0xFF626262),
                            ),
                          ),
                          Text(
                            publication.issueTagNumber == 0
                                ? publication.title
                                : publication.coverTitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).secondaryHeaderColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            publication.getRelativeDateText(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFFc3c3c3)
                                  : Color(0xFF626262),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -5,
                right: -15,
                child: PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
                  itemBuilder: (context) => [
                    getPubShareMenuItem(publication),
                    getPubLanguagesItem(context, "Autres langues", publication),
                    getPubFavoriteItem(publication),
                    getPubDownloadItem(context, publication),
                  ],
                ),
              ),

              /// -- Téléchargement / MAJ / Cancel bouton
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
                        icon: Icon(JwIcons.x, color: Color(0xFF9d9d9d)),
                      ),
                    );
                  } else if (publication.hasUpdate()) {
                    return Positioned(
                      bottom: 5,
                      right: -8,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => publication.update(context),
                        icon: Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
                      ),
                    );
                  } else {
                    return ValueListenableBuilder<bool>(
                      valueListenable: publication.isDownloadedNotifier,
                      builder: (context, isDownloaded, _) {
                        return !isDownloaded
                            ? Positioned(
                          bottom: 5,
                          right: -8,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => publication.download(context),
                            icon: Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
                          ),
                        )
                            : SizedBox.shrink();
                      },
                    );
                  }
                },
              ),

              /// -- Affichage de la taille du fichier si non téléchargé ou mise à jour dispo
              ValueListenableBuilder<bool>(
                valueListenable: publication.isDownloadingNotifier,
                builder: (context, isDownloading, _) {
                  if (isDownloading) return SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: publication.isDownloadedNotifier,
                    builder: (context, isDownloaded, _) {
                      if (!isDownloaded || publication.hasUpdate()) {
                        return Positioned(
                          bottom: 0,
                          right: -5,
                          width: 50,
                          child: Text(
                            formatFileSize(publication.expandedSize),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFFc3c3c3)
                                  : Color(0xFF626262),
                            ),
                          ),
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    },
                  );
                },
              ),

              /// -- Progress bar
              ValueListenableBuilder<bool>(
                valueListenable: publication.isDownloadingNotifier,
                builder: (context, isDownloading, _) {
                  return isDownloading
                      ? Positioned(
                    bottom: 0,
                    right: 0,
                    height: 2,
                    width: 340 - 85,
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
                  )
                      : SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
