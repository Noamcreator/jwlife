import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/data/databases/Audio.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/modules/bible/views/local_bible_chapter.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document_view.dart';
import 'package:jwlife/modules/library/views/publication/local/document/documents_manager.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_search_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield_widget.dart';
import 'package:sqflite/sqflite.dart';

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

  const PublicationMenuView({super.key, required this.publication, this.showAppBar = true});

  @override
  _PublicationMenuViewState createState() => _PublicationMenuViewState();
}

class _PublicationMenuViewState extends State<PublicationMenuView> with SingleTickerProviderStateMixin {
  late DocumentsManager _documentsManager;
  late List<TabWithItems> _tabsWithItems = [];
  late List<Audio> _audios = [];
  bool _isLoading = true;
  TabController? _tabController;
  int _initialTabIndex = 0;

  bool _isSearching = false;
  List<Map<String, dynamic>> suggestions = [];

  @override
  void initState() {
    super.initState();
    _init();

    if(widget.publication.schemaVersion != 9) {
      _iniAudio();
    }
  }

  // Méthode pour initialiser la base de données
  Future<void> _init() async {
    _documentsManager = DocumentsManager(publication: widget.publication, mepsDocumentId: -1);
    await _documentsManager.initializeDatabaseAndData();
    widget.publication.documentsManager = _documentsManager;
    await _fetchItems();
  }

