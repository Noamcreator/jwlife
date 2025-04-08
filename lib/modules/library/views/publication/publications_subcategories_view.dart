import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:sqflite/sqflite.dart';

import 'publications_items_view.dart';

class PublicationSubcategoriesView extends StatefulWidget {
  final PublicationCategory category;

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
    String langVernacular = JwLifeApp.settings.currentLanguage.vernacular;
    int langId = JwLifeApp.settings.currentLanguage.id;

    File catalogFile = await getCatalogFile();
    File mepsFile = await getMepsFile();

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
        categoryName = widget.category.getName(context);
        language = langVernacular;
        years = result;
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
              language,
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
          int year = years[index]['Year'];

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

  Widget _buildCategoryButton(BuildContext context, int year, Color textColor) {
    return ListTile(
      contentPadding: EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(widget.category.icon, size: 38.0, color: textColor),
      ),
      title: Row(
        children: [
          SizedBox(width: 15.0), // Ajouter plus d'espace entre leading et title
          Text(year.toString(), style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}
