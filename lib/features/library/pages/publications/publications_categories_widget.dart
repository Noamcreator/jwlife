import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/features/library/pages/publications/publications_items_page.dart';
import 'package:jwlife/features/library/pages/publications/publications_subcategories_page.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/ui/app_dimens.dart';
import '../../../../core/utils/common_ui.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';

class PublicationsCategoriesWidget extends StatelessWidget {
  const PublicationsCategoriesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PublicationCategory>>(
      valueListenable: AppDataService.instance.publicationsCategories,
      builder: (context, categories, _) {
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        // Transforme les catégories en widgets
        final List<Widget> categoryWidgets = categories.map((category) {
          final ThemeData theme = Theme.of(context);
          final bool isDark = theme.brightness == Brightness.dark;

          final Color backgroundColor = isDark ? const Color(0xFF292929) : Colors.white;
          final Color textColor = isDark ? Colors.white : Colors.grey[800]!;

          return Material(
            color: backgroundColor,
            child: InkWell(
              onTap: () {
                final Widget destinationPage = category.hasYears || category.type == 'Convention' ? PublicationSubcategoriesPage(category: category) : PublicationsItemsPage(category: category, mepsLanguage: JwLifeSettings.instance.currentLanguage.value);
                showPage(destinationPage);
              },
              child: FutureBuilder<Widget>(
                future: _buildCategoryButton(context, category, backgroundColor, textColor),
                builder: (context, snapshot) {
                  if (snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                    return _buildCategoryButtonSync(context, category, textColor);
                  }
                  return snapshot.data ?? _buildCategoryButtonSync(context, category, textColor);
                },
              ),
            ),
          );
        }).toList();

        return ResponsiveCategoriesWrapLayout(
          textDirection: JwLifeSettings.instance.currentLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: categoryWidgets,
        );
      },
    );
  }

  Future<Widget> _buildCategoryButton(BuildContext context, PublicationCategory category, Color backgroundColor, Color textColor) async {
    final String categoryName = await category.getNameAsync(JwLifeSettings.instance.currentLanguage.value.getSafeLocale());
    final iconColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFFC0C0C0) : Color(0xFF4F4F4F);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(category.icon, size: 38.0, color: iconColor),
          const SizedBox(width: 25.0),
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
    );
  }

  Widget _buildCategoryButtonSync(BuildContext context, PublicationCategory category, Color textColor) {
    final iconColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFFC0C0C0) : Color(0xFF4F4F4F);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(category.icon, size: 38.0, color: iconColor),
          const SizedBox(width: 25.0),
          Expanded(
            child: Text(
              category.getName(),
              style: TextStyle(color: textColor, fontSize: kFontBase),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
