import 'package:flutter/material.dart';
import 'package:jwlife/core/app_dimens.dart';

import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/library/pages/videos/videos_items_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../core/icons.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';

class VideosCategoriesPage extends StatelessWidget {
  final Category categories;

  const VideosCategoriesPage({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    // 1. Mapper les données en Widgets.
    final List<Widget> categoryWidgets = categories.subcategories.map((category) {
      return _buildCategoryButton(category);
    }).toList();

    // 2. Utiliser le layout générique pour disposer ces Widgets.
    return ResponsiveCategoriesWrapLayout(
      children: categoryWidgets,
    );
  }

  // NOTE : itemWidth n'est plus un paramètre !
  Widget _buildCategoryButton(Category category) {
    // Calcul du point de transition selon la longueur du texte
    int textLength = category.localizedName!.length - 8;
    double transitionPoint = (textLength / 19).clamp(0.38, 0.5);

    return InkWell(
      onTap: () {
        showPage(VideoItemsPage(category: category));
      },
      child: Stack(
        children: [
          // Image positionnée à droite
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ImageCachedWidget(
              imageUrl: category.persistedImages!.extraWideFullSizeImageUrl,
              icon: JwIcons.video,
              height: kItemHeight,
              fit: BoxFit.fill,
            ),
          ),
          // Dégradé
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(1.0),
                    Colors.black.withOpacity(1.0),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: [
                    0.0,
                    transitionPoint,
                    transitionPoint + 0.3,
                    1.0
                  ],
                ),
              ),
            ),
          ),
          // Titre positionné à gauche
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                // Utilisez un Padding pour créer l'espace à droite,
                // remplaçant le calcul de width: itemWidth * 0.7
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Text(
                  category.localizedName!,
                  style: const TextStyle(
                    fontSize: kFontBase,
                    color: Colors.white,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}