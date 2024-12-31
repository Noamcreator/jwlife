import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // N'oubliez pas d'importer http pour fetchHyperlink
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; // Importer pour json.decode

import '../../jwlife.dart';
import '../../utils/icons.dart';

import '../../video/FullScreenVideoPlayer.dart';
import '../../widgets/htmlView/html_widget.dart';
import '../library_pages/publication_pages/online/full_screen_image_view.dart';
import '../library_pages/publication_pages/publication_notes_view.dart';

class LifeAndMinistryPage extends StatefulWidget {
  final String doc;
  final int docId;

  const LifeAndMinistryPage({Key? key, required this.doc, required this.docId}) : super(key: key);

  @override
  _LifeAndMinistryPageState createState() => _LifeAndMinistryPageState();
}

class _LifeAndMinistryPageState extends State<LifeAndMinistryPage> {
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  bool _isLoading = true;
  dynamic _pubJson = {};
  List<Map<String, String>> _images = [];
  bool _showNotes = false;
  bool _showVerseDialog = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInputFields();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadInputFields() async {
    int lang = JwLifeApp.currentLanguage.id;
    var inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(widget.docId, lang);
    setState(() {
      _textInputs = inputFields; // Store the result in the variable
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleNotesView() {
    setState(() {
      if (!_showNotes) {
        _scrollPosition = _scrollController.position.pixels;
      }
      _showNotes = !_showNotes;

      if (!_showNotes) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.jumpTo(_scrollPosition);
        });
      }
    });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showNotes
          ? PublicationNotesView(docId: widget.docId)
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
                  widget.doc,
                  textStyle: const TextStyle(fontSize: 21),
                  onTapUrl: (url) async {
                    if (url.startsWith('https://wol.jw.org')) {
                      launchUrl(Uri.parse(url));
                    }
                    if (url.startsWith('https://www.jw.org/')) {
                      print('Opening $url');
                      bool? result = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text('Ouvrir le lien'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(false); // Fermer le dialogue sans ouvrir le lien
                                },
                                child: Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final uri = Uri.parse(url);
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                        return FullScreenVideoPlayer(
                                            lank: uri.queryParameters['lank']!,
                                            lang: uri.queryParameters['wtlocale']!
                                        );
                                      },
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  );
                                  //Navigator.of(context).pop(true); // Fermer le dialogue
                                },
                                child: Text('Lire'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    else {
                      await fetchHyperlink(url);
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
                    if (htmlElement.classes.contains('du-bgColor--black'))
                    {
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
                    else if (htmlElement.classes.contains('du-color--textSubdued')) {
                      styles['color'] = '#626262';
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
                    /*
                    if (element.classes.contains('dc-icon--music'))
                    {
                      return Row(
                        children: [
                          Icon(JwIcons.music),
                          HtmlWidget(
                            element.outerHtml,
                          )
                        ],
                      );
                    }

                     */
                    if (element.localName == 'input') {
                      var textFieldValue = '';
                      for (final textField in _textInputs) {
                        if (element.attributes['id'] == textField["TextTag"]) {
                          textFieldValue = textField["Value"];
                        }
                      }
                      if (element.attributes['type'] == 'text') {
                        return TextField(
                          controller: TextEditingController(text: textFieldValue),
                          maxLines: 1,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                          ),
                        );
                      }
                      if (element.attributes['type'] == 'checkbox') {
                        return Checkbox(
                          value: textFieldValue == '1' ? true : false,
                          onChanged: (value) {},
                        );
                      }
                    }
                    if (element.localName == 'textarea') {
                      var textFieldValue = '';
                      for (final textField in _textInputs) {
                        if (element.attributes['id'] == textField["TextTag"]) {
                          textFieldValue = textField["Value"];
                        }
                      }
                      return TextField(
                        controller: TextEditingController(text: textFieldValue),
                        maxLines: null,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                        ),
                      );
                    }
                    if (element.localName == 'figure') {
                      // Vérifier si le 'figure' contient un lien vidéo
                      var anchor = element.querySelector('a');
                      if (anchor != null && anchor.attributes['data-video'] != null) {
                        final videoUrl = anchor.attributes['href']!;
                        print("Lien vidéo : $videoUrl");

                        // Récupérer l'image dans le 'figure'
                        var image = element.querySelector('img');
                        if (image != null) {
                          final imageUrl = "https://wol.jw.org" + image.attributes['src']!;

                          Map<String, String> img = {
                            'imageUrl': imageUrl,
                            'videoUrl': videoUrl,
                            'description': image.attributes['alt'] ?? '',
                            'type': 'video',
                          };

                          _images.add(img);

                          return GestureDetector(
                            child: CachedNetworkImage(imageUrl: imageUrl),
                            onTap: () {
                              final uri = Uri.parse(videoUrl);

                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                    return FullScreenVideoPlayer(
                                        lank: uri.queryParameters['lank']!,
                                        lang: uri.queryParameters['wtlocale']!
                                    );
                                  },
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                          );
                        }
                      }
                      else if (anchor == null) {
                        // Récupérer l'image dans le 'figure'
                        var image = element.querySelector('img');
                        if (image != null) {
                          final imageUrl = "https://wol.jw.org" + image.attributes['src']!;

                          // Ajouter les informations dans les listes
                          Map<String, String> img = {
                            'imageUrl': imageUrl,
                            'description': image.attributes['alt'] ?? '',
                            'type': 'image',
                          };

                          _images.add(img);

                          return GestureDetector(
                            child: CachedNetworkImage(imageUrl: imageUrl),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                    return FullScreenImageView(
                                      images: _images,
                                      image: img,
                                    );
                                  },
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                          );
                        }
                      }
                    }
                    return null;
                  },
                ),
              ),
              _showVerseDialog ? VerseDialogItem(verses: _pubJson, onClose: closeVerseDialog) : Container(),
            ],
          )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleNotesView,
        elevation: 6.0,
        shape: const CircleBorder(),
        child: Icon(
          _showNotes ? JwIcons.arrow_to_bar_right : JwIcons.gem,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class VerseDialogItem extends StatefulWidget {
  final dynamic verses;
  final Function onClose; // Callback pour fermer le dialogue

  const VerseDialogItem({
    Key? key,
    required this.verses,
    required this.onClose,
  }) : super(key: key);

  @override
  _VerseDialogItemState createState() => _VerseDialogItemState();
}

class _VerseDialogItemState extends State<VerseDialogItem> {
  double xPosition = 0;
  double yPosition = 0;
  Map<String, dynamic> position = {'x': 0, 'y': 0};
  bool isFullScreen = false; // État pour le mode plein écran

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: yPosition,
      left: xPosition,
      child: GestureDetector(
        onPanUpdate: (tapInfo) {
          setState(() {
            if (!isFullScreen) {
              xPosition += tapInfo.delta.dx;
              yPosition += tapInfo.delta.dy;
            }
          });
        },
        child: Material( // Ajout d'un Material pour la surface du dialogue
          elevation: 4.0,
          child: Container(
            width: isFullScreen ? MediaQuery.of(context).size.width : 300,
            height: isFullScreen ? MediaQuery.of(context).size.height : 250,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                // Section du titre
                Container(
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF424242) : Color(0xFFd8d7d5),
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.verses["title"],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        // Bouton pour agrandir
                        icon: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                        onPressed: () {
                          setState(() {
                            isFullScreen = !isFullScreen; // Change l'état plein écran
                            if (isFullScreen) {
                              position = {'x': xPosition, 'y': yPosition}; // Enregistrer la position
                              xPosition = 0; // Réinitialiser la position si on quitte le plein écran
                              yPosition = 0;
                            }
                            else {
                              xPosition = position['x']; // Restaurer la position si on quitte le plein écran
                              yPosition = position['y'];
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          widget.onClose(); // Appel du callback pour fermer
                        },
                      ),
                    ],
                  ),
                ),
                // Section du thumbnail et des informations
                Container(
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF262626) : Color(0xFFf2f1ef),
                  child: Row(
                    children: [
                      // Thumbnail
                      Image.network(
                        "https://wol.jw.org" + widget.verses["items"][0]["imageUrl"],
                        width: 50, // Largeur du thumbnail
                        height: 50, // Hauteur du thumbnail
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      // Informations à droite
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.verses["items"][0]["title"],
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.verses["items"][0]["publicationTitle"],
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Section du contenu
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: HtmlWidget(
                      widget.verses["items"][0]["content"],
                      textStyle: const TextStyle(fontSize: 18),
                      customWidgetBuilder: (htmlElement) {
                        if (htmlElement.localName != 'a') {
                          /*
                          return SelectableText(
                            htmlElement.text, // Extraire uniquement le texte
                            style: const TextStyle(fontSize: 18),
                            showCursor: true, // Permet le surlignage
                            toolbarOptions: const ToolbarOptions(copy: true), // Copier le texte
                          );

                           */
                        }
                        return null;
                      },
                      customStylesBuilder: (htmlElement) {
                        if (widget.verses["items"][0]["categories"][0] == "bi") {
                          if (htmlElement.localName == 'p') {
                            return {
                              'font-family': 'Wt-ClearText',
                            };
                          }
                          // Styles pour les liens
                          if (htmlElement.localName == 'a') {
                            return {
                              'text-decoration': 'none',
                              'color': Theme.of(context).brightness == Brightness.dark ? '#9fb9e3' : '#4a6da7',
                              'font-family': 'NotoSans',
                              'font-weight': 'bold',
                            };
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
