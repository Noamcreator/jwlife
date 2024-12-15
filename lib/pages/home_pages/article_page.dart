import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../video/FullScreenVideoPlayer.dart';
import '../../widgets/htmlView/html_widget.dart';
import '../library_pages/publication_pages/online/full_screen_image_view.dart';
import '../meeting_pages/life_and_ministry_page.dart';

class ArticlePage extends StatefulWidget {
  final String title;
  final String html;

  const ArticlePage({Key? key, required this.title, required this.html}) : super(key: key);

  @override
  _ArticlePageState createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  String _data = '';
  bool _isLoading = true;
  dynamic _pubJson = {};
  List<Map<String, String>> _images = [];
  bool _showVerseDialog = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    setState(() {
      _data = widget.html;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchHyperlink(String docLink) async {
    try {
      // Enlève 'fr' du docLink
      String modifiedDocLink = docLink.replaceFirst('/fr', '');
      final response = await http.get(Uri.parse('https://wol.jw.org' + modifiedDocLink));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body); // Changez cela si nécessaire

        // Vérifiez que 'items' existe et récupérez le contenu
        if (jsonResponse['items'].isNotEmpty) {
          setState(() {
            _pubJson = jsonResponse;
            _showVerseDialog = true;
          });
        }
      }
      else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> closeVerseDialog() async {
    setState(() {
      _showVerseDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 10.0,
          radius: const Radius.circular(8),
          interactive: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: HtmlWidget(
                  _data,
                  textStyle: const TextStyle(fontSize: 21),
                  onTapUrl: (url) async {
                    if (await canLaunch("https://jw.org" + url)) {
                      await launch("https://jw.org" + url);
                    }
                    return true;
                  },
                  customStylesBuilder: (htmlElement) {
                    Map<String, String> styles = {};

                    // Styles pour le div avec l'ID "tt9"
                    if (htmlElement.id == 'tt9') {
                      styles.addAll({
                        'border-left': 'solid 4px #cca500', // couleur de la bordure jaune
                      });
                    }

                    // Styles pour les paragraphes à l'intérieur du div
                    if (htmlElement.localName == 'p') {
                      if (htmlElement.id == 'p5') {
                        styles.addAll({
                          'font-weight': 'bold', // mettre le texte en gras
                        });
                      } else if (htmlElement.id == 'p6') {
                        styles.addAll({
                          'margin': '8px 0', // marge pour séparer les paragraphes
                        });
                      }
                    }

                    // Gérer les autres classes et éléments existants
                    if (htmlElement.classes.contains('du-bgColor--black')) {
                      styles['background-color'] = 'black';
                    } else if (htmlElement.classes.contains('du-bgColor--warmGray-50')) {
                      styles['background-color'] = '#f0eeea';
                      styles['color'] = 'black';
                    }
                    else if (htmlElement.classes.contains('du-bgColor--yellow-600')) {
                      styles['background-color'] = '#cca500';
                      styles['color'] = 'white';
                      styles['padding'] = '5px';
                    }
                    else if (htmlElement.classes.contains('du-bgColor--cyan-900')) {
                      styles['background-color'] = '#003d59';
                      styles['color'] = 'white';
                      styles['padding'] = '5px';
                    }

                    // Autres styles précédemment définis
                    if (htmlElement.classes.contains('du-color--gold-700')) {
                      styles['color'] = '#9b6d17';
                    } else if (htmlElement.classes.contains('du-color--coolGray-400')) {
                      styles['color'] = '#A7A8AA';
                    }
                    else if (htmlElement.classes.contains('du-color--teal-700')) {
                      styles['color'] = '#2a6b77';
                    }
                    else if (htmlElement.classes.contains('du-color--coolGray-700')) {
                      styles['color'] = '#375255';
                    }
                    else if (htmlElement.classes.contains('du-color--maroon-600')) {
                      styles['color'] = '#942926';
                    }

                    if (htmlElement.classes.contains('du-textAlign--center')) {
                      styles['text-align'] = 'center';
                    }

                    if (['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'ul', 'ol'].contains(htmlElement.localName)
                        || htmlElement.className == 'gen-field') {
                      styles.addAll({
                        'padding-left': '20px',
                        'padding-right': '20px',
                      });
                    }

                    if (htmlElement.localName == 'label') {
                      styles.addAll({
                        'display': 'none',
                      });
                    }

                    if (htmlElement.localName == 'figure') {
                      styles.addAll({
                        'position': 'absolute',
                        'top': '0',
                        'left': '0',
                        'width': '100%',
                        'height': '100%',
                        'margin': '0',
                        'padding': '0',
                        'box-sizing': 'border-box',
                      });
                    }

                    if (htmlElement.className == 'qu') {
                      styles.addAll({
                        'text-size': '10px',
                        'color': '#626262',
                      });
                    }

                    if (htmlElement.className == 'pubRefs') {
                      styles.addAll({
                        'color': '#626262'
                      });
                    }

                    if (htmlElement.className == 'themeScrp') {
                      styles.addAll({
                        'color': '#626262',
                        'font-family': 'Wt-ClearText'
                      });
                    }

                    if (htmlElement.localName == 'a') {
                      styles.addAll({
                        'text-decoration': 'none',
                        'color': Theme.of(context).brightness == Brightness.dark ? '#9fb9e3' : '#4a6da7',
                      });
                    }

                    if (!htmlElement.outerHtml.contains('themeScrp')) {
                      styles.addAll({
                        'font-family': 'NotoSans',
                      });
                    }

                    return styles;
                  },
                  customWidgetBuilder: (element) {
                    if (element.localName == 'span' && element.attributes.containsKey('data-img-size-lg')) {
                      final imageUrl = element.attributes['data-img-size-lg']!;
                      final imageDescription = element.attributes['data-img-att-alt'] ?? 'Image';

                      Map<String, String> image = {
                        'urlImage': imageUrl,
                        'description': imageDescription,
                        'type': 'image',
                      };

                      // Ajouter l'URL de l'image et la description dans les listes
                      _images.add(image);

                      return GestureDetector(
                        child: CachedNetworkImage(imageUrl: imageUrl),
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                return FullScreenImageView(
                                  images: _images,
                                  image: image,
                                );
                              },
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      );
                    }
                    return null;
                  },
                ),
              ),
              _showVerseDialog ? VerseDialogItem(verses: _pubJson, onClose: closeVerseDialog) : Container(),
            ],
          )
      ),
    );
  }
}
