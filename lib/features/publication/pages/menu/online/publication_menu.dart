import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../../../../core/api.dart';
import '../../../../../core/utils/utils.dart';

class PublicationMenu extends StatefulWidget {
  final Publication publication;

  const PublicationMenu({
    super.key,
    required this.publication
  });

  @override
  _PublicationMenuState createState() => _PublicationMenuState();
}

class _PublicationMenuState extends State<PublicationMenu> with SingleTickerProviderStateMixin {
  String wolLink = 'https://wol.jw.org';
  String wolLinkJwOrg = 'https://www.jw.org';
  String description = '';
  List<Map<String, String>> _tabItems = [];
  List<List<Map<String, dynamic>>> _navigationCards = [];
  final List<Map<String, dynamic>> _allNavigationCards = []; // all navigation cards for page the publication
  TabController? _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupLanguageAndLoadContent();
  }

  Future<void> _setupLanguageAndLoadContent() async {
    //Map<String, dynamic> languageData = widget.publicationLanguage;
    //if (languageData.isNotEmpty) {
    // //_publicationData['LanguageSymbol'] = languageData['LanguageSymbol'];
      //_publicationData['Title'] = languageData['Title'];
      //_publicationData['ShortTitle'] = languageData['ShortTitle'];
    //}

    if (widget.publication.issueTagNumber != 0) {
      int issueTagNumber = widget.publication.issueTagNumber;
      int year = int.parse(issueTagNumber.toString().substring(0, 4));
      int month = int.parse(issueTagNumber.toString().substring(4, 6));
      int day = int.parse(issueTagNumber.toString().substring(6, 8));

      //if (widget.publication.keySymbol == 'km') {
      //  _publicationData['Symbol'] = 'km' + issueTagNumber.toString().substring(2, 4);
      //}

      wolLink = 'https://wol.jw.org/wol/finder?wtlocale=${widget.publication.mepsLanguage.symbol}&pub=${widget.publication.symbol}&year=$year&month=$month&day=$day';
    } else {
      wolLink = 'https://wol.jw.org/wol/finder?wtlocale=${widget.publication.mepsLanguage.symbol}&pub=${widget.publication.symbol}';
    }

    wolLinkJwOrg = 'https://www.jw.org/finder?wtlocale=${widget.publication.mepsLanguage.symbol}&pub=${widget.publication.symbol}';

    printTime(wolLink);
    _fetchHtmlContent();
  }

  Future<void> _fetchHtmlContent() async {
    try {
      final response = await Api.httpGetWithHeaders(wolLink);
      if (response.statusCode == 200) {
        _extractHtmlContent(response.body);
      }
      else {
        throw Exception('Failed to load publication content');
      }
    } catch (e) {
      printTime('Error fetching publication content: $e');
      setState(() {
        _isLoading = false;
      });
    }

    if (widget.publication.issueTagNumber == 0) {
      try {
        final response = await Api.httpGetWithHeaders(wolLinkJwOrg);
        if (response.statusCode == 200) {
          _extractPublicationDescription(response.body);
        }
        else {
          throw Exception('Failed to load publication content');
        }
      } catch (e) {
        printTime('Error fetching publication content: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _extractPublicationDescription(String htmlContent) {
    var document = htmlParser.parse(htmlContent);
    var metaDescription = document.querySelector('meta[name="description"]');

    if (metaDescription != null) {
      setState(() {
        description = metaDescription.attributes['content']?.trim() ?? '';
      });
    }
  }

  void _extractHtmlContent(String htmlContent) {
    var document = htmlParser.parse(htmlContent);
    var directoryPageList = document.querySelector('ul.directory.pageList.clearfix');

    List<Map<String, String>> tabs = [];

    if (directoryPageList != null) {
      var pageTabs = directoryPageList.querySelectorAll('li.viewPage');

      for (var tab in pageTabs) {
        var anchor = tab.querySelector('a');
        var link = anchor?.attributes['href'] ?? '';
        var title = anchor?.querySelector('.title')?.text.trim() ?? '';

        tabs.add({
          'link': link,
          'title': title,
        });
      }

      setState(() {
        _tabItems = tabs;
        _navigationCards = List.generate(tabs.length, (_) => []);
        _isLoading = false;
      });

      if (tabs.isNotEmpty) {
        _tabController = TabController(length: tabs.length, vsync: this);
        for (var tab in tabs) {
          _fetchTabContent('https://wol.jw.org${tab['link']!}', tabs.indexOf(tab));
        }
      }
    } else {
      _navigationCards = List.generate(1, (_) => []);
      _extractTabHtml(htmlContent, 0);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTabContent(String tabLink, int tabIndex) async {
    try {
      final response = await Api.httpGetWithHeaders(tabLink);
      if (response.statusCode == 200) {
        _extractTabHtml(response.body, tabIndex);
      } else {
        throw Exception('Failed to load tab content');
      }
    } catch (e) {
      printTime('Error fetching tab content: $e');
    }
  }

  void _extractTabHtml(String htmlContent, int tabIndex) {
    var document = htmlParser.parse(htmlContent);
    var directoryThumbnails = document.querySelector('ul.directory.thumbnails');
    var directoryNavCard = document.querySelector('ul.directory.navCard');
    var directoryGrid = document.querySelector('ul.directory.grid');

    List<Map<String, dynamic>> navCards = [];
    String currentGroupTitle = '';

    if (directoryThumbnails != null) {
      var groups = directoryThumbnails.querySelectorAll('li.group, li.row.card.navCard');

      for (var group in groups) {
        if (group.classes.contains('group')) {
          currentGroupTitle = group.querySelector('.title')?.text.trim() ?? '';
        }
        else {
          var anchor = group.querySelector('a');
          var link = anchor?.attributes['href'] ?? '';
          var titleElement = anchor?.querySelector('.cardLine1');
          var title = titleElement?.text.trim() ?? '';
          var detailElement = anchor?.querySelector('.cardLine2');
          var detail = detailElement?.text.trim() ?? '';
          var thumbnailElement = anchor?.querySelector('.cardThumbnail');

          var thumbnail =
              thumbnailElement?.querySelector('.cardThumbnailImage')?.attributes['src'] ?? '';

          navCards.add({
            'id': _allNavigationCards.length,
            'link': link,
            'title': title,
            'detail': detail,
            'thumbnail': thumbnail,
            'type': 'navCard',
            'groupTitle': currentGroupTitle,
          });

          _allNavigationCards.add({
            'link': link,
            'docId': int.parse(link.split('/').last),
          });
        }
      }
    }
    else if (directoryNavCard != null) {
      var groups = directoryNavCard.querySelectorAll('li.group, li.row.card');

      for (var group in groups) {
        if (group.classes.contains('group')) {
          currentGroupTitle = group.querySelector('.title')?.text.trim() ?? '';
        } else {
          var anchor = group.querySelector('a');
          var link = anchor?.attributes['href'] ?? '';
          var titleElement = anchor?.querySelector('.cardLine1');
          var title = titleElement?.text.trim() ?? '';
          var detailElement = anchor?.querySelector('.cardLine2');
          var detail = detailElement?.text.trim() ?? '';
          var thumbnailElement = anchor?.querySelector('.cardThumbnail');

          var thumbnail =
              thumbnailElement?.querySelector('.cardThumbnailImage')?.attributes['src'] ?? '';

          navCards.add({
            'id': _allNavigationCards.length,
            'link': link,
            'title': title,
            'detail': detail,
            'thumbnail': thumbnail,
            'type': 'navCard',
            'groupTitle': currentGroupTitle,
          });

          _allNavigationCards.add({
            'link': link,
            'docId': int.parse(link.split('/').last),
          });
        }
      }
    }
    else if (directoryGrid != null) {
      var groups = directoryGrid.querySelectorAll('li.gridItem');

      for (var item in groups) {
        var linkElement = item.querySelector('a');
        var titleElement = item.querySelector('.title');

        if (linkElement != null && titleElement != null) {
          var link = linkElement.attributes['href'] ?? '';
          var title = titleElement.text.trim();

          navCards.add({
            'id': _allNavigationCards.length,
            'link': link,
            'title': title,
            'type': 'grid',
          });

          // Ajouter à la liste des éléments
          _allNavigationCards.add({
            'link': link,
            'docId': int.parse(link.split('/').last),
          });
        }
      }
    }
    else if (directoryGrid != null) {
      var groups = directoryGrid.querySelectorAll('li.gridItem');

      for (var item in groups) {
        var linkElement = item.querySelector('a');
        var titleElement = item.querySelector('.title');

        if (linkElement != null && titleElement != null) {
          var link = linkElement.attributes['href'] ?? '';
          var title = titleElement.text.trim();

          navCards.add({
            'id': _allNavigationCards.length,
            'link': link,
            'title': title,
            'type': 'grid',
          });

          // Ajouter à la liste des éléments
          _allNavigationCards.add({
            'link': link,
            'docId': int.parse(link.split('/').last),
          });
        }
      }
    }

    setState(() {
      _navigationCards[tabIndex] = navCards;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.publication.shortTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
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
                  //widget.publication.imageLsr == null ? Container() :
                  //ImageCachedWidget(imageUrl: widget.publication.imageLsr, fit: BoxFit.fill, width: double.infinity, pathNoImage: ''),
                  Padding(
                    padding: EdgeInsets.only(left: 12.0, right: 12.0, bottom: 10.0, top: 10.0),
                    child: Column(
                        children: [
                          Text(
                            widget.publication.title,
                            style: TextStyle(
                              fontSize: 25.0,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ]
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                        padding: EdgeInsets.only(left: 12.0, right: 12.0, bottom: 10.0),
                        child: Column(
                            children: [
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  height: 1.2,
                                ),
                              ),
                            ]
                        )
                    ),

                  if (description.isNotEmpty)
                    Divider(
                      indent: 10,
                      endIndent: 10,
                      color: Color(0xFFa7a7a7),
                      height: 1,
                    ),
                  if (description.isNotEmpty)
                    SizedBox(height: 15),
                ],
              ),
            ),
          ];
        },
        body: Column(
          children: [ // Hauteur à ajuster selon votre besoin  )
            if (_tabItems.isNotEmpty)
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
                controller: _tabController!,
                tabs: _tabItems.map((tab) => Tab(text: tab['title']!)).toList(),
              ),
            Expanded(
              child: _tabItems.isEmpty ? _buildTabContent(0) : TabBarView(
                controller: _tabController,
                children: _tabItems.map((tab) {
                  var tabIndex = _tabItems.indexOf(tab);
                  return _buildTabContent(tabIndex);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    return _navigationCards[tabIndex].isNotEmpty && _navigationCards[tabIndex][0]['type'] == 'grid' ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child:  GridView.builder(
          physics: NeverScrollableScrollPhysics(), // Empêche le défilement du GridView
          shrinkWrap: true, // Rendre le GridView adaptable à la taille du parent
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, // Nombre de colonnes
            childAspectRatio: 1.0, // Ratio d'aspect pour les éléments
            crossAxisSpacing: 3.0, // Espacement entre les colonnes
            mainAxisSpacing: 3.0, // Espacement entre les lignes
          ),
          itemCount: _navigationCards[tabIndex].length,
          itemBuilder: (context, gridIndex) {
            var gridCard = _navigationCards[tabIndex][gridIndex];
            return GestureDetector(
              onTap: () {
                printTime('Grid card clicked: ${gridCard['title']}');
                ScrollController _scrollController = ScrollController();

                /*
                showPage(context, PagesDocumentView(
                  publication: _publicationData,
                  currentIndex: gridCard['id'],
                  navCards: _allNavigationCards,
                  scrollController: _scrollController,
                ));

                 */
              },
              child: Container(
                color: Color(0xFF8e8e8e),
                child: Center(
                  child: Text(
                    gridCard['title']!,
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                ),
              ),
            );
          },
        ),
      ) : ListView.builder(
      itemCount: _navigationCards[tabIndex].length,
      itemBuilder: (context, index) {
        var card = _navigationCards[tabIndex][index];

        // Si c'est le début d'un groupe, afficher le titre du groupe
        bool isGroupTitle = (index == 0 || _navigationCards[tabIndex][index - 1]['groupTitle'] != card['groupTitle']);
        String? groupTitle = card['groupTitle'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGroupTitle && groupTitle != null && groupTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle,
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
            // Vérifiez le type de card
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () {
                    printTime('Card clicked: ${card['title']}');
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          width: 65.0, // Largeur fixe
                          height: 65.0, // Hauteur fixe égale à la largeur
                          child: card['thumbnail']!.isNotEmpty
                              ? ClipRRect(
                            child: Image.network(
                              'https://wol.jw.org/${card['thumbnail']!}',
                              headers: Api.getHeaders(),
                              fit: BoxFit.cover, // Force l'image à s'adapter à la zone et la rendre carrée
                            ),
                          ) : Container(
                            color: Color(0xFF8e8e8e),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card['title']!,
                              style: TextStyle(
                                color: card['detail']!.isNotEmpty
                                    ? Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFFc0c0c0)
                                    : Color(0xFF626262)
                                    : Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF9fb9e3)
                                    : Color(0xFF4a6da7),
                                fontSize: card['detail']!.isNotEmpty ? 15 : 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                            ),
                            if (card['detail']!.isNotEmpty) SizedBox(height: 2.0),
                            Text(
                              card['detail']!,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF9fb9e3)
                                    : Color(0xFF4a6da7),
                                fontSize: 16.0,
                                // line spacing
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        popUpAnimationStyle: AnimationStyle.lerp(
                          AnimationStyle(curve: Curves.ease),
                          AnimationStyle(curve: Curves.ease),
                          0.5,
                        ),
                        icon: Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Text('Envoyer le lien'),
                            onTap: () {
                              // Action à effectuer pour l'option 1
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
