import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_document.dart';

import '../../../core/ui/app_dimens.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Pour formatFileSize
import '../../../core/utils/utils_pub.dart'; // Pour les fonctions de menu
import '../../../data/models/publication.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/image_cached_widget.dart';

class RectangleTopicItem extends StatelessWidget {
  final dynamic topic;
  final Publication publication;
  final Color? backgroundColor;

  const RectangleTopicItem({
    super.key,
    required this.topic,
    required this.publication,
    this.backgroundColor,
  });

  // 🔵 Boutons dynamiques RTL-safe
  Widget _buildDynamicButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        // 1. Téléchargement en cours → bouton annuler
        if (isDownloading) {
          return PositionedDirectional(
            bottom: -4,
            end: -5,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => publication.cancelDownload(context),
              icon: const Icon(
                JwIcons.x,
                color: Color(0xFF9d9d9d),
              ),
            ),
          );
        }

        // 2. Non téléchargé / Mise à jour
        return ValueListenableBuilder<bool>(
          valueListenable: publication.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (publication.hasUpdate()) {
              return Stack(
                children: [
                  PositionedDirectional(
                    bottom: 3,
                    end: -5,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        publication.update(context);
                      },
                      icon: Icon(
                        JwIcons.arrows_circular,
                        size: publication.hasUpdate() ? 20 : 24,
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

            // 3. Téléchargé : afficher favori
            return ValueListenableBuilder<bool>(
              valueListenable: publication.isFavoriteNotifier,
              builder: (context, isFavorite, _) {
                if (isFavorite) {
                  return const PositionedDirectional(
                    bottom: -4,
                    end: 2,
                    height: 40,
                    child: Icon(
                      JwIcons.star,
                      color: Color(0xFF9d9d9d),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }

  // 🔵 Menu contextuel amélioré
  Widget _buildPopupMenu(BuildContext context) {
    // Positionné en HAUT-FIN. Ceci est CORRECT.
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color itemBackgroundColor = backgroundColor ?? (isDarkMode ? const Color(0xFF292929) : Colors.white);
    final Color subtitleColor = isDarkMode ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () {
          if(topic['Type'] == 'heading') {
            showDocumentView(context, topic['MepsDocumentId'], topic['MepsLanguageId'], startParagraphId: topic['BeginParagraphOrdinal'], endParagraphId: topic['EndParagraphOrdinal']);
          }
          else if(topic['Type'] == 'topic') {
            showDocumentView(context, topic['MepsDocumentId'], topic['MepsLanguageId']);
          }
        },
        child: SizedBox(
          height: kSquareItemHeight,
          child: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    height: kSquareItemHeight,
                    width: kSquareItemHeight,
                    child: ClipRRect(
                      child: ImageCachedWidget(
                        imageUrl: publication.imageSqr,
                        icon: publication.category.icon,
                        height: kSquareItemHeight,
                        width: kSquareItemHeight,
                      ),
                    ),
                  ),

                  // Texte
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6.0, end: 25.0, top: 2.0, bottom: 2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic['ParentTitle'] != null ? '${publication.getShortTitle()} • ${topic['ParentTitle']}' : publication.getShortTitle(),
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start, // S'assurer de l'alignement
                          ),
                          Text(
                            topic['Title'],
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 14.5,
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

              // Menu (Utilise PositionedDirectional dans _buildPopupMenu)
              _buildPopupMenu(context),

              // Bouton dynamique (Utilise PositionedDirectional dans _buildDynamicButton)
              _buildDynamicButton(),
            ],
          ),
        ),
      ),
    );
  }
}