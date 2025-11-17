import 'package:flutter/material.dart';
import 'package:jwlife/core/app_dimens.dart';

import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/library/pages/videos/videos_items_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';

class VideosCategoriesPage extends StatelessWidget {
  final Category categories;

  const VideosCategoriesPage({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = JwLifeSettings().currentLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr;

    final List<Widget> categoryWidgets = categories.subcategories.map((category) {
      return _buildCategoryButton(category, direction);
    }).toList();

    return ResponsiveCategoriesWrapLayout(
      textDirection: direction,
      children: categoryWidgets,
    );
  }

  /// Construit un bouton de catégorie avec un support RTL complet,
  /// prenant en paramètre la direction ambiante.
  Widget _buildCategoryButton(Category category, TextDirection direction) {
    final bool isRtl = direction == TextDirection.rtl;

    // Calcul du point de transition selon la longueur du texte
    int textLength = category.localizedName!.length - 8;
    double transitionPoint = (textLength / 19).clamp(0.38, 0.5);

    // L'ordre des stops du dégradé doit être inversé pour le mode RTL :
    // [0.0] doit toujours correspondre au côté où commence le texte (start).
    final List<double> stops = isRtl
        ? [
      0.0, // Côté image (end)
      transitionPoint,
      transitionPoint + 0.3,
      1.0  // Côté texte (start)
    ]
        : [
      0.0, // Côté texte (start)
      transitionPoint,
      transitionPoint + 0.3,
      1.0  // Côté image (end)
    ];

    return InkWell(
      onTap: () {
        showPage(VideoItemsPage(category: category));
      },
      child: Stack(
        children: [
          // 1. Image positionnée de manière directionnelle à 'end'
          // (Droite en LTR, Gauche en RTL)
          Positioned.directional(
            textDirection: direction,
            end: 0,
            top: 0,
            bottom: 0,
            child: ImageCachedWidget(
              imageUrl: category.persistedImages!.extraWideFullSizeImageUrl,
              icon: JwIcons.video,
              height: kItemHeight,
              fit: BoxFit.fill,
            ),
          ),

          // 2. Dégradé directionnel
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // Commence à 'start' et finit à 'end'
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    Colors.black.withOpacity(1.0),
                    Colors.black.withOpacity(1.0),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  // Utilise les stops ajustés pour RTL/LTR
                  stops: stops,
                ),
              ),
            ),
          ),

          // 3. Titre positionné et aligné à 'start'
          // (Gauche en LTR, Droite en RTL)
          Positioned.fill(
            child: Align(
              // S'aligne du côté de début du texte
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
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