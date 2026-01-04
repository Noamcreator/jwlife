import 'package:flutter/material.dart';

import '../../../../core/ui/app_dimens.dart';
import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_pub.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';
import '../../../../widgets/image_cached_widget.dart';
import '../../../../widgets/multiple_listenable_builder_widget.dart';


class HomeSquarePublicationItem extends StatelessWidget {
  final Publication publication;
  final bool toolbox;
  final bool favorite;

  const HomeSquarePublicationItem({super.key, required this.publication, this.toolbox = false, this.favorite = false});

  Widget _buildPopupMenu() {
    return PositionedDirectional(
        top: -13,
        end: -8,
        child: RepaintBoundary(
            child: PopupMenuButton(
              useRootNavigator: true,
              popUpAnimationStyle: AnimationStyle.lerp(
                const AnimationStyle(curve: Curves.ease),
                const AnimationStyle(curve: Curves.ease),
                0.5,
              ),
              icon: const Icon(Icons.more_horiz, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
              shadowColor: Colors.black,
              elevation: 8,
              itemBuilder: (context) => [
                getPubShareMenuItem(publication),
                getPubQrCodeMenuItem(context, publication),
                getPubLanguagesItem(context, i18n().label_languages_more, publication),
                getPubFavoriteItem(publication),
                getPubDownloadItem(context, publication),
              ],
            )
        )
    );
  }

  Widget _buildDynamicButton() {
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

        // --- 1. CAS : TÉLÉCHARGEMENT EN COURS ---
        if (isDownloading) {
          return PositionedDirectional(
            bottom: -4,
            end: -8,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => publication.cancelDownload(),
              icon: const Icon(
                JwIcons.x,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
          );
        }

        // --- 2. CAS : NON TÉLÉCHARGÉ OU MISE À JOUR DISPONIBLE (OU SHOWSIZE) ---
        if (!isDownloaded || hasUpdate) {
          return PositionedDirectional(
            bottom: -4,
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
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
          );
        }

        // --- 3. CAS : TÉLÉCHARGÉ (AFFICHAGE FAVORI) ---
        if (isFavorite && !favorite) {
          return const PositionedDirectional(
            bottom: -4,
            end: 2,
            height: 40,
            child: Icon(
              JwIcons.star,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          );
        }

        // Par défaut, rien
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading ? PositionedDirectional(
          bottom: 0,
          end: 0,
          height: 2,
          width: kItemHeight,
          child: ValueListenableBuilder<bool>(
            valueListenable: publication.isDownloadingNotifier,
            builder: (context, isDownloading, _) {
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
        ) : const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => publication.showMenu(context, showDownloadDialog: false),
        child: SizedBox(
            width: kItemHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.0),
                      child: ImageCachedWidget(
                        imageUrl: publication.imageSqr,
                        icon: publication.category.icon,
                        height: kItemHeight,
                        width: kItemHeight,
                      ),
                    ),

                    _buildPopupMenu(),

                    _buildDynamicButton(),

                    _buildProgressBar(),
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