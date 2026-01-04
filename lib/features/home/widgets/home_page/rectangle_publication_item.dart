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
import '../../../../widgets/multiple_listenable_builder_widget.dart';
import '../../../library/pages/downloads/downloads_widget.dart';

class HomeRectanglePublicationItem extends StatelessWidget {
  final Publication pub;

  const HomeRectanglePublicationItem({super.key, required this.pub});

  Widget _buildDynamicButton(Publication publication) {
    return MultiValueListenableBuilder(
      listenables: [
        publication.isDownloadingNotifier,
        publication.isDownloadedNotifier,
        publication.hasUpdateNotifier,
        publication.isFavoriteNotifier,
      ],
      builder: (context) {
        final bool isDownloading = publication.isDownloadingNotifier.value;
        final bool isDownloaded = publication.isDownloadedNotifier.value;
        final bool hasUpdate = publication.hasUpdateNotifier.value;
        final bool isFavorite = publication.isFavoriteNotifier.value;

        // 1. CAS : TÉLÉCHARGEMENT EN COURS
        if (isDownloading) {
          return PositionedDirectional(
            bottom: -4,
            end: -5,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => publication.cancelDownload(),
              icon: const Icon(
                JwIcons.x,
                color: Color(0xFF9d9d9d),
              ),
            ),
          );
        }

        // 2. CAS : NON TÉLÉCHARGÉ OU MISE À JOUR DISPONIBLE
        if (!isDownloaded || hasUpdate) {
          return Stack(
            children: [
              PositionedDirectional(
                bottom: 3,
                end: -5,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (hasUpdate) {
                      publication.update(context);
                    } else {
                      publication.download(context);
                    }
                  },
                  icon: Icon(
                    hasUpdate ? JwIcons.arrows_circular : JwIcons.cloud_arrow_down,
                    size: hasUpdate ? 20 : 24,
                    color: const Color(0xFF9d9d9d),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 2,
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

        // 3. CAS : TÉLÉCHARGÉ (AFFICHAGE FAVORI)
        if (isFavorite) {
          return const PositionedDirectional(
            bottom: -4,
            end: 2,
            height: 40,
            child: Icon(
              JwIcons.star,
              color: Color(0xFF9d9d9d),
              size: 22,
            ),
          );
        }

        // 4. RIEN À AFFICHER
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPopupMenu(Publication publication) {
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

  Widget _buildProgressBar(BuildContext context, Publication publication) {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading ? PositionedDirectional(
          bottom: 0,
          start: kItemHeight,
          end: 0,
          height: 2,
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
        ) : const SizedBox.shrink();
      },
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
          height: kItemHeight,
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
                      height: kItemHeight,
                      width: kItemHeight,
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