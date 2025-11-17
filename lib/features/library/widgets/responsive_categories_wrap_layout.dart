import 'package:flutter/material.dart';

import '../../../core/app_dimens.dart';

class ResponsiveCategoriesWrapLayout extends StatelessWidget {
  final TextDirection textDirection;
  final List<Widget> children;

  const ResponsiveCategoriesWrapLayout({super.key, required this.textDirection, required this.children});

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: textDirection,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;

            // 1. Calculer le padding adaptatif
            final double contentPadding = getContentPadding(screenWidth);

            // La largeur totale disponible pour les items et les espacements
            final double availableWidth = screenWidth - (contentPadding * 2);

            // 2. Calculer le nombre d'éléments par ligne (crossAxisCount)
            // Logique plus robuste : on divise la largeur disponible (plus un espacement pour compenser le retrait)
            // par la largeur désirée de l'item + l'espacement.
            final int crossAxisCount =
            ((availableWidth + kSpacing) / (kMaxItemWidth + kSpacing)).floor();

            // S'assurer qu'il y a au moins 1 colonne
            final int finalCrossAxisCount = crossAxisCount > 0 ? crossAxisCount : 1;

            // 3. Calculer la largeur réelle de chaque élément (itemWidth)
            // Largeur totale disponible - l'espace total occupé par tous les "gutters" / Nombre d'éléments
            final double totalSpacing = kSpacing * (finalCrossAxisCount - 1);
            final double itemWidth = (availableWidth - totalSpacing) / finalCrossAxisCount;

            return SingleChildScrollView(
              // Amélioration : utiliser un BoundingBox pour gérer la hauteur si vous voulez un effet scroll-snap ou autre
              // Si SingleChildScrollView est le parent de haut niveau dans un Scaffold, c'est parfait.

              // 4. Appliquer le padding adaptatif
              padding: EdgeInsets.all(contentPadding),
              child: Wrap(
                spacing: kSpacing, // Espacement horizontal
                runSpacing: kSpacing, // Espacement vertical
                // Utilisation d'une collection `for` pour une meilleure performance et lisibilité
                children: [
                  for (final child in children)
                    SizedBox(
                      width: itemWidth,
                      height: kItemHeight,
                      child: child,
                    ),
                ],
              ),
            );
          },
        )
    );
  }
}