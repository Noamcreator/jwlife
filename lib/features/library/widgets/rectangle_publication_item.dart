import 'package:flutter/material.dart';

import '../../../core/ui/app_dimens.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/models/publication.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/image_cached_widget.dart';
import '../../../widgets/multiple_listenable_builder_widget.dart';

class RectanglePublicationItem extends StatelessWidget {
  final Publication publication;
  final Color? backgroundColor;
  final double height;
  final bool searchWidget;
  final bool refreshPendingUpdateTab;
  final bool showSize;

  const RectanglePublicationItem({
    super.key,
    required this.publication,
    this.backgroundColor,
    this.height = kItemHeight,
    this.searchWidget = false,
    this.refreshPendingUpdateTab = false,
    this.showSize = false
  });

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
            end: -5,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => publication.cancelDownload(),
              icon: const Icon(
                JwIcons.x,
                color: Color(0xFF9d9d9d),
                size: 20,
              ),
            ),
          );
        }

        // --- 2. CAS : NON TÉLÉCHARGÉ OU MISE À JOUR DISPONIBLE (OU SHOWSIZE) ---
        if (!isDownloaded || hasUpdate || showSize) {
          return Stack(
            children: [
              // Bouton Action (Download ou Update)
              if (!showSize || hasUpdate)
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
              // Affichage de la taille
              PositionedDirectional(
                bottom: hasUpdate ? 0 : (showSize ? 2 : 0),
                end: 2,
                child: Text(
                  formatFileSize(hasUpdate
                      ? publication.size
                      : (showSize ? publication.expandedSize : publication.size)),
                  style: TextStyle(
                    fontSize: hasUpdate ? 10 : (showSize ? 12 : 10),
                    color: const Color(0xFF9d9d9d),
                  ),
                ),
              ),
            ],
          );
        }

        // --- 3. CAS : TÉLÉCHARGÉ (AFFICHAGE FAVORI) ---
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

        // Par défaut, rien
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPopupMenu() {
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
          icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
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

  Widget _buildProgressBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading ? PositionedDirectional(
          bottom: 0,
          start: height, // Démarre juste après l'image
          end: 0, // Va jusqu'au bout du widget
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color itemBackgroundColor = backgroundColor ?? (isDarkMode ? const Color(0xFF292929) : Colors.white);
    final Color subtitleColor = isDarkMode ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () => publication.showMenu(context, showDownloadDialog: false),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    height: height,
                    width: height,
                    child: ClipRRect(
                      child: ImageCachedWidget(
                        imageUrl: publication.imageSqr,
                        icon: publication.category.icon,
                        height: height,
                        width: height,
                      ),
                    ),
                  ),

                  // Texte
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: 6.0,
                        end: 25.0,
                        top: publication.issueTitle.isNotEmpty || searchWidget ? 2.0 : 4.0,
                        bottom: 2.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty && searchWidget)
                            Text(
                              publication.category.getName(),
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          if (publication.issueTitle.isNotEmpty)
                            Text(
                              publication.issueTitle,
                              style: TextStyle(fontSize: height == kItemHeight ? 11 : 10, color: subtitleColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          if (publication.coverTitle.isNotEmpty)
                            Text(
                              publication.coverTitle,
                              style: TextStyle(
                                height: 1.2,
                                fontSize: height == kItemHeight ? 14 : 13,
                                color: Theme.of(context).secondaryHeaderColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty)
                            Text(
                              publication.title,
                              style: TextStyle(
                                height: 1.2,
                                fontSize: height == kItemHeight ? 14.5 : 14,
                                color: Theme.of(context).secondaryHeaderColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          const Spacer(),
                          Text(
                            // Le texte de référence est généralement aligné avec le reste
                            '${formatYear(publication.year, localeCode: publication.mepsLanguage.getSafeLocale())} · ${publication.keySymbol}',
                            style: TextStyle(fontSize: 11, color: subtitleColor),
                            textAlign: TextAlign.start, // S'assurer de l'alignement
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              _buildPopupMenu(),
              _buildDynamicButton(),
              _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }
}