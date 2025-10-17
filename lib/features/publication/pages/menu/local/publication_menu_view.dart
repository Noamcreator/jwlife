import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/html_styles.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/features/publication/pages/menu/local/publication_search_view.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../../../../app/services/global_key_service.dart';
import '../../../../../app/services/settings_service.dart';
import '../../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../../core/utils/utils_language_dialog.dart';
import '../../../../bible/pages/local_bible_chapter.dart';
import '../../../../image/image_page.dart';
import '../../document/data/models/document.dart';
import '../../document/local/documents_manager.dart';

class ListItem {
  final String displayTitle;
  final String landscapeDisplayTitle;
  final String title;
  final String subTitle;
  final String imageFilePath;
  final String? dataType;
  final int mepsDocumentId;
  final bool isTitle; // Pour savoir si c'est un titre avec des sous-éléments
  final bool isBibleBooks;
  final int? groupId;
  final int? bibleBookId;
  final bool showImage;
  final List<ListItem> subItems; // Liste des sous-éléments (si applicable)

  ListItem({
    this.displayTitle = '',
    this.landscapeDisplayTitle = '',
    this.title = '',
    this.subTitle = '',
    this.imageFilePath = '',
    this.dataType,
    this.mepsDocumentId = -1,
    this.isTitle = false,
    this.isBibleBooks = false,
    this.groupId,
    this.bibleBookId,
    this.showImage = true,
    this.subItems = const [],
  });
}

class TabWithItems {
  final Map<String, dynamic> tab;
  final List<ListItem> items;

  TabWithItems({required this.tab, required this.items});
}

class PublicationMenuView extends StatefulWidget {
  final Publication publication;
  final bool showAppBar;
  final bool biblePage;

  const PublicationMenuView({super.key, required this.publication, this.showAppBar = true, this.biblePage = false});

  @override
  PublicationMenuViewState createState() => PublicationMenuViewState();
}

class PublicationMenuViewState extends State<PublicationMenuView> with SingleTickerProviderStateMixin {
  late DocumentsManager _documentsManager;
  late List<TabWithItems> _tabsWithItems = [];
  bool _isLoading = true;
  TabController? _tabController;
  int _initialTabIndex = 0;

  bool _isSearching = false;
  List<Map<String, dynamic>> suggestions = [];

  bool multimediaExists = false;
  bool documentMultimediaExists = false;
  bool hasMultimediaColumns = false;

  @override
  void initState() {
    super.initState();
    _init();
    _iniAudio();
  }

  // Méthode pour initialiser la base de données
  Future<void> _init() async {
    if(widget.publication.documentsManager == null) {
      _documentsManager = DocumentsManager(publication: widget.publication, mepsDocumentId: -1);
    }
    else {
      _documentsManager = widget.publication.documentsManager!;
    }

    await _documentsManager.initializeDatabaseAndData();
    widget.publication.documentsManager = _documentsManager;
    await _fetchItems();
  }

