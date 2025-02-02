import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_widget.dart';

import 'audio_items_view.dart';

class AudioView extends StatefulWidget {
  final Category audio;

  AudioView({super.key, required this.audio});

  @override
  _AudioViewState createState() => _AudioViewState();
}

class _AudioViewState extends State<AudioView> {

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
        children: widget.audio.subcategories.map((category) {
          return buildCategoryItem(category, itemWidth);
        }).toList(),
      )
    );
  }

  Widget buildCategoryItem(Category category, double itemWidth) {
    return InkWell(
      onTap: () {
        showPage(context, AudioItemsView(category: category));
      },
      child: SizedBox(
        width: itemWidth,
        child: Stack(
          children: [
            ImageCachedWidget(
              imageUrl: category.persistedImages!.extraWideFullSizeImageUrl,
              pathNoImage: "pub_type_audio",
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
