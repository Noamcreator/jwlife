import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_jwpub.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/PublicationRepository.dart';
import '../../../../data/databases/catalog.dart';
import '../../../meetings/pages/meeting_page.dart';
import '../../../publication/pages/menu/local/publication_menu_view.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late Future<void> _loadingFuture;
  String categoryName = '';
  String language = '';
  Map<String, List<Map<String, dynamic>>> groupedMedias = {};

  @override
  void initState() {
    super.initState();
    _loadingFuture = loadItems();
  }

  Future<void> loadItems() async {
    // Chargement des médias
    File mediasCollectionsFile = await getMediaCollectionsFile();
    if (await mediasCollectionsFile.exists()) {
      Database mediaCollectionsDB = await openReadOnlyDatabase(mediasCollectionsFile.path);

      List<Map<String, dynamic>> resultAudios = await mediaCollectionsDB.rawQuery('''
        SELECT MediaKey.*, Audio.* FROM MediaKey JOIN Audio ON MediaKey.MediaKeyId = Audio.MediaKeyId
      ''');

      List<Map<String, dynamic>> resultVideos = await mediaCollectionsDB.rawQuery('''
        SELECT MediaKey.*, Video.* FROM MediaKey JOIN Video ON MediaKey.MediaKeyId = Video.MediaKeyId
      ''');

      groupedMedias = {
        if (resultAudios.isNotEmpty) 'Audios': resultAudios.map((a) => {...a, 'isDownload': 1}).toList(),
        if (resultVideos.isNotEmpty) 'Videos': resultVideos.map((v) => {...v, 'isDownload': 1}).toList(),
      };

      mediaCollectionsDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        else if (snapshot.hasError) {
          return Center(child: Text("Une erreur est survenue"));
        }

        return buildContent();
      },
    );
  }

  Widget buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth > 800 ? (screenWidth / 2 - 16) : screenWidth;

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: 3, // Vous pouvez ajuster cela en fonction du nombre de sections à afficher
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return OutlinedButton.icon(
              onPressed: _importJwpub,
              icon: const Icon(JwIcons.publications_pile),
              label: Text(localization(context).import_jwpub.toUpperCase()),
              style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
            );
          case 1:
            return buildPublicationSections(itemWidth);
          case 2:
            return buildMediaSections(groupedMedias, itemWidth);
          default:
            return SizedBox(); // Par sécurité si l'index dépasse les options
        }
      },
    );
  }

  Widget buildPublicationSections(double itemWidth) {
    // On trie d'abord les publications par category.id
    List<Publication> sortedPublications = List.from(PublicationRepository().getAllDownloadedPublications())
      ..sort((a, b) => a.category.id.compareTo(b.category.id));

    // On les groupe ensuite par nom de catégorie
    Map<String, List<Publication>> groupedPublications = {};
    for (Publication pub in sortedPublications) {
      groupedPublications.putIfAbsent(pub.category.getName(context), () => []).add(pub);
    }

    // On construit les sections
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: groupedPublications.entries.map((entry) {
        return buildSection<Publication>(
          entry.key,
          entry.value,
          itemWidth,
          _buildCategoryButton,
        );
      }).toList(),
    );
  }

  Widget buildMediaSections(Map<String, List<Map<String, dynamic>>> groupedMedias, double itemWidth) {
    return Wrap(
      spacing: 8.0, // Espacement horizontal entre les éléments
      runSpacing: 8.0, // Espacement vertical entre les lignes
      children: groupedMedias.entries.map((entry) {
        return buildSection<Map<String, dynamic>>(entry.key, entry.value, itemWidth, _buildMediaButton);
      }).toList(),
    );
  }

  Widget buildSection<T>(String title, List<T> items, double itemWidth, Widget Function(BuildContext, T, double) buildItem) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Text(
              title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 3.0,
            runSpacing: 3.0,
            children: items.map((item) {
              return GestureDetector(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF292929)
                        : Colors.white,
                  ),
                  child: buildItem(context, item, itemWidth),
                ),
                onTap: () {
                  // Exemple pour la publication, vous pouvez adapter pour d'autres types d'éléments
                  if (item is Publication) {
                    showPage(context, PublicationMenuView(publication: item));
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, Publication publication, double itemWidth) {
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
                  imageUrl: publication.imageSqr,
                  pathNoImage: publication.category.image,
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
                      if (publication.issueTitle.isNotEmpty)
                        Text(
                          publication.issueTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc3c3c3)
                                : const Color(0xFF626262),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (publication.coverTitle.isNotEmpty)
                        Text(
                          publication.coverTitle,
                          style: TextStyle(
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty)
                        Text(
                          publication.title,
                          style: TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Spacer(),
                      Text(
                        '${publication.year} · ${publication.symbol}',
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
              icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFc3c3c3)
                  : const Color(0xFF626262),
              ),
              itemBuilder: (BuildContext context) {
                return [
                  getPubShareMenuItem(publication),
                  getPubLanguagesItem(context, "Autres langues", publication),
                  getPubFavoriteItem(publication),
                  getPubDownloadItem(context, publication),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton(BuildContext context, Map<String, dynamic> publication, double itemWidth) {
    var imageSqr = publication['ImagePath'] ?? '';
    var title = publication['Title'] ?? '';

    //var categoryImage = initializeCategories(context).firstWhere((category) => category['type'] == publication['PublicationType'] || category['type2'] == publication['PublicationType'])['image'];

    return SizedBox(
      width: itemWidth,
      height: 80,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                  imageUrl: imageSqr,
                  pathNoImage: '',
                  height: 80,
                  width: 80,
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
                      Text(
                        title,
                        style: TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      Text(
                        '${publication['MepsLanguage']}',
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
                  //getPubShareMenuItem(publication),
                  //getPubLanguagesItem(context, "Autres langues", publication),
                  //getPubFavoriteItem(publication),
                  //getPubDownloadItem(context, publication, update: loadItems),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  void _importJwpub() {
    FilePicker.platform.pickFiles(allowMultiple: true).then((result) async {
      if (result != null) {
        for (PlatformFile f in result.files) {
          File file = File(f.path!);
          if(file.path.endsWith('.jwpub')) {
            Publication jwpub = await jwpubUnzip(file.readAsBytesSync(), context);
            if (f == result.files.last) {
              PubCatalog.updateCatalogCategories();
              loadItems();
              if(jwpub.symbol == 'S-34') {
                MeetingsPage.refreshMeetingsPubs();
              }
              showPage(context, PublicationMenuView(publication: jwpub));
            }
          }
        }
      }
    });
  }
}