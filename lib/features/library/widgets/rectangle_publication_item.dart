import 'package:flutter/material.dart';

import '../../../core/ui/app_dimens.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Pour formatFileSize
import '../../../core/utils/utils_pub.dart'; // Pour les fonctions de menu
import '../../../data/models/publication.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/image_cached_widget.dart';

class RectanglePublicationItem extends StatelessWidget {
  final Publication publication;
  final Color? backgroundColor;

  /// Hauteur de l’item (sert aussi pour la largeur de l’image)
  final double height;

  const RectanglePublicationItem({
    super.key,
    required this.publication,
    this.backgroundColor,
    this.height = kItemHeight,
  });

  // 🔵 Progress bar compatible RTL
  Widget _buildProgressBar(double startOffset) {
    // La barre de progression est positionnée du coin de l'image (startOffset) jusqu'à la fin (end: 0).
    // Ceci est CORRECT.
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading
            ? PositionedDirectional(
          bottom: 0,
          start: startOffset, // Démarre juste après l'image
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
        )
            : const SizedBox.shrink();
      },
    );
  }

  // 🔵 Boutons dynamiques RTL-safe
  Widget _buildDynamicButton() {
    // Tous les éléments dynamiques (téléchargement, favori, mise à jour)
    // sont positionnés en `end: -8` ou `end: 2`. Ceci est CORRECT.
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
            if (!isDownloaded || publication.hasUpdate()) {
              return Stack(
                children: [
                  PositionedDirectional(
                    bottom: 3,
                    end: -5,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (publication.hasUpdate()) {
                          publication.update(context);
                        } else {
                          publication.download(context);
                        }
                      },
                      icon: Icon(
                        publication.hasUpdate()
                            ? JwIcons.arrows_circular
                            : JwIcons.cloud_arrow_down,
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
          popUpAnimationStyle: AnimationStyle.lerp(
            const AnimationStyle(curve: Curves.ease),
            const AnimationStyle(curve: Curves.ease),
            0.5,
          ),
          icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
          itemBuilder: (context) => [
            getPubShareMenuItem(publication),
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

    final Color itemBackgroundColor =
        backgroundColor ?? (isDarkMode ? const Color(0xFF292929) : Colors.white);

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
                textDirection: Directionality.of(context),
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
                      // 2. **CONFIRMATION RTL:** Utilisation de EdgeInsetsDirectional.only est CORRECT
                      // pour un padding sensible à la direction.
                      padding: EdgeInsetsDirectional.only(
                        start: 6.0,
                        end: 25.0,
                        top: publication.issueTitle.isNotEmpty ? 2.0 : 4.0,
                        bottom: 2.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // 3. **CONFIRMATION RTL:** CrossAxisAlignment.start est CORRECT
                        // pour aligner le texte au début de la direction de lecture.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (publication.issueTitle.isNotEmpty)
                            Text(
                              publication.issueTitle,
                              style: TextStyle(fontSize: height == 85 ? 11 : 10, color: subtitleColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          if (publication.coverTitle.isNotEmpty)
                            Text(
                              publication.coverTitle,
                              style: TextStyle(
                                height: 1.2,
                                fontSize: height == 85 ? 14 : 13,
                                color: Theme.of(context).secondaryHeaderColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          if (publication.issueTitle.isEmpty &&
                              publication.coverTitle.isEmpty)
                            Text(
                              publication.title,
                              style: TextStyle(
                                height: 1.2,
                                fontSize: height == 85 ? 14.5 : 14,
                                color: Theme.of(context).secondaryHeaderColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start, // S'assurer de l'alignement
                            ),
                          const Spacer(),
                          Text(
                            // Le texte de référence est généralement aligné avec le reste
                            '${formatYear(publication.year, localeCode: Locale(publication.mepsLanguage.primaryIetfCode))} · ${publication.keySymbol}',
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

              // Barre de progression (Utilise PositionedDirectional dans _buildProgressBar)
              _buildProgressBar(height),
            ],
          ),
        ),
      ),
    );
  }
}