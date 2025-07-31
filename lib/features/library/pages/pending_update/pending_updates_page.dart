import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../publication/pages/menu/local/publication_menu_view.dart';

class PendingUpdatesPage extends StatefulWidget {
  const PendingUpdatesPage({super.key});

  @override
  _PendingUpdatesPageState createState() => _PendingUpdatesPageState();
}

class _PendingUpdatesPageState extends State<PendingUpdatesPage> {
  late Future<void> _loadingFuture;
  String categoryName = '';
  String language = '';
  Map<String, List<Publication>> groupedPublications = {};
  Map<String, List<Map<String, dynamic>>> groupedMedias = {};

  @override
  void initState() {
    super.initState();
    _loadingFuture = loadItems();
  }

  Future<void> loadItems() async {
    // Chargement des publications
    File pubCollectionsFile = await getPubCollectionsFile();
    File catalogFile = await getCatalogFile();
    File mepsFile = await getMepsFile();

    if (await pubCollectionsFile.exists()) {
      Database pubCollectionsDB = await openReadOnlyDatabase(pubCollectionsFile.path);
      await pubCollectionsDB.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
      await pubCollectionsDB.execute("ATTACH DATABASE '${catalogFile.path}' AS catalog");

      List<Map<String, dynamic>> result = await pubCollectionsDB.rawQuery('''
        SELECT DISTINCT
          p.*,
          pa.ExpandedSize,
          pa.LastModified,
          pip.Title AS IssueTitle,
          pip.CoverTitle AS CoverTitle,
          l.Symbol AS LanguageSymbol,
          l.VernacularName AS LanguageVernacularName,
          l.PrimaryIetfCode AS LanguagePrimaryIetfCode,
          (SELECT img.Path 
           FROM Image img
           WHERE img.Type = 't' 
             AND img.PublicationId = p.PublicationId 
           ORDER BY img.Width DESC, img.Height DESC 
           LIMIT 1) AS ImageSqr,
          (SELECT img.Path 
           FROM Image img
           WHERE img.Width = 1200 
             AND img.Height = 600 
             AND img.Type = 'lsr' 
             AND img.PublicationId = p.PublicationId 
           LIMIT 1) AS ImageLsr
        FROM Publication p
        LEFT JOIN PublicationIssueProperty pip ON pip.PublicationId = p.PublicationId
        LEFT JOIN meps.Language l ON p.MepsLanguageId = l.LanguageId
        LEFT JOIN catalog.Publication cp 
          ON p.MepsLanguageId = cp.MepsLanguageId 
          AND p.Symbol = cp.Symbol 
          AND p.IssueTagNumber = cp.IssueTagNumber
        LEFT JOIN catalog.PublicationAsset pa ON cp.Id = pa.PublicationId
        WHERE STRFTIME('%Y-%m-%d %H:%M:%S', pa.LastModified) > STRFTIME('%Y-%m-%d %H:%M:%S', p.Timestamp)
        ORDER BY p.PublicationType
      ''');

      setState(() {
        groupedPublications = {};
        for (var pub in result) {
          Publication publication = Publication.fromJson(pub);
          groupedPublications.putIfAbsent(publication.category.getName(context), () => []).add(publication);
        }
      });

      await pubCollectionsDB.execute("DETACH DATABASE catalog");
      await pubCollectionsDB.execute("DETACH DATABASE meps");
      await pubCollectionsDB.close();
    }

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
        } else if (snapshot.hasError) {
          return Center(child: Text("Une erreur est survenue"));
        }

        return groupedPublications.isEmpty && groupedMedias.isEmpty ? Center(child: Text('Pas de mise à jour en attente', style: Theme.of(context).textTheme.titleLarge)) : buildContent();
      },
    );
  }

  Widget buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth > 800 ? (screenWidth / 2 - 16) : screenWidth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Column(children: [
        buildPublicationSections(groupedPublications, itemWidth),
        buildMediaSections(groupedMedias, itemWidth),
      ]),
    );
  }

  Widget buildPublicationSections(Map<String, List<Publication>> groupedByCategory, double itemWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedByCategory.entries.map((entry) {
        return buildSection(entry.key, entry.value, itemWidth, _buildCategoryButton);
      }).toList(),
    );
  }

  Widget buildMediaSections(Map<String, List<Map<String, dynamic>>> groupedMedias, double itemWidth) {
    return Column();
    /*
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedMedias.entries.map((entry) {
        return buildSection(entry.key, entry.value, itemWidth, _buildMediaButton);
      }).toList(),
    );

     */
  }

  Widget buildSection(String title, List<Publication> items, double itemWidth, Function(BuildContext, Publication, double) buildItem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
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
                showPage(context, PublicationMenuView(publication: item));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(BuildContext context, Publication publication, double itemWidth) {
    // Gestion des dates : Version actuelle
    String? lastModified = publication.lastModified;
    String formattedDate = "N/A";  // Valeur par défaut

    if (lastModified != null) {
      lastModified = lastModified.replaceAll('+00:00', 'Z'); // Normalisation du format
      try {
        formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(lastModified));  // Formatage de la date
      } catch (e) {
        printTime("Erreur lors du formatage de la date : $e");
      }
    }

    // Gestion des dates : Version téléchargée
    String? downloadedDateStr = publication.timeStamp;  // Par exemple, publication.downloadedDate
    String downloadedDate = "N/A";  // Valeur par défaut

    downloadedDateStr = downloadedDateStr!.replaceAll('+00:00', 'Z'); // Normalisation du format
    try {
      downloadedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(downloadedDateStr));  // Formatage de la date
    } catch (e) {
      printTime("Erreur lors du formatage de la date téléchargée : $e");
    }

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Version téléchargée : $downloadedDate',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFc3c3c3)
                                  : const Color(0xFF626262),
                              ),
                            ),
                            Text(
                              'Mise à jour disponible : $formattedDate',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFc3c3c3)
                                  : const Color(0xFF626262),
                              ),
                            ),
                          ],
                        )
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
              icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFc3c3c3) : Color(0xFF626262),
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
          publication.progressNotifier.value == 0 ? Positioned(
            bottom: 5,
            right: -8,
            height: 45,
            child: IconButton(
              padding: const EdgeInsets.all(0),
              onPressed: () async {
                await publication.update(context);
                setState(() {
                  groupedPublications[publication.category.getName(context)]?.remove(publication);
                  if(groupedPublications[publication.category.getName(context)]!.isEmpty) groupedPublications.remove(publication.category.getName(context));
                });
              },
              icon: Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
            ),
          ) : Container(),
          publication.progressNotifier.value == 0 ? Positioned(
              bottom: 0,
              right: -5,
              width: 50,
              child: Text(
                textAlign: TextAlign.center,
                formatFileSize(publication.expandedSize),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFc3c3c3)
                      : const Color(0xFF626262),
                ),
              )
          ) : Container(),
          Positioned(
            bottom: 0,
            right: 0,
            height: 2,
            width: 340-40,
            child: publication.progressNotifier.value != 0
                ? LinearProgressIndicator(
              value: publication.progressNotifier.value == -1 ? null : publication.progressNotifier.value,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              backgroundColor: Colors.grey, // Fond gris
              minHeight: 2, // Assure que la hauteur est bien prise en compte
            )
                : Container(),
          )
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
      height: 85,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                  imageUrl: imageSqr,
                  pathNoImage: '',
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
}