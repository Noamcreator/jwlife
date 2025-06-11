import 'package:flutter/material.dart';

import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_widget.dart';

import 'video_items_view.dart';

class VideoView extends StatefulWidget {
  final Category video;

  VideoView({super.key, required this.video});

  @override
  _VideoViewState createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double padding = 8.0;
    double spacing = 3.0;

    // Calcul de largeur en tenant compte des marges et espaces
    double itemWidth = screenWidth > 800
        ? (screenWidth - padding * 2 - spacing) / 2 // Retirer spacing * nombre d'espaces
        : screenWidth;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: widget.video.subcategories.map((category) {
          return buildCategoryItem(category, itemWidth);
        }).toList(),
      ),
    );
  }

  Widget buildCategoryItem(Category category, double itemWidth) {
    return InkWell(
      onTap: () {
        showPage(context, VideoItemsView(category: category));
      },
      child: Container(
        width: itemWidth,
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        child: Stack(
          children: [
            ImageCachedWidget(
              imageUrl: category.persistedImages!.extraWideFullSizeImageUrl,
              pathNoImage: "pub_type_video",
              height: 85.0,
              width: itemWidth,
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    category.localizedName!,
                    style: const TextStyle(
                      fontSize: 20.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}