  Future<void> _iniAudio() async {
    await widget.publication.fetchAudios();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchItems() async {
    try {
      List<Map<String, dynamic>> tabs = await _documentsManager.database.rawQuery('''
        SELECT 
          pvi.PublicationViewItemId,
          pvi.Title,
          COALESCE(
              CASE 
                  WHEN pvi.ChildTemplateSchemaType != pvi.SchemaType 
                  THEN cvs.DataType
              END,
              vs.DataType
          ) AS DataType
      FROM PublicationView pv
      INNER JOIN PublicationViewItem pvi 
          ON pvi.PublicationViewId = pv.PublicationViewId
         AND pvi.ParentPublicationViewItemId = -1
      LEFT JOIN (
          SELECT SchemaType, MIN(DataType) AS DataType
          FROM PublicationViewSchema
          GROUP BY SchemaType
      ) vs ON pvi.SchemaType = vs.SchemaType
      LEFT JOIN (
          SELECT SchemaType, MIN(DataType) AS DataType
          FROM PublicationViewSchema
          GROUP BY SchemaType
      ) cvs ON pvi.ChildTemplateSchemaType = cvs.SchemaType
            AND pvi.ChildTemplateSchemaType != pvi.SchemaType
      WHERE pv.Symbol = 'jwpub';
      ''');

      // Vérifications en parallèle
      final List<bool> results = await Future.wait([
        _checkIfTableExists('Multimedia'),
        _checkIfTableExists('DocumentMultimedia'),
      ]);

      multimediaExists = results[0];
      documentMultimediaExists = results[1];

      // Vérification des colonnes
      hasMultimediaColumns = multimediaExists && (await _getColumnsForTable('Multimedia')).contains('CategoryType');

      // Récupérer tous les items pour chaque onglet en parallèle
      final allItemsPerTab = await Future.wait(
        tabs.map((tab) => _getItemsForParent(tab['PublicationViewItemId'])).toList(),
      );

      // Construire la liste des TabWithItems
      final List<TabWithItems> tabsWithItems = [];

      for (int i = 0; i < tabs.length; i++) {
        final tab = tabs[i];
        final items = allItemsPerTab[i];
        final List<ListItem> itemList = [];

        for (final item in items) {
          // Vérifie que l'item n'est pas un sous-élément d'un autre
          if (!items.any((subItem) => subItem['PublicationViewItemId'] == item['ParentPublicationViewItemId'])) {
            if (item['DefaultDocumentId'] == -1) {
              final subItems = items.where((subItem) => subItem['ParentPublicationViewItemId'] == item['PublicationViewItemId']).toList();
              final bool isBibleBooks = subItems.any((subItem) => subItem['Type'] == 2);

              if (isBibleBooks && _initialTabIndex == 0) {
                _initialTabIndex = items.indexOf(item);
              }

              itemList.add(
                ListItem(
                  title: item['DisplayTitle'],
                  isTitle: true,
                  isBibleBooks: isBibleBooks,
                  showImage: false,
                  subItems: subItems.map(_mapToListItem).toList(),
                ),
              );
            } else {
              itemList.add(_mapToListItem(item));
            }
          }
        }

        tabsWithItems.add(TabWithItems(tab: tab, items: itemList));
      }

      // Met à jour l'état
      if (mounted) {
        setState(() {
          _tabsWithItems = tabsWithItems;
          _tabController = TabController(
            initialIndex: _initialTabIndex,
            length: _tabsWithItems.length,
            vsync: this,
          );
          _isLoading = false;
        });
      }
    }
    catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      throw Exception('Erreur lors de la récupération des données : $e');
    }
  }

