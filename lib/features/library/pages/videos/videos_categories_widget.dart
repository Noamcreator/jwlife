import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';

import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/library/pages/videos/videos_items_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';

class VideosCategoriesWidget extends StatelessWidget {
  final RealmCategory categories;

  const VideosCategoriesWidget({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = JwLifeSettings.instance.currentLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr;

    final List<Widget> categoryWidgets = categories.subCategories.map((category) {
      return _buildCategoryButton(category, direction);
    }).toList();

    return ResponsiveCategoriesWrapLayout(
      textDirection: direction,
      children: categoryWidgets,
    );
  }

  Widget _buildCategoryButton(RealmCategory category, TextDirection direction) {
    final bool isRtl = direction == TextDirection.rtl;

    int textLength = category.name!.length - 8;
    double transitionPoint = (textLength / 19).clamp(0.38, 0.5);

    final List<double> stops = isRtl
        ? [0.0, transitionPoint, transitionPoint + 0.3, 1.0]
        : [0.0, transitionPoint, transitionPoint + 0.3, 1.0];

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. Image positionnée à 'end'
          Positioned.directional(
            textDirection: direction,
            end: 0,
            top: 0,
            bottom: 0,
            child: ImageCachedWidget(
              imageUrl: category.images!.extraWideImageUrl,
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
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    Colors.black.withOpacity(1.0),
                    Colors.black.withOpacity(1.0),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: stops,
                ),
              ),
            ),
          ),

          // 3. Titre positionné à 'start'
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Text(
                  category.name!,
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

          // 4. InkWell PAR-DESSUS tout le reste
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showPage(VideoItemsPage(category: category));
                },
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}