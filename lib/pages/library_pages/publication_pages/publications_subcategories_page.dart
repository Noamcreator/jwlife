import 'dart:ffi';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_items_page.dart';
import 'package:sqflite/sqflite.dart';

import '../../../jwlife.dart';
import '../../../utils/files_helper.dart';
import '../../../utils/icons.dart';
import '../../../utils/shared_preferences_helper.dart';
import '../../../widgets/dialog/language_dialog.dart';

class PublicationSubcategoriesPage extends StatefulWidget {
  final Map<String, dynamic> category;

  PublicationSubcategoriesPage({Key? key, required this.category}) : super(key: key);

  @override
  _PublicationSubcategoriesPageState createState() => _PublicationSubcategoriesPageState();
}

class _PublicationSubcategoriesPageState extends State<PublicationSubcategoriesPage> {
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
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                    return PublicationsItemsPage(
                      category: widget.category,
                      year: year,
                    );
                  },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
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
