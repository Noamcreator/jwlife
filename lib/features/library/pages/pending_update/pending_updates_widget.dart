import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/library/widgets/rectangle_mediaItem_item.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../data/databases/catalog.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/video.dart';
import '../../../../data/repositories/MediaRepository.dart';
import '../../../../i18n/i18n.dart';
import '../../../publication/pages/local/publication_menu_view.dart';

class PendingUpdatesWidget extends StatefulWidget {
  const PendingUpdatesWidget({super.key});

  @override
  _PendingUpdatesWidgetState createState() => _PendingUpdatesWidgetState();
}

class _PendingUpdatesWidgetState extends State<PendingUpdatesWidget> {
  bool _isLoading = true;

  Map<String, List<Publication>> _groupedPublications = {};
  Map<String, List<Media>> _groupedMedias = {};
  double _itemWidth = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Chargement des médias
      await _loadMedias();

      // Pré-calcul des publications groupées
      await _loadAndGroupPublications();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Gestion d'erreur
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMedias() async {
    List<Media> mediasDownload = List.from(MediaRepository().getAllDownloadedMedias());
    List<Audio> audiosDownload = mediasDownload.whereType<Audio>().toList();
    List<Video> videosDownload = mediasDownload.whereType<Video>().toList();

    _groupedMedias = {
      if (audiosDownload.isNotEmpty) 'Audios': audiosDownload.toList(),
      if (videosDownload.isNotEmpty) 'Videos': videosDownload.toList(),
    };
  }

  Future<void> _loadAndGroupPublications() async {
    File pubCollectionsFile = await getPubCollectionsDatabaseFile();
    File mepsFile = await getMepsUnitDatabaseFile();

    if (await pubCollectionsFile.exists()) {
      Database pubCollectionsDB = await openReadOnlyDatabase(
          pubCollectionsFile.path);
      await pubCollectionsDB.execute(
          "ATTACH DATABASE '${mepsFile.path}' AS meps");
      await pubCollectionsDB.execute(
          "ATTACH DATABASE '${CatalogDb.instance.database.path}' AS catalog");

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
          AND p.KeySymbol = cp.KeySymbol 
          AND p.IssueTagNumber = cp.IssueTagNumber
        LEFT JOIN catalog.PublicationAsset pa ON cp.Id = pa.PublicationId
        WHERE STRFTIME('%Y-%m-%d %H:%M:%S', pa.LastModified) > STRFTIME('%Y-%m-%d %H:%M:%S', p.Timestamp)
        ORDER BY p.PublicationType
      ''');

      setState(() {
        _groupedPublications = {};
        for (var pub in result) {
          Publication publication = Publication.fromJson(pub);
          _groupedPublications.putIfAbsent(
              publication.category.getName(), () => []).add(publication);
        }
      });

      await pubCollectionsDB.execute("DETACH DATABASE catalog");
      await pubCollectionsDB.execute("DETACH DATABASE meps");
      await pubCollectionsDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de la largeur une seule fois
    if (_itemWidth == 0) {
      final screenWidth = MediaQuery.of(context).size.width;
      _itemWidth = screenWidth > 800 ? (screenWidth / 2 - 16) : screenWidth;
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildContent();
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: [
        // Sections des publications
        if (_groupedPublications.isNotEmpty) ..._buildPublicationSections(),

        // Sections des médias
        if (_groupedMedias.isNotEmpty) ..._buildMediaSections(),
      ],
    );
  }

  List<Widget> _buildPublicationSections() {
    return _groupedPublications.entries.map((entry) {
      return _buildSection<Publication>(
        entry.key,
        entry.value,
        _buildCategoryButton,
      );
    }).toList();
  }

  List<Widget> _buildMediaSections() {
    return _groupedMedias.entries.map((entry) {
      return _buildSection<Media>(
        entry.key,
        entry.value,
        _buildMediaButton,
      );
    }).toList();
  }
  Widget _buildSection<T>(
      String title,
      List<T> items,
      Widget Function(BuildContext, T) buildItem,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  child: buildItem(context, item),
                ),
                onTap: () {
                  if (item is Publication) {
                    showPage(PublicationMenuView(publication: item));
                  }
                  else if (item is Media) {
                    item.showPlayer(context);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, Publication publication) {
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
      width: _itemWidth,
      height: 85,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                  imageUrl: publication.imageSqr,
                  icon: publication.category.icon,
                  height: 85,
                  width: 85,
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10.0, end: 20.0, top: 4.0, bottom: 4.0),
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
          PositionedDirectional(
            top: -5,
            end: -10,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFc3c3c3) : Color(0xFF626262),
              ),
              itemBuilder: (BuildContext context) {
                return [
                  getPubShareMenuItem(publication),
                  getPubQrCodeMenuItem(context, publication),
                  getPubLanguagesItem(context, i18n().label_languages_more, publication),
                  getPubFavoriteItem(publication),
                  getPubDownloadItem(context, publication),
                ];
              },
            ),
          ),
          publication.progressNotifier.value == 0 ? PositionedDirectional(
            bottom: 5,
            end: -8,
            height: 45,
            child: IconButton(
              padding: const EdgeInsets.all(0),
              onPressed: () async {
                await publication.update(context);
                setState(() {
                  _groupedPublications[publication.category.getName()]?.remove(publication);
                  if(_groupedPublications[publication.category.getName()]!.isEmpty) _groupedPublications.remove(publication.category.getName());
                });
              },
              icon: Icon(JwIcons.arrows_circular, color: Color(0xFF9d9d9d)),
            ),
          ) : Container(),
          publication.progressNotifier.value == 0 ? PositionedDirectional(
              bottom: 0,
              end: -5,
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
          PositionedDirectional(
            bottom: 0,
            end: 0,
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

  Widget _buildMediaButton(BuildContext context, Media media) {
    return RectangleMediaItemItem(media: media);
  }
}