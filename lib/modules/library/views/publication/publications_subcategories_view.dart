import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:sqflite/sqflite.dart';

import 'publications_items_view.dart';

class PublicationSubcategoriesView extends StatefulWidget {
  final Map<String, dynamic> category;

  PublicationSubcategoriesView({Key? key, required this.category}) : super(key: key);

  @override
  _PublicationSubcategoriesViewState createState() => _PublicationSubcategoriesViewState();
}

class _PublicationSubcategoriesViewState extends State<PublicationSubcategoriesView> {
  String categoryName = '';
  String language = '';
  List<Map<String, dynamic>> years = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems() async {
    String langVernacular = JwLifeApp.currentLanguage.vernacular;
    int langId = JwLifeApp.currentLanguage.id;

    File catalogFile = await getCatalogFile();
    File mepsFile = await getMepsFile();

    if (await catalogFile.exists() && await mepsFile.exists()) {
      Database catalogDB = await openDatabase(catalogFile.path);
      await catalogDB.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

      List<Map<String, dynamic>> result = await catalogDB.rawQuery(''' 
    SELECT DISTINCT
      p.Year
    FROM 
      Publication p
    WHERE p.MepsLanguageId = ? AND p.PublicationTypeId = ?
    ORDER BY p.Year DESC
    ''', [langId, widget.category['id']]);

      setState(() {
        categoryName = widget.category['name'];
        language = langVernacular;
        years = result;
      });

      await catalogDB.execute("DETACH DATABASE meps");
      await catalogDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category['name']!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              language,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            onPressed: () async {
              LanguageDialog languageDialog = const LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) {
                loadItems();
              });
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index]['Year'].toString();

          // Déterminer la couleur de fond en fonction du thème
          Color backgroundColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white;

          // Déterminer la couleur du texte en fonction du thème
          Color? textColor = Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.white;

          return InkWell(
            onTap: () {
              showPage(context, PublicationsItemsView(
                category: widget.category,
                year: year,
              ));
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 1.0),
              color: backgroundColor,
              child: _buildCategoryButton(context, year, textColor!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, String year, Color textColor) {
    return ListTile(
      contentPadding: EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(widget.category['icon'], size: 38.0, color: textColor),
      ),
      title: Row(
        children: [
          SizedBox(width: 15.0), // Ajouter plus d'espace entre leading et title
          Text(year, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}
