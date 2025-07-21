import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/publication_category.dart';

import 'publications_items_page.dart';
import 'publications_subcategories_page.dart';

class PublicationsPage extends StatelessWidget {
  final List<PublicationCategory> categories;

  const PublicationsPage({super.key, required this.categories});

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
        spacing: spacing, // Espacement horizontal
        runSpacing: spacing, // Espacement vertical
        children: categories.map((category) {
          // Déterminer les couleurs selon le thème
          Color backgroundColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF292929)
              : Colors.white;

          Color textColor = Theme.of(context).brightness == Brightness.light
              ? Colors.grey[800]!
              : Colors.white;

          return InkWell(
            onTap: () {
              if (category.hasYears) {
                showPage(context, PublicationSubcategoriesView(category: category));
              }
              else if(category.type == 'Convention') {
                showPage(context, PublicationSubcategoriesView(category: category));
              }
              else {
                showPage(context, PublicationsItemsView(category: category));
              }
            },
            child: Container(
              width: itemWidth, // Largeur calculée
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: _buildCategoryButton(context, category, textColor),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, PublicationCategory category, Color textColor) {
    return ListTile(
      contentPadding: const EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(category.icon, size: 38.0, color: textColor),
      ),
      title: Text(
        category.getName(context),
        style: TextStyle(color: textColor, fontSize: 16.0),
        overflow: TextOverflow.ellipsis, // Gère les textes trop longs
      ),
    );
  }
}