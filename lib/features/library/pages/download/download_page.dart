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

import '../../../../app/services/global_key_service.dart';
import '../../../../data/repositories/PublicationRepository.dart';
import '../../../../data/databases/catalog.dart';
import '../../../publication/pages/menu/local/publication_menu_view.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  bool _isLoading = true;

  // Données pré-calculées pour éviter les recalculs dans build
  Map<String, List<Publication>> _groupedPublications = {};
  Map<String, List<Map<String, dynamic>>> _groupedMedias = {};
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
    File mediasCollectionsFile = await getMediaCollectionsDatabaseFile();
    if (await mediasCollectionsFile.exists()) {
      Database mediaCollectionsDB = await openReadOnlyDatabase(mediasCollectionsFile.path);

      List<Map<String, dynamic>> resultAudios = await mediaCollectionsDB.rawQuery('''
        SELECT MediaKey.*, Audio.* FROM MediaKey JOIN Audio ON MediaKey.MediaKeyId = Audio.MediaKeyId
      ''');

      List<Map<String, dynamic>> resultVideos = await mediaCollectionsDB.rawQuery('''
        SELECT MediaKey.*, Video.* FROM MediaKey JOIN Video ON MediaKey.MediaKeyId = Video.MediaKeyId
      ''');

      _groupedMedias = {
        if (resultAudios.isNotEmpty) 'Audios': resultAudios.map((a) => {...a, 'isDownload': 1}).toList(),
        if (resultVideos.isNotEmpty) 'Videos': resultVideos.map((v) => {...v, 'isDownload': 1}).toList(),
      };

      mediaCollectionsDB.close();
    }
  }

  Future<void> _loadAndGroupPublications() async {
    // Tri et groupement des publications - fait une seule fois
    List<Publication> sortedPublications = List.from(PublicationRepository().getAllDownloadedPublications())
      ..sort((a, b) => a.category.id.compareTo(b.category.id));

    _groupedPublications = {};
    for (Publication pub in sortedPublications) {
      final categoryName = pub.category.getName(context);
      _groupedPublications.putIfAbsent(categoryName, () => []).add(pub);
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
        // Bouton d'import
        OutlinedButton.icon(
          onPressed: _importJwpub,
          icon: const Icon(JwIcons.publications_pile),
          label: Text(localization(context).import_jwpub.toUpperCase()),
          style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
        ),
        const SizedBox(height: 10),

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
      return _buildSection<Map<String, dynamic>>(
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

  Widget _buildCategoryButton(BuildContext context, Publication publication) {
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
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (publication.issueTitle.isEmpty && publication.coverTitle.isEmpty)
                        Text(
                          publication.title,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      Text(
                        '${publication.year} · ${publication.symbol}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
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
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).brightness == Brightness.dark
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

  Widget _buildMediaButton(BuildContext context, Map<String, dynamic> publication) {
    final imageSqr = publication['ImagePath'] ?? '';
    final title = publication['Title'] ?? '';
    final mepsLanguage = publication['MepsLanguage'] ?? '';

    return SizedBox(
      width: _itemWidth,
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
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        mepsLanguage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
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
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFc3c3c3)
                    : const Color(0xFF626262),
              ),
              itemBuilder: (BuildContext context) {
                return [
                  // Ajoutez vos éléments de menu ici si nécessaire
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
          if (file.path.endsWith('.jwpub')) {
            Publication jwpub = await jwpubUnzip(file.readAsBytesSync());
            if (f == result.files.last) {
              PubCatalog.updateCatalogCategories();
              // Recharger les données après import
              _isLoading = true;
              setState(() {});
              await _loadData();

              if (jwpub.symbol == 'S-34') {
                GlobalKeyService.meetingsKey.currentState?.refreshMeetingsPubs();
              }
              showPage(context, PublicationMenuView(publication: jwpub));
            }
          }
        }
      }
    });
  }

  // Méthode pour recharger les données depuis l'extérieur si nécessaire
  Future<void> refreshData() async {
    _isLoading = true;
    setState(() {});
    await _loadData();
  }
}