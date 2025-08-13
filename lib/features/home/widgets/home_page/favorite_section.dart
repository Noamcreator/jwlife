import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../app/jwlife_page.dart';
import '../../../../app/services/global_key_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../i18n/localization.dart';

class FavoritesSection extends StatelessWidget {
  final void Function(int oldIndex, int newIndex) onReorder;

  const FavoritesSection({super.key, required this.onReorder});

  @override
  State<FavoritesSection> createState() => FavoritesSectionState();
}

class FavoritesSectionState extends State<FavoritesSection> {
  List<dynamic> get favorites => JwLifeApp.of(context).favorites;

  void refreshFavorites() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localization(context).navigation_favorites, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        SizedBox(
          height: 120,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            onReorderStart: (int index) {
              HapticFeedback.mediumImpact();
            },
            onReorder: onReorder,
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
            children: [
              for (int index = 0; index < favorites.length; index++)
                Padding(
                  key: ValueKey(favorites[index]),
                  padding: const EdgeInsets.only(right: 2.0),
                  child: _buildFavoriteItem(favorites[index], context),
                )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteItem(dynamic item, BuildContext context) {
    if (item is Publication) return HomeSquarePublicationItem(pub: item);
    if (item is MediaItem) return HomeSquareMediaItemItem(mediaItem: item);
    // fallback custom widget for other types
    return InkWell(
        child: SizedBox(
          width: 80,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.0),
                      child: Container(
                        color: Color(0xFF757575),
                        height: 80,
                        width: 80,
                        child: Center(
                          child: Icon(
                            JwIcons.publication_video_music,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -10,
                      child: PopupMenuButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(JwIcons.star__fill),
                                SizedBox(width: 8),
                                Text('Supprimer des favoris'),
                              ],
                            ),
                            onTap: () async {
                              await JwLifeApp.userdata.removeAFavorite(item);
                              GlobalKeyService.homeKey.currentState?.refreshFavorites();
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 80,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2.0, right: 4.0),
                    child: Text(
                      item['KeySymbol'] + ' • ' + item['LanguageVernacularName'],
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w100,
                        fontFamily: 'Roboto',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      softWrap: true,
                    ),
                  ),
                ),
              ],
          ),
        ),
        onTap: () {}
    );
  }
}
