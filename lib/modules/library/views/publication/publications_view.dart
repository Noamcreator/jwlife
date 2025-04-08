import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/l10n/localization.dart';

import 'publications_items_view.dart';
import 'publications_subcategories_view.dart';

class PublicationsView extends StatelessWidget {
  const PublicationsView({super.key});

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
        children: initializeCategories(context).map((category) {
          // Déterminer les couleurs selon le thème
          Color backgroundColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF292929)
              : Colors.white;

          Color textColor = Theme.of(context).brightness == Brightness.light
              ? Colors.grey[800]!
              : Colors.white;

          return InkWell(
            onTap: () {
              if (category['yearsPubs']) {
                showPage(context, PublicationSubcategoriesView(category: category));
              } else {
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

  Widget _buildCategoryButton(BuildContext context, Map<String, dynamic> category, Color textColor) {
    return ListTile(
      contentPadding: const EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(category['icon'], size: 38.0, color: textColor),
      ),
      title: Text(
        category['name'],
        style: TextStyle(color: textColor, fontSize: 16.0),
        overflow: TextOverflow.ellipsis, // Gère les textes trop longs
      ),
    );
  }
}

List<Map<String, dynamic>> initializeCategories(BuildContext context) {
  return [
    {'id': 1, 'symbols': ['bi'], 'type': 'Bible', 'name': 'Bibles', 'icon': JwIcons.bible, "image": "pub_type_bible", "yearsPubs": false},
    {'id': 2, 'symbols': ['bk', 'gloss'], 'type': 'Book', 'type2': 'Glossary', 'name': localization(context).pub_type_books, 'icon': JwIcons.book_stack, "image": "pub_type_book", "yearsPubs": false},
    {'id': 4, 'symbols': ['brch'], 'type': 'Brochure', 'type2': 'Booklet', 'name': localization(context).pub_type_brochures_booklets, 'icon': JwIcons.brochure_stack, "image": "pub_type_booklet_brochure", "yearsPubs": false},
    {'id': 10, 'symbols': ['trct'], 'type': 'Tract', 'name': localization(context).pub_type_tracts, 'icon': JwIcons.tract_stack, "image": "pub_type_tract", "yearsPubs": false},
    {'id': 22, 'symbols': ['web'], 'type': 'Web', 'name': localization(context).pub_type_web, 'icon': JwIcons.article_stack, "image": "pub_type_article_series", "yearsPubs": false},
    {'id': 14, 'symbols': ['w'], 'type': 'Watchtower', 'name': localization(context).pub_type_watchtower, 'icon': JwIcons.watchtower, "image": "pub_type_watchtower", "yearsPubs": true},
    {'id': 13, 'symbols': ['g'], 'type': 'Awake!', 'name': localization(context).pub_type_awake, 'icon': JwIcons.awake_exclamation_mark, "image": "pub_type_awake", "yearsPubs": true},
    {'id': 30, 'symbols': ['mwb'], 'type': 'Meeting Workbook', 'name': localization(context).pub_type_meeting_workbook, 'icon': JwIcons.meeting_workbook_stack, "image": "pub_type_meeting_workbook", "yearsPubs": true},
    {'id': 7, 'symbols': ['km'], 'type': 'Kingdom Ministry', 'name': localization(context).pub_type_kingdom_ministry, 'icon': JwIcons.kingdom_ministry, "image": "pub_type_kingdom_ministry", "yearsPubs": true},
    {'id': 31, 'symbols': ['pgm'], 'type': 'Program', 'name': localization(context).pub_type_programs, 'icon': JwIcons.clock, "image": "pub_type_program", "yearsPubs": false},
    {'id': 6, 'symbols': ['dx'], 'type': 'Index', 'name': localization(context).pub_type_index, 'icon': JwIcons.publications_pile, "image": "pub_type_index", "yearsPubs": false},
    {'id': 0, 'symbols': ['talk'], 'type': 'Talk', 'name': localization(context).pub_type_talks, 'icon': JwIcons.document_speaker, "image": "pub_type_talk_outline", "yearsPubs": false},
    {'id': 17, 'symbols': ['manual'], 'type': 'Manual/Guidelines', 'name': localization(context).pub_type_manuals_guidelines, 'icon': JwIcons.checklist, "image": "pub_type_manual_guidelines", "yearsPubs": false},
    {'id': 0, 'symbols': ['manual'], 'type': 'Information Packet', 'name': localization(context).pub_type_information_packets, 'icon': JwIcons.document, "image": "pub_type_information_packet", "yearsPubs": false},
    {'id': 0, 'symbols': ['fm'], 'type': 'Form', 'name': localization(context).pub_type_forms, 'icon': JwIcons.text_pencil, "image": "pub_type_form", "yearsPubs": false},
    {'id': 0, 'symbols': ['lt'], 'type': 'Letter', 'name': localization(context).pub_type_letters, 'icon': JwIcons.envelope, "image": "pub_type_letter", "yearsPubs": false}
  ];
}
