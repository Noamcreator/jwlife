import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_items_page.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_subcategories_page.dart';

import '../../../utils/icons.dart';

class PublicationsPage extends StatelessWidget {
  const PublicationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];

          // Déterminer la couleur de fond en fonction du thème
          Color backgroundColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white;

          // Déterminer la couleur du texte en fonction du thème
          Color? textColor = Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.white;

          return InkWell(
            onTap: () {
              if (category['yearsPubs']) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                      return PublicationSubcategoriesPage(
                        category: category,
                      );
                    },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
              else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                      return PublicationsItemsPage(
                        category: category,
                      );
                    },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 1.0),
              color: backgroundColor,
              child: _buildCategoryButton(context, category, textColor!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, Map<String, dynamic> category, Color textColor) {
    return ListTile(
      contentPadding: EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(category['icon'], size: 38.0, color: textColor),
      ),
      title: Row(
        children: [
          SizedBox(width: 15.0), // Ajouter plus d'espace entre leading et title
          Text(category['name'], style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}

// Liste de catégories à afficher
List<Map<String, dynamic>> categories = [
  {'id': 1, 'name': 'Bibles', 'icon': JwIcons.bible, "image": "pub_type_bible", "yearsPubs": false},
  {'id': 2, 'name': 'Livres', 'icon': JwIcons.book_stack, "image": "pub_type_book", "yearsPubs": false},
  {'id': 4, 'name': 'Brochures', 'icon': JwIcons.brochure_stack, "image": "pub_type_booklet_brochure", "yearsPubs": false},
  {'id': 10, 'name': 'Tracts et Invitations', 'icon': JwIcons.tract_stack, "image": "pub_type_tract", "yearsPubs": false},
  {'id': 22, 'name': 'Rubriques', 'icon': JwIcons.article_stack, "image": "pub_type_article_series", "yearsPubs": false},
  {'id': 14, 'name': 'Tour de Garde', 'icon': JwIcons.watchtower, "image": "pub_type_watchtower", "yearsPubs": true},
  {'id': 13, 'name': 'Réveillez-vous !', 'icon': JwIcons.awake_exclamation_mark, "image": "pub_type_awake", "yearsPubs": true},
  {'id': 30, 'name': 'Cahiers Vie et ministère', 'icon': JwIcons.meeting_workbook_stack, "image": "pub_type_meeting_workbook", "yearsPubs": true},
  {'id': 7, 'name': 'Ministère du Royaume', 'icon': JwIcons.kingdom_ministry, "image": "pub_type_kingdom_ministry", "yearsPubs": true},
  {'id': 31, 'name': 'Programmes', 'icon': JwIcons.clock, "image": "pub_type_program", "yearsPubs": false},
  {'id': 6, 'name': 'Index', 'icon': JwIcons.publications_pile, "image": "pub_type_index", "yearsPubs": false},
  {'id': 6, 'name': 'Plans de discours', 'icon': JwIcons.document_speaker, "image": "pub_type_talk_outline", "yearsPubs": false},
  {'id': 17, 'name': 'Instructions', 'icon': JwIcons.checklist, "image": "pub_type_manual_guidelines", "yearsPubs": false},
];

