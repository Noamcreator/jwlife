import 'package:flutter/material.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../core/icons.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../i18n/localization.dart';

class FavoritesSection extends StatelessWidget {
  final List<dynamic> favorites;
  final void Function(int oldIndex, int newIndex) onReorder;

  const FavoritesSection({required this.favorites, required this.onReorder, super.key});

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
            onReorder: onReorder,
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
                    )
                  ],
                ),
              ]
          ),
        ),
        onTap: () {}
    );
  }
}
