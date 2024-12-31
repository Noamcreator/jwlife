import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/publication_pages/online/publication_menu.dart';
import 'package:jwlife/pages/library_pages/publication_pages/local/publication_menu_local.dart';
import 'package:jwlife/pages/library_pages/publication_pages/publications_page.dart';
import 'package:sqflite/sqflite.dart';

import '../../../jwlife.dart';
import '../../../utils/files_helper.dart';
import '../../../utils/icons.dart';
import '../../../utils/utils_jwpub.dart';
import '../../../utils/utils_publication.dart';
import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/image_widget.dart';
import '../publication_pages/publications_items_page.dart';

class PublicationDownload extends StatefulWidget {
  PublicationDownload({Key? key}) : super(key: key);

  @override
  _PublicationDownloadState createState() => _PublicationDownloadState();
}

class _PublicationDownloadState extends State<PublicationDownload> {
  String categoryName = '';
  String language = '';
  List<Map<String, dynamic>> groupedPublications = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems() async {
    File pubCollectionsFile = await getPubCollectionsFile();

    if (await pubCollectionsFile.exists()) {
      Database pubCollectionsDB = await openReadOnlyDatabase(
          pubCollectionsFile.path);

      List<Map<String, dynamic>> result = await pubCollectionsDB.rawQuery('''
    SELECT DISTINCT
      Publication.*,
      (SELECT Image.Path
       FROM Image
       WHERE Image.Width = 600 AND Image.Height = 600 AND Image.Type = 't'
       AND Image.PublicationId = Publication.PublicationId
       LIMIT 1) AS ImageSqr,
       (SELECT Image.Path
       FROM Image
       WHERE Image.Width = 1200 AND Image.Height = 600 AND Image.Type = 'lsr'
       AND Image.PublicationId = Publication.PublicationId
       LIMIT 1) AS ImageLsr
    FROM 
      Publication
    ORDER BY Publication.PublicationType
''');

      List<Map<String, dynamic>> publications = [];
      for(var publication in result) {
        Map<String, dynamic> pub = Map.from(publication);
        print('pub: $pub');
        pub['isDownload'] = true;
        pub['isFavorite'] = await JwLifeApp.userdata.isPubFavorite(publication);
        publications.add(pub);
      }

        setState(() {
          groupedPublications = publications;
        });

      pubCollectionsDB.close();
      }
    }

  @override
  Widget build(BuildContext context) {
    // Grouper les publications par PublicationCategorySymbol
    Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
    for (var pub in groupedPublications) {
      Map<String, dynamic> category = categories.firstWhere((p) => p['type'] == pub['PublicationType']);

      String categorySymbol = category != null ? category['name'] : 'Autre';
      if (!groupedByCategory.containsKey(categorySymbol)) {
        groupedByCategory[categorySymbol] = [];
      }
      groupedByCategory[categorySymbol]!.add(pub);
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _importJwpub,
                icon: const Icon(JwIcons.document_plus_circle),
                label: const Text("IMPORTER JWPUB"),
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            child: Column(
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
                    ...publications.map((publication) {
                      return GestureDetector(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 1.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF292929)
                                : Colors.white,
                          ),
                          child: _buildCategoryButton(context, publication),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                return PublicationMenuLocal(publication: publication);
                              },
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCategoryButton(BuildContext context, Map<String, dynamic> publication) {
    var imageSqr = publication['ImageSqr'] ?? '';
    print('imageSqr: $imageSqr');
    var title = publication['Title'] ?? '';
    var issueTitle = publication['IssueTitle'] ?? '';
    var coverTitle = publication['CoverTitle'] ?? '';
    var year = publication['Year'] ?? '';

    return SizedBox(
      height: 85,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                  imageUrl: imageSqr,
                  pathNoImage: categories.firstWhere((category) => category['type'] == publication['PublicationType'])['image'],
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
                          '$year - ${publication['Symbol']}',
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
                  getPubDownloadItem(context, publication)
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
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                    return PublicationMenuLocal(publication: jwpub);
                  },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            }
          }
        }
      }
    });
  }
}