  Future<void> _iniAudio() async {
    try {
      final keySymbol = widget.publication.keySymbol;
      final issueTagNumber = widget.publication.issueTagNumber.toString();
      final languageSymbol = widget.publication.mepsLanguage.symbol;

      final queryParams = {
        'pub': keySymbol,
        'issue': issueTagNumber,
        'langwritten': languageSymbol,
        'fileformat': 'mp3',
      };

      final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);
      print('Generated URL: $url');

      final response = await Dio().getUri(url, options: Options(validateStatus: (status) => status! < 500));
      print('API Response: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data.containsKey('files') && data['files'].containsKey(languageSymbol)) {
          setState(() {
            _audios = data['files'][languageSymbol]['MP3'].map<Audio>((audio) => Audio.fromJson(audio, languageSymbol: widget.publication.mepsLanguage.symbol)).toList();
          });
        }
      }
    }
    catch (e) {
      print('Error: $e');
      throw Exception('Error initializing the database: $e');
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
              WHEN pvi.ChildTemplateSchemaType != pvi.SchemaType THEN cvs.DataType
              ELSE NULL
              END,
              vs.DataType
            ) AS DataType
          FROM PublicationViewItem pvi
          LEFT JOIN PublicationViewSchema vs ON pvi.SchemaType = vs.SchemaType
          LEFT JOIN PublicationViewSchema cvs ON pvi.ChildTemplateSchemaType = cvs.SchemaType
          LEFT JOIN PublicationView pv ON pvi.PublicationViewId = pv.PublicationViewId
          WHERE pv.Symbol = 'jwpub' AND pvi.ParentPublicationViewItemId = -1;
      ''');

      // Récupérer les items et sous-items pour chaque onglet
      final List<TabWithItems> tabsWithItems = await Future.wait(tabs.map((tab) async {
        final items = await _getItemsForParent(tab['PublicationViewItemId']);

        final itemList = await Future.wait(items.map((item) async {
          if (item['DefaultDocumentId'] == -1) {
            final subItems = await _getItemsForParent(item['PublicationViewItemId']);
            bool isBibleBooks = subItems.any((subItem) => subItem['Type'] == 2);

            if (isBibleBooks && _initialTabIndex == 0) {
              _initialTabIndex = items.indexOf(item);
            }

            return ListItem(
              title: item['DisplayTitle'],
              isTitle: true,
              isBibleBooks: isBibleBooks,
              showImage: false,
              subItems: subItems.map(_mapToListItem).toList(),
            );
          }
          else {
            return _mapToListItem(item);
          }
        }));

        return TabWithItems(tab: tab, items: itemList);
      }).toList());

      setState(() {
        _tabsWithItems = tabsWithItems;
        _isLoading = false;
        _tabController = TabController(initialIndex: _initialTabIndex, length: _tabsWithItems.length, vsync: this);
      });
    }
    catch (e) {
      setState(() => _isLoading = false);
      throw Exception('Erreur lors de la récupération des données : $e');
    }
  }

  Future<bool> _checkIfTableExists(String tableName) async {
    var result = await _documentsManager.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", [tableName]);
    return result.isNotEmpty;
  }

  Future<List<String>> _getColumnsForTable(String tableName) async {
    var result = await _documentsManager.database.rawQuery("PRAGMA table_info($tableName)");
    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> _getItemsForParent(int parentId) async {

    List<Map<String, dynamic>> result = [];
    if(widget.publication.schemaVersion <= 8) {
      String query = await getVersionSchema8();
      result = await _documentsManager.database.rawQuery(query, [parentId]);
    }
    else if (widget.publication.schemaVersion == 9) {
      result = await getVersionSchema9(parentId);
    }
    return result;
  }

  Future<String> getVersionSchema8() async {
    bool multimediaExists = await _checkIfTableExists('Multimedia');
    bool documentMultimediaExists = await _checkIfTableExists('DocumentMultimedia');
    List<String> multimediaColumns = multimediaExists ? await _getColumnsForTable('Multimedia') : [];

    // Vérifier si les colonnes nécessaires existent
    bool hasMultimediaColumns = multimediaColumns.contains('Width') && multimediaColumns.contains('Height') && multimediaColumns.contains('CategoryType');

    String query = '''
  SELECT
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.ParentPublicationViewItemId,
    PublicationViewItem.Title AS DisplayTitle,
    PublicationViewItem.DefaultDocumentId,
    PublicationViewSchema.DataType,
  ''';

    // Ajouter la colonne FilePath seulement si les colonnes nécessaires existent
    if (hasMultimediaColumns) {
      query += '''
    MAX(CASE 
        WHEN Multimedia.Width = 600 AND Multimedia.Height = 600 AND Multimedia.CategoryType = 9 
        THEN Multimedia.FilePath 
        ELSE NULL 
    END) AS FilePath
    ''';
    }
    else {
      query += "NULL AS FilePath";  // Retourne NULL si les colonnes n'existent pas
    }

    query += '''
  FROM PublicationViewItem
  LEFT JOIN PublicationViewSchema ON PublicationViewItem.SchemaType = PublicationViewSchema.SchemaType
  ''';

    // Ajouter la jointure avec Multimedia uniquement si la table et les colonnes existent
    if (documentMultimediaExists) {
      query += "LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = PublicationViewItem.DefaultDocumentId ";
    }

    // Ajouter la jointure avec Multimedia uniquement si la table et les colonnes existent
    if (multimediaExists && documentMultimediaExists) {
      query += "LEFT JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId ";
    }

    query += '''
  WHERE PublicationViewItem.ParentPublicationViewItemId = ?
  GROUP BY 
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.ParentPublicationViewItemId,
    PublicationViewItem.Title,
    PublicationViewItem.DefaultDocumentId
  ''';

    return query;
  }

  Future<List<Map<String, dynamic>>> getVersionSchema9(int parentId) async {
    String query = '''
  SELECT
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.ParentPublicationViewItemId,
    PublicationViewItem.Title AS DisplayTitle,
    PublicationViewItem.DefaultDocumentId,
    PublicationViewSchema.DataType,
    Document.Type,
    BibleBook.BibleBookId,
    MAX(CASE 
        WHEN Multimedia.Width = 600 AND Multimedia.Height = 600 AND Multimedia.CategoryType = 9 
        THEN Multimedia.FilePath 
        ELSE NULL 
    END) AS FilePath
    FROM PublicationViewItem
    LEFT JOIN PublicationViewSchema ON PublicationViewItem.SchemaType = PublicationViewSchema.SchemaType
    LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = PublicationViewItem.DefaultDocumentId
    LEFT JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
    LEFT JOIN Document ON Document.DocumentId = PublicationViewItem.DefaultDocumentId
    LEFT JOIN BibleBook ON Document.ChapterNumber = BibleBook.BibleBookId
    WHERE PublicationViewItem.ParentPublicationViewItemId = ?
    GROUP BY 
      PublicationViewItem.PublicationViewItemId,
      PublicationViewItem.ParentPublicationViewItemId,
      PublicationViewItem.Title,
      PublicationViewItem.DefaultDocumentId;
  ''';

    List<Map<String, dynamic>> result = await _documentsManager.database.rawQuery(query, [parentId]);

    List<Map<String, dynamic>> items = [];
    for(var item in result) {
      if(item['Type'] == 2) {
        Map<String, dynamic> book = Map<String, dynamic>.from(item);
        File mepsFile = await getMepsFile();
        Database mepsDatabase = await openDatabase(mepsFile.path);
        List<Map<String, dynamic>> name = await mepsDatabase.rawQuery("""
          SELECT 
            bbn.StandardBookName,
            bbn.OfficialBookAbbreviation,
            bbg.GroupId
          FROM 
            BibleBookName bbn
          JOIN BibleCluesInfo bci ON bbn.BibleCluesInfoId = bci.BibleCluesInfoId
          JOIN BibleBookGroup bbg ON bbg.BookNumber = bbn.BookNumber
          WHERE 
            bbn.BookNumber = ? AND bci.LanguageId = ?
          """, [item['BibleBookId'], widget.publication.mepsLanguage.id]);

        book.addAll(name.first);
        items.add(book);
      }
      else {
        items.add(item);
      }
    }

    return items;
  }

  ListItem _mapToListItem(Map<String, dynamic> item) {
    Document document = _documentsManager.documents.firstWhere((d) => d.documentId == item['DefaultDocumentId']);
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

  Widget buildNameItem(BuildContext context, bool showImage, ListItem item) {
    String subtitle = item.subTitle.replaceAll('​', '');
    bool showSubTitle = item.subTitle.isNotEmpty && subtitle != item.title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          showPage(context, DocumentView(
            publication: widget.publication,
            audios: _audios,
            mepsDocumentId: item.mepsDocumentId,
          ));
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage de l'image ou d'un conteneur de remplacement
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: showImage ? SizedBox(
                width: 65.0, // Largeur fixe
                height: 65.0, // Hauteur fixe égale à la largeur
                child: item.imageFilePath.isNotEmpty == true
                    ? ClipRRect(
                  child: Image.file(
                    File('${widget.publication.path}/${item.imageFilePath}'),
                    fit: BoxFit.cover,
                  ),
                )
                    : Container(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e), // Couleur de fond par défaut
                ),
              ) : Container(),
            ),
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
                  const SizedBox(height: 2.0), // Espacement entre les textes
                  Text(
                    item.title,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9fb9e3)
                          : const Color(0xFF4a6da7),
                      fontSize: 15.0,
                      height: 1.2, // Espacement vertical des lignes
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
                    ? Color(0xFF8e8e8e)
                    : Color(0xFF757575),
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

                Audio? audio = _audios.firstWhereOrNull((audio) => audio.documentId == item.mepsDocumentId);
                if (audio != null) {
                  Audio localAudio = JwLifeApp.mediaCollections.getAudio(audio);

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
                          Text(
                            localAudio.isDownloaded ? "Supprimer l'audio (${formatFileSize(localAudio.fileSize)})" : "Télécharger l'audio (${formatFileSize(localAudio.fileSize)})",
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if(localAudio.isDownloaded) {
                          deleteAudio(context, widget.publication.keySymbol, widget.publication.issueTagNumber, localAudio.documentId, localAudio.track, widget.publication.mepsLanguage.symbol);
                        }
                        else {
                          downloadAudio(context, widget.publication.keySymbol, widget.publication.issueTagNumber, localAudio.documentId, localAudio.track, widget.publication.mepsLanguage.symbol,  '${widget.publication.path}/${item.imageFilePath}', audio);
                        }
                      },
                    ),
                  );

                  items.add(
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            JwIcons.headphones_simple,
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
                        int? index = _audios.indexWhere((audio) => audio.documentId == item.mepsDocumentId);
                        if (index != -1) {
                          showAudioPlayerLink(context, widget.publication, _audios, index);
                        }
                      },
                    ),
                  );
                }

                return items;
              },
            )
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
                showPage(context, DocumentView(
                  publication: widget.publication,
                  mepsDocumentId: items[index].mepsDocumentId,
                ));
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(0xFF757575),
                ),
                child: Text(
                  items[index].dataType == 'number' ? items[index].displayTitle : items[index].title,
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

        // Calculer le nombre de tuiles en fonction de la largeur de l'écran
        int crossAxisCount = isLandscape
            ? (screenWidth / 140).floor()  // Moins de tuiles en mode paysage (largeur doublée pour des rectangles)
            : (screenWidth / 60).floor();  // Plus de tuiles en mode portrait

        // S'assurer qu'il y a au moins une colonne
        crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8.0),
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
            childAspectRatio: isLandscape ? 2.5 : 1.0,  // Pour des rectangles en paysage
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                showPage(context, LocalChapterBiblePage(
                  bible: widget.publication,
                  book: items[index].bibleBookId!,
                ));
              },
              child: Container(
                alignment: isLandscape ? Alignment.centerLeft : Alignment.center,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: TypeColors.generateTypeColor(context, items[index].groupId!),
                ),
                child: Text(
                  isLandscape ? items[index].landscapeDisplayTitle : items[index].title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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

  Widget buildMenusColumns() {
    return Column(
      children: [
        // TabBar
        if (_tabsWithItems.isNotEmpty && _tabsWithItems.length > 1)
          widget.publication.schemaVersion == 9
              ? TabBar(
            isScrollable: true,
            controller: _tabController,
            tabs: _tabsWithItems
                .map((tabWithItems) =>
                Tab(text: tabWithItems.tab['Title'] ?? 'Tab'))
                .toList(),
          )
              : TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: EdgeInsets.symmetric(vertical: 5.0),
            labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
            labelColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            labelStyle: TextStyle(
              fontSize: 15,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]
                : Colors.black,
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              letterSpacing: 2,
            ),
            controller: _tabController,
            tabs: _tabsWithItems
                .map((tabWithItems) =>
                Tab(text: tabWithItems.tab['Title'] ?? 'Tab'))
                .toList(),
          ),
        // Contenu des onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabsWithItems.map((tabWithItems) {
              return tabWithItems.tab['DataType'] == 'number'
                  ? buildNumberList(context, tabWithItems.items)
                  : ListView.builder(
                itemCount: tabWithItems.items.length,
                itemBuilder: (context, index) {
                  final item = tabWithItems.items[index];

                  bool hasImageFilePath = tabWithItems.items.any((item) => item.imageFilePath != '');

                  if (item.isTitle) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 8.0, right: 8.0, top: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.bold),
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
                        if (item.isBibleBooks)
                          buildBibleBooksList(context, item.subItems),
                        if (!item.isBibleBooks)
                          ...item.subItems.map<Widget>((subItem) {
                            return buildNameItem(context, hasImageFilePath, subItem);
                          }),
                      ],
                    );
                  }
                  else {
                    return buildNameItem(context, hasImageFilePath, item);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCircuitMenu() {
    // Récupération de la couleur de texte en fonction du thème
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image en haut
        widget.publication.imageLsr == null
            ? Container()
            : Image.file(
          File('${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}'),
          fit: BoxFit.fill,
          width: double.infinity,
        ),

        // Titre de la publication
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Column(
            children: [
              Text(
                widget.publication.coverTitle.isNotEmpty
                    ? widget.publication.coverTitle
                    : widget.publication.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Liste des éléments dans une colonne
        _isLoading ? Center(child: CircularProgressIndicator()) : Column(
          children: _tabsWithItems.first.items.map<Widget>((item) {
            bool hasImageFilePath = _tabsWithItems.first.items.any((item) => item.imageFilePath != '');

            if (item.isTitle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
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
            } else {
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
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return !widget.showAppBar
        ? _buildCircuitMenu()
        : Scaffold(
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
            setState(() {
              fetchSuggestions(text);
            });
          },
          onSuggestionTap: (item) async {
            // Accéder à l'élément encapsulé
            String query = item.item!['query'];  // Utilise 'item.item' au lieu de 'item['query']'

            showPage(
              context,
              PublicationSearchView(
                query: query,
                publication: widget.publication,
                documentsManager: _documentsManager,
                audios: _audios,
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
              context,
              PublicationSearchView(
                query: text,
                publication: widget.publication,
                documentsManager: _documentsManager,
                audios: _audios,
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
                "${widget.publication.mepsLanguage.vernacular} · ${widget.publication.symbol}",
                style: textStyleSubtitle),
          ],
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
                  Map<String, dynamic>? bookmark =
                  await showBookmarkDialog(context, widget.publication);
                  if (bookmark != null) {
                    if (bookmark['BookNumber'] != null && bookmark['ChapterNumber'] != null) {
                      showPage(
                          context,
                          DocumentView.bible(
                              bible: widget.publication,
                              book: bookmark['BookNumber'],
                              chapter: bookmark['ChapterNumber'],
                              firstVerse: bookmark['BlockIdentifier'],
                              lastVerse: bookmark['BlockIdentifier']
                          )
                      );
                    }
                    else {
                      showPage(
                          context,
                          DocumentView(
                              publication: widget.publication,
                              audios: _audios,
                              mepsDocumentId: bookmark['DocumentId'],
                              startParagraphId: bookmark['BlockIdentifier'],
                              endParagraphId: bookmark['BlockIdentifier']
                          )
                      );
                    }
                  }
                },
              ),
              IconTextButton(
                text: "Langues",
                icon: Icon(JwIcons.language),
                onPressed: () async {
                  LanguagesPubDialog languageDialog =
                  LanguagesPubDialog(
                      publication: widget.publication);
                  showDialog(
                    context: context,
                    builder: (context) => languageDialog,
                  ).then((value) {
                    if (value != null) {
                      //showPage(context, PublicationMenu(publication: widget.publication, publicationLanguage: value));
                    }
                  });
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
                  //showPage(context, Container());
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
    return widget.publication.schemaVersion == 9 && _isLoading ? Center(child: CircularProgressIndicator()) : widget.publication.schemaVersion == 9 ? buildMenusColumns() :
    NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image en haut
                  widget.publication.imageLsr == null
                      ? Container()
                      : Image.file(
                    File('${widget.publication.path}/${widget.publication.imageLsr!.split('/').last}'),
                    fit: BoxFit.fill,
                    width: double.infinity,
                  ),
                  // Titre de la publication
                  Padding(
                    padding: EdgeInsets.only(left: 12.0, right: 12.0, bottom: 10.0, top: 10.0),
                    child: Column(
                      children: [
                        Text(
                          widget.publication.coverTitle.isNotEmpty ? widget.publication.coverTitle : widget.publication.title,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            fontSize: 25.0,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: _isLoading ? Center(child: CircularProgressIndicator()) : buildMenusColumns()
    );
  }

  Future<void> fetchSuggestions(String text) async {
    List<Map<String, dynamic>> suggestionsForWord = [];

    if (text.isEmpty) {
      setState(() {
        suggestions.clear();
      });
      return;
    }

    List<String> words = text.split(' ');
    for (String word in words) {
      suggestionsForWord = await _documentsManager.database.rawQuery(
        '''
      SELECT Word
      FROM Word
      WHERE Word LIKE ?
    ''',
        ['$word%'], // Seulement les mots qui commencent par "word"
      );
    }

    setState(() {
      suggestions.clear();

      for (Map<String, dynamic> suggestion in suggestionsForWord) {
        suggestions.add({
          'type': 0,
          'query': suggestion['Word'],
        });
      }
    });
  }
}

class TypeColors {
  static Color generateTypeColor(BuildContext context, int groupId) {
    final primaryColor = Theme.of(context).primaryColor;

    // Vous pouvez ajuster les couleurs selon le groupId
    switch (groupId) {
      case 0:
        return primaryColor;
      case 1:
        return primaryColor.withOpacity(0.7); // Variante plus claire
      case 2:
        return primaryColor.withOpacity(0.8); // Variante intermédiaire
      case 3:
        return primaryColor;
      case 4:
        return primaryColor;
      case 5:
        return primaryColor.withOpacity(0.7); // Variante plus claire
      case 6:
        return primaryColor.withOpacity(0.8); // Variante intermédiaire
      case 7:
        return primaryColor;
      default:
        return primaryColor; // Valeur par défaut si le groupId ne correspond à aucun cas
    }
  }
}
