import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_publication.dart';
import 'package:sqflite/sqflite.dart';

import 'page_local_document.dart';

class ListItem {
  final String displayTitle;
  final String title;
  final String featureTitle;
  final String imageFilePath;
  final String? dataType;
  final int mepsDocumentId;
  final bool isTitle; // Pour savoir si c'est un titre avec des sous-éléments
  final bool showImage;
  final List<ListItem> subItems; // Liste des sous-éléments (si applicable)

  ListItem({
    this.displayTitle = '',
    this.title = '',
    this.featureTitle = '',
    this.imageFilePath = '',
    this.dataType,
    this.mepsDocumentId = -1,
    this.isTitle = false,
    this.showImage = true,
    this.subItems = const [],
  });
}

class TabWithItems {
  final Map<String, dynamic> tab;
  final List<ListItem> items;

  TabWithItems({required this.tab, required this.items});
}

class PublicationMenuLocal extends StatefulWidget {
  final Map<String, dynamic> publication;

  const PublicationMenuLocal({
    Key? key,
    required this.publication,
  }) : super(key: key);

  @override
  _PublicationMenuLocalState createState() => _PublicationMenuLocalState();
}

class _PublicationMenuLocalState extends State<PublicationMenuLocal> with SingleTickerProviderStateMixin {
  Database? _database;
  late List<TabWithItems> _tabsWithItems = [];
  late List<dynamic> _audios = [];
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _iniAudio();
  }

  // Méthode pour initialiser la base de données
  Future<void> _initDatabase() async {
    try {
      _database = await openDatabase(widget.publication['DatabasePath']);
      await _fetchItems(); // Charger les éléments après l'initialisation de la base de données
    }
    catch (e) {
      setState(() {
        _isLoading = false;
      });
      throw Exception(
          'Erreur lors de l\'initialisation de la base de données: $e');
    }
  }

  // Méthode pour initialiser la base de données
  Future<void> _iniAudio() async {
    try {
      final queryParams = {
        'pub': widget.publication['KeySymbol'],
        'issue': widget.publication['IssueTagNumber'].toString(),
        'langwritten': widget.publication['LanguageSymbol'],
        'fileformat': 'mp3',
      };

      final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);

      final response = await Dio().getUri(url);

      if (response.statusCode == 200) {
        final data = response.data;

        final listAudios = data['files'][widget.publication['LanguageSymbol']]['MP3'];
        setState(() {
          _audios = listAudios;
        });
      }
    }
    catch (e) {

      throw Exception(
          'Erreur lors de l\'initialisation de la base de données: $e');
    }
  }

  Future<void> _fetchItems() async {
    try {
      List<Map<String, dynamic>> tabs = await _database!.rawQuery('''
    SELECT 
      PublicationViewItem.PublicationViewItemId,
      PublicationViewItem.Title,
      PublicationViewSchema.DataType
    FROM PublicationViewItem
    LEFT JOIN PublicationViewSchema ON PublicationViewItem.ChildTemplateSchemaType = PublicationViewSchema.SchemaType
    WHERE PublicationViewItem.ParentPublicationViewItemId = ?
  ''', [-1]);

      for (var tab in tabs) {
        print('tab: $tab');
      }

      // Récupérer les items et sous-items pour chaque onglet
      final List<TabWithItems> tabsWithItems = await Future.wait(tabs.map((tab) async {
        final items = await _getItemsForParent(tab['PublicationViewItemId'] as int);

        final itemList = await Future.wait(items.map((item) async {
          if (item['DefaultDocumentId'] == -1) {
            // Sous-éléments pour les titres
            final subItems = await _getItemsForParent(item['PublicationViewItemId']);
            return ListItem(
              title: item['DisplayTitle'],
              isTitle: true,
              showImage: item['FilePath'] != null,
              subItems: subItems.map(_mapToListItem).toList(),
            );
          }
          else {
            // Item normal
            return _mapToListItem(item);
          }
        }));

        return TabWithItems(tab: tab, items: itemList);
      }).toList());

      setState(() {
        _tabsWithItems = tabsWithItems;
        _isLoading = false;
        _tabController = TabController(length: _tabsWithItems.length, vsync: this);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      throw Exception('Erreur lors de la récupération des données : $e');
    }
  }

  Future<bool> _checkIfMultimediaTableExists() async {
    var result = await _database!.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Multimedia'");
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> _getItemsForParent(int parentId) async {
    bool multimediaExists = await _checkIfMultimediaTableExists();

    String query = '''
  SELECT 
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.Title AS DisplayTitle,
    PublicationViewItem.DefaultDocumentId,
    PublicationViewSchema.DataType,
    Document.*,
  ''';

    // Ajouter la condition concernant Multimedia si elle existe
    if (multimediaExists) {
      query += '''
    MAX(CASE 
        WHEN Multimedia.Width = 600 AND Multimedia.Height = 600 AND Multimedia.CategoryType = 9 
        THEN Multimedia.FilePath 
        ELSE NULL 
    END) AS FilePath
    ''';
    } else {
      query += "NULL AS FilePath";  // Retourne NULL si la table Multimedia n'existe pas
    }

    query += '''
  FROM PublicationViewItem
  LEFT JOIN PublicationViewSchema ON PublicationViewItem.SchemaType = PublicationViewSchema.SchemaType
  LEFT JOIN Document ON PublicationViewItem.DefaultDocumentId = Document.DocumentId
  LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = Document.DocumentId
  LEFT JOIN Multimedia ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
  WHERE PublicationViewItem.ParentPublicationViewItemId = ?
  GROUP BY 
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.Title,
    PublicationViewItem.DefaultDocumentId,
    Document.DocumentId;
  ''';

    return await _database!.rawQuery(query, [parentId]);
  }

  ListItem _mapToListItem(Map<String, dynamic> item) {
    return ListItem(
      title: item['Title'],
      displayTitle: item['DisplayTitle'] ?? '',
      featureTitle: item['ContextTitle'] ?? item['FeatureTitle'] ?? '',
      imageFilePath: item['FilePath'] ?? '',
      dataType: item['DataType'] ?? '',
      mepsDocumentId: item['MepsDocumentId'] ?? -1,
      isTitle: false,
    );
  }

  Widget buildNameItem(BuildContext context, bool showImage, ListItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          showPage(context, PageLocalDocumentView(
            publication: widget.publication,
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
                    File(widget.publication['Path'] + '/' + item.imageFilePath),
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
                  if (item.featureTitle.isNotEmpty == true && item.featureTitle != item.title) ...[
                    Text(
                      item.featureTitle,
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
                      // Action pour cette option
                    },
                  ),
                ];

                if (_audios.any((audio) => audio['docid'] == item.mepsDocumentId)) {
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
                        int? index = _audios.indexWhere((audio) => audio['docid'] == item.mepsDocumentId);
                        if (index != -1) {
                          Uri imageFilePath = Uri.parse(widget.publication['Path'] + '/' + item.imageFilePath);
                          showAudioPlayerLink(context, widget.publication['ShortTitle'], _audios, imageFilePath, index);
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
                showPage(context, PageLocalDocumentView(
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


  @override
  Widget build(BuildContext context) {
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
                widget.publication['IssueTitle'] != null && widget.publication['IssueTitle'] != '' ? widget.publication['IssueTitle'] : widget.publication['ShortTitle'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)
            ),
            Text(
                widget.publication['LanguageVernacularName'] != null ? widget.publication['LanguageVernacularName'] + " · " + widget.publication['Symbol'] : widget.publication['KeySymbol'] ?? '',
                style: textStyleSubtitle
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {},
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert),
            itemBuilder: (context) => [
              getPubShareMenuItem(widget.publication),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image en haut
                  widget.publication['ImageLsr'] == null
                      ? Container()
                      : Image.file(
                    File(widget.publication['Path'] + '/' +
                        widget.publication['ImageLsr']
                            .split('/')
                            .last),
                    fit: BoxFit.fill,
                    width: double.infinity,
                  ),
                  // Titre de la publication
                  Padding(
                    padding: EdgeInsets.only(
                        left: 12.0, right: 12.0, bottom: 10.0, top: 10.0),
                    child: Column(
                      children: [
                        Text(
                          widget.publication['CoverTitle'] != null && widget.publication['CoverTitle'] != '' ? widget.publication['CoverTitle'] : widget.publication['Title'] ?? '',
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
                  // Description de la publication
                  if (widget.publication['Description'] != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        widget.publication['Description'],
                        style: TextStyle(
                          fontSize: 16.0,
                          height: 1.2,
                        ),
                      ),
                    ),
                  if (widget.publication['Description'] != null)
                    Divider(
                      indent: 10,
                      endIndent: 10,
                      color: Color(0xFFa7a7a7),
                      height: 1,
                    ),
                  if (widget.publication['Description'] != null)
                    SizedBox(height: 15),
                ],
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // TabBar
            if (_tabsWithItems.isNotEmpty && _tabsWithItems.length > 1)
              TabBar(
                tabAlignment: TabAlignment.start,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorPadding: EdgeInsets.symmetric(vertical: 5.0),
                labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
                labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                labelStyle: TextStyle(
                  fontSize: 15,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.black,
                unselectedLabelStyle: TextStyle(
                  fontSize: 15,
                  letterSpacing: 2,
                ),
                controller: _tabController,
                tabs: _tabsWithItems.map((tabWithItems) =>
                    Tab(text: tabWithItems.tab['Title'] ?? 'Tab')).toList(),
              ),
            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabsWithItems.map((tabWithItems) {
                  return tabWithItems.tab['DataType'] == 'number' ? buildNumberList(context, tabWithItems.items)
                    : ListView.builder(
                    itemCount: tabWithItems.items.length,
                    itemBuilder: (context, index) {
                      final item = tabWithItems.items[index];

                      bool hasImageFilePath = tabWithItems.items.any((item) => item.imageFilePath != '');

                      if (item.isTitle) {
                        bool hasImageFilePath = item.subItems.any((item) => item.imageFilePath != '');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Afficher le titre
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold
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
                            // Afficher les sous-éléments
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
        ),
      ),
    );
  }
}
