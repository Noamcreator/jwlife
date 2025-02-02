import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_publication.dart';
import 'package:jwlife/l10n/localization.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_local.dart';
import 'package:jwlife/modules/library/views/publication/publications_view.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:sqflite/sqflite.dart';


class DownloadView extends StatefulWidget {
  const DownloadView({Key? key}) : super(key: key);

  @override
  _DownloadViewState createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  String categoryName = '';
  String language = '';
  List<Map<String, dynamic>> groupedPublications = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    File pubCollectionsFile = await getPubCollectionsFile();
    File userdataFile = await getUserdataFile();

    if (await pubCollectionsFile.exists()) {
      Database pubCollectionsDB = await openReadOnlyDatabase(pubCollectionsFile.path);

      await pubCollectionsDB.execute("ATTACH DATABASE '${userdataFile.path}' AS userdata");

      List<Map<String, dynamic>> result = await pubCollectionsDB.rawQuery('''
    SELECT DISTINCT
      Publication.*,
      PublicationIssueProperty.Title AS IssueTitle,
      PublicationIssueProperty.CoverTitle AS CoverTitle,
      (SELECT Image.Path
       FROM Image
       WHERE Image.Width = 600 AND Image.Height = 600 AND Image.Type = 't'
       AND Image.PublicationId = Publication.PublicationId
       LIMIT 1) AS ImageSqr,
       (SELECT Image.Path
       FROM Image
       WHERE Image.Width = 1200 AND Image.Height = 600 AND Image.Type = 'lsr'
       AND Image.PublicationId = Publication.PublicationId
       LIMIT 1) AS ImageLsr,
       (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
        FROM userdata.TagMap tg
        JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
        WHERE userdata.Location.IssueTagNumber = Publication.IssueTagNumber
        AND userdata.Location.KeySymbol = Publication.KeySymbol
        AND userdata.Location.MepsLanguage = Publication.MepsLanguageId
        AND tg.TagId = 1) AS isFavorite
    FROM 
      Publication
    LEFT JOIN PublicationIssueProperty ON PublicationIssueProperty.PublicationId = Publication.PublicationId  
    ORDER BY Publication.PublicationType
''');

      List<Map<String, dynamic>> publications = [];
      for(var publication in result) {
        print(publication);
        Map<String, dynamic> pub = Map.from(publication);
        pub['isDownload'] = 1;
        publications.add(pub);
      }

      setState(() {
        groupedPublications = publications;
      });

      pubCollectionsDB.execute("DETACH DATABASE userdata");
      pubCollectionsDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth > 800 ? (screenWidth / 2 - 16) : screenWidth;

    // Grouper les publications par PublicationCategorySymbol
    Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
    for (var pub in groupedPublications) {
      Map<String, dynamic> category = initializeCategories(context).firstWhere(
              (p) => p['type'] == pub['PublicationType'] || p['type2'] == pub['PublicationType'],
          orElse: () => {'type': 'Other', 'name': 'Autres', "image": "pub_type_pending_update"}
      );

      String categorySymbol = category['name'];
      if (!groupedByCategory.containsKey(categorySymbol)) {
        groupedByCategory[categorySymbol] = [];
      }
      groupedByCategory[categorySymbol]!.add(pub);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Column(children: [
        OutlinedButton.icon(
          onPressed: _importJwpub,
          icon: const Icon(JwIcons.document_plus_circle),
          label: Text(localization(context).import_jwpub.toUpperCase()),
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(),
          ),
        ),
        const SizedBox(height: 10.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groupedByCategory.entries.map((entry) {
            String categorySymbol = entry.key;
            List<Map<String, dynamic>> publications = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre de la catégorie (PublicationType)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
                  child: Text(
                    categorySymbol, // Utilisez PublicationType ici si disponible
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
                // Liste des publications sous la catégorie
                Wrap(
                    spacing: 3.0,
                    runSpacing: 3.0,
                    children: publications.map((publication) {
                      return GestureDetector(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF292929)
                                : Colors.white,
                          ),
                          child: _buildCategoryButton(context, publication, itemWidth),
                        ),
                        onTap: () {
                          showPage(context, PublicationMenuLocal(publication: publication));
                        },
                      );
                    }).toList()
                )
              ],
            );
          }).toList(),
        ),
      ],
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, Map<String, dynamic> publication, double itemWidth) {
    var imageSqr = publication['ImageSqr'] ?? '';
    var title = publication['Title'] ?? '';
    var issueTitle = publication['IssueTitle'] ?? '';
    var coverTitle = publication['CoverTitle'] ?? '';
    var year = publication['Year'] ?? '';

    var categoryImage = initializeCategories(context).firstWhere((category) => category['type'] == publication['PublicationType'] || category['type2'] == publication['PublicationType'])['image'];

    return SizedBox(
      width: itemWidth,
      height: 85,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                  imageUrl: imageSqr,
                  pathNoImage: categoryImage,
                  height: 85,
                  width: 85,
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 20.0, top: 4.0, bottom: 4.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (issueTitle.isNotEmpty)
                          Text(
                            issueTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFc3c3c3)
                                  : const Color(0xFF626262),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (coverTitle.isNotEmpty)
                          Text(
                            coverTitle,
                            style: TextStyle(
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (issueTitle.isEmpty && coverTitle.isEmpty)
                          Text(
                            title,
                            style: TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Spacer(),
                        Text(
                          '$year · ${publication['Symbol']}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFc3c3c3)
                              : const Color(0xFF626262),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -5,
            right: -10,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ?
              const Color(0xFFc3c3c3)
                  : const Color(0xFF626262),
              ),
              itemBuilder: (BuildContext context) {
                return [
                  getPubShareMenuItem(publication),
                  getPubLanguagesItem(context, "Autres langues", publication),
                  getPubFavoriteItem(publication),
                  getPubDownloadItem(context, publication, update: loadItems),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  void _importJwpub() {
    FilePicker.platform.pickFiles(
      allowMultiple: true,
    ).then((result) async {
      if (result != null) {
        for (PlatformFile f in result.files) {
          File file = File(f.path!);
          if(file.path.endsWith('.jwpub')) {
            Map<String, dynamic> jwpub = await jwpubUnzip(file, context);
            if (f == result.files.last) {
              loadItems();
              showPage(context, PublicationMenuLocal(publication: jwpub));
            }
          }
        }
      }
    });
  }
}