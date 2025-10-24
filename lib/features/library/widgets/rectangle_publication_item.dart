import 'package:flutter/material.dart';

import '../../../core/app_dimens.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils.dart'; // Pour formatFileSize
import '../../../core/utils/utils_pub.dart'; // Pour les fonctions de menu
import '../../../data/models/publication.dart';
import '../../../widgets/image_cached_widget.dart';

class RectanglePublicationItem extends StatelessWidget {
  final Publication publication;
  final Color? backgroundColor;

  final double height; // Renommé pour correspondre à votre code

  const RectanglePublicationItem({
    super.key,
    required this.publication,
    this.backgroundColor,
    this.height = kItemHeight
  });

  // Extrait la logique de la barre de progression
  Widget _buildProgressBar(double leftOffset) {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return isDownloading
            ? Positioned(
          bottom: 0,
          right: 0,
          left: leftOffset, // Décalage basé sur la taille de l'image
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

  // Extrait la logique du bouton dynamique
  Widget _buildDynamicButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        // --- 1. Mode Téléchargement en cours (Annuler) ---
        if (isDownloading) {
          return Positioned(
            bottom: -4,
            right: -8,
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

        // --- 2. Mode Non Téléchargé / Mise à jour requise ---
        return ValueListenableBuilder<bool>(
          valueListenable: publication.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded || publication.hasUpdate()) {
              return Stack(
                children: [
                  // Icône de téléchargement ou de mise à jour
                  Positioned(
                    bottom: 3,
                    right: -10,
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
                        publication.hasUpdate() ? JwIcons.arrows_circular : JwIcons.cloud_arrow_down,
                        size: publication.hasUpdate() ? 20 : 24,
                        color: const Color(0xFF9d9d9d),
                      ),
                    ),
                  ),
                  // Texte sous l'icône (taille du fichier)
                  Positioned(
                    bottom: 0,
                    right: 2,
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

            // --- 3. Mode Téléchargé (Afficher Favori si besoin) ---
            return ValueListenableBuilder<bool>(
              valueListenable: publication.isFavoriteNotifier,
              builder: (context, isFavorite, _) {
                if (isFavorite) {
                  return const Positioned(
                    bottom: -4,
                    right: 2,
                    height: 40,
                    child: Icon(
                      JwIcons.star,
                      color: Color(0xFF9d9d9d),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            );
          },
        );
      },
    );
  }

  // Extrait le menu contextuel (const)
  Widget _buildPopupMenu(BuildContext context) {
    return Positioned(
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
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Simplifie le calcul de la couleur de fond
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
              // --- Contenu principal (Image + Texte) ---
              Row(
                children: [
                  // 🎯 FIXE : Ajout d'un SizedBox pour garantir que l'espace de l'image est EXACTEMENT 'height'x'height'
                  SizedBox(
                    height: height,
                    width: height,
                    child: ClipRRect(
                      child: ImageCachedWidget(
                        imageUrl: publication.imageSqr,
                        icon: publication.category.icon,
                        height: height, // Utilisation de la hauteur demandée
                        width: height, // L'image est carrée
                      ),
                    ),
                  ),
                  // Texte
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
                              style: TextStyle(fontSize: 11, color: subtitleColor),
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
                            '${publication.year} - ${publication.keySymbol}',
                            style: TextStyle(fontSize: 11, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // --- Éléments Positionnés (Optimisés) ---

              // Menu contextuel
              _buildPopupMenu(context),

              // Bouton dynamique
              _buildDynamicButton(),

              // Barre de progression
              _buildProgressBar(height), // Utilise le paramètre height pour le décalage
            ],
          ),
        ),
      ),
    );
  }
}