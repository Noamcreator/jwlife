import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/pages/library_pages/publication_pages/local/page_local_document.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../utils/icons.dart';

class ListItem {
  final String title;
  final String featureTitle;
  final String imageFilePath;
  final int documentId;
  final bool isTitle; // Pour savoir si c'est un titre avec des sous-éléments
  final List<ListItem> subItems; // Liste des sous-éléments (si applicable)

  ListItem({
    this.documentId = -1,
    this.title = '',
    this.featureTitle = '',
    this.imageFilePath = '',
    this.isTitle = false,
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
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  // Méthode pour initialiser la base de données
  Future<void> _initDatabase() async {
    try {
      _database = await openDatabase(widget.publication['DatabasePath']);
      await _fetchItems(); // Charger les éléments après l'initialisation de la base de données
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      throw Exception(
          'Erreur lors de l\'initialisation de la base de données: $e');
    }
  }

  // Méthode pour récupérer les éléments et organiser les données
  Future<void> _fetchItems() async {
    try {
      List<TabWithItems> tabsWithItems = [];

      // Récupérer les onglets principaux
      List<Map<String, dynamic>> tabs = await _database!.query(
          'PublicationViewItem', where: 'ParentPublicationViewItemId = -1');

      // Pour chaque onglet, récupérer les éléments associés
      for (Map<String, dynamic> tab in tabs) {
        List<Map<String, dynamic>> items = await _database!.rawQuery('''
  SELECT 
    PublicationViewItem.PublicationViewItemId,
    PublicationViewItem.Title,
    PublicationViewItem.DefaultDocumentId,
    Document.DocumentId,
    Document.FeatureTitle,
    Multimedia.FilePath
FROM PublicationViewItem
LEFT JOIN Document
    ON PublicationViewItem.DefaultDocumentId = Document.DocumentId
LEFT JOIN DocumentMultimedia
    ON DocumentMultimedia.DocumentId = Document.DocumentId
LEFT JOIN Multimedia
    ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
WHERE PublicationViewItem.ParentPublicationViewItemId = ? 
  AND (Multimedia.MultimediaId IS NULL OR (Multimedia.Width = 600 AND Multimedia.Height = 600));
''', [tab['PublicationViewItemId']]);

        // Convertir les items en ListItem pour stockage et affichage
        List<ListItem> itemList = await Future.wait(items.map((item) async {
          if (item['DefaultDocumentId'] == -1) {
            // C'est un titre avec sous-éléments
            List<Map<String, dynamic>> subItemsData = await _database!.rawQuery('''
  SELECT 
      PublicationViewItem.PublicationViewItemId,
      PublicationViewItem.DefaultDocumentId,
      Document.DocumentId,
      Document.Title,
      Document.FeatureTitle,
      Document.ContextTitle,
      Multimedia.FilePath
  FROM PublicationViewItem
  LEFT JOIN Document
      ON PublicationViewItem.DefaultDocumentId = Document.DocumentId
  LEFT JOIN DocumentMultimedia
      ON DocumentMultimedia.DocumentId = Document.DocumentId
  LEFT JOIN Multimedia
      ON DocumentMultimedia.MultimediaId = Multimedia.MultimediaId
  WHERE PublicationViewItem.ParentPublicationViewItemId = ?
    AND (Multimedia.MultimediaId IS NULL OR (Multimedia.Width = 600 AND Multimedia.Height = 600))
''', [item['PublicationViewItemId']]);

            List<ListItem> subItems = subItemsData.map((subItem) {
              return ListItem(
                documentId: subItem['DocumentId'] ?? -1,
                title: subItem['Title'],
                featureTitle: subItem['FeatureTitle'] ?? subItem['ContextTitle'] ?? '',
                imageFilePath: subItem['FilePath'] ?? '',
              );
            }).toList();

            return ListItem(
              title: item['Title'],
              isTitle: true,
              subItems: subItems,
            );
          }
          else {
            // C'est un item normal
            return ListItem(
              documentId: item['DocumentId'] ?? -1,
              title: item['Title'],
              featureTitle: item['FeatureTitle'] ?? '',
              imageFilePath: item['FilePath'] ?? '',
              isTitle: false,
            );
          }
        }).toList());

        tabsWithItems.add(TabWithItems(tab: tab, items: itemList));
      }

      setState(() {
        _tabsWithItems = tabsWithItems;
        _isLoading = false; // Les données sont chargées, arrêter le loader
        _tabController = TabController(length: _tabsWithItems.length, vsync: this);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Erreur lors de la récupération des données : $e');
    }
  }

  Widget buildItem(BuildContext context, dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                return PageLocalDocumentView(
                  publication: widget.publication,
                  documentId: item.documentId,
                );
              },
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage de l'image ou d'un conteneur de remplacement
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 65.0, // Largeur fixe
                height: 65.0, // Hauteur fixe égale à la largeur
                child: item.imageFilePath?.isNotEmpty == true
                    ? ClipRRect(
                  child: Image.file(
                    File(widget.publication['Path'] + '/' + item.imageFilePath),
                    fit: BoxFit.cover,
                  ),
                )
                    : Container(
                  color: const Color(0xFF8e8e8e), // Couleur de fond par défaut
                ),
              ),
            ),
            // Affichage du texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.featureTitle?.isNotEmpty == true) ...[
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
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Envoyer le lien'),
                  onTap: () {
                    // Action pour cette option
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.publication['ShortTitle'] ?? 'Publication Menu Local',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
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
                          widget.publication['Title'] ?? '',
                          style: TextStyle(
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
                  return ListView.builder(
                    itemCount: tabWithItems.items.length,
                    itemBuilder: (context, index) {
                      final item = tabWithItems.items[index];

                      if (item.isTitle) {
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
                                    style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
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
                              return buildItem(context, subItem);
                            }).toList(),
                          ],
                        );
                      } else {
                        return buildItem(context, item);
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