  Future<bool> _checkIfTableExists(String tableName) async {
    var result = await _documentsManager.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]);
    return result.isNotEmpty;
  }

  Future<List<String>> _getColumnsForTable(String tableName) async {
    var result = await _documentsManager.database.rawQuery("PRAGMA table_info($tableName)");
    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> _getItemsForParent(int parentId) async {
    List<Map<String, dynamic>> result = [];
    if (widget.publication.category.id != 1) {
      String query = await getPublicationItems();
      result = await _documentsManager.database.rawQuery(query, [parentId, parentId]);
    }
    else {
      result = await getBibleItems(parentId);
    }
    return result;
  }

  Future<String> getPublicationItems() async {
    final buffer = StringBuffer()
      ..writeln('SELECT')
      ..writeln('  pvi.PublicationViewItemId,')
      ..writeln('  pvi.ParentPublicationViewItemId,')
      ..writeln('  pvi.Title AS DisplayTitle,')
      ..writeln('  pvi.DefaultDocumentId,')
      ..writeln('  pvs.DataType,');

    // Ajout conditionnel FilePath
    if (hasMultimediaColumns && documentMultimediaExists && multimediaExists) {
      buffer.writeln('  MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath');
    }
    else {
      buffer.writeln('  NULL AS FilePath');
    }

    // FROM & JOINS
    buffer.writeln('FROM PublicationViewItem pvi');
    buffer.writeln('LEFT JOIN PublicationViewSchema pvs ON pvi.SchemaType = pvs.SchemaType');

    if (documentMultimediaExists) {
      buffer.writeln('LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = pvi.DefaultDocumentId');
      if (multimediaExists && hasMultimediaColumns) {
        buffer.writeln('LEFT JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId');
      }
    }

    // JOIN pour récupérer les enfants d'éléments avec DefaultDocumentId = -1
    buffer.writeln('LEFT JOIN PublicationViewItem pvx');
    buffer.writeln('  ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId');
    buffer.writeln('  AND pvx.ParentPublicationViewItemId = ?');
    buffer.writeln('  AND pvx.DefaultDocumentId = -1');

    // WHERE optimisé
    buffer.writeln('WHERE pvi.ParentPublicationViewItemId = ?');
    buffer.writeln('   OR pvx.PublicationViewItemId IS NOT NULL');

    // GROUP BY
    buffer.writeln('GROUP BY pvi.PublicationViewItemId');

    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> getBibleItems(int parentId) async {
    const query = '''
    SELECT
      pvi.PublicationViewItemId,
      pvi.ParentPublicationViewItemId,
      pvi.Title AS DisplayTitle,
      pvi.DefaultDocumentId,
      pvs.DataType,
      d.Type,
      bb.BibleBookId,
      MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath
    FROM PublicationViewItem pvi
    LEFT JOIN PublicationViewSchema pvs 
      ON pvi.SchemaType = pvs.SchemaType
    LEFT JOIN DocumentMultimedia dm 
      ON dm.DocumentId = pvi.DefaultDocumentId
    LEFT JOIN Multimedia m 
      ON dm.MultimediaId = m.MultimediaId
    LEFT JOIN Document d 
      ON d.DocumentId = pvi.DefaultDocumentId
    LEFT JOIN BibleBook bb 
      ON d.ChapterNumber = bb.BibleBookId
    LEFT JOIN PublicationViewItem pvx
      ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId
      AND pvx.ParentPublicationViewItemId = ?
      AND pvx.DefaultDocumentId = -1  
    WHERE pvi.ParentPublicationViewItemId = ? OR pvx.PublicationViewItemId IS NOT NULL
    GROUP BY 
      pvi.PublicationViewItemId,
      pvi.ParentPublicationViewItemId,
      pvi.Title,
      pvi.DefaultDocumentId,
      pvs.DataType;
  ''';

    final result = await _documentsManager.database.rawQuery(query, [parentId, parentId]);

    // Séparer les éléments Bible et non-Bible
    final bibleItems = <Map<String, dynamic>>[];
    final nonBibleItems = <Map<String, dynamic>>[];

    for (final item in result) {
      if (item['Type'] == 2) {
        bibleItems.add(item);
      } else {
        nonBibleItems.add(item);
      }
    }

    // Traiter les éléments Bible en parallèle si nécessaire
    if (bibleItems.isNotEmpty) {
      final processedBibleItems = await _processBibleItems(bibleItems);
      nonBibleItems.addAll(processedBibleItems);
    }

    return nonBibleItems;
  }

  // Méthode helper pour traiter les éléments bibliques en batch
  Future<List<Map<String, dynamic>>> _processBibleItems(List<Map<String, dynamic>> bibleItems) async {
    final mepsFile = await getMepsUnitDatabaseFile();
    final mepsDatabase = await openDatabase(mepsFile.path);

    try {
      // Collecte des IDs uniques
      final bookIds = bibleItems
          .map((item) => item['BibleBookId'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (bookIds.isEmpty) return bibleItems;

      // Requête unique pour tous les livres
      final placeholders = List.filled(bookIds.length, '?').join(',');
      final bookNamesQuery = '''
        SELECT 
          bbn.BookNumber,
          bbn.StandardBookName,
          bbn.OfficialBookAbbreviation,
          bbg.GroupId
        FROM BibleBookName bbn
        INNER JOIN BibleCluesInfo bci ON bbn.BibleCluesInfoId = bci.BibleCluesInfoId
        INNER JOIN BibleBookGroup bbg ON bbg.BookNumber = bbn.BookNumber
        WHERE bbn.BookNumber IN ($placeholders) AND bci.LanguageId = ?''';

      final bookNames = await mepsDatabase.rawQuery(
        bookNamesQuery,
        [...bookIds, widget.publication.mepsLanguage.id],
      );

      // Map pour accès rapide
      final bookNamesMap = <int, Map<String, dynamic>>{
        for (final book in bookNames) book['BookNumber'] as int: book
      };

      // Application des données
      return bibleItems.map((item) {
        final bookId = item['BibleBookId'] as int?;
        if (bookId != null && bookNamesMap.containsKey(bookId)) {
          return {...item, ...bookNamesMap[bookId]!};
        }
        return item;
      }).toList();
    }
    finally {
      await mepsDatabase.close();
    }
  }

  ListItem _mapToListItem(Map<String, dynamic> item) {
    Document document = _documentsManager.documents.firstWhere((d) =>
    d.documentId == item['DefaultDocumentId']);
    return ListItem(
      title: widget.publication.schemaVersion >= 8 ? document.type == 2 ? item['OfficialBookAbbreviation'] : document.title : item['DisplayTitle'].trim() ?? '',
      landscapeDisplayTitle: document.type == 2 ? item['StandardBookName'] : '',
      displayTitle: item['DisplayTitle'] ?? '',
      subTitle: document.contextTitle ?? document.featureTitle ?? '',
      imageFilePath: item['FilePath'] ?? '',
      dataType: item['DataType'] ?? '',
      groupId: document.type == 2 ? item['GroupId'] : -1,
      bibleBookId: item['BibleBookId'] ?? -1,
      mepsDocumentId: document.mepsDocumentId,
      isTitle: false,
    );
  }

  Future<void> goToTheBooksTab() async {
    if(_tabController != null) {
      _tabController!.animateTo(1);
    }
  }

  Widget buildNameItem(BuildContext context, bool showImage, ListItem item) {
    String subtitle = item.subTitle.replaceAll('​', '');
    bool showSubTitle = item.subTitle.isNotEmpty && subtitle != item.title;

    Audio? audio = widget.publication.audios.firstWhereOrNull((audio) => audio.documentId == item.mepsDocumentId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          showPageDocument(widget.publication, item.mepsDocumentId);
        },
        child: Stack(
          children: [
            Row(
              // ... votre code existant pour l'image, le texte et le PopupMenuButton
              spacing: 8.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Affichage de l'image
                showImage ? SizedBox(
                  width: 60.0,
                  height: 60.0,
                  child: item.imageFilePath.isNotEmpty == true
                      ? ClipRRect(
                    child: Image.file(
                      File('${widget.publication.path}/${item.imageFilePath}'),
                      fit: BoxFit.cover,
                    ),
                  )
                      : Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF4f4f4f)
                        : const Color(0xFF8e8e8e),
                  ),
                ) : Container(),
                // Affichage du texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if(showSubTitle) ...[
                        Text(
                          item.subTitle,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc0c0c0)
                                : const Color(0xFF626262),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2.0),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9fb9e3)
                              : const Color(0xFF4a6da7),
                          fontSize: showSubTitle ? 15.0 : 16.0,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Menu d'options
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8e8e8e)
                        : const Color(0xFF757575),
                  ),
                  itemBuilder: (context) {
                    List<PopupMenuEntry> items = [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(
                              JwIcons.share,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'Envoyer le lien',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          _documentsManager.getDocumentFromMepsDocumentId(item.mepsDocumentId).share(false);
                        },
                      ),
                    ];
                    if (audio != null) {
                      items.add(
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(
                                JwIcons.cloud_arrow_down,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              const SizedBox(width: 8.0),
                              ValueListenableBuilder<bool>(
                                valueListenable: audio.isDownloadingNotifier,
                                builder: (context, isDownloading, child) {
                                  return Text(
                                    isDownloading
                                        ? "Téléchargement en cours..."
                                        : audio.isDownloadedNotifier.value
                                        ? "Supprimer l'audio (${formatFileSize(audio.fileSize!)})"
                                        : "Télécharger l'audio (${formatFileSize(audio.fileSize!)})",
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            if (audio.isDownloadedNotifier.value) {
                              audio.remove(context);
                            } else {
                              audio.download(context);
                            }
                          },
                        ),
                      );

                      items.add(
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(
                                JwIcons.headphones__simple,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                "Écouter l'audio",
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            int? index = widget.publication.audios.indexWhere((audio) => audio.documentId == item.mepsDocumentId);
                            if (index != -1) {
                              showAudioPlayerPublicationLink(context, widget.publication, index);
                            }
                          },
                        ),
                      );
                    }
                    return items;
                  },
                ),
              ],
            ),
            if (audio != null)
              ValueListenableBuilder<bool>(
                valueListenable: audio.isDownloadingNotifier,
                builder: (context, isDownloading, child) {
                  if (isDownloading) {
                    return Positioned(
                      bottom: 0,
                      left: 65,
                      right: 20,
                      child: ValueListenableBuilder<double>( // Écoute le progressNotifier
                        valueListenable: audio.progressNotifier,
                        builder: (context, progress, child) {
                          return LinearProgressIndicator(
                            value: progress, // Utilise la valeur de la progression
                            minHeight: 2.0,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget buildNumberList(BuildContext context, List<ListItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 60).floor();
        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8.0),
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                showPageDocument(widget.publication, items[index].mepsDocumentId);
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(0xFF757575),
                ),
                child: Text(
                  items[index].dataType == 'number'
                      ? items[index].displayTitle
                      : items[index].title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildBibleBooksList(BuildContext context, List<ListItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        double screenWidth = constraints.maxWidth;

        // Définir la largeur minimale souhaitée pour chaque tuile.
        // 55.0 est une bonne valeur pour obtenir des tuiles plus petites que 60.
        const double minTileWidthPortrait = 55.0;

        // Calculer le nombre de tuiles en fonction de la largeur de l'écran.
        // On augmente le crossAxisCount en portrait pour obtenir des tuiles plus petites.
        int crossAxisCount = isLandscape
            ? (screenWidth / 140).floor() // Valeur inchangée pour le paysage (rectangles)
            : (screenWidth / minTileWidthPortrait).floor(); // Augmenté pour le portrait

        // S'assurer qu'il y a au moins une colonne
        crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2.0, // Espacement augmenté pour un look moderne et aéré
            mainAxisSpacing: 2.0,   // Espacement augmenté
            childAspectRatio: isLandscape
                ? 2.5
                : 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                showPage(LocalChapterBiblePage(
                    bible: widget.publication,
                    book: items[index].bibleBookId!
                ));
              },
              child: Container(
                alignment: isLandscape ? Alignment.centerLeft : Alignment.center,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: TypeColors.generateTypeColor(context, items[index].groupId!),
                ),
                child: Text(
                  isLandscape
                      ? items[index].landscapeDisplayTitle
                      : items[index].title,
                  style: TextStyle(
                    color: Colors.white,
                    // Diminuer légèrement la taille de police pour les tuiles plus petites
                    fontSize: isLandscape ? 20 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCircuitMenu() {
    // Récupération de la couleur de texte en fonction du thème
    final textColor = Theme
        .of(context)
        .brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Liste des éléments dans une colonne
        _isLoading ? Center(child: CircularProgressIndicator()) : Column(
          children: _tabsWithItems.first.items.map<Widget>((item) {
            bool hasImageFilePath = _tabsWithItems.first.items.any((
                item) => item.imageFilePath != '');

            if (item.isTitle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 19.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Divider(
                          color: Color(0xFFa7a7a7),
                          height: 1,
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                  ...item.subItems.map<Widget>((subItem) {
                    return buildNameItem(context, hasImageFilePath, subItem);
                  }),
                ],
              );
            }
            else {
              return buildNameItem(context, hasImageFilePath, item);
            }
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme
          .of(context)
          .brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return !widget.showAppBar
        ? _buildCircuitMenu()
        : Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Color(0xFFf1f1f1),
      resizeToAvoidBottomInset: false,
      appBar: _isSearching
          ? AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isSearching = false;
              });
            },
          ),
          title: SearchFieldWidget(
            query: '',
            onSearchTextChanged: (text) {
              fetchSuggestions(text);
              return null;
            },
            onSuggestionTap: (item) async {
              // Accéder à l'élément encapsulé
              String query = item.item!['word']; // Utilise 'item.item' au lieu de 'item['query']'

              showPage(
                PublicationSearchView(
                  query: query,
                  publication: widget.publication,
                  documentsManager: _documentsManager
                ),
              );

              setState(() {
                _isSearching = false;
              });
            },
            onSubmit: (text) async {
              setState(() {
                _isSearching = false;
              });
              showPage(
                PublicationSearchView(
                  query: text,
                  publication: widget.publication,
                  documentsManager: _documentsManager
                ),
              );
            },
            onTapOutside: (event) {
              setState(() {
                _isSearching = false;
              });
            },
            suggestions: suggestions,
          )
      ) : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                widget.publication.issueTitle.isNotEmpty
                    ? widget.publication.issueTitle
                    : widget.publication.shortTitle,
                style: textStyleTitle),
            Text(
                "${widget.publication.mepsLanguage.vernacular} · ${widget.publication.keySymbol}",
                style: textStyleSubtitle),
          ],
        ),
        leading: widget.biblePage ? null : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
          },
        ),
        actions: [
          ResponsiveAppBarActions(
            allActions: [
              IconTextButton(
                text: "Rechercher",
                icon: Icon(JwIcons.magnifying_glass),
                onPressed: () async {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              IconTextButton(
                text: "Marque-pages",
                icon: Icon(JwIcons.bookmark),
                onPressed: () async {
                  Bookmark? bookmark = await showBookmarkDialog(
                      context, widget.publication);
                  if (bookmark != null) {
                    if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) {
                      showPageBibleChapter(widget.publication, bookmark.location.bookNumber!, bookmark.location.chapterNumber!, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier);
                    }
                    else if (bookmark.location.mepsDocumentId != null) {
                      showPageDocument(widget.publication, bookmark.location.mepsDocumentId!, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier);
                    }
                  }
                },
              ),
              IconTextButton(
                text: "Langues",
                icon: Icon(JwIcons.language),
                onPressed: () async {
                  if(widget.biblePage) {
                    showLanguagePubDialog(context, null).then((languageBible) async {
                      if (languageBible != null) {
                        String bibleKey = languageBible.getKey();
                        JwLifeSettings().lookupBible = bibleKey;
                        setLookUpBible(bibleKey);

                        GlobalKeyService.bibleKey.currentState?.refreshBiblePage();
                      }
                    });
                  }
                  else {
                    showLanguagePubDialog(context, widget.publication).then((languagePub) async {
                      if(languagePub != null) {
                        languagePub.showMenu(context);
                      }
                    });
                  }
                },
              ),
              IconTextButton(
                text: "Ajouter un widget sur l'écran d'accueil",
                icon: Icon(JwIcons.article),
                onPressed: () async {
                  //String imagePath = widget.publication['Path'] + '/' + widget.publication['ImageSqr'].split('/').last;
                  //updateHomeScreenWidget(widget.publication['Title'], imagePath);
                },
              ),
              IconTextButton(
                text: "Télécharger les médias",
                icon: const Icon(JwIcons.cloud_arrow_down),
                onPressed: () {
                  //showPage(Container());
                },
              ),
              IconTextButton(
                text: "Historique",
                icon: const Icon(JwIcons.arrow_circular_left_clock),
                onPressed: () {
                  History.showHistoryDialog(context);
                },
              ),
              IconTextButton(
                text: "Envoyer le lien",
                icon: Icon(JwIcons.share),
                onPressed: () {
                  widget.publication.shareLink();
                },
              ),
            ],
          ),
        ],
      ),
      body: _buildPublication(),
    );
  }

  Widget _buildPublication() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Cas 1 : Aucune tab
    if (_tabsWithItems.isEmpty) {
      return Center(child: Text("Aucun contenu disponible ou la publication a un problème."));
    }

    // Cas 2 : Une seule tab → on affiche directement son contenu dans une ListView
    if (_tabsWithItems.length == 1) {
      final tabWithItems = _tabsWithItems.first;

      bool hasImageFilePath = tabWithItems.items.any((item) => item.imageFilePath != '');

      final List<Widget> items = [];

      // Partie image + titre + description
      if (widget.publication.category.id != 1) {
        if (widget.publication.imageLsr != null) {
          items.add(
            GestureDetector(
              onTap: () {
                showPage(
                  ImagePage(
                    filePath:
                    '${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}',
                  ),
                );
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          tileColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF4f4f4f)
                              : Colors.white,
                          leading: const Icon(Icons.download),
                          title: const Text('Enregistrer l’image'),
                          onTap: () async {
                            final imagePath =
                                '${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}';
                            final file = File(imagePath);

                            if (await file.exists()) {
                              try {
                                await Gal.putImage(file.path);
                                showBottomMessageWithAction(
                                  'Image enregistrée',
                                  SnackBarAction(
                                    label: 'Ouvrir',
                                    onPressed: () async {
                                      await Gal.open();
                                    },
                                  ),
                                );
                              } on GalException catch (e) {
                                log(e.type.message);
                              }
                            } else {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fichier introuvable')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Image.file(
                File(
                    '${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}'),
                fit: BoxFit.fill,
                width: double.infinity,
              ),
            ),
          );
        }

        items.add(const SizedBox(height: 15));

        items.add(
          Text(
            widget.publication.coverTitle.isNotEmpty ? widget.publication.coverTitle : widget.publication.title,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        );

        if (widget.publication.description.isEmpty) {
          items.add(const SizedBox(height: 15));
        }
        else {
          items.add(
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextHtmlWidget(
                text: widget.publication.description,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 15,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                isSearch: false,
              ),
            ),
          );
        }
      }

      // Partie items
      if (tabWithItems.tab['DataType'] == 'number') {
        items.add(
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: buildNumberList(context, tabWithItems.items),
          ),
        );
      } else {
        for (var item in tabWithItems.items) {
          if (item.isTitle) {
            items.add(
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Divider(color: Color(0xFFa7a7a7), height: 1),
                    const SizedBox(height: 10),
                    if (item.isBibleBooks)
                      buildBibleBooksList(context, item.subItems)
                    else
                      ...item.subItems.map((subItem) => buildNameItem(context, hasImageFilePath, subItem)),
                  ],
                ),
              ),
            );
          }
          else {
            items.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: buildNameItem(context, hasImageFilePath, item),
              ),
            );
          }
        }
      }

      items.add(const SizedBox(height: 20));

      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      );
    }

    bool isBible = widget.publication.category.id == 1;

    // Cas 3 : Plusieurs tabs → affichage complet avec TabBar + TabBarView
    return DefaultTabController(
      length: _tabsWithItems.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
        [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isBible) ...[
                  if (widget.publication.imageLsr != null)
                    Image.file(
                      File('${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}'),
                      fit: BoxFit.fill,
                      width: double.infinity,
                    ),
                  const SizedBox(height: 15),
                  Text(
                    widget.publication.coverTitle.isNotEmpty
                        ? widget.publication.coverTitle
                        : widget.publication.title,
                    style: TextStyle(
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.publication.description.isNotEmpty)
                    const SizedBox(height: 15),
                  if (widget.publication.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextHtmlWidget(
                        text: widget.publication.description,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        isSearch: false,
                      ),
                    ),
                ],
                // TabBar (si plus d'un onglet)
                !isBible ? TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.black,
                  dividerHeight: 0,
                  labelStyle: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                  unselectedLabelStyle: TextStyle(
                      fontSize: 15, letterSpacing: 2),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorPadding: EdgeInsets.symmetric(vertical: 5.0),
                  labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
                  tabs: _tabsWithItems.map((tabWithItems) {
                    return Tab(text: tabWithItems.tab['Title'] ?? 'Tab');
                  }).toList(),
                ) : Container(
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF111111) : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    dividerHeight: 1,
                    dividerColor: Color(0xFF686868),
                    tabs: _tabsWithItems.map((tabWithItems) {
                      return Tab(text: tabWithItems.tab['Title'] ?? 'Tab');
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabsWithItems.map((tabWithItems) {
            if (tabWithItems.tab['DataType'] == 'number') {
              return buildNumberList(context, tabWithItems.items);
            }

            bool hasImageFilePath = tabWithItems.items.any((item) => item.imageFilePath != '');

            return ListView.builder(
              padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 20.0),
              itemCount: tabWithItems.items.length,
              itemBuilder: (context, index) {
                final item = tabWithItems.items[index];

                if (item.isTitle) {
                  return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: Theme
                                  .of(context)
                                  .brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Divider(color: Color(0xFFa7a7a7), height: 1),
                          SizedBox(height: 10),
                          if (item.isBibleBooks)
                            buildBibleBooksList(context, item.subItems),
                          if (!item.isBibleBooks)
                            ...item.subItems.map((subItem) =>
                                buildNameItem(context, item.subItems.any((subItem) => subItem.imageFilePath.isNotEmpty), subItem)),
                        ],
                      ));
                }
                else {
                  if (tabWithItems.items.indexOf(item) == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: buildNameItem(context, hasImageFilePath, item),
                    );
                  }
                  return buildNameItem(context, hasImageFilePath, item);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  int _latestRequestId = 0;

  Future<void> fetchSuggestions(String text) async {
    final int requestId = ++_latestRequestId;

    if (text.isEmpty) {
      if (requestId != _latestRequestId) return;
      setState(() {
        suggestions.clear();
      });
      return;
    }

    String normalizedText = normalize(text);

    List<String> words = normalizedText.split(' ');
    List<Map<String, dynamic>> allSuggestions = [];

    for (String word in words) {
      final suggestionsForWord = await _documentsManager.database.rawQuery(
        '''
      SELECT Word
      FROM Word
      WHERE Word LIKE ?
      ''',
        ['%$word%'],
      );

      allSuggestions.addAll(suggestionsForWord);
      if (requestId != _latestRequestId) return;
    }

    // Trier par similarité avec le texte tapé
    allSuggestions.sort((a, b) {
      double simA = StringSimilarity.compareTwoStrings(normalize(a['Word']), normalizedText);
      double simB = StringSimilarity.compareTwoStrings(normalize(b['Word']), normalizedText);
      return simB.compareTo(simA); // du plus similaire au moins similaire
    });

    List<Map<String, dynamic>> suggs = [];
    for (Map<String, dynamic> suggestion in allSuggestions) {
      suggs.add({
        'type': 0,
        'query': text,
        'word': suggestion['Word'],
      });
    }

    if (requestId != _latestRequestId) return;

    setState(() {
      suggestions = suggs;
    });
  }
}

  class TypeColors {
  static Color generateTypeColor(BuildContext context, int groupId) {
    final primaryColor = Theme.of(context).primaryColor;

    // Vous pouvez ajuster les couleurs selon le groupId
    switch (groupId) {
      case 0:
        return primaryColor.withOpacity(0.5);
      case 1:
        return primaryColor.withOpacity(1.0); // Variante plus claire
      case 2:
        return primaryColor.withOpacity(0.7); // Variante intermédiaire
      case 3:
        return primaryColor.withOpacity(0.4);
      case 4:
        return primaryColor.withOpacity(0.5);
      case 5:
        return primaryColor.withOpacity(1.0); // Variante plus claire
      case 6:
        return primaryColor.withOpacity(0.7); // Variante intermédiaire
      case 7:
        return primaryColor.withOpacity(0.5);
      default:
        return primaryColor; // Valeur par défaut si le groupId ne correspond à aucun cas
    }
  }
}
