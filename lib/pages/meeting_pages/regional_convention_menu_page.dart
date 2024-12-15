import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../library_pages/publication_pages/pages_document_view.dart';

class RegionalConventionMenu extends StatefulWidget {
  final Map<String, dynamic> publication;

  const RegionalConventionMenu({Key? key, required this.publication}) : super(key: key);

  @override
  _RegionalConventionMenuState createState() => _RegionalConventionMenuState();
}

class _RegionalConventionMenuState extends State<RegionalConventionMenu> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _publication = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _navCards = [];

  @override
  void initState() {
    super.initState();
    _publication = Map.from(widget.publication);
    _initializeLanguageAndFetchContent();
  }

  Future<void> _initializeLanguageAndFetchContent() async {
    _publication['PublicationLink'] = 'https://wol.jw.org/wol/finder?wtlocale=${_publication['LanguageSymbol']}&pub=${_publication['KeySymbol']}';

    print(_publication['PublicationLink']);
    _fetchHtmlContent();
  }

  Future<void> _fetchHtmlContent() async {
    try {
      final response = await http.get(Uri.parse(_publication['PublicationLink']));
      if (response.statusCode == 200) {
        _parseHtml(response.body);
      } else {
        throw Exception('Failed to load publication content');
      }
    } catch (e) {
      print('Error fetching publication content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseHtml(String htmlContent) {
    var document = html_parser.parse(htmlContent);
    var directoryPageList = document.querySelector('ul.directory.pageList.clearfix');

    if (directoryPageList != null) {
      var pageTabs = directoryPageList.querySelectorAll('li.viewPage');

      // Vous pouvez choisir de récupérer les titres des pages si nécessaire ici,
      // mais pour ce cas, nous les ignorons.

      // Il n'y a pas de tabs, donc on ne fait rien ici.
    }

    // Continuer avec l'extraction du contenu sans utiliser de tabulations.
    _fetchNavCards(htmlContent);
  }

  Future<void> _fetchNavCards(String htmlContent) async {
    // Analysez le contenu HTML pour récupérer les cartes de navigation.
    var document = html_parser.parse(htmlContent);
    var directoryThumbnails = document.querySelector('ul.directory.thumbnails');
    var directoryNavCard = document.querySelector('ul.directory.navCard');

    List<Map<String, String>> navCards = [];
    String currentGroupTitle = '';

    if (directoryThumbnails != null) {
      var groups = directoryThumbnails.querySelectorAll('li.group, li.row.card.navCard');

      for (var group in groups) {
        if (group.classes.contains('group')) {
          currentGroupTitle = group
              .querySelector('.title')
              ?.text
              .trim() ?? '';
        } else {
          var anchor = group.querySelector('a');
          var link = anchor?.attributes['href'] ?? '';
          var titleElement = anchor?.querySelector('.cardLine1');
          var title = titleElement?.text.trim() ?? '';
          var detailElement = anchor?.querySelector('.cardLine2');
          var detail = detailElement?.text.trim() ?? '';
          var thumbnailElement = anchor?.querySelector('.cardThumbnail');

          var thumbnail =
              thumbnailElement
                  ?.querySelector('.cardThumbnailImage')
                  ?.attributes['src'] ?? '';

          navCards.add({
            'link': link,
            'title': title,
            'detail': detail,
            'thumbnail': thumbnail,
            'groupTitle': currentGroupTitle,
          });
        }
      }
    } else if (directoryNavCard != null) {
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
              thumbnailElement
                  ?.querySelector('.cardThumbnailImage')
                  ?.attributes['src'] ?? '';

          navCards.add({
            'link': link,
            'title': title,
            'detail': detail,
            'thumbnail': thumbnail,
            'groupTitle': currentGroupTitle,
          });
        }
      }
    }

    setState(() {
      _navCards = navCards; // Stockez toutes les cartes dans une seule liste
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Image en haut
          _publication['ImageLsr'] == null
              ? Container()
              : CachedNetworkImage(
            imageUrl: 'https://app.jw-cdn.org/catalogs/publications/' + _publication['ImageLsr'],
            fit: BoxFit.fill,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _publication['Title'],
              style: TextStyle(
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
          Expanded(
            child: _buildNavCardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCardContent() {
    return ListView.builder(
      itemCount: _navCards.length,
      itemBuilder: (context, index) {
        var card = _navCards[index];

        // Si c'est le début d'un groupe, afficher le titre du groupe
        bool isGroupTitle = (index == 0 || _navCards[index - 1]['groupTitle'] != card['groupTitle']);
        String? groupTitle = card['groupTitle'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGroupTitle && groupTitle != null && groupTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 20.0),
                child: Text(
                  groupTitle,
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: () {
                  print('Card clicked: ${card['title']}');
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                        return PagesDocumentView(
                          publication: _publication,
                          currentIndex: index,
                          navCards: _navCards, // Passez la liste des navCards
                          scrollController: ScrollController(),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 65.0,
                        height: 65.0,
                        child: card['thumbnail']!.isNotEmpty
                            ? ClipRRect(
                          child: Image.network(
                            'https://wol.jw.org/' + card['thumbnail']!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Container(
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
                              color: card['detail']!.isNotEmpty ? Colors.grey[600] : Color(0xFF4a6da7),
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
                              color: Color(0xFF4a6da7),
                              fontSize: 16.0,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      popUpAnimationStyle: AnimationStyle.lerp(AnimationStyle(curve: Curves.ease), AnimationStyle(curve: Curves.linear), 0.5),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'option1',
                          child: Text('Option 1'),
                        ),
                        PopupMenuItem(
                          value: 'option2',
                          child: Text('Option 2'),
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
}
