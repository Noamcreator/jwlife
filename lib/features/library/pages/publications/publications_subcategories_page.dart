import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:realm/realm.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/i18n.dart';
import 'convention_items_page.dart';
import 'publications_items_page.dart';

class PublicationSubcategoriesView extends StatefulWidget {
  final PublicationCategory category;

  const PublicationSubcategoriesView({super.key, required this.category});

  @override
  _PublicationSubcategoriesViewState createState() => _PublicationSubcategoriesViewState();
}

class _PublicationSubcategoriesViewState extends State<PublicationSubcategoriesView> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    if(widget.category.type == 'Convention') {
      loadItemsDays();
    }
    else {
      loadItemsYears();
    }
  }

  void loadItemsDays() async {
    List<Map<String, dynamic>> days = [];

    List<Publication> pubs = await PubCatalog.fetchPubsFromConventionsDays();
    RealmResults<Category> convDaysCategories = RealmLibrary.realm.all<Category>().query("language == '${JwLifeSettings().currentLanguage.symbol}'").query("key == 'ConvDay1' OR key == 'ConvDay2' OR key == 'ConvDay3'");

    for(int i = 1; i < 3+1; i++) {
      if (pubs.any((element) => element.conventionReleaseDayNumber == i) || convDaysCategories.any((element) => element.key == 'ConvDay$i')) {
        days.add({
          "Day": i,
          "Publications": pubs.where((element) => element.conventionReleaseDayNumber == i).toList(),
          "Medias": convDaysCategories.firstWhere((element) => element.key == 'ConvDay$i').media
        });
      }
    }

    setState(() {
      items = days;
    });
  }

  void loadItemsYears() async {
    int langId = JwLifeSettings().currentLanguage.id;

    File catalogFile = await getCatalogDatabaseFile();
    File mepsFile = await getMepsUnitDatabaseFile();

    if (await catalogFile.exists() && await mepsFile.exists()) {
      Database catalogDB = await openDatabase(catalogFile.path);
      List<Map<String, dynamic>> result = await catalogDB.rawQuery(''' 
    SELECT DISTINCT
      p.Year
    FROM 
      Publication p
    WHERE p.MepsLanguageId = ? AND p.PublicationTypeId = ?
    ORDER BY p.Year DESC
    ''', [langId, widget.category.id]);

      setState(() {
        items = result;
      });

      await catalogDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.getName(context),
              style: textStyleTitle,
            ),
            Text(
              JwLifeSettings().currentLanguage.vernacular,
              style: textStyleSubtitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {
              showLanguageDialog(context).then((language) async {
                if (language != null) {
                  loadItemsYears();
                }
              });
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          int number = items[index]['Year'] ?? items[index]['Day'];

          // Déterminer la couleur de fond en fonction du thème
          Color backgroundColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white;

          // Déterminer la couleur du texte en fonction du thème
          Color? textColor = Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.white;

          return InkWell(
            onTap: () {
              if(widget.category.type == 'Convention') {
                showPage(ConventionItemsView(
                  category: widget.category,
                  indexDay: items[index]['Day'],
                  publications: items[index]['Publications'],
                  medias: items[index]['Medias'],
                ));
              }
              else {
                showPage(PublicationsItemsView(
                  category: widget.category,
                  year: number,
                ));
              }
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 1.0),
              color: backgroundColor,
              child: _buildCategoryButton(context, number, textColor!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, int number, Color textColor) {
    return ListTile(
      contentPadding: EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(widget.category.icon, size: 38.0, color: textColor),
      ),
      title: Row(
        children: [
          SizedBox(width: 15.0), // Ajouter plus d'espace entre leading et title
          Text(widget.category.type == 'Convention' ? i18n().label_convention_day(number) : number.toString(), style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}
