import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/features/library/pages/publications/publications_items_page.dart';
import 'package:jwlife/features/library/pages/publications/publications_subcategories_page.dart';

import '../../../../core/app_dimens.dart';
import '../../../../core/utils/common_ui.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';

class PublicationsCategoriesPage extends StatelessWidget {
  final List<PublicationCategory> categories;

  const PublicationsCategoriesPage({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    // 1. Transformer la liste de données (categories) en une liste de Widgets
    final List<Widget> categoryWidgets = categories.map((category) {
      final ThemeData theme = Theme.of(context);
      final bool isDark = theme.brightness == Brightness.dark;

      // Déterminer les couleurs
      final Color backgroundColor = isDark
          ? const Color(0xFF292929) // Couleur sombre spécifique
          : Colors.white; // Blanc clair

      final Color textColor = isDark
          ? Colors.white
          : Colors.grey[800]!;

      return InkWell(
        onTap: () {
          final Widget destinationPage =
          category.hasYears || category.type == 'Convention'
              ? PublicationSubcategoriesView(category: category)
              : PublicationsItemsView(category: category);

          showPage(destinationPage);
        },
        // Utiliser FutureBuilder pour gérer l'appel asynchrone
        child: FutureBuilder<Widget>(
          future: _buildCategoryButton(context, category, backgroundColor, textColor),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Afficher un placeholder pendant le chargement
              return _buildPlaceholder(context, category, backgroundColor, textColor);
            }

            if (snapshot.hasError) {
              // En cas d'erreur, afficher le nom par défaut
              return _buildCategoryButtonSync(context, category, backgroundColor, textColor);
            }

            // Afficher le widget chargé
            return snapshot.data ?? _buildCategoryButtonSync(context, category, backgroundColor, textColor);
          },
        ),
      );
    }).toList();

    // 2. Passer la liste de Widgets au layout réactif
    return ResponsiveCategoriesWrapLayout(
      textDirection: JwLifeSettings().currentLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: categoryWidgets,
    );
  }

  /// Construit le contenu interne d'un bouton de catégorie (version async).
  Future<Widget> _buildCategoryButton(BuildContext context, PublicationCategory category,
      Color backgroundColor, Color textColor) async {
    final String categoryName = await category.getNameAsync(
        Locale(JwLifeSettings().currentLanguage.primaryIetfCode)
    );

    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(category.icon, size: 38.0, color: textColor),
            const SizedBox(width: 20.0),
            Expanded(
              child: Text(
                categoryName,
                style: TextStyle(color: textColor, fontSize: kFontBase),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit un placeholder pendant le chargement.
  Widget _buildPlaceholder(BuildContext context, PublicationCategory category,
      Color backgroundColor, Color textColor) {
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(category.icon, size: 38.0, color: textColor),
            const SizedBox(width: 20.0),
            Expanded(
              child: SizedBox(
                height: 16.0,
                child: LinearProgressIndicator(
                  backgroundColor: textColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le bouton avec le nom synchrone (fallback).
  Widget _buildCategoryButtonSync(BuildContext context, PublicationCategory category,
      Color backgroundColor, Color textColor) {
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(category.icon, size: 38.0, color: textColor),
            const SizedBox(width: 20.0),
            Expanded(
              child: Text(
                category.getName(context),
                style: TextStyle(color: textColor, fontSize: kFontBase),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}