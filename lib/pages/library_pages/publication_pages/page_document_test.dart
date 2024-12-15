import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as html_dom;
import 'package:share_plus/share_plus.dart';

import '../../../jwlife.dart';
import '../../../utils/icons.dart';
import '../../../utils/shared_preferences_helper.dart';
import '../../../utils/utils.dart';
import '../../../utils/utils_document.dart';
import '../../personal_page/note_page.dart';

class PagesDocumentViewTest extends StatefulWidget {
  final Map<String, dynamic> publication;
  final int currentIndex;
  final List<Map<String, dynamic>> navCards;

  const PagesDocumentViewTest({
    Key? key,
    required this.publication,
    required this.currentIndex,
    required this.navCards,
  }) : super(key: key);

  @override
  _PagesDocumentViewTestState createState() => _PagesDocumentViewTestState();
}

class _PagesDocumentViewTestState extends State<PagesDocumentViewTest> {
  late InAppWebViewController _controller;
  String _title = '';
  String _htmlFile = '';
  List<Map<String, String>> _images = [];
  List<Map<String, dynamic>> _textInputs = []; // Store the input fields here
  List<Map<String, dynamic>> _blockRange = []; // Store the input fields here
  dynamic _pubJson = {};
  bool _showVerseDialog = false;
  Map<String, double> _verseDialogPosition = {'x': 0, 'y': 0};
  bool _isLoading = true; // Indique si WebView est prêt

  @override
  void initState() {
    super.initState();
    fetchData(widget.navCards[widget.currentIndex]['link']!);
  }

  Future<void> fetchData(String docLink) async {
    try {
      final uri = Uri.parse(docLink);
      final pathSegments = uri.pathSegments;
      final newPath = pathSegments.skip(1).join('/');
      final response = await http.get(Uri.parse('https://wol.jw.org/' + newPath));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final title = convertHtmlToText(json['title']);
        final content = json['content'] ?? '';
        final articleClasses = json['articleClasses'] + ' layout-reading layout-sidebar' ?? '';

        setState(() {
          _title = title;
        });

        _htmlFile = await createHtmlContent(context, content, articleClasses);
        loadUserdata();

        setState(() {
          _isLoading = false;
        });
      }
      else {
        throw Exception('Failed to load the document.');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> loadUserdata() async {
    int lang = JwLifeApp.currentLanguage.id;
    var inputFields = await JwLifeApp.userdata.getInputFieldsFromDocId(widget.navCards[widget.currentIndex]['docId']!, lang);
    var blockRange = await JwLifeApp.userdata.getHightlightsFromDocId(widget.navCards[widget.currentIndex]['docId']!, lang);
    print('inputFields: $inputFields');
    print('blockRange: $blockRange');
    setState(() {
      _textInputs = inputFields; // Store the result in the variable
      _blockRange = blockRange; // Store the result in the variable
    });
  }

  Future<void> fetchHyperlink(String docLink) async {
    try {
      final response = await http.get(Uri.parse(docLink));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body); // Changez cela si nécessaire

        // Vérifiez que 'items' existe et récupérez le contenu
        if (jsonResponse['items'].isNotEmpty) {
          // Vérifie si un élément avec le 'docId' existe dans 'navCards'
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
  }

  Future<void> closeVerseDialog() async {
    setState(() {
      _showVerseDialog = false;
    });
  }

  void _openFullScreenImageView(String url, String alt) {
    print('url: $url');
    print('alt: $alt');

    /*
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
          return FullScreenImageView(
              images: _images,
              image: image
          );
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

     */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.publication['ShortTitle'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  child: Text('Langues'),
                  onTap: () {

                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Ajouter une note'),
                  onTap: () async {
                    int mepsDocumentId = widget.navCards[widget.currentIndex]['docId']!;
                    var note = await JwLifeApp.userdata.addNote(_title, '', 0, [], mepsDocumentId, widget.publication['IssueTagNumber'], widget.publication['KeySymbol'], widget.publication['MepsLanguageId']);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                          return NotePage(note: note);
                        },
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ).then((_) => {
                      //_toggleNotesView()
                    });
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Voir les médias'),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                          return Container();
                        },
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Envoyer le lien'),
                  onTap: () {
                    int mepsDocumentId = widget.navCards[widget.currentIndex]['docId']!;
                    Share.share(
                      'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.publication['LanguageSymbol']}&prefer=lang&docid=$mepsDocumentId',
                      subject: widget.publication['ShortTitle'],
                    );
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Mode Image'),
                  onTap: () {
                    //switchImageMode();
                  },
                ),
                PopupMenuItem<String>(
                  child: Text('Taille de police'),
                  onTap: () {
                    Future.delayed(
                      Duration.zero,
                          () => showFontSizeDialog(context, _controller),
                    );
                  },
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: _htmlFile, mimeType: 'text/html', baseUrl: WebUri('https://wol.jw.org/')),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true
              ),
              onWebViewCreated: (controller) async {
                _controller = controller;
                // Gestionnaire pour les clics sur les images
                controller.addJavaScriptHandler(
                  handlerName: 'onImageClick',
                  callback: (args) async {
                    _openFullScreenImageView(args[0], args[1]); // Gérer l'affichage de l'image
                  },
                );

                // Gestionnaire pour les modifications des champs de formulaire
                controller.addJavaScriptHandler(
                  handlerName: 'onInputChange',
                  callback: (args) async {
                    updateFieldValue(args[0], widget.publication, widget.navCards[widget.currentIndex]['docId']); // Fonction pour mettre à jour la liste _textInputs
                  },
                );
              },
              onLoadStop: (controller, url) async {
                double fontSize = await getFontSize();
                await controller.evaluateJavascript(source: "document.body.style.fontSize = '${fontSize}px';");

                // Injection de JavaScript après le chargement complet de la page
                await controller.evaluateJavascript(source: """
        // Gérer les clics sur les images
        document.querySelectorAll('img').forEach(function(img) {
          img.addEventListener('click', function() {
            window.flutter_inappwebview.callHandler('onImageClick', img.src, img.alt);
          });
        });

        // Gérer les modifications dans les champs de formulaire
        document.querySelectorAll('input, textarea').forEach(function(input) {
          const eventType = input.type === 'checkbox' ? 'change' : 'input';
          input.addEventListener(eventType, function() {
            const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
            window.flutter_inappwebview.callHandler('onInputChange', {
              tag: input.id,
              value: value
            });
          });
        });

        // Désactiver la sélection de texte
        document.body.style.userSelect = 'text';

        // Fonction pour préremplir les champs depuis _textInputs
        (function populateInputs() {
          const inputs = ${_textInputs.map((item) => """
            { tag: '${item['TextTag']}', value: \`${item['Value'] ?? ''}\` }
          """).toList()};

          inputs.forEach(function(input) {
            const element = document.getElementById(input.tag);
            if (element) {
              if (element.type === 'checkbox') {
                element.checked = input.value === '1';
              } else if (element.tagName === 'TEXTAREA' || element.type === 'text') {
                element.value = input.value;
              }
            }
          });
        })();
      """);
              },
            ),
          ),
        ],
      ),
    );
  }
}

