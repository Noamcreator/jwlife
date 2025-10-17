import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import 'audio_items_page.dart';

class AudioPage extends StatefulWidget {
  final Category audio;

  const AudioPage({super.key, required this.audio});

  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {

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
    // Calcul du point de transition selon la longueur du texte
    int textLength = category.localizedName!.length-8;
    double transitionPoint = (textLength / 19).clamp(0.38, 0.5);

    return InkWell(
      onTap: () {
        showPage(AudioItemsPage(category: category));
      },
      child: Container(
        width: itemWidth,
        height: 85.0,
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        child: Stack(
          children: [
            // Image positionnée à droite, sans étirement
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: itemWidth * 0.6, // 60% de la largeur pour l'image
              child: ImageCachedWidget(
                imageUrl: category.persistedImages!.extraWideFullSizeImageUrl,
                icon: JwIcons.headphones__simple,
                height: 85.0,
                fit: BoxFit.fill,
              ),
            ),
            // Dégradé qui va du noir (gauche) vers transparent (droite)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(1.0), // Noir opaque à gauche
                      Colors.black.withOpacity(1.0), // Noir opaque au centre
                      Colors.transparent, // Transparent à droite pour laisser voir l'image
                      Colors.transparent, // Transparent à droite pour laisser voir l'image
                    ],
                    stops: [
                      0.0,
                      transitionPoint, // Point adaptatif calculé selon la taille
                      transitionPoint+0.3,
                      1.0
                    ],
                  ),
                ),
              ),
            ),
            // Titre positionné à gauche
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: itemWidth * 0.7, // 70% de la largeur pour le texte
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    category.localizedName!,
                    style: const TextStyle(
                      fontSize: 19.0,
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
