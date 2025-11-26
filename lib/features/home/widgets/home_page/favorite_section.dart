import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_document.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class FavoritesSection extends StatefulWidget {
  final void Function(int oldIndex, int newIndex) onReorder;

  const FavoritesSection({super.key, required this.onReorder});

  @override
  State<FavoritesSection> createState() => FavoritesSectionState();
}

class FavoritesSectionState extends State<FavoritesSection> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: AppDataService.instance.favorites,
      builder: (context, favorites, _) {
        if (favorites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n().navigation_favorites,
              style: Theme.of(context)
                  .extension<JwLifeThemeStyles>()!
                  .labelTitle,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 120,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                onReorderStart: (int index) {
                  HapticFeedback.mediumImpact();
                },
                onReorder: widget.onReorder,
                proxyDecorator: (child, index, animation) {
                  return Opacity(
                    opacity: 0.8,
                    child: Material(
                      elevation: 6,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: child,
                    ),
                  );
                },
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final item = favorites[index];
                  return Padding(
                    key: ValueKey(item),
                    padding: const EdgeInsets.only(right: 2.0),
                    child: _buildFavoriteItem(item, context),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteItem(dynamic item, BuildContext context) {
    Publication? pub;

    // -------------------------
    // PUBLICATION
    // -------------------------
    if (item is Publication) {
      pub = PublicationRepository().getPublicationWithMepsLanguageId(
        item.keySymbol,
        item.issueTagNumber,
        item.mepsLanguage.id,
      );

      if (pub != null) {
        return HomeSquarePublicationItem(pub: pub);
      }
    }

    // -------------------------
    // MEDIA
    // -------------------------
    if (item is Media) {
      return HomeSquareMediaItemItem(media: item);
    }

    // -------------------------
    // OBJET JSON (fallback)
    // -------------------------
    pub = PublicationRepository().getPublicationWithMepsLanguageId(
      item['KeySymbol'] ?? '',
      item['IssueTagNumber'] ?? 0,
      item['MepsLanguage'] ?? 0,
    );

    if (pub != null) {
      return HomeSquarePublicationItem(pub: pub);
    }

    // -------------------------
    // WIDGET PAR DÉFAUT
    // -------------------------
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
    isDark ? const Color(0xFF4F4F4F) : const Color(0xFF999999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showImportPublication(
            context,
            item['KeySymbol'] ?? '',
            item['IssueTagNumber'] ?? 0,
            item['MepsLanguage'] ?? 0,
          );
        },
        child: SizedBox(
          width: kSquareItemHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: Container(
                      color: backgroundColor,
                      height: kSquareItemHeight,
                      width: kSquareItemHeight,
                      child: const Center(
                        child: Icon(
                          JwIcons.publication_video_music,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // MENU DE SUPPRESSION
                  Positioned(
                    top: -13,
                    right: -7,
                    child: PopupMenuButton(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              const Icon(JwIcons.star__fill),
                              const SizedBox(width: 8),
                              Text(i18n().action_favorites_remove),
                            ],
                          ),
                          onTap: () async {
                            await JwLifeApp.userdata.removeAFavorite(item);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // TITRE
              SizedBox(
                width: kSquareItemHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0, right: 4.0),
                  child: Text(
                    '${item['KeySymbol']} • ${item['LanguageVernacularName']}',
                    style: Theme.of(context)
                        .extension<JwLifeThemeStyles>()!
                        .squareTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
